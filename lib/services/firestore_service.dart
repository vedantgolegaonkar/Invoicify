import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addDocument(String path, Map<String, dynamic> data) async {
    await _firestore.collection(path).add(data);
  }

  Future<void> setDocument(String path, String id, Map<String, dynamic> data) async {
    await _firestore.collection(path).doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> updateDocument(String path, String id, Map<String, dynamic> data) async {
    await _firestore.collection(path).doc(id).update(data);
  }

  Future<void> deleteDocument(String path, String id) async {
    await _firestore.collection(path).doc(id).delete();
  }

  Future<void> softDeleteDocument(String path, String id) async {
    await _firestore.collection(path).doc(id).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restoreDocument(String path, String id) async {
    await _firestore.collection(path).doc(id).update({
      'isDeleted': false,
      'deletedAt': FieldValue.delete(),
    });
  }

  Stream<List<T>> collectionStream<T>({
    required String path,
    required T Function(Map<String, dynamic> data, String documentId) builder,
    Query Function(Query query)? queryBuilder,
  }) {
    Query query = _firestore.collection(path);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    final snapshots = query.snapshots();
    return snapshots.map((snapshot) =>
        snapshot.docs.map((doc) => builder(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<T?> getDocument<T>({
    required String path,
    required String id,
    required T Function(Map<String, dynamic> data, String documentId) builder,
  }) async {
    final reference = _firestore.collection(path).doc(id);
    final snapshot = await reference.get();
    if (snapshot.exists && snapshot.data() != null) {
      return builder(snapshot.data()!, snapshot.id);
    }
    return null;
  }
  
  Future<List<T>> getCollection<T>({
    required String path,
    required T Function(Map<String, dynamic> data, String documentId) builder,
    Query Function(Query query)? queryBuilder,
  }) async {
    Query query = _firestore.collection(path);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => builder(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  FirebaseFirestore get instance => _firestore;
}
