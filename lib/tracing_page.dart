import 'package:flutter/material.dart' hide Ink; // Hide Flutter's Ink for ML Kit
import 'package:flutter_kanjivg/flutter_kanjivg.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

class TracingPage extends StatefulWidget {
  final String kanjiUnicode;
  final String expectedKanji;

  const TracingPage({
    super.key, 
    required this.kanjiUnicode, 
    required this.expectedKanji,
  });

  @override
  State<TracingPage> createState() => _TracingPageState();
}

class _TracingPageState extends State<TracingPage> with TickerProviderStateMixin {
  late final KanjiController _kanjiController;
  final DigitalInkRecognizer _recognizer = DigitalInkRecognizer(languageCode: 'ja-JP');
  
  bool _isLoaded = false;
  bool _hasError = false;
  
  // Tracking the S Pen Drawing
  Ink _ink = Ink();
  final List<Offset?> _points = [];
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _kanjiController = KanjiController(
      vsync: this,
      duration: const Duration(seconds: 4), 
    );
    _loadKanjiSvg();
  }

  Future<void> _loadKanjiSvg() async {
    final bundle = DefaultAssetBundle.of(context);
    try {
      final svgString = await bundle.loadString('assets/kanji/${widget.kanjiUnicode}.svg');
      const parser = KanjiParser();
      final data = parser.parse(svgString);
      
      _kanjiController.load(data);
      _kanjiController.forward(); 
      setState(() => _isLoaded = true);
    } catch (e) {
      print("Error loading Kanji SVG: $e");
      setState(() => _hasError = true);
    }
  }

  // ----------------------------------------------------
  // ML KIT VALIDATION FOR TRACING
  // ----------------------------------------------------
  void _processInk() async {
    try {
      final candidates = await _recognizer.recognize(_ink);
      bool isMatch = candidates.any((c) => c.text == widget.expectedKanji);
      
      if (isMatch) {
        // Traced correctly! 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfect trace! Now try it from memory!'), 
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Wait 1.5 seconds so they can see their successful drawing, then return to quiz
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) Navigator.pop(context);
          });
        }
      } else {
        setState(() {
          _recognizedText = candidates.take(5).map((c) => c.text).join(', ');
        });
      }
    } catch (e) {
      print("Tracing recognition error: $e");
    }
  }

  void _clearCanvas() {
    setState(() {
      _points.clear();
      _ink = Ink();
      _recognizedText = '';
    });
  }

  @override
  void dispose() {
    _kanjiController.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('Trace: ${widget.expectedKanji}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            tooltip: 'Clear Drawing',
            onPressed: _clearCanvas,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // TRACING CANVAS
          Center(
            child: SizedBox(
              width: 320,
              height: 320,
              child: Stack(
                children: [
                  // LAYER 1: Background grid
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 2),
                      color: Colors.white, 
                    ),
                    child: CustomPaint(
                      painter: GridPainter(), 
                      size: Size.infinite,
                    ),
                  ),

                  // LAYER 2: FAINT WATERMARK FOR TRACING
                  Center(
                    child: Text(
                      widget.expectedKanji,
                      style: const TextStyle(
                        fontSize: 250,
                        color: Colors.black12, // Faint grey template
                        height: 1.0,
                      ),
                    ),
                  ),

                  // LAYER 3: KanjiVG Animation (Black ink drawing automatically)
                  if (_isLoaded)
                    Center(child: KanjiCanvas(controller: _kanjiController)),

                  if (_hasError)
                    Center(
                      child: Text(
                        'Missing file: ${widget.kanjiUnicode}.svg',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),

                  // LAYER 4: Your S Pen Drawing overlay (Red ink + ML Kit capture)
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _points.add(details.localPosition);
                          _ink.strokes.add(Stroke());
                          _ink.strokes.last.points.add(
                            StrokePoint(
                              x: details.localPosition.dx,
                              y: details.localPosition.dy,
                              t: DateTime.now().millisecondsSinceEpoch,
                            ),
                          );
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _points.add(details.localPosition);
                          if (_ink.strokes.isNotEmpty) {
                            _ink.strokes.last.points.add(
                              StrokePoint(
                                x: details.localPosition.dx,
                                y: details.localPosition.dy,
                                t: DateTime.now().millisecondsSinceEpoch,
                              ),
                            );
                          }
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _points.add(null);
                        });
                        _processInk(); // Validate trace!
                      },
                      child: CustomPaint(
                        painter: TracingPainter(_points),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Display guesses
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _recognizedText.isEmpty ? 'Trace over the grey outline!' : 'Guesses: $_recognizedText',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        onPressed: () {
          _clearCanvas();
          _kanjiController.reset();
          _kanjiController.forward();
        },
        child: const Icon(Icons.replay, color: Colors.black),
      ),
    );
  }
}

// ----------------------------------------------------------------
// PAINTERS
// ----------------------------------------------------------------

class TracingPainter extends CustomPainter {
  final List<Offset?> points;
  TracingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.red // Red ink for your S Pen
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(TracingPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black12 
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}