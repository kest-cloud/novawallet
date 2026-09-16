import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/sync/domain/entities/queued_action.dart';
import 'package:nova_wallet_mobile/core/sync/domain/repositories/sync_queue_repository.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/core/theme/app_theme.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/datasources/savings_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/models/savings_goal_model.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/repositories/savings_repository_impl.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/contribute_to_savings_goal_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/create_savings_goal_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/get_savings_goals_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/presentation/notifier/nova_save_provider.dart';
import 'package:nova_wallet_mobile/features/nova_save/presentation/screens/nova_save_screen.dart';
import 'package:provider/provider.dart';

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
  Future<int> getPendingCount() async => _actions
      .where(
        (a) =>
            a.status == ActionStatus.pending ||
            a.status == ActionStatus.sending,
      )
      .length;

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
        _actions
            .where(
              (a) =>
                  a.status == ActionStatus.pending ||
                  a.status == ActionStatus.sending,
            )
            .length,
      );
    }
  }

  void dispose() {
    _actionsController.close();
    _pendingCountController.close();
  }
}

class FakeSavingsRemoteDataSource implements SavingsRemoteDataSource {
  final List<SavingsGoalModel> goals;

  FakeSavingsRemoteDataSource({required this.goals});

  @override
  Future<List<SavingsGoalModel>> fetchSavingsGoals() async => List.from(goals);

  @override
  Future<SavingsGoalModel> createGoal(Map<String, dynamic> payload) async {
    final newGoal = SavingsGoalModel.fromJson(payload);
    goals.add(newGoal);
    return newGoal;
  }

  @override
  Future<SavingsGoalModel> contributeToGoal(
    Map<String, dynamic> payload,
  ) async {
    final goalId = payload['goal_id'] as String;
    final amountKobo = payload['amount_kobo'] as int;

    final index = goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      final existing = goals[index];
      final updated = existing.copyWith(
        currentAmount: existing.currentAmount + Money.fromKobo(amountKobo),
      );
      final model = SavingsGoalModel.fromEntity(updated);
      goals[index] = model;
      return model;
    }
    throw Exception('Goal not found');
  }
}

Widget createTestWidget({required NovaSaveProvider provider}) {
  return ChangeNotifierProvider<NovaSaveProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const NovaSaveScreen(),
    ),
  );
}

