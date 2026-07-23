import 'package:flutter/material.dart' hide Ink;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

class DrawingPage extends StatefulWidget {
  final String expectedKanji;
  final VoidCallback onCorrect;

  const DrawingPage({
    super.key,
    required this.expectedKanji,
    required this.onCorrect,
  });

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  final DigitalInkRecognizer _recognizer = DigitalInkRecognizer(languageCode: 'ja-JP');

  Ink _ink = Ink();
  final List<Offset?> _points = [];
  String _recognizedText = '';
  
  // NEW: State for the Hint toggle
  bool _showHint = false;

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  void _clearPad() {
    setState(() {
      _ink = Ink();
      _points.clear();
      _recognizedText = '';
    });
  }

  void _processInk() async {
    if (_ink.strokes.isEmpty) return;
    try {
      final candidates = await _recognizer.recognize(_ink);
      
      bool isMatch = candidates.any((candidate) => candidate.text == widget.expectedKanji);

      if (isMatch) {
        widget.onCorrect();
      } else {
        setState(() {
          _recognizedText = candidates.take(4).map((c) => c.text).join(', ');
        });
      }
    } catch (e) {
      print('Error recognizing ink: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BIG CLEAN DRAWING CANVAS
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 10))
                ],
              ),
              child: Stack(
                children: [
                  // LAYER 1: Grid background crosshairs
                  CustomPaint(
                    painter: GridPainter(),
                    size: Size.infinite,
                  ),
                  
                  // LAYER 2: THE HINT WATERMARK
                  // Only shows if the user tapped the Lightbulb!
                  if (_showHint)
                    Center(
                      child: Text(
                        widget.expectedKanji,
                        style: const TextStyle(
                          fontSize: 250,
                          color: Colors.black12, // Faint grey template for tracing
                          height: 1.0,
                        ),
                      ),
                    ),
                  
                  // LAYER 3: S-Pen Drawing Area
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _points.add(details.localPosition);
                        _ink.strokes.add(Stroke());
                        _ink.strokes.last.points.add(StrokePoint(
                          x: details.localPosition.dx,
                          y: details.localPosition.dy,
                          t: DateTime.now().millisecondsSinceEpoch,
                        ));
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _points.add(details.localPosition);
                        if (_ink.strokes.isNotEmpty) {
                          _ink.strokes.last.points.add(StrokePoint(
                            x: details.localPosition.dx,
                            y: details.localPosition.dy,
                            t: DateTime.now().millisecondsSinceEpoch,
                          ));
                        }
                      });
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _points.add(null);
                      });
                      _processInk(); // Read ink on lift
                    },
                    child: CustomPaint(
                      painter: SignaturePainter(_points),
                      size: Size.infinite,
                    ),
                  ),
                  
                  // TOOLS: Hint Button (Top Left)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: IconButton(
                      icon: Icon(
                        _showHint ? Icons.lightbulb : Icons.lightbulb_outline, 
                        color: _showHint ? Colors.amber : Colors.grey, 
                        size: 32
                      ),
                      onPressed: () {
                        setState(() {
                          _showHint = !_showHint;
                        });
                      },
                      tooltip: 'Toggle Tracing Hint',
                    ),
                  ),

                  // TOOLS: Clear Button (Top Right)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 32),
                      onPressed: _clearPad,
                      tooltip: 'Clear Canvas',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // ML KIT LIVE GUESSES
        Padding(
          padding: const EdgeInsets.only(bottom: 32.0, left: 16, right: 16),
          child: Text(
            _recognizedText.isEmpty 
                ? 'Draw the character from memory!' 
                : 'Guesses: $_recognizedText',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------
// PAINTERS
// ----------------------------------------------------------------

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black 
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8.0; 

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
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