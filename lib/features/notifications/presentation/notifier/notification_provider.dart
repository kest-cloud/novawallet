import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/repositories/notification_repository.dart';

enum NotificationFilter {
  all,
  transfers,
  savings,
  pending;

  String get label {
    switch (this) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.transfers:
        return 'Transfers';
      case NotificationFilter.savings:
        return 'NovaSave';
      case NotificationFilter.pending:
        return 'Pending';
    }
  }
}

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository repository;

  StreamSubscription<List<NotificationItem>>? _notifSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  bool _isDisposed = false;

  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  NotificationFilter _selectedFilter = NotificationFilter.all;

  NotificationProvider({required this.repository}) {
    _initListeners();
    loadNotifications();
  }

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  NotificationFilter get selectedFilter => _selectedFilter;

  List<NotificationItem> get filteredNotifications {
    switch (_selectedFilter) {
      case NotificationFilter.all:
        return _notifications;
      case NotificationFilter.transfers:
        return _notifications
            .where((n) => n.type.category == 'transfers')
            .toList();
      case NotificationFilter.savings:
        return _notifications
            .where((n) => n.type.category == 'savings')
            .toList();
      case NotificationFilter.pending:
        return _notifications.where((n) => n.type.isPending).toList();
    }
  }

  void _initListeners() {
    _unreadCountSubscription = repository.watchUnreadCount().listen((count) {
      if (!_isDisposed) {
        _unreadCount = count;
        notifyListeners();
      }
    });

    _notifSubscription = repository.watchNotifications().listen((items) {
      if (!_isDisposed) {
        _notifications = items;
        notifyListeners();
      }
    });
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await repository.getNotifications();
      _unreadCount = await repository.getUnreadCount();
    } catch (_) {
      // Keep existing state on error
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void setFilter(NotificationFilter filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    await repository.markAsRead(id);
    await loadNotifications();
  }

  Future<void> markAllAsRead() async {
    await repository.markAllAsRead();
    await loadNotifications();
  }

  Future<void> clearAll() async {
    await repository.clearAll();
    await loadNotifications();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notifSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.dispose();
  }
}
