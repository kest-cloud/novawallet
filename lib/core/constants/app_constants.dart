class AppConstants {
  static const String appName = 'NovaWallet Mobile';
  static const String currencySymbol = '₦';
  static const String currencyCode = 'NGN';
  
  // Storage Keys
  static const String authTokenKey = 'nova_auth_token';
  static const String userProfileKey = 'nova_user_profile';
  static const String offlineQueueKey = 'nova_offline_queue';

  // Network & Sync
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
}
