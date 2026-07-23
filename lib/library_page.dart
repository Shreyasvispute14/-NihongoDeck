import 'package:flutter/material.dart' hide Ink;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_helper.dart';
import 'flashcard_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<KanjiCard> _allCards = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; 
  
  final DigitalInkRecognizer _recognizer = DigitalInkRecognizer(languageCode: 'ja-JP');

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    _recognizer.close(); 
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);
    final cards = await DatabaseHelper.instance.getAllCards();
    setState(() {
      _allCards = cards;
      if (_selectedFilter != 'All' && !cards.any((c) => c.deck == _selectedFilter)) {
        _selectedFilter = 'All';
      }
      _isLoading = false;
    });
  }

  List<String> get _existingDecks {
    return _allCards.map((c) => c.deck).toSet().toList()..sort();
  }

  List<KanjiCard> get _displayedCards {
    if (_selectedFilter == 'All') return _allCards;
    return _allCards.where((c) => c.deck == _selectedFilter).toList();
  }

  void _showAddCardFormat() {
    String newKanji = '';
    
    final TextEditingController meaningController = TextEditingController();
    final TextEditingController deckController = TextEditingController(
      text: _selectedFilter == 'All' ? 'Custom Library' : _selectedFilter
    );
    
    Ink ink = Ink();
    List<Offset?> points = [];
    bool isDrawingMode = true; 
    bool isFetchingMeaning = false;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              
              void processInk() async {
                if (ink.strokes.isEmpty) return;
                try {
                  final candidates = await _recognizer.recognize(ink);
                  if (candidates.isNotEmpty) {
                    setDialogState(() {
                      newKanji = candidates.first.text; 
                    });
                  }
                } catch (e) {
                  print("Recognition error: $e");
                }
              }

              // Hybrid Smart Lookup: Local DB First -> Internet Fallback -> Auto-Cache
              Future<void> autoFillMeaningHybrid() async {
                if (newKanji.trim().isEmpty) return;
                
                final kanjiQuery = newKanji.trim();
                setDialogState(() => isFetchingMeaning = true);

                // 1. Check local offline database
                final localMeaning = await DatabaseHelper.instance.lookupOfflineDictionary(kanjiQuery);
                
                if (localMeaning != null) {
                  setDialogState(() {
                    meaningController.text = localMeaning;
                    isFetchingMeaning = false;
                  });
                  return;
                }

                // 2. Fallback to online Jisho API if connected
                try {
                  final url = Uri.parse('https://jisho.org/api/v1/search/words?keyword=$kanjiQuery');
                  final response = await http.get(url);
                  
                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    if (data['data'] != null && data['data'].isNotEmpty) {
                      final List<dynamic> definitions = data['data'][0]['senses'][0]['english_definitions'];
                      final String apiMeaning = definitions.take(3).join(', '); 
                      
                      setDialogState(() {
                        meaningController.text = apiMeaning;
                      });

                      // Save to local DB so it is offline-ready forever from now on
                      await DatabaseHelper.instance.saveToOfflineDictionary(kanjiQuery, apiMeaning);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Word not found locally or online.')));
                      }
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline: Word not found in local database.')));
                  }
                }

                setDialogState(() => isFetchingMeaning = false);
              }

              return Container(
                height: 480, 
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Stack(
                        children: [
                          if (isDrawingMode) ...[
                            Positioned.fill(
                              child: GestureDetector(
                                onPanStart: (details) {
                                  setDialogState(() {
                                    points.add(details.localPosition);
                                    ink.strokes.add(Stroke());
                                    ink.strokes.last.points.add(StrokePoint(
                                      x: details.localPosition.dx, y: details.localPosition.dy, t: DateTime.now().millisecondsSinceEpoch
                                    ));
                                  });
                                },
                                onPanUpdate: (details) {
                                  setDialogState(() {
                                    points.add(details.localPosition);
                                    if (ink.strokes.isNotEmpty) {
                                      ink.strokes.last.points.add(StrokePoint(
                                        x: details.localPosition.dx, y: details.localPosition.dy, t: DateTime.now().millisecondsSinceEpoch
                                      ));
                                    }
                                  });
                                },
                                onPanEnd: (details) {
                                  setDialogState(() => points.add(null));
                                  processInk(); 
                                },
                                child: CustomPaint(
                                  painter: SPenPainter(points),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                            
                            if (newKanji.isNotEmpty)
                              Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text(
                                    newKanji, 
                                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.4)),
                                  ),
                                ),
                              ),
                              
                            if (points.isEmpty && newKanji.isEmpty)
                              Center(
                                child: Text('Draw Kanji Here', style: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 28, fontWeight: FontWeight.bold)),
                              ),
                          ] else ...[
                            Center(
                              child: TextField(
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.black),
                                decoration: InputDecoration(
                                  hintText: '漢字', 
                                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 80),
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) => newKanji = val,
                              ),
                            ),
                          ],
                          
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Row(
                              children: [
                                if (isDrawingMode)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    tooltip: 'Clear Ink',
                                    onPressed: () => setDialogState(() {
                                      points.clear();
                                      ink = Ink();
                                      newKanji = '';
                                      meaningController.clear();
                                    }),
                                  ),
                                IconButton(
                                  icon: Icon(isDrawingMode ? Icons.keyboard : Icons.edit, color: Colors.black54),
                                  tooltip: 'Toggle Input Method',
                                  onPressed: () => setDialogState(() {
                                    isDrawingMode = !isDrawingMode;
                                    newKanji = ''; 
                                    meaningController.clear();
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(height: 2, color: Colors.black12), 

                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextField(
                              controller: meaningController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, color: Colors.black87, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'English Meaning',
                                hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)),
                                border: InputBorder.none,
                                isDense: true,
                                suffixIcon: IconButton(
                                  icon: isFetchingMeaning 
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                      : const Icon(Icons.auto_fix_high, color: Colors.amber),
                                  onPressed: autoFillMeaningHybrid,
                                  tooltip: 'Smart Dictionary Lookup',
                                ),
                              ),
                            ),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.folder_special, color: Colors.amber, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: deckController,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      hintText: 'Library Name',
                                      hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (_existingDecks.isNotEmpty)
                              Container(
                                height: 28,
                                margin: const EdgeInsets.only(top: 4),
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _existingDecks.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    return GestureDetector(
                                      onTap: () {
                                        deckController.text = _existingDecks[i];
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _existingDecks[i], 
                                            style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    GestureDetector(
                      onTap: () async {
                        String finalDeckName = deckController.text.trim();
                        if (finalDeckName.isEmpty) finalDeckName = 'Custom Library'; 
                        
                        String finalMeaning = meaningController.text.trim();

                        if (newKanji.isNotEmpty && finalMeaning.isNotEmpty) {
                          final kanjiClean = newKanji.trim();
                          
                          final newCard = KanjiCard(
                            kanji: kanjiClean,
                            meaning: finalMeaning,
                            deck: finalDeckName, 
                            dueDate: DateTime.now().millisecondsSinceEpoch,
                          );
                          await DatabaseHelper.instance.database.then((db) => db.insert('kanji_cards', newCard.toMap()));

                          // Auto-learn/cache locally for future offline lookups
                          await DatabaseHelper.instance.saveToOfflineDictionary(kanjiClean, finalMeaning);

                          if (mounted) {
                            Navigator.pop(context);
                            _loadLibrary(); 
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                        ),
                        child: const Text(
                          'ADD TO LIBRARY',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, top: 4, bottom: 4),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
        selected: isSelected,
        selectedColor: Colors.amber,
        backgroundColor: Colors.white10,
        showCheckmark: false, 
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedFilter = label);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Card Library'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_displayedCards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.amber, size: 32),
                tooltip: 'Practice ${_selectedFilter == 'All' ? 'All' : _selectedFilter} Cards',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FlashcardPage(
                        dueCards: _displayedCards, 
                        updateSrs: false,    
                        onFinished: () {},   
                      ),
                    ),
                  );
                },
              ),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Column(
              children: [
                if (_existingDecks.isNotEmpty)
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFilterChip('All'),
                        ..._existingDecks.map((deck) => _buildFilterChip(deck)),
                      ],
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _displayedCards.length,
                    itemBuilder: (context, index) {
                      final card = _displayedCards[index];
                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Text(
                            card.kanji,
                            style: const TextStyle(fontSize: 32, color: Colors.amber, fontWeight: FontWeight.bold),
                          ),
                          title: Text(card.meaning, style: const TextStyle(color: Colors.white, fontSize: 18)),
                          subtitle: Text(card.deck, style: const TextStyle(color: Colors.white54)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () async {
                              await DatabaseHelper.instance.deleteCard(card.id!);
                              _loadLibrary();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        onPressed: _showAddCardFormat,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('New Card', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class SPenPainter extends CustomPainter {
  final List<Offset?> points;
  SPenPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black 
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SPenPainter oldDelegate) => true;
}