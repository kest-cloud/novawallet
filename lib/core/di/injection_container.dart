import 'package:get_it/get_it.dart';
import 'package:nova_wallet_mobile/core/network/network_info.dart';
import 'package:nova_wallet_mobile/core/storage/secure_storage_service.dart';
import 'package:nova_wallet_mobile/core/sync/offline_queue_engine.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/datasources/savings_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/nova_save/data/repositories/savings_repository_impl.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/repositories/savings_repository.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/usecases/get_savings_goals_usecase.dart';
import 'package:nova_wallet_mobile/features/nova_save/presentation/providers/nova_save_provider.dart';
import 'package:nova_wallet_mobile/features/send_money/data/datasources/transfer_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/send_money/data/repositories/transfer_repository_impl.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/repositories/transfer_repository.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/usecases/send_money_usecase.dart';
import 'package:nova_wallet_mobile/features/send_money/presentation/providers/send_money_provider.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/datasources/wallet_remote_datasource.dart';
import 'package:nova_wallet_mobile/features/wallet_home/data/repositories/wallet_repository_impl.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/repositories/wallet_repository.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:nova_wallet_mobile/features/wallet_home/presentation/providers/wallet_home_provider.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // -------------------------------------------------------------
  // Core Infrastructure
  // -------------------------------------------------------------
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageServiceImpl(),
  );
  sl.registerLazySingleton<OfflineQueueEngine>(
    () => OfflineQueueEngineImpl(storage: sl(), networkInfo: sl()),
  );

  // -------------------------------------------------------------
  // Feature: Wallet Home
  // -------------------------------------------------------------
  // Data sources
  sl.registerLazySingleton<WalletRemoteDataSource>(
    () => WalletRemoteDataSourceImpl(),
  );
  // Repositories
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  // Usecases
  sl.registerLazySingleton(() => GetWalletBalanceUseCase(sl()));
  // Providers (Factory)
  sl.registerFactory(() => WalletHomeProvider(getWalletBalanceUseCase: sl()));

  // -------------------------------------------------------------
  // Feature: Send Money
  // -------------------------------------------------------------
  // Data sources
  sl.registerLazySingleton<TransferRemoteDataSource>(
    () => TransferRemoteDataSourceImpl(),
  );
  // Repositories
  sl.registerLazySingleton<TransferRepository>(
    () => TransferRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      offlineQueueEngine: sl(),
    ),
  );
  // Usecases
  sl.registerLazySingleton(() => SendMoneyUseCase(sl()));
  // Providers (Factory)
  sl.registerFactory(() => SendMoneyProvider(sendMoneyUseCase: sl()));

  // -------------------------------------------------------------
  // Feature: Nova Save
  // -------------------------------------------------------------
  // Data sources
  sl.registerLazySingleton<SavingsRemoteDataSource>(
    () => SavingsRemoteDataSourceImpl(),
  );
  // Repositories
  sl.registerLazySingleton<SavingsRepository>(
    () => SavingsRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  // Usecases
  sl.registerLazySingleton(() => GetSavingsGoalsUseCase(sl()));
  // Providers (Factory)
  sl.registerFactory(() => NovaSaveProvider(getSavingsGoalsUseCase: sl()));
}
