import 'package:flutter/material.dart' hide Ink;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';
import 'database_helper.dart';

class MockTestPage extends StatefulWidget {
  final List<KanjiCard> cards;
  final String deckName;

  const MockTestPage({super.key, required this.cards, required this.deckName});

  @override
  State<MockTestPage> createState() => _MockTestPageState();
}

class _MockTestPageState extends State<MockTestPage> {
  late List<KanjiCard> _testCards;
  int _currentIndex = 0;
  int _score = 0;
  bool _testCompleted = false;

  final DigitalInkRecognizer _recognizer = DigitalInkRecognizer(languageCode: 'ja-JP');
  Ink _ink = Ink();
  final List<Offset?> _points = [];
  String _recognizedText = '';
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    // Shuffle cards so it's a genuine randomized test
    _testCards = List.from(widget.cards)..shuffle();
  }

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
      
      final currentCard = _testCards[_currentIndex];
      
      // SUPPORT MULTI-ANSWER AMBIGUITY:
      // If a card has multiple valid kanji separated by commas (e.g. "円, ￥"), 
      // we split them and check if ML Kit matched any of them.
      final List<String> validTargets = currentCard.kanji.split(',').map((e) => e.trim()).toList();
      
      bool isMatch = candidates.any((candidate) => validTargets.contains(candidate.text));

      if (isMatch) {
        // Correct! Increment score and move to next question
        setState(() {
          _score++;
        });
        _nextQuestion();
      } else {
        setState(() {
          _recognizedText = candidates.take(4).map((c) => c.text).join(', ');
        });
      }
    } catch (e) {
      print('Recognition error: $e');
    }
  }

  void _nextQuestion() {
    _clearPad();
    setState(() {
      _showHint = false;
      if (_currentIndex < _testCards.length - 1) {
        _currentIndex++;
      } else {
        _testCompleted = true; // End of test!
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_testCompleted) {
      // SCORECARD SCREEN
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(title: Text('${widget.deckName} Results'), backgroundColor: Colors.transparent),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
                const SizedBox(height: 16),
                const Text('Test Completed!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('You scored $_score / ${_testCards.length}', style: const TextStyle(color: Colors.amberAccent, fontSize: 22)),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Return to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentCard = _testCards[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('Mock Test: ${_currentIndex + 1}/${_testCards.length}'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // PROMPT BOX (English Meaning)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text('Write the Japanese for:', style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 6),
                Text(
                  currentCard.meaning, // Displays full multi-word meanings cleanly
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // DRAWING CANVAS
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 10))],
                ),
                child: Stack(
                  children: [
                    CustomPaint(painter: GridPainter(), size: Size.infinite),
                    
                    // Hint Watermark
                    if (_showHint)
                      Center(
                        child: Text(
                          currentCard.kanji.split(',')[0], // Show primary kanji for hint
                          style: const TextStyle(fontSize: 250, color: Colors.black12, height: 1.0),
                        ),
                      ),
                    
                    // S Pen Input
                    GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _points.add(details.localPosition);
                          _ink.strokes.add(Stroke());
                          _ink.strokes.last.points.add(StrokePoint(
                            x: details.localPosition.dx, y: details.localPosition.dy, t: DateTime.now().millisecondsSinceEpoch,
                          ));
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _points.add(details.localPosition);
                          if (_ink.strokes.isNotEmpty) {
                            _ink.strokes.last.points.add(StrokePoint(
                              x: details.localPosition.dx, y: details.localPosition.dy, t: DateTime.now().millisecondsSinceEpoch,
                            ));
                          }
                        });
                      },
                      onPanEnd: (details) {
                        setState(() => _points.add(null));
                        _processInk();
                      },
                      child: CustomPaint(painter: TestPainter(_points), size: Size.infinite),
                    ),

                    // Lightbulb Hint Button
                    Positioned(
                      left: 8,
                      top: 8,
                      child: IconButton(
                        icon: Icon(_showHint ? Icons.lightbulb : Icons.lightbulb_outline, color: _showHint ? Colors.amber : Colors.grey, size: 32),
                        onPressed: () => setState(() => _showHint = !_showHint),
                        tooltip: 'Show Hint',
                      ),
                    ),

                    // Clear Button
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

          // LIVE GUESSES & SKIP BUTTON
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _recognizedText.isEmpty ? 'Draw answer from memory' : 'Guesses: $_recognizedText',
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
                TextButton.icon(
                  onPressed: _nextQuestion,
                  icon: const Icon(Icons.skip_next, color: Colors.amber),
                  label: const Text('Skip', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Painters
class TestPainter extends CustomPainter {
  final List<Offset?> points;
  TestPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Colors.black..strokeCap = StrokeCap.round..strokeWidth = 8.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }
  @override
  bool shouldRepaint(TestPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black12..strokeWidth = 1..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}