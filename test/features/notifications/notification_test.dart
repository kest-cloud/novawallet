import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet_mobile/core/notifications/notification_service.dart';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:nova_wallet_mobile/features/notifications/presentation/notifier/notification_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Notification System Tests', () {
    late Database db;
    late SyncDatabaseHelper dbHelper;
    late NotificationRepositoryImpl repository;
    late NotificationService notificationService;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await SyncDatabaseHelper.createAllTables(db);
      dbHelper = SyncDatabaseHelper(databaseOverride: db);
      repository = NotificationRepositoryImpl(dbHelper: dbHelper);
      notificationService = NotificationService(repository: repository);
    });

    tearDown(() async {
      repository.dispose();
      notificationService.dispose();
      await db.close();
    });

    test('Initial notification count is 0', () async {
      final notifs = await repository.getNotifications();
      final unread = await repository.getUnreadCount();

      expect(notifs, isEmpty);
      expect(unread, 0);
    });

    test('Adding notifications stores and updates unread count', () async {
      await notificationService.notifyTransferPending(
        idempotencyKey: 'key_001',
        amountKobo: 500000, // ₦5,000.00
        recipientName: 'Chidi Obi',
        accountNumber: '0123456789',
        bankName: 'Access Bank',
      );

      final notifs = await repository.getNotifications();
      expect(notifs.length, 1);
      expect(notifs.first.type, NotificationType.transferPending);
      expect(notifs.first.type.displayName, 'Pending Send');
      expect(notifs.first.type.isPending, isTrue);
      expect(notifs.first.isRead, isFalse);
      expect(await repository.getUnreadCount(), 1);

      // Now notify transfer synced
      await notificationService.notifyTransferSynced(
        idempotencyKey: 'key_001',
        amountKobo: 500000,
        recipientName: 'Chidi Obi',
        accountNumber: '0123456789',
        bankName: 'Access Bank',
      );

      final updated = await repository.getNotifications();
      // Pending notification is replaced/removed, leaving the synced success item
      expect(updated.length, 1);
      expect(updated.first.type, NotificationType.transferSuccess);
      expect(updated.first.type.displayName, 'Transfer Synced');
      expect(updated.any((n) => n.type.isPending), isFalse);
      expect(await repository.getUnreadCount(), 1);
    });

    test('Savings notifications categorize correctly', () async {
      await notificationService.notifySavingsGoalCreated(
        goalId: 'goal_001',
        title: 'Vacation Trip',
        targetAmountKobo: 20000000,
        isOffline: false,
      );

      await notificationService.notifySavingsContributed(
        goalId: 'goal_001',
        goalTitle: 'Vacation Trip',
        amountKobo: 5000000,
        isOffline: false,
      );

      final notifs = await repository.getNotifications();
      expect(notifs.length, 2);
      expect(notifs[0].type, NotificationType.savingsContributed);
      expect(notifs[0].type.displayName, 'Vault Deposit');
      expect(notifs[0].type.category, 'savings');

      expect(notifs[1].type, NotificationType.savingsGoalCreated);
      expect(notifs[1].type.displayName, 'Vault Created');
      expect(notifs[1].type.category, 'savings');
    });

    test('Mark single notification as read updates unread counter', () async {
      await notificationService.notifyTransferPending(
        idempotencyKey: 'key_002',
        amountKobo: 100000,
        recipientName: 'Amina Bello',
        accountNumber: '1122334455',
        bankName: 'GTBank',
      );

      final notifs = await repository.getNotifications();
      final id = notifs.first.id;

      await repository.markAsRead(id);
      expect(await repository.getUnreadCount(), 0);

      final reloaded = await repository.getNotifications();
      expect(reloaded.first.isRead, isTrue);
    });

    test('Mark all notifications as read resets counter to 0', () async {
      await notificationService.notifyTransferPending(
        idempotencyKey: 'k1',
        amountKobo: 100000,
        recipientName: 'A',
        accountNumber: '001',
        bankName: 'Bank',
      );
      await notificationService.notifySavingsGoalCreated(
        goalId: 'g1',
        title: 'Goal',
        targetAmountKobo: 1000000,
        isOffline: false,
      );

      expect(await repository.getUnreadCount(), 2);

      await repository.markAllAsRead();
      expect(await repository.getUnreadCount(), 0);

      final list = await repository.getNotifications();
      expect(list.every((n) => n.isRead), isTrue);
    });

    test('In-app alerts are emitted on sync success', () async {
      final emitted = <InAppAlert>[];
      final sub = notificationService.inAppAlerts.listen(emitted.add);

      await notificationService.notifyTransferSynced(
        idempotencyKey: 'k_alert',
        amountKobo: 250000,
        recipientName: 'Emeka Eze',
        accountNumber: '9988776655',
        bankName: 'Zenith Bank',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emitted.length, 1);
      expect(emitted.first.type, NotificationType.transferSuccess);
      expect(emitted.first.message, contains('Emeka Eze synced!'));

      await sub.cancel();
    });

    test(
      'NotificationProvider filters correctly by category and pending flag',
      () async {
        final provider = NotificationProvider(repository: repository);
        await provider.loadNotifications();

        await notificationService.notifyTransferPending(
          idempotencyKey: 'k_pending',
          amountKobo: 100000,
          recipientName: 'Pending Recipient',
          accountNumber: '123',
          bankName: 'Bank A',
        );
        await notificationService.notifyTransferSynced(
          idempotencyKey: 'k_synced',
          amountKobo: 200000,
          recipientName: 'Synced Recipient',
          accountNumber: '456',
          bankName: 'Bank B',
        );
        await notificationService.notifySavingsGoalCreated(
          goalId: 'g_vault',
          title: 'Emergency Vault',
          targetAmountKobo: 5000000,
          isOffline: false,
        );

        await provider.loadNotifications();
        expect(provider.notifications.length, 3);
        expect(provider.unreadCount, 3);

        // Filter: All
        provider.setFilter(NotificationFilter.all);
        expect(provider.filteredNotifications.length, 3);

        // Filter: Transfers
        provider.setFilter(NotificationFilter.transfers);
        expect(provider.filteredNotifications.length, 2);

        // Filter: Savings
        provider.setFilter(NotificationFilter.savings);
        expect(provider.filteredNotifications.length, 1);
        expect(
          provider.filteredNotifications.first.title,
          contains('Savings Vault'),
        );

        // Filter: Pending
        provider.setFilter(NotificationFilter.pending);
        expect(provider.filteredNotifications.length, 1);
        expect(
          provider.filteredNotifications.first.type,
          NotificationType.transferPending,
        );

        provider.dispose();
      },
    );
  });
}
