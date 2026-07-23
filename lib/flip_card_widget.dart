import 'dart:math';
import 'package:flutter/material.dart';

class FlipFlashcard extends StatefulWidget {
  final String frontText;
  final String backText;
  final Function(int quality) onGraded; // Triggers SRS logic (3=Hard, 4=Good, 5=Easy)

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
        // The Animated Card
        GestureDetector(
          onTap: _flipCard,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final angle = _controller.value * pi;
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Adds 3D depth effect
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

        // SRS Rating Buttons (Only visible when card is flipped)
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
        _flipCard(); // Reset flip state for the next card
      },
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

Widget _buildStudyWidget(Map<String, dynamic> card) {
  // --- FLIP CARD LOGIC ---
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
  } 
  
  // --- WRITING CARD LOGIC ---
  else {
    return Column(
      children: [
        // The Prompt
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
                card['front_text'], // e.g., "Water"
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        // The Canvas OR The Grading Buttons
        Expanded(
          child: _isDrawingCorrect
              ? _buildDrawingGradingButtons(card) // Show buttons if correct
              : DrawingCanvas( // Show canvas if not yet correct
                  expectedKanji: card['kanji'],
                  onCorrect: () {
                    setState(() {
                      _isDrawingCorrect = true; // Trigger the UI swap
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