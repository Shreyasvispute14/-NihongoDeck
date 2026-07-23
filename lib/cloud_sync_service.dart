import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';

class CloudSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Automatically push local data up to Firestore
  static Future<void> uploadLocalDataToCloud() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final localCards = await DatabaseHelper.instance.getAllCards();
      if (localCards.isEmpty) return;

      final batch = _firestore.batch();
      final collectionRef = _firestore.collection('users').doc(user.uid).collection('cards');

      for (var card in localCards) {
        final docId = '${card.deck}_${card.kanji}'.replaceAll(RegExp(r'[^\w]+'), '_');
        final docRef = collectionRef.doc(docId);

        batch.set(docRef, {
          ...card.toMap(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      print('Auto-sync: Local data successfully uploaded to Firebase.');
    } catch (e) {
      print('Auto-sync upload error: $e');
    }
  }

  // Automatically pull cloud data down to local SQLite on startup
  static Future<void> downloadCloudDataToLocal() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cards')
          .get();

      if (querySnapshot.docs.isEmpty) return;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        KanjiCard cloudCard = KanjiCard.fromMap(data);
        
        await DatabaseHelper.instance.insertCard(cloudCard);
      }
      print('Auto-sync: Cloud data successfully restored to local database.');
    } catch (e) {
      print('Auto-sync download error: $e');
    }
  }
}