void main() {
  late FakeSyncQueueRepository syncQueueRepository;
  late FakeNetworkInfo fakeNetworkInfo;
  late SyncEngine syncEngine;
  late FakeSavingsRemoteDataSource fakeRemoteDataSource;
  late SavingsRepositoryImpl savingsRepository;
  late GetSavingsGoalsUseCase getSavingsGoalsUseCase;
  late CreateSavingsGoalUseCase createSavingsGoalUseCase;
  late ContributeToSavingsGoalUseCase contributeToSavingsGoalUseCase;
  late NovaSaveProvider novaSaveProvider;

  // Single test goal: ₦100,000.00 target, initially ₦0.00 saved
  final initialGoal = SavingsGoalModel(
    id: 'goal_car_fund',
    title: 'Car Fund',
    targetAmount: const Money.fromKobo(
      10000000,
    ), // ₦100,000.00 (10,000,000 kobo)
    currentAmount: Money.zero,
    targetDate: DateTime.now().add(const Duration(days: 120)),
    isLocked: false,
  );

  setUp(() async {
    syncQueueRepository = FakeSyncQueueRepository();
    fakeNetworkInfo = FakeNetworkInfo(
      isConnected: false,
    ); // Test offline queueing
    syncEngine = SyncEngine(
      repository: syncQueueRepository,
      networkInfo: fakeNetworkInfo,
    );
    await syncEngine.init();

    fakeRemoteDataSource = FakeSavingsRemoteDataSource(goals: [initialGoal]);

    savingsRepository = SavingsRepositoryImpl(
      remoteDataSource: fakeRemoteDataSource,
      networkInfo: fakeNetworkInfo,
      syncEngine: syncEngine,
    );

    getSavingsGoalsUseCase = GetSavingsGoalsUseCase(savingsRepository);
    createSavingsGoalUseCase = CreateSavingsGoalUseCase(savingsRepository);
    contributeToSavingsGoalUseCase = ContributeToSavingsGoalUseCase(
      savingsRepository,
    );

    novaSaveProvider = NovaSaveProvider(
      getSavingsGoalsUseCase: getSavingsGoalsUseCase,
      createSavingsGoalUseCase: createSavingsGoalUseCase,
      contributeToSavingsGoalUseCase: contributeToSavingsGoalUseCase,
    );
  });

  tearDown(() {
    fakeNetworkInfo.dispose();
    syncQueueRepository.dispose();
  });

  group('NovaSaveScreen Sequential Contributions & Integer Progress Stability', () {
    testWidgets(
      'Sequential contributions calculate exact integer progress without float drift and render Semantics',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(provider: novaSaveProvider));
        await tester.pumpAndSettle();

        // -------------------------------------------------------------
        // Initial State: ₦0.00 / ₦100,000.00 (0%)
        // -------------------------------------------------------------
        expect(find.text('Car Fund'), findsOneWidget);
        expect(find.text('0% achieved'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Savings progress for Car Fund: 0 percent'),
          findsOneWidget,
        );

        // -------------------------------------------------------------
        // Contribution #1: +₦10,000.00 -> Saved: ₦10,000.00 (10%)
        // -------------------------------------------------------------
        await novaSaveProvider.contributeToGoal(
          goalId: 'goal_car_fund',
          amount: const Money.fromKobo(1000000), // ₦10,000.00
        );
        await tester.pumpAndSettle();

        expect(find.text('10% achieved'), findsOneWidget);
        expect(find.text('Saved: ₦10,000.00'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Savings progress for Car Fund: 10 percent'),
          findsOneWidget,
        );

        // -------------------------------------------------------------
        // Contribution #2: +₦23,456.00 -> Total: ₦33,456.00 (33%)
        // Pure integer math: (3345600 * 100) ~/ 10000000 = 33%
        // (Catches any double division drift)
        // -------------------------------------------------------------
        await novaSaveProvider.contributeToGoal(
          goalId: 'goal_car_fund',
          amount: const Money.fromKobo(2345600), // ₦23,456.00
        );
        await tester.pumpAndSettle();

        expect(find.text('33% achieved'), findsOneWidget);
        expect(find.text('Saved: ₦33,456.00'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Savings progress for Car Fund: 33 percent'),
          findsOneWidget,
        );

        // -------------------------------------------------------------
        // Contribution #3: +₦16,544.00 -> Total: ₦50,000.00 (50%)
        // Pure integer math: (5000000 * 100) ~/ 10000000 = 50%
        // -------------------------------------------------------------
        await novaSaveProvider.contributeToGoal(
          goalId: 'goal_car_fund',
          amount: const Money.fromKobo(1654400), // ₦16,544.00
        );
        await tester.pumpAndSettle();

        expect(find.text('50% achieved'), findsOneWidget);
        expect(find.text('Saved: ₦50,000.00'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Savings progress for Car Fund: 50 percent'),
          findsOneWidget,
        );

        // -------------------------------------------------------------
        // Contribution #4: +₦50,000.00 -> Total: ₦100,000.00 (100%)
        // -------------------------------------------------------------
        await novaSaveProvider.contributeToGoal(
          goalId: 'goal_car_fund',
          amount: const Money.fromKobo(5000000), // ₦50,000.00
        );
        await tester.pumpAndSettle();

        expect(find.text('100% achieved'), findsOneWidget);
        expect(find.text('Saved: ₦100,000.00'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Savings progress for Car Fund: 100 percent'),
          findsOneWidget,
        );

        // -------------------------------------------------------------
        // Verify Offline Sync Queue Actions
        // -------------------------------------------------------------
        // All 4 contributions were enqueued into the core sync queue
        final queuedActions = await syncQueueRepository.getAllActions();
        expect(queuedActions.length, equals(4));

        for (final action in queuedActions) {
          expect(action.actionType, equals(ActionType.contributeSavings));
          expect(action.payload['goal_id'], equals('goal_car_fund'));
          expect(action.payload['amount_kobo'], isNotNull);
        }
      },
    );

    testWidgets(
      'Create goal dialog creates new vault and enqueues to SyncEngine when offline',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(provider: novaSaveProvider));
        await tester.pumpAndSettle();

        // Tap create new vault button in AppBar
        final createBtn = find.byIcon(Icons.add_circle_outline_rounded);
        expect(createBtn, findsOneWidget);
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        // Enter Vault Name and Target Amount
        final nameField = find.widgetWithText(TextFormField, 'Vault Name');
        final targetField = find.widgetWithText(
          TextFormField,
          'Target Amount (₦)',
        );

        await tester.enterText(nameField, 'Emergency Fund 2027');
        await tester.enterText(targetField, '500000');
        await tester.pump();

        // Tap Create Vault
        final submitBtn = find.text('Create Vault');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Assert new vault is rendered with 0% progress
        expect(find.text('Emergency Fund 2027'), findsOneWidget);
        expect(find.text('Target: ₦500,000.00'), findsOneWidget);
        expect(find.text('Saved: ₦0.00'), findsNWidgets(2));

        // Assert create goal action was enqueued to SQLite sync engine
        final queuedActions = await syncQueueRepository.getAllActions();
        final createAction = queuedActions.firstWhere(
          (a) => a.actionType == ActionType.createSavingsGoal,
        );
        expect(createAction.payload['title'], equals('Emergency Fund 2027'));
        expect(
          createAction.payload['target_amount_kobo'],
          equals(50000000),
        ); // ₦500,000
      },
    );

    testWidgets(
      'Initial fresh install renders empty state card and creates first vault via empty card action',
      (WidgetTester tester) async {
        // Setup provider with empty initial goals list
        final emptyRemoteDataSource = FakeSavingsRemoteDataSource(goals: []);
        final emptyRepo = SavingsRepositoryImpl(
          remoteDataSource: emptyRemoteDataSource,
          networkInfo: fakeNetworkInfo,
          syncEngine: syncEngine,
        );
        final emptyProvider = NovaSaveProvider(
          getSavingsGoalsUseCase: GetSavingsGoalsUseCase(emptyRepo),
          createSavingsGoalUseCase: CreateSavingsGoalUseCase(emptyRepo),
          contributeToSavingsGoalUseCase: ContributeToSavingsGoalUseCase(
            emptyRepo,
          ),
        );

        await tester.pumpWidget(createTestWidget(provider: emptyProvider));
        await tester.pumpAndSettle();

        // 1. Assert Empty State is rendered
        expect(find.text('No savings vaults yet'), findsOneWidget);
        expect(
          find.text(
            'Create your first savings vault to start saving toward target goals with interest.',
          ),
          findsOneWidget,
        );
        expect(find.text('Total Locked & Active Savings'), findsOneWidget);
        expect(find.text('₦0.00'), findsOneWidget);

        // 2. Tap 'Create First Vault' button in empty card
        final createFirstBtn = find.text('Create First Vault');
        expect(createFirstBtn, findsOneWidget);
        await tester.tap(createFirstBtn);
        await tester.pumpAndSettle();

        // 3. Fill and submit the form
        final nameField = find.widgetWithText(TextFormField, 'Vault Name');
        final targetField = find.widgetWithText(
          TextFormField,
          'Target Amount (₦)',
        );

        await tester.enterText(nameField, 'House Down Payment');
        await tester.enterText(targetField, '10000000');
        await tester.pump();

        final submitBtn = find.text('Create Vault');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // 4. Assert empty state is gone and newly created goal is rendered
        expect(find.text('No savings vaults yet'), findsNothing);
        expect(find.text('House Down Payment'), findsOneWidget);
        expect(find.text('Target: ₦10,000,000.00'), findsOneWidget);
        expect(find.text('0% achieved'), findsOneWidget);
      },
    );
  });
}
