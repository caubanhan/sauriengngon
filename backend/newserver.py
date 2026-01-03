from typing import List, Optional, Union
import os
import json
import base64
import threading
import io

import numpy as np
import tensorflow as tf
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
from PIL import Image


# ============================================================================
# App initialization
# ============================================================================
app = FastAPI(title="Plant Disease Detection API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================================
# Model and metadata loading (ONCE at startup)
# For image classification on plant disease detection
# ============================================================================
BASE_DIR = os.path.dirname(__file__)
MODEL_PATH = os.path.join(BASE_DIR, "model_normal.tflite")
LABELS_PATH = os.path.join(BASE_DIR, "labels.txt")

try:
    print("Loading model labels...")
    with open(LABELS_PATH, "r", encoding="utf-8") as f:
        labels = [line.strip() for line in f if line.strip()]
    
    image_size = 224  # Fixed image size for MobileNetV3Large
    
    print(f"Model configured for {len(labels)} classes, image size {image_size}×{image_size}")

    print("Loading TFLite model...")
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH, num_threads=2)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    input_index = input_details[0]["index"]
    output_index = output_details[0]["index"]
    input_dtype = input_details[0]["dtype"]
    input_shape = input_details[0]["shape"]
    output_shape = output_details[0]["shape"]

    # Validate model is image classification (batch, height, width, channels)
    if len(input_shape) != 4:
        raise RuntimeError(
            f"Expected 4D input shape [batch, height, width, channels], "
            f"got {input_shape}"
        )

    expected_classes = output_shape[-1]
    if expected_classes != len(labels):
        print(f"⚠️ Warning: {expected_classes} output classes but {len(labels)} labels loaded")

    # Thread lock for safe concurrent inference
    inference_lock = threading.Lock()

    print("Model loaded successfully!")
    print(f"Input shape: {input_shape.tolist()}")
    print(f"Output shape: {output_shape.tolist()}")

except Exception as e:
    raise RuntimeError(f"Failed to initialize TFLite model: {e}")


# ============================================================================
# Schemas
# ============================================================================
class PredictionRequest(BaseModel):
    image: str  # Base64 encoded image (JPEG/PNG)


class PredictionResponse(BaseModel):
    top_prediction: str
    confidence: float
    all_predictions: List[dict]


# ============================================================================
# Image Processing
# ============================================================================
def decode_base64_image(encoded: str) -> np.ndarray:
    """
    Decode base64 image and preprocess for model input.
    
    Mirrors Dart _preprocessImageInIsolate():
    - Reads image bytes from base64
    - Resizes to [image_size, image_size]
    - Returns [1, image_size, image_size, 3] array with values in [0, 255] range
    - NO manual normalization (model handles it)
    """
    try:
        # Strip data URI prefix if present (e.g., "data:image/png;base64,...")
        if "," in encoded:
            encoded = encoded.split(",", 1)[1]
        
        # Decode base64 to bytes
        image_bytes = base64.b64decode(encoded)
        
        # Load image from bytes
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if needed (handles PNG with alpha, grayscale, etc.)
        if image.mode != "RGB":
            image = image.convert("RGB")
        
        # Resize to model input size - matches Dart img.copyResize()
        image = image.resize((image_size, image_size), Image.Resampling.LANCZOS)
        
        # Convert to numpy array [height, width, 3] with values 0-255
        image_array = np.array(image, dtype=np.float32)
        
        # Add batch dimension: [1, height, width, 3]
        batch_image = np.expand_dims(image_array, axis=0)
        
        return batch_image
        
    except Exception as e:
        raise ValueError(f"Failed to decode/preprocess image: {e}")


def apply_softmax(logits: np.ndarray) -> np.ndarray:
    """
    Apply softmax to convert logits to probabilities.
    
    Dart app checks if output sum ≈ 1.0 to detect softmax.
    If TFLite model outputs logits instead of probabilities, apply softmax.
    """
    # Numerical stability: subtract max before exp
    logits = logits - np.max(logits, axis=-1, keepdims=True)
    exp_logits = np.exp(logits)
    return exp_logits / np.sum(exp_logits, axis=-1, keepdims=True)


# ============================================================================
# Routes
# ============================================================================
@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": True}


@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest):
    """
    Plant disease detection endpoint.
    
    Data flow (matching Dart implementation):
    1. Decode base64 image and resize to [1, 224, 224, 3]
    2. Pass to TFLite interpreter (no preprocessing normalization)
    3. Get raw output [1, num_classes]
    4. Apply softmax if needed
    5. Return top prediction + all predictions with confidence scores
    """
    try:
        # Step 1: Preprocess image (matches _preprocessImageInIsolate)
        model_input = decode_base64_image(request.image)
        
        # Validate shape matches model
        if model_input.shape != tuple(input_shape):
            raise ValueError(
                f"Image shape {model_input.shape} doesn't match model input {tuple(input_shape)}"
            )
        
        # Ensure dtype matches model (usually float32 for images)
        if input_dtype != np.float32:
            model_input = model_input.astype(input_dtype)
        
        # Step 2: Run inference with thread safety (matches _runInference)
        with inference_lock:
            interpreter.set_tensor(input_index, model_input)
            interpreter.invoke()
            raw_output = interpreter.get_tensor(output_index)  # Shape: [1, num_classes]
        
        # Step 3: Extract predictions from batch dimension
        predictions_raw = np.ravel(raw_output)  # Shape: [num_classes]
        
        # Step 4: Apply softmax if output doesn't look like probabilities
        # (Dart checks: if sum ≈ 1.0, softmax confirmed; if sum > 1.5, logits likely)
        output_sum = np.sum(predictions_raw)
        if output_sum > 1.5:
            # Likely logits, apply softmax
            predictions_raw = apply_softmax(predictions_raw)
        
        # Step 5: Build response matching Dart output format
        all_predictions = []
        for idx, confidence in enumerate(predictions_raw):
            if idx < len(labels):
                label = labels[idx]
            else:
                label = f"Class_{idx}"
            
            all_predictions.append({
                "label": label,
                "confidence": float(confidence),
            })
        
        # Sort by confidence descending
        all_predictions.sort(key=lambda x: x["confidence"], reverse=True)
        
        # Get top prediction
        top = all_predictions[0]
        
        return {
            "top_prediction": top["label"],
            "confidence": top["confidence"],
            "all_predictions": all_predictions,
        }
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference failed: {e}")


# ============================================================================
# Local dev entry point
# ============================================================================
if __name__ == "__main__":
    print("=" * 60)
    print("Plant Disease Detection API")
    print("=" * 60)
    print(f"Model: {os.path.basename(MODEL_PATH)}")
    print(f"Classes: {len(labels)}")
    print(f"Input size: {image_size}×{image_size}")
    print("Server running at: http://localhost:5000")
    print("Docs: http://localhost:5000/docs")
    print("=" * 60)
    uvicorn.run(app, host="0.0.0.0", port=5000)
