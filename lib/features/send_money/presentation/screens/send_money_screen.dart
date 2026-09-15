import 'package:flutter/material.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/core/theme/app_colors.dart';
import 'package:nova_wallet_mobile/features/send_money/presentation/notifier/send_money_provider.dart';
import 'package:provider/provider.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountNairaController = TextEditingController();
  final _narrationController = TextEditingController();
  final String _selectedBankCode = '058';

  @override
  void dispose() {
    _accountController.dispose();
    _nameController.dispose();
    _amountNairaController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  void _handleTransfer() {
    if (_formKey.currentState?.validate() ?? false) {
      final naira = int.tryParse(_amountNairaController.text.trim()) ?? 0;
      final amount = Money.fromNaira(naira);

      context.read<SendMoneyProvider>().sendMoney(
        recipientAccountNumber: _accountController.text.trim(),
        recipientBankCode: _selectedBankCode,
        recipientName: _nameController.text.trim(),
        amount: amount,
        narration: _narrationController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Money')),
      body: Consumer<SendMoneyProvider>(
        builder: (context, provider, _) {
          if (provider.status == SendMoneyStatus.success) {
            return _buildSuccessView(context, provider);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (provider.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Account Number
                  TextFormField(
                    controller: _accountController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Account Number',
                      hintText: '10 digit NUBAN',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().length != 10)
                        ? 'Enter valid 10-digit account number'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Recipient Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                      hintText: 'e.g. John Doe',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter recipient name'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Amount in Naira (Integer)
                  TextFormField(
                    controller: _amountNairaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₦)',
                      hintText: 'e.g. 5000',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter an amount';
                      }
                      final val = int.tryParse(v.trim());
                      if (val == null || val <= 0) {
                        return 'Enter a valid positive integer';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Narration
                  TextFormField(
                    controller: _narrationController,
                    decoration: const InputDecoration(
                      labelText: 'Narration (Optional)',
                      hintText: 'What is this for?',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: provider.status == SendMoneyStatus.submitting
                        ? null
                        : _handleTransfer,
                    child: provider.status == SendMoneyStatus.submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Confirm & Send'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, SendMoneyProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.accent,
            size: 80,
          ),
          const SizedBox(height: 20),
          const Text(
            'Transfer Initiated!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            provider.transactionReference ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              provider.reset();
              Navigator.pop(context);
            },
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}
