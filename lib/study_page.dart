import 'dart:math';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'drawing_page.dart';
import 'srs_logic.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({Key? key}) : super(key: key);

  @override
  _StudyPageState createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  List<Map<String, dynamic>> _cards = [];
  int _currentIndex = 0;
  bool _isDrawingCorrect = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    var cards = await DatabaseHelper.instance.queryAllCards();
    
    if (cards.isEmpty) {
      await DatabaseHelper.instance.insertCard({
        'front_text': 'ねこ (Neko)',
        'back_text': 'Cat',
        'card_type': 'flip',
        'kanji': null,
        'next_review_date': DateTime.now().millisecondsSinceEpoch,
        'interval': 0,
        'repetitions': 0,
        'ease_factor': 2.5,
      });

      await DatabaseHelper.instance.insertCard({
        'front_text': 'Water',
        'back_text': '水',
        'card_type': 'writing',
        'kanji': '水',
        'next_review_date': DateTime.now().millisecondsSinceEpoch,
        'interval': 0,
        'repetitions': 0,
        'ease_factor': 2.5,
      });
      
      cards = await DatabaseHelper.instance.queryAllCards();
    }

    setState(() {
      _cards = cards;
    });
  }

  Future<void> _processSRSGrade(Map<String, dynamic> card, int quality) async {
    final updatedStats = SRSLogic.calculateNextReview(
      quality: quality,
      currentInterval: card['interval'],
      repetitions: card['repetitions'],
      easeFactor: card['ease_factor'],
    );

    await DatabaseHelper.instance.updateCardStats(card['id'], updatedStats);

    setState(() {
      _isDrawingCorrect = false;
      if (_currentIndex < _cards.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
    });
  }

  Widget _buildStudyWidget(Map<String, dynamic> card) {
    if (card['card_type'] == 'flip') {
      return Center(
        child: FlipFlashcard(
          frontText: card['front_text'], 
          backText: card['back_text'],   
          onGraded: (quality) {
            _processSRSGrade(card, quality);
          },
        ),
      );
    } else {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            width: double.infinity,
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Text(
                  'Draw the Kanji for:',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                Text(
                  card['front_text'], 
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isDrawingCorrect
                ? _buildDrawingGradingButtons(card)
                : DrawingCanvas(
                    expectedKanji: card['kanji'],
                    onCorrect: () {
                      setState(() {
                        _isDrawingCorrect = true;
                      });
                    },
                  ),
          ),
        ],
      );
    }
  }

  Widget _buildDrawingGradingButtons(Map<String, dynamic> card) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 20),
        Text(
          "Correct! ${card['kanji']}",
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 40),
        const Text("How well did you know this?", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => _processSRSGrade(card, 3),
              child: const Text("Hard", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () => _processSRSGrade(card, 4),
              child: const Text("Good", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => _processSRSGrade(card, 5),
              child: const Text("Easy", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentCard = _cards[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Mode')),
      body: _buildStudyWidget(currentCard),
    );
  }
} // <-- Closing brace for _StudyPageState

// --- FLIP CARD WIDGET (Top-level class) ---

class FlipFlashcard extends StatefulWidget {
  final String frontText;
  final String backText;
  final Function(int quality) onGraded; 

  const FlipFlashcard({
    Key? key,
    required this.frontText,
    required this.backText,
    required this.onGraded,
  }) : super(key: key);

  @override
  _FlipFlashcardState createState() => _FlipFlashcardState();
}

class _FlipFlashcardState extends State<FlipFlashcard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_showBack) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _showBack = !_showBack;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _flipCard,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final angle = _controller.value * pi;
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle);

              return Transform(
                transform: transform,
                alignment: Alignment.center,
                child: angle >= pi / 2
                    ? Transform(
                        transform: Matrix4.identity()..rotateY(pi),
                        alignment: Alignment.center,
                        child: _buildCardFace(widget.backText, Colors.lightBlue.shade50, "Tap to flip back"),
                      )
                    : _buildCardFace(widget.frontText, Colors.white, "Tap to reveal answer"),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
        if (_showBack) ...[
          const Text("How well did you know this?", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildGradeButton("Hard", Colors.orange, 3),
              _buildGradeButton("Good", Colors.blue, 4),
              _buildGradeButton("Easy", Colors.green, 5),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCardFace(String text, Color bgColor, String hint) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: bgColor,
      child: Container(
        width: 300,
        height: 220,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              hint,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeButton(String label, Color color, int quality) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: () {
        widget.onGraded(quality);
        _flipCard(); 
      },
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}