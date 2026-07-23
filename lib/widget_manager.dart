import 'dart:math';
import 'package:home_widget/home_widget.dart';
import 'database_helper.dart';

class WidgetManager {
  static Future<void> updateWidgetWord() async {
    try {
      String sourceType = await HomeWidget.getWidgetData<String>('widget_source_type') ?? 'random';
      String kanji = '愛';
      String meaning = 'love, affection';

      if (sourceType == 'single_deck') {
        String? selectedDeck = await HomeWidget.getWidgetData<String>('widget_selected_deck');
        if (selectedDeck != null) {
          final cards = await DatabaseHelper.instance.getCardsForDeck(selectedDeck);
          if (cards.isNotEmpty) {
            final randomCard = cards[Random().nextInt(cards.length)];
            kanji = randomCard.kanji;
            meaning = randomCard.meaning;
          }
        }
      } else if (sourceType == 'multi_deck') {
        // Fetch comma-separated string of selected decks (e.g., "JLPT N5,Hiragana Basics")
        String? decksString = await HomeWidget.getWidgetData<String>('widget_selected_decks');
        if (decksString != null && decksString.isNotEmpty) {
          List<String> targetDecks = decksString.split(',');
          List<KanjiCard> combinedCards = [];
          
          for (var deck in targetDecks) {
            final deckCards = await DatabaseHelper.instance.getCardsForDeck(deck.trim());
            combinedCards.addAll(deckCards);
          }

          if (combinedCards.isNotEmpty) {
            final randomCard = combinedCards[Random().nextInt(combinedCards.length)];
            kanji = randomCard.kanji;
            meaning = randomCard.meaning;
          }
        }
      }

      // Fallback or 'random' mode
      if (sourceType == 'random' || kanji == '愛') {
        final db = await DatabaseHelper.instance.database;
        final result = await db.query('offline_dictionary');
        
        if (result.isNotEmpty) {
          final randomEntry = result[Random().nextInt(result.length)];
          kanji = randomEntry['kanji'] as String;
          meaning = randomEntry['meaning'] as String;
        }
      }

      // Save to native storage
      await HomeWidget.saveWidgetData<String>('widget_kanji', kanji);
      await HomeWidget.saveWidgetData<String>('widget_meaning', meaning);

      // Trigger native widget redraws
      await HomeWidget.updateWidget(
        name: 'NihongoWidgetProvider',
        androidName: 'NihongoWidgetProvider',
      );
      await HomeWidget.updateWidget(
        name: 'NihongoSmallWidgetProvider',
        androidName: 'NihongoSmallWidgetProvider',
      );
    } catch (e) {
      print('Widget sync error: $e');
    }
  }
}