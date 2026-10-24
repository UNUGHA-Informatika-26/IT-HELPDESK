import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/app_notification.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(AppConstants.notificationsCollection);

  Stream<List<AppNotification>> watchNotifications(String uid) => _notifications
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((document) =>
              AppNotification.fromMap(document.id, document.data()))
          .toList());

  Future<void> markRead(String id) =>
      _notifications.doc(id).update({'read': true});

  Future<void> markAllRead(String uid) async {
    final unread = await _notifications
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    for (var offset = 0; offset < unread.docs.length; offset += 500) {
      final batch = _firestore.batch();
      for (final notification in unread.docs.skip(offset).take(500)) {
        batch.update(notification.reference, {'read': true});
      }
      await batch.commit();
    }
  }

  Future<void> deleteNotification(String id) => _notifications.doc(id).delete();
}
