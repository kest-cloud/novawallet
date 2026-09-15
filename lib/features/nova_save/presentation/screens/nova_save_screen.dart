import 'package:flutter/material.dart';
import 'package:nova_wallet_mobile/core/theme/app_colors.dart';
import 'package:nova_wallet_mobile/features/nova_save/presentation/notifier/nova_save_provider.dart';
import 'package:provider/provider.dart';

class NovaSaveScreen extends StatefulWidget {
  const NovaSaveScreen({super.key});

  @override
  State<NovaSaveScreen> createState() => _NovaSaveScreenState();
}

class _NovaSaveScreenState extends State<NovaSaveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NovaSaveProvider>().fetchSavingsGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Save'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<NovaSaveProvider>(
        builder: (context, provider, _) {
          if (provider.status == NovaSaveStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.status == NovaSaveStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.errorMessage ?? 'Failed to load savings',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: provider.fetchSavingsGoals,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total Savings Header Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Locked & Active Savings',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.totalSavings.formatToNaira(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Your Savings Vaults (${provider.goals.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Vaults List
                ...provider.goals.map((goal) => _buildGoalCard(goal)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(dynamic goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (goal.isLocked)
                const Chip(
                  label: Text('Locked', style: TextStyle(fontSize: 11)),
                  backgroundColor: Color(0xFFFEF3C7),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saved: ${goal.currentAmount.formatToNaira()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentDark,
                ),
              ),
              Text(
                'Target: ${goal.targetAmount.formatToNaira()}',
                style: const TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: goal.progressPercentage / 100.0,
            backgroundColor: AppColors.borderLight,
            color: AppColors.accent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${goal.progressPercentage}% achieved',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
