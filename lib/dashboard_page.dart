import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'database_helper.dart';
import 'flashcard_page.dart';
import 'mock_test_page.dart';
import 'library_page.dart';
import 'drawing_page.dart';
import 'widget_manager.dart'; // Added missing import

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _deckStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseHelper.instance.getDeckStats();
    
    int totalDue = 0;
    for (var deck in stats) {
      totalDue += (deck['due'] as int? ?? 0);
    }

    // Save data for the home screen widget
    await HomeWidget.saveWidgetData<int>('total_due', totalDue);
    await HomeWidget.updateWidget(
      name: 'NihongoWidgetProvider',
      androidName: 'NihongoWidgetProvider',
    );

    setState(() {
      _deckStats = stats;
      _isLoading = false;
    });
  }

  void _openDeck(String deckName, int totalCount, int dueCount) async {
    if (totalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This deck is empty! Add cards in the Library.')),
      );
      return;
    }

    final allDeckCards = await DatabaseHelper.instance.getCardsForDeck(deckName);
    final dueCards = await DatabaseHelper.instance.getDueCardsForDeck(deckName);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(deckName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('$dueCount due today ($totalCount total cards)', style: const TextStyle(color: Colors.amberAccent)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StudyModeButton(
                    icon: Icons.edit,
                    title: 'Draw',
                    onTap: () {
                      Navigator.pop(context);
                      final cardsToReview = dueCards.isNotEmpty ? dueCards : allDeckCards;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => _ReviewLoopPage(cards: cardsToReview, onFinished: _loadStats)),
                      );
                    },
                  ),
                  _StudyModeButton(
                    icon: Icons.flip,
                    title: 'Flashcards',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlashcardPage(
                            dueCards: allDeckCards,
                            onFinished: _loadStats,
                            updateSrs: false,
                          ),
                        ),
                      );
                    },
                  ),
                  _StudyModeButton(
                    icon: Icons.assignment,
                    title: 'Mock Test',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MockTestPage(cards: allDeckCards, deckName: deckName)),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showWidgetSettingsDialog() async {
    final allCards = await DatabaseHelper.instance.getAllCards();
    final decks = allCards.map((c) => c.deck).toSet().toList()..sort();

    if (decks.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No libraries available to configure widgets.')),
      );
      return;
    }

    String currentSource = await HomeWidget.getWidgetData<String>('widget_source_type') ?? 'random';
    String? currentSingleDeck = await HomeWidget.getWidgetData<String>('widget_selected_deck') ?? decks.first;
    
    String savedMultiDecks = await HomeWidget.getWidgetData<String>('widget_selected_decks') ?? decks.first;
    Set<String> selectedMultiDecks = savedMultiDecks.split(',').map((e) => e.trim()).toSet();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Widget Settings', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Choose what your widgets display:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 12),
                      
                      RadioListTile<String>(
                        title: const Text('Random Words (Dictionary)', style: TextStyle(color: Colors.white)),
                        value: 'random',
                        groupValue: currentSource,
                        activeColor: Colors.amber,
                        onChanged: (val) => setDialogState(() => currentSource = val!),
                      ),
                      
                      RadioListTile<String>(
                        title: const Text('Single Library Deck', style: TextStyle(color: Colors.white)),
                        value: 'single_deck',
                        groupValue: currentSource,
                        activeColor: Colors.amber,
                        onChanged: (val) => setDialogState(() => currentSource = val!),
                      ),

                      if (currentSource == 'single_deck') ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: decks.contains(currentSingleDeck) ? currentSingleDeck : decks.first,
                                dropdownColor: const Color(0xFF2C2C2C),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                                items: decks.map((deck) => DropdownMenuItem(value: deck, child: Text(deck))).toList(),
                                onChanged: (val) => setDialogState(() => currentSingleDeck = val),
                              ),
                            ),
                          ),
                        ),
                      ],

                      RadioListTile<String>(
                        title: const Text('Multiple Libraries', style: TextStyle(color: Colors.white)),
                        value: 'multi_deck',
                        groupValue: currentSource,
                        activeColor: Colors.amber,
                        onChanged: (val) => setDialogState(() => currentSource = val!),
                      ),

                      if (currentSource == 'multi_deck') ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, bottom: 4.0),
                          child: Text('Select libraries to include:', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: decks.map((deck) {
                              bool isChecked = selectedMultiDecks.contains(deck);
                              return CheckboxListTile(
                                title: Text(deck, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                value: isChecked,
                                activeColor: Colors.amber,
                                checkColor: Colors.black,
                                onChanged: (bool? checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedMultiDecks.add(deck);
                                    } else {
                                      if (selectedMultiDecks.length > 1) {
                                        selectedMultiDecks.remove(deck);
                                      }
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: () async {
                    await HomeWidget.saveWidgetData<String>('widget_source_type', currentSource);
                    
                    if (currentSource == 'single_deck' && currentSingleDeck != null) {
                      await HomeWidget.saveWidgetData<String>('widget_selected_deck', currentSingleDeck);
                    } else if (currentSource == 'multi_deck') {
                      String joinedDecks = selectedMultiDecks.join(',');
                      await HomeWidget.saveWidgetData<String>('widget_selected_decks', joinedDecks);
                    }

                    await WidgetManager.updateWidgetWord();

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Widget multi-library settings applied successfully!')),
                      );
                    }
                  },
                  child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Nihongodeck', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.amber),
            tooltip: 'Widget Settings',
            onPressed: _showWidgetSettingsDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _deckStats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No decks found!', style: TextStyle(color: Colors.white70, fontSize: 18)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LibraryPage()),
                          ).then((_) => _loadStats());
                        },
                        child: const Text('Open Card Library', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _deckStats.length,
                    itemBuilder: (context, index) {
                      final deck = _deckStats[index];
                      final deckName = deck['deck'] as String;
                      final totalCount = deck['total'] as int;
                      final dueCount = deck['due'] as int;

                      return GestureDetector(
                        onTap: () => _openDeck(deckName, totalCount, dueCount),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: dueCount > 0 ? Colors.amber.withOpacity(0.5) : Colors.white10,
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.folder_special, color: Colors.amber, size: 28),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: dueCount > 0 ? Colors.amber : Colors.white10,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$dueCount due',
                                      style: TextStyle(
                                        color: dueCount > 0 ? Colors.black : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    deckName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalCount total cards',
                                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LibraryPage()),
          ).then((_) => _loadStats());
        },
        icon: const Icon(Icons.library_books, color: Colors.black),
        label: const Text('Library', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _StudyModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _StudyModeButton({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.black, size: 28),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ReviewLoopPage extends StatefulWidget {
  final List<KanjiCard> cards;
  final VoidCallback onFinished;

  const _ReviewLoopPage({required this.cards, required this.onFinished});

  @override
  State<_ReviewLoopPage> createState() => _ReviewLoopPageState();
}

class _ReviewLoopPageState extends State<_ReviewLoopPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.cards.length) {
      widget.onFinished();
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(title: const Text('Review Completed'), backgroundColor: Colors.transparent),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.amber, size: 80),
              const SizedBox(height: 16),
              const Text('Great job completing the review!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final card = widget.cards[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('Draw Review (${_currentIndex + 1}/${widget.cards.length})'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              card.meaning,
              style: const TextStyle(color: Colors.amberAccent, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: DrawingPage(
              expectedKanji: card.kanji,
              onCorrect: () async {
                await DatabaseHelper.instance.updateCardReview(card, true);
                setState(() {
                  _currentIndex++;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}