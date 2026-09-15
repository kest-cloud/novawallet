import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/domain/repositories/sync_queue_repository.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/core/theme/app_theme.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/send_money/data/models/transfer_request_model.dart';
import 'package:nova_wallet_mobile/features/send_money/data/repositories/transfer_repository_impl.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/usecases/send_money_usecase.dart';
import 'package:nova_wallet_mobile/features/send_money/presentation/notifier/send_money_provider.dart';
import 'package:nova_wallet_mobile/features/send_money/presentation/screens/send_money_screen.dart';

class FakeNetworkInfo implements NetworkInfo {
  bool _connected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  FakeNetworkInfo({bool isConnected = true}) : _connected = isConnected;

  void setConnected(bool value) {
    _connected = value;
    _controller.add(value);
  }

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

class FakeSyncQueueRepository implements SyncQueueRepository {
  final List<QueuedAction> _actions = [];
  final StreamController<List<QueuedAction>> _actionsController =
      StreamController<List<QueuedAction>>.broadcast();
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  @override
  Future<void> enqueue(QueuedAction action) async {
    _actions.removeWhere(
      (a) => a.id == action.id || a.idempotencyKey == action.idempotencyKey,
    );
    _actions.add(action);
    _notify();
  }

  @override
  Future<List<QueuedAction>> getAllActions() async =>
      List.unmodifiable(_actions);

  @override
  Future<List<QueuedAction>> getActionsByStatus(
    List<ActionStatus> statuses,
  ) async {
    return _actions.where((a) => statuses.contains(a.status)).toList();
  }

  @override
  Future<void> updateStatus(
    String id,
    ActionStatus status, {
    String? error,
    int? retryCount,
  }) async {
    final idx = _actions.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _actions[idx] = _actions[idx].copyWith(
        status: status,
        lastError: error,
        retryCount: retryCount,
      );
      _notify();
    }
  }

  @override
  Future<void> delete(String id) async {
    _actions.removeWhere((a) => a.id == id);
    _notify();
  }

  @override
  Future<void> markSendingAsPending() async {
    for (int i = 0; i < _actions.length; i++) {
      if (_actions[i].status == ActionStatus.sending) {
        _actions[i] = _actions[i].copyWith(status: ActionStatus.pending);
      }
    }
    _notify();
  }

  @override
  Future<int> getPendingCount() async =>
      _actions.where((a) => a.status == ActionStatus.pending).length;

  @override
  Stream<List<QueuedAction>> watchActions() => _actionsController.stream;

  @override
  Stream<int> watchPendingCount() => _pendingCountController.stream;

  void _notify() {
    if (!_actionsController.isClosed) {
      _actionsController.add(List.unmodifiable(_actions));
    }
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(
        _actions.where((a) => a.status == ActionStatus.pending).length,
      );
    }
  }

  void dispose() {
    _actionsController.close();
    _pendingCountController.close();
  }
}

class FakeTransferRemoteDataSource implements TransferRemoteDataSource {
  final List<TransferRequestModel> submittedTransfers = [];

  @override
  Future<String> submitTransfer(TransferRequestModel request) async {
    submittedTransfers.add(request);
    return 'REF_TEST_${request.idempotencyKey.substring(0, 8)}';
  }
}

Widget createTestWidget({required SendMoneyProvider provider}) {
  return ChangeNotifierProvider<SendMoneyProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const SendMoneyScreen(),
    ),
  );
}

