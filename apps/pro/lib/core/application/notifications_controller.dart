// ============================================================
// MON CAR PRO — Notifications (catégorie + priorité, lu/non lu persistant).
// ⚠️ MOCK : les notifications push (FCM) seront reçues ici (NOT-001).
// ============================================================

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../domain/models.dart';

class NotificationsController extends Notifier<List<ProNotification>> {
  @override
  List<ProNotification> build() => demoNotifications();

  int get unread => state.where((n) => !n.read).length;

  void push(
    String title,
    String body, {
    NotifCategory category = NotifCategory.information,
    String? route,
  }) {
    state = [
      ProNotification(
        id: 'n-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        body: body,
        category: category,
        at: DateTime.now(),
        route: route,
      ),
      ...state,
    ];
  }

  void markRead(String id) {
    state = [for (final n in state) n.id == id ? n.copyWith(read: true) : n];
  }

  void markAllRead() {
    state = [for (final n in state) n.copyWith(read: true)];
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsController, List<ProNotification>>(
      NotificationsController.new,
    );

final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);
