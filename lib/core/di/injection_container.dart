import 'package:get_it/get_it.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/storage/secure_storage_service.dart';
import 'package:nova_wallet_mobile/core/sync/data/datasources/sync_database_helper.dart';
import 'package:nova_wallet_mobile/core/sync/data/repositories/sync_queue_repository_impl.dart';
import 'package:nova_wallet_mobile/core/sync/domain/repositories/sync_queue_repository.dart';
import 'package:nova_wallet_mobile/core/sync/sync_engine.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/datasources/savings_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/repositories/savings_repository_impl.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/repositories/savings_repository.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/contribute_to_savings_goal_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/create_savings_goal_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/get_savings_goals_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/presentation/notifier/nova_save_provider.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/send_money/data/repositories/transfer_repository_impl.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/repositories/transfer_repository.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/usecases/send_money_usecase.dart';
import 'package:nova_wallet_mobile/features/send_money/presentation/notifier/send_money_provider.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/datasources/wallet_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/repositories/wallet_repository_impl.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/repositories/wallet_repository.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_recent_transactions_usecase.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:nova_wallet_mobile/features/wallet_home/presentation/notifier/wallet_home_provider.dart';

final sl = GetIt.instance;

Future<void> initDependencies({
  NetworkInfo? networkInfo,
  SyncDatabaseHelper? dbHelper,
  TransferRemoteDataSource? transferRemoteDataSource,
  SavingsRemoteDataSource? savingsRemoteDataSource,
  WalletRemoteDataSource? walletRemoteDataSource,
}) async {
  // Core Infrastructure
  sl.registerLazySingleton<NetworkInfo>(() => networkInfo ?? NetworkInfoImpl());
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageServiceImpl(),
  );

  // SQLite Offline Action Queue Database & Repository
  sl.registerLazySingleton<SyncDatabaseHelper>(
    () => dbHelper ?? SyncDatabaseHelper(),
  );
  sl.registerLazySingleton<SyncQueueRepository>(
    () => SyncQueueRepositoryImpl(dbHelper: sl()),
  );
  sl.registerLazySingleton<SyncEngine>(
    () => SyncEngine(repository: sl(), networkInfo: sl()),
  );

  // Data sources
  sl.registerLazySingleton<WalletRemoteDataSource>(
    () => walletRemoteDataSource ?? WalletRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<TransferRemoteDataSource>(
    () => transferRemoteDataSource ?? TransferRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<SavingsRemoteDataSource>(
    () => savingsRemoteDataSource ?? SavingsRemoteDataSourceImpl(),
  );

  // Repositories
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      dbHelper: sl(),
    ),
  );
  sl.registerLazySingleton<TransferRepository>(
    () => TransferRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      syncEngine: sl(),
      walletRepository: sl(),
    ),
  );
  sl.registerLazySingleton<SavingsRepository>(
    () => SavingsRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      syncEngine: sl(),
      walletRepository: sl(),
      dbHelper: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetWalletBalanceUseCase(sl()));
  sl.registerLazySingleton(() => GetRecentTransactionsUseCase(sl()));
  sl.registerLazySingleton(() => SendMoneyUseCase(sl()));
  sl.registerLazySingleton(() => GetSavingsGoalsUseCase(sl()));
  sl.registerLazySingleton(() => CreateSavingsGoalUseCase(sl()));
  sl.registerLazySingleton(() => ContributeToSavingsGoalUseCase(sl()));

  // Providers (Factory)
  sl.registerFactory(
    () => WalletHomeProvider(
      getWalletBalanceUseCase: sl(),
      getRecentTransactionsUseCase: sl(),
      syncEngine: sl(),
    ),
  );
  sl.registerFactory(() => SendMoneyProvider(sendMoneyUseCase: sl()));
  sl.registerFactory(
    () => NovaSaveProvider(
      getSavingsGoalsUseCase: sl(),
      createSavingsGoalUseCase: sl(),
      contributeToSavingsGoalUseCase: sl(),
    ),
  );

  // Eagerly resolve repositories that register offline action handlers
  sl<TransferRepository>();
  sl<SavingsRepository>();

  // Initialize Sync Engine crash recovery & connectivity listener
  await sl<SyncEngine>().init();
}
