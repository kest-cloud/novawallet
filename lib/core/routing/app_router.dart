import 'package:flutter/material.dart';
import 'package:nova_wallet_mobile/core/constants/route_constants.dart';
import 'package:nova_wallet_mobile/features/notifications/presentation/screens/notification_list_screen.dart';
import 'package:nova_wallet_mobile/features/nova_save/presentation/screens/nova_save_screen.dart';
import 'package:nova_wallet_mobile/features/send_money/presentation/screens/send_money_screen.dart';
import 'package:nova_wallet_mobile/features/wallet_home/presentation/screens/wallet_home_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteConstants.initial:
      case RouteConstants.walletHome:
        return MaterialPageRoute(
          builder: (_) => const WalletHomeScreen(),
          settings: settings,
        );

      case RouteConstants.sendMoney:
        return MaterialPageRoute(
          builder: (_) => const SendMoneyScreen(),
          settings: settings,
        );

      case RouteConstants.novaSave:
        return MaterialPageRoute(
          builder: (_) => const NovaSaveScreen(),
          settings: settings,
        );

      case RouteConstants.notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationListScreen(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
          settings: settings,
        );
    }
  }
}
