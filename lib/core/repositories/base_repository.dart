import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';

abstract class BaseRepository<T> {
  final FirestoreService firestoreService;
  final String collectionPath;
  final Future<void> Function(String title, String message)? onLogNotification;

  BaseRepository(this.firestoreService, this.collectionPath, {this.onLogNotification});

  T fromMap(Map<String, dynamic> map, String id);
  Map<String, dynamic> toMap(T item);

  String _getDisplayName() {
    if (collectionPath.isEmpty) return 'Record';
    final parts = collectionPath.split('/');
    String name = parts.last;
    if (name.endsWith('s') && name.length > 1) {
      name = name.substring(0, name.length - 1);
    }
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1);
    }
    return name;
  }

  Future<void> create(T item, String id) async {
    try {
      await firestoreService.setDocument(collectionPath, id, toMap(item));
      final entity = _getDisplayName();
      await onLogNotification?.call('$entity Added', '$entity was added successfully.');
    } catch (e) {
      debugPrint('Error creating in $collectionPath: $e');
      rethrow;
    }
  }

  Future<T?> getById(String id) async {
    try {
      return await firestoreService.getDocument<T>(
        path: collectionPath,
        id: id,
        builder: fromMap,
      );
    } catch (e) {
      debugPrint('Error reading $id from $collectionPath: $e');
      return null;
    }
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await firestoreService.updateDocument(collectionPath, id, data);
      final entity = _getDisplayName();
      await onLogNotification?.call('$entity Updated', '$entity was updated successfully.');
    } catch (e) {
      debugPrint('Error updating $id in $collectionPath: $e');
      rethrow;
    }
  }

  Future<void> softDelete(String id) async {
    try {
      await firestoreService.softDeleteDocument(collectionPath, id);
      final entity = _getDisplayName();
      await onLogNotification?.call('$entity Deleted', '$entity was removed successfully.');
    } catch (e) {
      debugPrint('Error soft deleting $id in $collectionPath: $e');
      rethrow;
    }
  }

  Future<void> restore(String id) async {
    try {
      await firestoreService.restoreDocument(collectionPath, id);
    } catch (e) {
      debugPrint('Error restoring $id in $collectionPath: $e');
      rethrow;
    }
  }

  Future<List<T>> getAll({bool includeDeleted = false}) async {
    try {
      return await firestoreService.getCollection<T>(
        path: collectionPath,
        builder: fromMap,
        queryBuilder: includeDeleted
            ? null
            : (query) => query.where('isDeleted', isEqualTo: false),
      );
    } catch (e) {
      debugPrint('Error getting all from $collectionPath: $e');
      return [];
    }
  }

  Stream<List<T>> streamAll({bool includeDeleted = false}) {
    return firestoreService.collectionStream<T>(
      path: collectionPath,
      builder: fromMap,
      queryBuilder: includeDeleted
          ? null
          : (query) => query.where('isDeleted', isEqualTo: false),
    );
  }

  Future<List<T>> search(String field, String queryText, {bool includeDeleted = false}) async {
    try {
      return await firestoreService.getCollection<T>(
        path: collectionPath,
        builder: fromMap,
        queryBuilder: (query) {
          Query q = query
              .where(field, isGreaterThanOrEqualTo: queryText)
              .where(field, isLessThanOrEqualTo: '$queryText\uf8ff');
          if (!includeDeleted) {
            q = q.where('isDeleted', isEqualTo: false);
          }
          return q;
        },
      );
    } catch (e) {
      debugPrint('Error searching $collectionPath: $e');
      return [];
    }
  }

  Future<List<T>> getPaginated({
    DocumentSnapshot? startAfter,
    int limit = 20,
    bool includeDeleted = false,
  }) async {
    try {
      return await firestoreService.getCollection<T>(
        path: collectionPath,
        builder: fromMap,
        queryBuilder: (query) {
          Query q = query.limit(limit);
          if (!includeDeleted) {
            q = q.where('isDeleted', isEqualTo: false);
          }
          q = q.orderBy('createdAt', descending: true);
          if (startAfter != null) {
            q = q.startAfterDocument(startAfter);
          }
          return q;
        },
      );
    } catch (e) {
      debugPrint('Error getting paginated from $collectionPath: $e');
      return [];
    }
  }
}
