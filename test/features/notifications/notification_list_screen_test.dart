import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet_mobile/core/theme/app_theme.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:nova_wallet_mobile/features/notifications/presentation/notifier/notification_provider.dart';
import 'package:nova_wallet_mobile/features/notifications/presentation/screens/notification_list_screen.dart';
import 'package:provider/provider.dart';

class FakeNotificationRepository implements NotificationRepository {
  List<NotificationItem> items = [];

  @override
  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    return List.from(items);
  }

  @override
  Future<void> addNotification(NotificationItem notification) async {
    items.insert(0, notification);
  }

  @override
  Future<void> markAsRead(String id) async {
    final idx = items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    items = items.map((i) => i.copyWith(isRead: true)).toList();
  }

  @override
  Future<int> getUnreadCount() async {
    return items.where((i) => !i.isRead).length;
  }

  @override
  Stream<int> watchUnreadCount() =>
      Stream.value(items.where((i) => !i.isRead).length);

  @override
  Stream<List<NotificationItem>> watchNotifications() =>
      Stream.value(List.from(items));

  @override
  Future<void> clearAll() async {
    items.clear();
  }
}

Widget createNotificationTestWidget({required NotificationProvider provider}) {
  return ChangeNotifierProvider<NotificationProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const NotificationListScreen(),
    ),
  );
}

void main() {
  group('NotificationListScreen Widget Tests', () {
    late FakeNotificationRepository fakeRepo;
    late NotificationProvider provider;

    setUp(() {
      fakeRepo = FakeNotificationRepository();
      provider = NotificationProvider(repository: fakeRepo);
    });

    tearDown(() {
      provider.dispose();
    });

    testWidgets('Displays empty state when there are no notifications', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createNotificationTestWidget(provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(4));
    });

    testWidgets(
      'Displays notifications with distinct visual type flags and handles interactions',
      (WidgetTester tester) async {
        fakeRepo.items = [
          NotificationItem(
            id: 'notif_1',
            title: 'Pending Transfer Queued',
            message: 'Transfer of ₦5,000.00 to Chidi Obi is saved offline.',
            type: NotificationType.transferPending,
            timestamp: DateTime.now(),
            isRead: false,
          ),
          NotificationItem(
            id: 'notif_2',
            title: 'Transfer Sent Successfully',
            message: 'Transfer of ₦12,000.00 to Amina Bello has synced.',
            type: NotificationType.transferSuccess,
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            isRead: false,
          ),
          NotificationItem(
            id: 'notif_3',
            title: 'Savings Vault Created',
            message: 'New vault "Rent Savings" created.',
            type: NotificationType.savingsGoalCreated,
            timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            isRead: true,
          ),
          NotificationItem(
            id: 'notif_4',
            title: 'Vault Contribution Successful',
            message: '₦50,000.00 deposited into "Rent Savings".',
            type: NotificationType.savingsContributed,
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            isRead: true,
          ),
        ];

        await provider.loadNotifications();
        await tester.pumpWidget(
          createNotificationTestWidget(provider: provider),
        );
        await tester.pumpAndSettle();

        // Check that visual type flags/badges are visible
        expect(find.text('Pending Send'), findsOneWidget);
        expect(find.text('Transfer Synced'), findsOneWidget);
        expect(find.text('Vault Created'), findsOneWidget);
        expect(find.text('Vault Deposit'), findsOneWidget);

        // Check filter switching to "Pending"
        await tester.tap(find.widgetWithText(FilterChip, 'Pending'));
        await tester.pumpAndSettle();

        expect(find.text('Pending Send'), findsOneWidget);
        expect(find.text('Transfer Synced'), findsNothing);
        expect(find.text('Vault Created'), findsNothing);

        // Switch filter to "NovaSave"
        await tester.tap(find.widgetWithText(FilterChip, 'NovaSave'));
        await tester.pumpAndSettle();

        expect(find.text('Vault Created'), findsOneWidget);
        expect(find.text('Vault Deposit'), findsOneWidget);
        expect(find.text('Pending Send'), findsNothing);

        // Switch back to "All"
        await tester.tap(find.widgetWithText(FilterChip, 'All'));
        await tester.pumpAndSettle();

        expect(find.text('Pending Send'), findsOneWidget);
        expect(find.text('Transfer Synced'), findsOneWidget);

        // Tap "Mark Read" button
        expect(provider.unreadCount, 2);
        await tester.tap(find.text('Mark Read'));
        await tester.pumpAndSettle();

        expect(provider.unreadCount, 0);
      },
    );
  });
}
