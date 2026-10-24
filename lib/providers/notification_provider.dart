import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/firebase_error_messages.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    required AuthProvider authProvider,
    NotificationService? notificationService,
  })  : _authProvider = authProvider,
        _notificationService = notificationService ?? NotificationService() {
    _authProvider.addListener(_syncUser);
    _syncUser();
  }

  final AuthProvider _authProvider;
  final NotificationService _notificationService;
  StreamSubscription<List<AppNotification>>? _subscription;
  List<AppNotification> _notifications = [];
  String? _uid;
  String? _error;
  bool _isLoading = false;
  bool _isBusy = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((item) => !item.read).length;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;

  void _syncUser() {
    final user = _authProvider.isSignedIn ? _authProvider.user : null;
    final uid = user != null && !user.isAdmin ? user.uid : null;
    if (_uid == uid) return;

    _subscription?.cancel();
    _subscription = null;
    _uid = uid;
    _notifications = [];
    _error = null;
    _isLoading = uid != null;
    notifyListeners();
    if (uid == null) return;

    _subscription = _notificationService.watchNotifications(uid).listen(
      (notifications) {
        _notifications = notifications;
        _error = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        _error = error is FirebaseException
            ? firestoreErrorMessage(error)
            : 'Pemberitahuan gagal dimuat.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> markRead(String id) =>
      _mutate(() => _notificationService.markRead(id));

  Future<bool> markAllRead() {
    final uid = _uid;
    if (uid == null) return Future.value(false);
    return _mutate(() => _notificationService.markAllRead(uid));
  }

  Future<bool> deleteNotification(String id) =>
      _mutate(() => _notificationService.deleteNotification(id));

  void retry() {
    final user = _authProvider.isSignedIn ? _authProvider.user : null;
    if (user == null || user.isAdmin) return;
    _subscription?.cancel();
    _uid = null;
    _syncUser();
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on FirebaseException catch (exception) {
      _error = firestoreErrorMessage(exception);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_syncUser);
    _subscription?.cancel();
    super.dispose();
  }
}
