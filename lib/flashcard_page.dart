import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'database_helper.dart';

class FlashcardPage extends StatefulWidget {
  final List<KanjiCard> dueCards; // Reused for library cards as well
  final VoidCallback onFinished;
  final bool updateSrs; // NEW: Protects your SRS schedule during free practice

  const FlashcardPage({
    super.key, 
    required this.dueCards, 
    required this.onFinished,
    this.updateSrs = true, // Defaults to true for daily reviews
  });

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int _currentIndex = 0;
  bool _isFlipped = false;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("ja-JP"); // Set to Japanese
    await flutterTts.setSpeechRate(0.4); // Slower, clearer pronunciation for learning
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  void _processResult(bool success) async {
    final currentCard = widget.dueCards[_currentIndex];
    
    // Only update the database if this is a real Daily Review
    if (widget.updateSrs) {
      await DatabaseHelper.instance.updateCardReview(currentCard, success);
    }

    if (_currentIndex < widget.dueCards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      widget.onFinished();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.dueCards.length) return const SizedBox.shrink();
    final card = widget.dueCards[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.updateSrs 
            ? 'Quick Review (${_currentIndex + 1}/${widget.dueCards.length})' 
            : 'Practice Mode (${_currentIndex + 1}/${widget.dueCards.length})'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The Flashcard
            GestureDetector(
              onTap: () => setState(() => _isFlipped = !_isFlipped),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 300,
                height: 400,
                decoration: BoxDecoration(
                  color: _isFlipped ? Colors.amber : Colors.white10,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)
                  ],
                ),
                child: Center(
                  child: Text(
                    _isFlipped ? card.meaning : card.kanji,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _isFlipped ? 48 : 100,
                      fontWeight: FontWeight.bold,
                      color: _isFlipped ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // NEW: Pronunciation Audio Button
            IconButton(
              iconSize: 48,
              icon: const Icon(Icons.volume_up_rounded, color: Colors.amberAccent),
              onPressed: () => _speak(card.kanji),
              tooltip: 'Pronounce',
            ),
            
            const Text("Tap card to flip", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            
            // Pass / Fail Buttons (Only show when flipped)
            if (_isFlipped)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'btnFail',
                    backgroundColor: widget.updateSrs ? Colors.redAccent : Colors.grey,
                    onPressed: () => _processResult(false),
                    label: Text(widget.updateSrs ? 'Missed' : 'Next', style: const TextStyle(color: Colors.white)),
                    icon: Icon(widget.updateSrs ? Icons.close : Icons.arrow_forward, color: Colors.white),
                  ),
                  if (widget.updateSrs) // Only show "Got it" during active SRS reviews
                    FloatingActionButton.extended(
                      heroTag: 'btnPass',
                      backgroundColor: Colors.greenAccent,
                      onPressed: () => _processResult(true),
                      label: const Text('Got it', style: TextStyle(color: Colors.black)),
                      icon: const Icon(Icons.check, color: Colors.black),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}