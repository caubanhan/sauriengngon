import 'package:flutter/material.dart';
import 'camera_screen.dart';
import 'pesticide_screen.dart';


class ResultScreen extends StatefulWidget {
  static const String _fallbackImage = 'assets/durian_leaf.png';
  // Maps each disease to a list of asset image paths (extendable to multiple images later)
  static const Map<String, List<String>> _diseaseImages = {
    'Bệnh đốm rong': [
      'assets/Algal/1.jpg',
      'assets/Algal/2.jpg',
      'assets/Algal/3.jpg',
    ],

    'Bệnh cháy lá': [
      'assets/Bright/1.jpg',
      'assets/Bright/2.jpg',
      'assets/Bright/3.jpg',
    ],

    'Bệnh thán thư': [
      'assets/Colletotrichum/1.jpg',
      'assets/Colletotrichum/2.jpg',
      'assets/Colletotrichum/3.jpg',
    ],

    'Lá khỏe mạnh': [
      'assets/Healthy/1.jpg',
      'assets/Healthy/2.jpg',
      'assets/Healthy/3.jpg',
    ],

    'Bệnh đốm lá': [
      'assets/Phomopsis/1.jpg',
      'assets/Phomopsis/2.jpg',
      'assets/Phomopsis/3.jpg',
    ],

    'Bệnh cháy lá chết ngọn do nấm Rhizoctonia': [
      'assets/Rhizoctonia/1.jpg',
      'assets/Rhizoctonia/2.jpg',
      'assets/Rhizoctonia/3.jpg',
    ],
  };

  final Map<String, dynamic> detectionResult;
  const ResultScreen({required this.detectionResult, super.key});

  static List<String> getImagesFor(String prediction) {
    final images = _diseaseImages[prediction];
    if (images != null && images.isNotEmpty) {
      return images;
    }
    return [_fallbackImage];
  }

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Parse response from newserver.py:
    // {
    //   "top_prediction": "disease_name",
    //   "confidence": 0.95,
    //   "all_predictions": [
    //     {"label": "disease1", "confidence": 0.95},
    //     {"label": "disease2", "confidence": 0.03},
    //     ...
    //   ]
    // }

    final topPrediction = (widget.detectionResult["top_prediction"] ?? "Unknown").toString();
    final confidenceNum = widget.detectionResult["confidence"] as num?;
    // final confidence = confidenceNum?.toDouble() ?? 0.0;
    final allPredictions = (widget.detectionResult["all_predictions"] as List?) ?? [];
    final carouselImages = ResultScreen.getImagesFor(topPrediction);


    return Scaffold(
      appBar: AppBar(
        title: const Text("Kết quả"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CameraScreen()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tappable Disease Card (text + carousel)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PesticideScreen(
                          diseaseName: topPrediction,
                          imagePathes: carouselImages,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Disease name + chevron row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                topPrediction,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.green,
                              size: 28,
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Image Carousel with PageView
                        Column(
                          children: [
                            // PageView Carousel
                            SizedBox(
                              height: 260,
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: carouselImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        carouselImages[index],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              size: 48,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Page Indicator Dots
                            if (carouselImages.length > 1)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  carouselImages.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    width: _currentPage == index ? 12 : 8,
                                    height: _currentPage == index ? 12 : 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentPage == index
                                          ? Colors.green
                                          : Colors.grey[300],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Hint text
                        Center(
                          child: Text(
                            "Tap để xem hướng dẫn sử dụng thuốc",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