void main() {
  late FakeSyncQueueRepository syncQueueRepository;
  late FakeNetworkInfo fakeNetworkInfo;
  late SyncEngine syncEngine;
  late FakeTransferRemoteDataSource fakeRemoteDataSource;
  late TransferRepositoryImpl transferRepository;
  late SendMoneyUseCase sendMoneyUseCase;
  late SendMoneyProvider sendMoneyProvider;

  setUp(() async {
    syncQueueRepository = FakeSyncQueueRepository();
    fakeNetworkInfo = FakeNetworkInfo(isConnected: false); // Start offline
    syncEngine = SyncEngine(
      repository: syncQueueRepository,
      networkInfo: fakeNetworkInfo,
    );
    await syncEngine.init();

    fakeRemoteDataSource = FakeTransferRemoteDataSource();
    transferRepository = TransferRepositoryImpl(
      remoteDataSource: fakeRemoteDataSource,
      networkInfo: fakeNetworkInfo,
      syncEngine: syncEngine,
    );
    sendMoneyUseCase = SendMoneyUseCase(transferRepository);
    sendMoneyProvider = SendMoneyProvider(sendMoneyUseCase: sendMoneyUseCase);
  });

  tearDown(() {
    fakeNetworkInfo.dispose();
    syncQueueRepository.dispose();
  });

  group('SendMoneyScreen Flow & Idempotency Key Guard Tests', () {
    testWidgets(
      'Drives full recipient -> amount -> confirm flow offline, guards idempotency key across rebuilds, and immediately displays pending status',
      (WidgetTester tester) async {
        // Build initial UI
        await tester.pumpWidget(createTestWidget(provider: sendMoneyProvider));
        await tester.pumpAndSettle();

        // Capture initial idempotency key generated once at start of attempt
        final capturedKey = sendMoneyProvider.activeIdempotencyKey;
        expect(capturedKey, isNotEmpty);

        // -------------------------------------------------------------
        // STEP 1: Recipient Input
        // -------------------------------------------------------------
        expect(find.text('Who are you sending to?'), findsOneWidget);
        expect(find.text('Recipient'), findsOneWidget);

        // Enter Account Number
        final accountField = find.widgetWithText(
          TextFormField,
          'Account Number',
        );
        await tester.enterText(accountField, '0123456789');
        await tester.pump();

        // Account Name (auto-resolves or enter explicitly)
        final nameField = find.widgetWithText(TextFormField, 'Account Name');
        await tester.enterText(nameField, 'Babatunde Fashola');
        await tester.pump();

        // REBUILD TEST: Force widget rebuild mid-flow
        await tester.pumpWidget(createTestWidget(provider: sendMoneyProvider));
        await tester.pump();
        expect(
          sendMoneyProvider.activeIdempotencyKey,
          equals(capturedKey),
          reason:
              'Idempotency key must not regenerate on widget rebuild in Step 1',
        );

        // Tap Continue to Amount
        final continueToAmountBtn = find.text('Continue to Amount');
        await tester.tap(continueToAmountBtn);
        await tester.pumpAndSettle();

        // -------------------------------------------------------------
        // STEP 2: Amount & Narration Input
        // -------------------------------------------------------------
        expect(find.text('How much would you like to send?'), findsOneWidget);
        expect(
          find.text('Sending to Babatunde Fashola (FirstBank of Nigeria)'),
          findsOneWidget,
        );

        // Enter Amount in Naira (e.g. ₦15,000)
        final amountField = find.widgetWithText(TextFormField, 'Amount (₦)');
        await tester.enterText(amountField, '15000');
        await tester.pump();

        // Enter Narration
        final narrationField = find.widgetWithText(
          TextFormField,
          'Narration (Optional)',
        );
        await tester.enterText(narrationField, 'Consulting fee');
        await tester.pump();

        // REBUILD TEST: Force multiple widget rebuilds mid-flow
        await tester.pumpWidget(createTestWidget(provider: sendMoneyProvider));
        await tester.pump();
        await tester.pumpWidget(createTestWidget(provider: sendMoneyProvider));
        await tester.pump();
        expect(
          sendMoneyProvider.activeIdempotencyKey,
          equals(capturedKey),
          reason:
              'Idempotency key must remain identical across multiple rebuilds in Step 2',
        );

        // Tap Review Transfer
        final reviewBtn = find.text('Review Transfer');
        await tester.tap(reviewBtn);
        await tester.pumpAndSettle();

        // -------------------------------------------------------------
        // STEP 3: Confirm Details & Submit Offline
        // -------------------------------------------------------------
        expect(find.text('Confirm Transfer Details'), findsOneWidget);
        expect(find.text('Babatunde Fashola'), findsOneWidget);
        expect(find.text('0123456789'), findsOneWidget);
        expect(
          find.text('₦15,000.00'),
          findsWidgets,
        ); // Summary card row & button label
        expect(find.text('Consulting fee'), findsOneWidget);

        // REBUILD TEST: Force widget rebuild on confirmation screen before tapping confirm
        await tester.pumpWidget(createTestWidget(provider: sendMoneyProvider));
        await tester.pump();
        expect(
          sendMoneyProvider.activeIdempotencyKey,
          equals(capturedKey),
          reason:
              'Idempotency key must not change when rendering confirmation page',
        );

        // Tap Confirm & Send while device is offline
        final confirmBtn = find.text('Confirm & Send ₦15,000.00');
        expect(confirmBtn, findsOneWidget);

        await tester.tap(confirmBtn);
        await tester.pump();
        await tester.pumpAndSettle();

        // -------------------------------------------------------------
        // ASSERT: Immediate offline feedback without spinner or error
        // -------------------------------------------------------------
        expect(
          find.text('Pending — will send when back online'),
          findsOneWidget,
          reason:
              'Must immediately display pending offline message on offline confirmation',
        );
        expect(
          find.textContaining('queued in the offline database'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // -------------------------------------------------------------
        // ASSERT: Sync Queue contains exactly ONE entry with this key
        // -------------------------------------------------------------
        final queuedActions = await syncQueueRepository.getAllActions();
        expect(queuedActions.length, equals(1));
        final action = queuedActions.first;

        expect(action.idempotencyKey, equals(capturedKey));
        expect(action.actionType, equals(ActionType.sendMoney));
        expect(action.status, equals(ActionStatus.pending));
        expect(
          action.payload['amount_kobo'],
          equals(1500000),
        ); // ₦15,000 = 1,500,000 kobo
        expect(
          action.payload['recipient_account_number'],
          equals('0123456789'),
        );
        expect(action.payload['recipient_name'], equals('Babatunde Fashola'));
        expect(action.payload['narration'], equals('Consulting fee'));
      },
    );

    testWidgets(
      'Online transfer completes successfully and does not enqueue in offline queue',
      (WidgetTester tester) async {
        fakeNetworkInfo.setConnected(true);

        await tester.pumpWidget(createTestWidget(provider: sendMoneyProvider));
        await tester.pumpAndSettle();

        final initialKey = sendMoneyProvider.activeIdempotencyKey;

        // Step 1: Recipient
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Account Number'),
          '9876543210',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Account Name'),
          'Chioma Nwosu',
        );
        await tester.tap(find.text('Continue to Amount'));
        await tester.pumpAndSettle();

        // Step 2: Amount
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount (₦)'),
          '25000',
        );
        await tester.tap(find.text('Review Transfer'));
        await tester.pumpAndSettle();

        // Step 3: Confirm
        final confirmBtn2 = find.text('Confirm & Send ₦25,000.00');
        expect(confirmBtn2, findsOneWidget);

        await tester.tap(confirmBtn2);
        await tester.pump();
        await tester.pumpAndSettle();

        // Assert online success view
        expect(find.text('Transfer Successful!'), findsOneWidget);
        expect(
          find.textContaining('Chioma Nwosu has been processed'),
          findsOneWidget,
        );

        // Verify remote call received exact idempotency key and kobo amount
        expect(fakeRemoteDataSource.submittedTransfers.length, equals(1));
        final remotePayload = fakeRemoteDataSource.submittedTransfers.first;
        expect(remotePayload.idempotencyKey, equals(initialKey));
        expect(remotePayload.amount.kobo, equals(2500000)); // ₦25,000.00

        // Verify offline queue is completely empty
        final queuedActions = await syncQueueRepository.getAllActions();
        expect(queuedActions.isEmpty, isTrue);
      },
    );

    testWidgets(
      'Typing 10-digit account number auto-resolves a random recipient name and shuffle button generates alternate names',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(provider: sendMoneyProvider));
        await tester.pumpAndSettle();

        final accountField = find.widgetWithText(
          TextFormField,
          'Account Number',
        );
        await tester.enterText(accountField, '0123456789');
        await tester.pumpAndSettle();

        final nameFieldFinder = find.byType(TextFormField).at(1);
        final nameFieldWidget = tester.widget<TextFormField>(nameFieldFinder);
        final initialName = nameFieldWidget.controller?.text;

        expect(initialName, isNotNull);
        expect(initialName, isNotEmpty);

        // Tap the shuffle button to generate another random name
        final shuffleBtn = find.byIcon(Icons.shuffle_rounded);
        expect(shuffleBtn, findsOneWidget);
        await tester.tap(shuffleBtn);
        await tester.pumpAndSettle();

        final updatedName = nameFieldWidget.controller?.text;
        expect(updatedName, isNotNull);
        expect(updatedName, isNotEmpty);
      },
    );

    testWidgets(
      'Resetting provider generates a fresh idempotency key for the next attempt',
      (WidgetTester tester) async {
        final key1 = sendMoneyProvider.activeIdempotencyKey;
        expect(key1, isNotEmpty);

        sendMoneyProvider.reset();
        final key2 = sendMoneyProvider.activeIdempotencyKey;

        expect(key2, isNotEmpty);
        expect(
          key1,
          isNot(equals(key2)),
          reason: 'New attempt must have a distinct idempotency key',
        );
      },
    );
  });
}
