import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/route_constants.dart';
import 'core/di/injection_container.dart' as di;
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/presentation/notifier/notification_provider.dart';
import 'features/nova_save/presentation/notifier/nova_save_provider.dart';
import 'features/send_money/presentation/notifier/send_money_provider.dart';
import 'features/wallet_home/presentation/notifier/wallet_home_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencies();
  runApp(const NovaWalletApp());
}

class NovaWalletApp extends StatelessWidget {
  const NovaWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<WalletHomeProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<SendMoneyProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<NovaSaveProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<NotificationProvider>()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: RouteConstants.initial,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
