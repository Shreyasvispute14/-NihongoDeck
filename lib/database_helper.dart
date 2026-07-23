import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class KanjiCard {
  final int? id;
  final String kanji;
  final String meaning;
  final String deck;
  final int interval;
  final int repetition;
  final double easeFactor;
  final int dueDate;

  KanjiCard({
    this.id,
    required this.kanji,
    required this.meaning,
    this.deck = 'Uncategorized',
    this.interval = 0,
    this.repetition = 0,
    this.easeFactor = 2.5,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kanji': kanji,
      'meaning': meaning,
      'deck': deck,
      'interval': interval,
      'repetition': repetition,
      'easeFactor': easeFactor,
      'dueDate': dueDate,
    };
  }

  factory KanjiCard.fromMap(Map<String, dynamic> map) {
    return KanjiCard(
      id: map['id'],
      kanji: map['kanji'],
      meaning: map['meaning'],
      deck: map['deck'] as String,
      interval: map['interval'] as int,
      repetition: map['repetition'] as int,
      easeFactor: (map['easeFactor'] as num).toDouble(),
      dueDate: map['dueDate'] as int,
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nihongo.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE kanji_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kanji TEXT NOT NULL,
        meaning TEXT NOT NULL,
        deck TEXT NOT NULL,
        interval INTEGER NOT NULL,
        repetition INTEGER NOT NULL,
        easeFactor REAL NOT NULL,
        dueDate INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_dictionary (
        kanji TEXT PRIMARY KEY,
        meaning TEXT NOT NULL
      )
    ''');

    await _seedInitialData(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS offline_dictionary (
          kanji TEXT PRIMARY KEY,
          meaning TEXT NOT NULL
        )
      ''');
      await _seedInitialData(db);
    }
  }

  Future _seedInitialData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('kanji_cards', KanjiCard(kanji: '水', meaning: 'Water', deck: 'JLPT N5', dueDate: now).toMap());
    await db.insert('kanji_cards', KanjiCard(kanji: '火', meaning: 'Fire', deck: 'JLPT N5', dueDate: now).toMap());
    await db.insert('kanji_cards', KanjiCard(kanji: 'あ', meaning: 'a', deck: 'Hiragana Basics', dueDate: now).toMap());
    await db.insert('kanji_cards', KanjiCard(kanji: 'い', meaning: 'i', deck: 'Hiragana Basics', dueDate: now).toMap());
    await db.insert('kanji_cards', KanjiCard(kanji: 'う', meaning: 'u', deck: 'Hiragana Basics', dueDate: now).toMap());
    await db.insert('kanji_cards', KanjiCard(kanji: 'え', meaning: 'e', deck: 'Hiragana Basics', dueDate: now).toMap());
    await db.insert('kanji_cards', KanjiCard(kanji: 'お', meaning: 'o', deck: 'Hiragana Basics', dueDate: now).toMap());

    final commonWords = {
      '愛': 'love, affection',
      '水': 'water',
      '火': 'fire',
      '木': 'tree, wood',
      '金': 'gold, money, metal',
      '土': 'soil, earth',
      '日': 'sun, day',
      '月': 'moon, month',
      '人': 'person',
      '車': 'car, vehicle',
      '1': 'one',
      '2': 'two',
      '3': 'three',
      '円': 'yen, circle',
      '猫': 'cat',
      '犬': 'dog',
    };

    for (var entry in commonWords.entries) {
      await db.insert(
        'offline_dictionary',
        {'kanji': entry.key, 'meaning': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<KanjiCard>> getDueCards() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final result = await db.query(
      'kanji_cards',
      where: 'dueDate <= ?',
      whereArgs: [now],
    );

    return result.isNotEmpty ? result.map((json) => KanjiCard.fromMap(json)).toList() : [];
  }

  Future<void> updateCardReview(KanjiCard card, bool wasSuccessful) async {
    final db = await database;
    
    int interval = card.interval;
    int repetition = card.repetition;
    double easeFactor = card.easeFactor;

    if (wasSuccessful) {
      if (repetition == 0) {
        interval = 1;
      } else if (repetition == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor).round();
      }
      repetition++;
    } else {
      repetition = 0;
      interval = 1;
      easeFactor = max(1.3, easeFactor - 0.2);
    }

    final nextDueDate = DateTime.now().add(Duration(days: interval)).millisecondsSinceEpoch;

    final updatedCard = KanjiCard(
      id: card.id,
      kanji: card.kanji,
      meaning: card.meaning,
      deck: card.deck,
      interval: interval,
      repetition: repetition,
      easeFactor: easeFactor,
      dueDate: nextDueDate,
    );

    await db.update(
      'kanji_cards',
      updatedCard.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  double max(double a, double b) => a > b ? a : b;

  Future<List<Map<String, dynamic>>> getDeckStats() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return await db.rawQuery('''
      SELECT 
        deck, 
        COUNT(*) as total, 
        SUM(CASE WHEN dueDate <= ? THEN 1 ELSE 0 END) as due
      FROM kanji_cards 
      GROUP BY deck
    ''', [now]);
  }

  Future<List<KanjiCard>> getDueCardsForDeck(String deckName) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final result = await db.query(
      'kanji_cards',
      where: 'dueDate <= ? AND deck = ?',
      whereArgs: [now, deckName],
    );
    
    return result.isNotEmpty ? result.map((json) => KanjiCard.fromMap(json)).toList() : [];
  }

  Future<List<KanjiCard>> getCardsForDeck(String deckName) async {
    final db = await database;
    final result = await db.query(
      'kanji_cards',
      where: 'deck = ?',
      whereArgs: [deckName],
    );
    return result.isNotEmpty ? result.map((json) => KanjiCard.fromMap(json)).toList() : [];
  }

  Future<List<KanjiCard>> getAllCards() async {
    final db = await database;
    final result = await db.query('kanji_cards', orderBy: 'deck ASC, id DESC');
    return result.map((json) => KanjiCard.fromMap(json)).toList();
  }

  Future<void> deleteCard(int id) async {
    final db = await database;
    await db.delete('kanji_cards', where: 'id = ?', whereArgs: [id]);
  }

  // Offline Dictionary Helpers
  Future<String?> lookupOfflineDictionary(String kanji) async {
    final db = await database;
    final result = await db.query(
      'offline_dictionary',
      where: 'kanji = ?',
      whereArgs: [kanji.trim()],
    );

    if (result.isNotEmpty) {
      return result.first['meaning'] as String;
    }
    return null;
  }
  Future<void> insertCard(KanjiCard card) async {
  final db = await database;
  await db.insert(
    'kanji_cards',
    card.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

  Future<void> saveToOfflineDictionary(String kanji, String meaning) async {
    final db = await database;
    await db.insert(
      'offline_dictionary',
      {'kanji': kanji.trim(), 'meaning': meaning.trim()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}