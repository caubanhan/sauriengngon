from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import torch
from transformers import AutoImageProcessor, AutoModelForImageClassification
from PIL import Image
import io
import base64
import numpy as np
import uvicorn

app = FastAPI(title="Plant Disease Detection API")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load processor and model from the current directory
print("Loading model...")
processor = AutoImageProcessor.from_pretrained(".")
model = AutoModelForImageClassification.from_pretrained(".")
model.eval()

print("Model loaded successfully!")

# Get class labels
id2label = model.config.id2label
num_classes = len(id2label)

# Request model
class PredictionRequest(BaseModel):
    image: str

# Response model
class PredictionResponse(BaseModel):
    disease: str
    confidence: float

@app.get('/health')
def health():
    return {'status': 'ok', 'model_loaded': True}

@app.post('/predict', response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    try:
        image_data = request.image
        
        # Remove data URI prefix if present
        if ',' in image_data:
            image_data = image_data.split(',')[1]
        
        # Decode base64 to bytes
        image_bytes = base64.b64decode(image_data)
        
        # Open image and convert to RGB
        pil_image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        
        # Convert to numpy array for processing
        img_array = np.array(pil_image)
        
        # Process image using AutoImageProcessor
        inputs = processor(images=pil_image, return_tensors="pt")
        
        # Run inference
        with torch.no_grad():
            outputs = model(**inputs)
            probs = torch.nn.functional.softmax(outputs.logits, dim=-1)
        
        # Get top prediction
        top_prob, top_idx = torch.max(probs, dim=-1)
        label = model.config.id2label[top_idx.item()]
        confidence = float(top_prob.item())
        
        # Return result
        return {
            'disease': label,
            'confidence': confidence
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == '__main__':
    print("=" * 50)
    print("Plant Disease Detection API Server")
    print("=" * 50)
    print(f"Model: MobileNetV2")
    print(f"Classes: {num_classes} plant diseases")
    print(f"Server running at: http://localhost:5000")
    print(f"API docs: http://localhost:5000/docs")
    print(f"Test endpoint: http://localhost:5000/health")
    print("=" * 50)
    uvicorn.run(app, host="0.0.0.0", port=5000)
