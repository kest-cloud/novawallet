import 'package:flutter/material.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/theme/app_colors.dart';
import 'package:nova_wallet_mobile/features/nova_save/domain/entities/savings_goal.dart';
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

  void _showCreateGoalDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 90));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create New Savings Vault',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Set a target amount and lock date to stay disciplined.',
                      style: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Vault Name',
                        hintText: 'e.g. Vacation in Zanzibar',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Vault name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Target Amount (₦)',
                        hintText: '0',
                        prefixText: '₦ ',
                        prefixIcon: Icon(Icons.savings_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Target amount is required';
                        }
                        final naira = int.tryParse(v.trim());
                        if (naira == null || naira <= 0) {
                          return 'Enter a valid positive amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      label: 'Submit create savings vault',
                      button: true,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final naira = int.parse(
                              amountController.text.trim(),
                            );
                            final targetMoney = Money.fromNaira(naira);
                            final provider = context.read<NovaSaveProvider>();

                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(modalContext);
                            final success = await provider.createGoal(
                              title: titleController.text.trim(),
                              targetAmount: targetMoney,
                              targetDate: selectedDate,
                            );

                            if (mounted && success) {
                              final msg =
                                  provider.lastActionResult?.message ??
                                  'Vault created!';
                              messenger.showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            }
                          }
                        },
                        child: const Text('Create Vault'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showContributeDialog(BuildContext context, SavingsGoal goal) {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Contribute to ${goal.title}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Target: ${goal.targetAmount.formatToNaira()} • Saved: ${goal.currentAmount.formatToNaira()}',
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Contribution Amount (₦)',
                    hintText: '0',
                    prefixText: '₦ ',
                    prefixIcon: Icon(Icons.add_circle_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter contribution amount';
                    }
                    final naira = int.tryParse(v.trim());
                    if (naira == null || naira <= 0) {
                      return 'Enter a valid positive amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [5000, 10000, 25000, 50000].map((presetNaira) {
                    final presetMoney = Money.fromNaira(presetNaira);
                    return ActionChip(
                      label: Text(
                        '+${presetMoney.formatToNaira(showKobo: false)}',
                      ),
                      onPressed: () {
                        final current =
                            int.tryParse(amountController.text.trim()) ?? 0;
                        amountController.text = '${current + presetNaira}';
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: 'Submit contribution to ${goal.title}',
                  button: true,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState?.validate() ?? false) {
                        final naira = int.parse(amountController.text.trim());
                        final money = Money.fromNaira(naira);
                        final provider = context.read<NovaSaveProvider>();

                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(modalContext);
                        final success = await provider.contributeToGoal(
                          goalId: goal.id,
                          amount: money,
                        );

                        if (mounted && success) {
                          final msg =
                              provider.lastActionResult?.message ??
                              'Contribution added!';
                          messenger.showSnackBar(SnackBar(content: Text(msg)));
                        }
                      }
                    },
                    child: const Text('Confirm Contribution'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Save'),
        actions: [
          Semantics(
            label: 'Create new savings vault',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => _showCreateGoalDialog(context),
            ),
          ),
        ],
      ),
      body: Consumer<NovaSaveProvider>(
        builder: (context, provider, _) {
          if (provider.status == NovaSaveStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.status == NovaSaveStatus.error &&
              provider.goals.isEmpty) {
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

                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Your Savings Vaults (${provider.goals.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Vault'),
                      onPressed: () => _showCreateGoalDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vaults List
                if (provider.goals.isEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 36,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.savings_outlined,
                            size: 44,
                            color: AppColors.textSecondaryLight,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No savings vaults yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Create your first savings vault to start saving toward target goals with interest.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            label: 'Create your first savings vault',
                            button: true,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Create First Vault'),
                              onPressed: () => _showCreateGoalDialog(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...provider.goals.map((goal) => _buildGoalCard(context, goal)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, SavingsGoal goal) {
    // Integer-computed progress percentage strictly from pure integer division
    final int progressPercent = goal.progressPercentage;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
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
          const SizedBox(height: 12),

          // Accessible Progress Bar with Semantics
          Semantics(
            label:
                'Savings progress for ${goal.title}: $progressPercent percent',
            value: '$progressPercent%',
            child: _buildIntegerProgressBar(progressPercent),
          ),
          const SizedBox(height: 8),

          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Semantics(
                label: '$progressPercent percent achieved',
                child: Text(
                  '$progressPercent% achieved',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: progressPercent >= 100
                        ? AppColors.accentDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              Semantics(
                label: 'Contribute funds to ${goal.title}',
                button: true,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_circle, size: 16),
                  label: const Text('Contribute'),
                  onPressed: () => _showContributeDialog(context, goal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntegerProgressBar(int progressPercent) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          // Compute filled width: (totalWidth * percent) / 100
          final filledWidth = (totalWidth * progressPercent) / 100.0;

          return Stack(
            children: [
              Container(
                width: filledWidth.clamp(0.0, totalWidth),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: progressPercent >= 100
                        ? [const Color(0xFF059669), const Color(0xFF10B981)]
                        : [AppColors.accentDark, AppColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
