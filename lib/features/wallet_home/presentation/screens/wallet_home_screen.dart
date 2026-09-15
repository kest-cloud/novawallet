import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nova_wallet_mobile/core/constants/route_constants.dart';
import 'package:nova_wallet_mobile/core/theme/app_colors.dart';
import 'package:nova_wallet_mobile/features/wallet_home/presentation/notifier/wallet_home_provider.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletHomeProvider>().fetchWalletBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NovaWallet Mobile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<WalletHomeProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => provider.fetchWalletBalance(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Balance Card
                  _buildBalanceCard(context, provider),
                  const SizedBox(height: 24),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.send_rounded,
                          label: 'Send Money',
                          color: AppColors.primary,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              RouteConstants.sendMoney,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.savings_rounded,
                          label: 'Nova Save',
                          color: AppColors.accent,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              RouteConstants.novaSave,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Recent Activity Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Activity List
                  _buildRecentActivityList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WalletHomeProvider provider) {
    final balance = provider.availableBalance;
    final isHidden = provider.isBalanceHidden;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Available Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: provider.toggleBalanceVisibility,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isHidden ? '••••••••••' : balance.formatToNaira(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Active Wallet',
                  style: TextStyle(
                    color: AppColors.accentLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'No recent transactions',
            style: TextStyle(color: AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }
}
