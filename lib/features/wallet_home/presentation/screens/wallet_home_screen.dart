import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_wallet_mobile/features/wallet_home/domain/entities/transaction.dart';
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
      context.read<WalletHomeProvider>().fetchDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NovaWallet Mobile'),
        actions: [
          Semantics(
            label: 'View notifications',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Consumer<WalletHomeProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => provider.fetchDashboardData(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Top section (Header, Balance Card, Offline Banner, Action Buttons)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (provider.pendingSyncCount > 0) ...[
                          _buildOfflineBanner(provider.pendingSyncCount),
                          const SizedBox(height: 16),
                        ],

                        _buildBalanceCard(context, provider),
                        const SizedBox(height: 20),

                        _buildActionButtons(context),
                        const SizedBox(height: 28),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Recent Transactions',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Semantics(
                              label: 'View all transaction history',
                              button: true,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text('See All'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // Transactions List (Lazy ListView.builder via SliverList.builder)
                if (provider.isLoading && provider.transactions.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (provider.transactions.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 24.0,
                      ),
                      child: Center(
                        child: Text(
                          'No recent transactions yet',
                          style: TextStyle(color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverList.builder(
                      itemCount: provider.transactions.length,
                      itemBuilder: (context, index) {
                        final tx = provider.transactions[index];
                        return _buildTransactionItem(context, tx, index);
                      },
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfflineBanner(int count) {
    return Semantics(
      label:
          'Offline status: $count pending transactions waiting for connection',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count pending action${count > 1 ? 's' : ''} — will send when back online',
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WalletHomeProvider provider) {
    final balance = provider.availableBalance;
    final isHidden = provider.isBalanceHidden;

    return Semantics(
      label: isHidden
          ? 'Available balance hidden'
          : 'Total available balance: ${balance.formatToNaira()}',
      container: true,
      child: Container(
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
                Expanded(
                  child: Text(
                    'Total Available Balance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Semantics(
                  label: isHidden
                      ? 'Show available balance'
                      : 'Hide available balance',
                  button: true,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white70,
                      size: 22,
                    ),
                    onPressed: provider.toggleBalanceVisibility,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isHidden ? '••••••••••' : balance.formatToNaira(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                if (provider.walletBalance?.accountNumber.isNotEmpty ?? false)
                  Text(
                    'Acct: ${provider.walletBalance!.accountNumber}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.send_rounded,
            label: 'Send Money',
            semanticsLabel: 'Send money to bank account',
            color: AppColors.primary,
            onTap: () {
              Navigator.pushNamed(context, RouteConstants.sendMoney);
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.savings_rounded,
            label: 'Nova Save',
            semanticsLabel: 'Open Nova Save savings vault',
            color: AppColors.accent,
            onTap: () {
              Navigator.pushNamed(context, RouteConstants.novaSave);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String semanticsLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        key: Key('action_${label.toLowerCase().replaceAll(' ', '_')}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Transaction tx,
    int index,
  ) {
    final isCredit = tx.type == TransactionType.credit;
    final formattedAmount =
        '${isCredit ? '+' : '-'}${tx.amount.formatToNaira()}';
    final dateStr = DateFormat('MMM d, h:mm a').format(tx.timestamp);

    return Semantics(
      key: ValueKey('tx_item_$index'),
      label:
          '${tx.title}, ${isCredit ? 'credit' : 'debit'} of ${tx.amount.formatToNaira()}, on $dateStr',
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: (isCredit ? AppColors.accent : AppColors.error)
                  .withValues(alpha: 0.12),
              child: Icon(
                isCredit
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: isCredit ? AppColors.accentDark : AppColors.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx.subtitle.isNotEmpty ? tx.subtitle : dateStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formattedAmount,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isCredit
                        ? AppColors.accentDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
