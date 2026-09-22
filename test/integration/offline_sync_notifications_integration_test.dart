import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/notifications/notification_service.dart';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/core/sync/data/repositories/sync_queue_repository_impl.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:nova_wallet_mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/send_money/data/models/transfer_request_model.dart';
import 'package:nova_wallet_mobile/features/send_money/data/repositories/transfer_repository_impl.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/datasources/wallet_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/transaction_model.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/models/wallet_balance_model.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/repositories/wallet_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeNetworkInfo implements NetworkInfo {
  bool _connected;
  FakeNetworkInfo({bool initialConnected = true})
    : _connected = initialConnected;

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(_connected);

  void setConnected(bool value) {
    _connected = value;
  }
}

class FakeTransferRemoteDataSource implements TransferRemoteDataSource {
  final List<TransferRequestModel> submittedTransfers = [];

  @override
  Future<String> submitTransfer(TransferRequestModel request) async {
    submittedTransfers.add(request);
    return 'REF_${request.idempotencyKey}';
  }
}

class FakeWalletRemoteDataSource implements WalletRemoteDataSource {
  @override
  Future<WalletBalanceModel> fetchWalletBalance() async {
    return const WalletBalanceModel(
      availableBalance: Money.fromKobo(125050050),
      ledgerBalance: Money.fromKobo(125050050),
      accountId: 'acc_nova_001',
      accountNumber: '0123456789',
      accountName: 'Ademola Afolayan',
    );
  }

  @override
  Future<List<TransactionModel>> fetchRecentTransactions({
    int limit = 50,
  }) async {
    return [];
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Offline Sync Notifications Integration', () {
    late Database db;
    late SyncDatabaseHelper dbHelper;
    late FakeNetworkInfo networkInfo;
    late SyncEngine syncEngine;
    late NotificationRepositoryImpl notificationRepo;
    late NotificationService notificationService;
    late WalletRepositoryImpl walletRepo;
    late FakeTransferRemoteDataSource remoteDataSource;
    late TransferRepositoryImpl transferRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await SyncDatabaseHelper.createAllTables(db);
      dbHelper = SyncDatabaseHelper(databaseOverride: db);
      networkInfo = FakeNetworkInfo(initialConnected: false);

      final queueRepo = SyncQueueRepositoryImpl(dbHelper: dbHelper);
      syncEngine = SyncEngine(
        repository: queueRepo,
        networkInfo: networkInfo,
        syncStepDelay: Duration.zero,
      );

      notificationRepo = NotificationRepositoryImpl(dbHelper: dbHelper);
      notificationService = NotificationService(repository: notificationRepo);

      walletRepo = WalletRepositoryImpl(
        remoteDataSource: FakeWalletRemoteDataSource(),
        networkInfo: networkInfo,
        dbHelper: dbHelper,
      );

      remoteDataSource = FakeTransferRemoteDataSource();

      transferRepo = TransferRepositoryImpl(
        remoteDataSource: remoteDataSource,
        networkInfo: networkInfo,
        syncEngine: syncEngine,
        walletRepository: walletRepo,
        notificationService: notificationService,
      );

      await syncEngine.init();
    });

    tearDown(() async {
      syncEngine.dispose();
      notificationRepo.dispose();
      notificationService.dispose();
      await db.close();
    });

    test(
      'Offline queued send logs pending notification, and re-connect sync logs success notification with responsive badge updates',
      () async {
        // 1. Initially offline
        networkInfo.setConnected(false);

        final request = TransferRequest(
          idempotencyKey: 'tx_offline_001',
          recipientAccountNumber: '0123456789',
          recipientBankCode: '058',
          recipientBankName: 'GTBank',
          recipientName: 'Babatunde Raji',
          amount: const Money.fromKobo(2500000),
          narration: 'Office supplies',
        );

        final result = await transferRepo.executeTransfer(request);
        expect(result.isSuccess, isTrue);

        // Verify pending action in queue
        final pendingActions = await syncEngine.getPendingActions();
        expect(pendingActions.length, 1);
        expect(pendingActions.first.actionType, ActionType.sendMoney);

        // Verify pending notification is stored
        var notifs = await notificationRepo.getNotifications();
        expect(notifs.length, 1);
        expect(notifs.first.type, NotificationType.transferPending);
        expect(notifs.first.type.displayName, 'Pending Send');
        expect(notifs.first.title, 'Pending Transfer Queued');
        expect(await notificationRepo.getUnreadCount(), 1);

        // 2. Internet comes back online
        networkInfo.setConnected(true);

        // Process queue
        await syncEngine.processQueue();

        // Verify queue is now empty
        final remaining = await syncEngine.getPendingActions();
        expect(remaining, isEmpty);
        expect(remoteDataSource.submittedTransfers.length, 1);

        // 3. Verify pending notification was cleanly removed and replaced by Synced notification
        notifs = await notificationRepo.getNotifications();
        expect(notifs.length, 1);
        expect(notifs.any((n) => n.type.isPending), isFalse);

        // Notification is Transfer Synced
        expect(notifs.first.type, NotificationType.transferSuccess);
        expect(notifs.first.type.displayName, 'Transfer Synced');
        expect(notifs.first.title, 'Transfer Sent Successfully');
        expect(notifs.first.message, contains('Babatunde Raji'));

        // Unread count is 1 (Synced notification)
        expect(await notificationRepo.getUnreadCount(), 1);

        // 4. Mark all as read
        await notificationRepo.markAllAsRead();
        expect(await notificationRepo.getUnreadCount(), 0);
      },
    );
  });
}
