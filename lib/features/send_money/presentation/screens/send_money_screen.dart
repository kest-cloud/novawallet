import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late PageController _pageController;
  final _recipientFormKey = GlobalKey<FormState>();
  final _amountFormKey = GlobalKey<FormState>();

  late final TextEditingController _accountController;
  late final TextEditingController _nameController;
  late final TextEditingController _amountNairaController;
  late final TextEditingController _narrationController;

  String _selectedBankCode = '011';
  String _selectedBankName = 'FirstBank of Nigeria';
  String _lastResolvedAccountNumber = '';

  static final List<String> _sampleRecipientNames = [
    'Chioma Chukwu',
    'Babatunde Fashola',
    'Fatima Aliko Dangote',
    'Oluwaseun Adeleke',
    'Ibrahim Danjuma',
    'Ngozi Okonjo',
    'Kelechi Iheanacho',
    'Zainab Ahmed',
    'Tunde Bakare',
    'Aisha Bello',
    'Folake Solanke',
    'Damilola Taylor',
    'Chinedu Okeke',
    'Halima Abubakar',
    'Opeoluwa Balogun',
    'Yusuf Maitama',
    'Blessing Okagbare',
    'Kunle Afolayan',
    'Amaka Eze',
    'Femi Otedola',
  ];

  String _resolveRandomRecipientName([String? accountNumber]) {
    final random = Random();
    if (accountNumber != null && accountNumber.trim().length >= 10) {
      final seed =
          (accountNumber.hashCode ^ DateTime.now().microsecondsSinceEpoch)
              .abs();
      return _sampleRecipientNames[seed % _sampleRecipientNames.length];
    }
    return _sampleRecipientNames[random.nextInt(_sampleRecipientNames.length)];
  }

  final List<Map<String, String>> _supportedBanks = [
    {'code': '011', 'name': 'FirstBank of Nigeria'},
    {'code': '058', 'name': 'Guaranty Trust Bank (GTBank)'},
    {'code': '057', 'name': 'Zenith Bank'},
    {'code': '044', 'name': 'Access Bank'},
    {'code': '033', 'name': 'United Bank for Africa (UBA)'},
    {'code': '214', 'name': 'First City Monument Bank (FCMB)'},
    {'code': '035', 'name': 'Wema Bank / ALAT'},
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<SendMoneyProvider>();
    _pageController = PageController(initialPage: provider.currentStep);
    _accountController = TextEditingController(
      text: provider.recipientAccountNumber,
    );
    _nameController = TextEditingController(text: provider.recipientName);
    _amountNairaController = TextEditingController(
      text: provider.amount.isPositive ? '${provider.amount.naira}' : '',
    );
    _narrationController = TextEditingController(text: provider.narration);
    _selectedBankCode = provider.recipientBankCode;
    _selectedBankName = provider.recipientBankName;
    _accountController.addListener(_onAccountNumberChanged);
  }

  void _onAccountNumberChanged() {
    final text = _accountController.text.trim();
    if (text.length == 10 && text != _lastResolvedAccountNumber) {
      _lastResolvedAccountNumber = text;
      setState(() {
        _nameController.text = _resolveRandomRecipientName(text);
      });
    } else if (text.length < 10) {
      _lastResolvedAccountNumber = '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _accountController.dispose();
    _nameController.dispose();
    _amountNairaController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
        leading: Consumer<SendMoneyProvider>(
          builder: (context, provider, _) {
            if (provider.status == SendMoneyStatus.completedOnline ||
                provider.status == SendMoneyStatus.queuedOffline) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (provider.currentStep > 0) {
                  provider.previousStep();
                  _previousPage();
                } else {
                  Navigator.pop(context);
                }
              },
            );
          },
        ),
      ),
      body: Consumer<SendMoneyProvider>(
        builder: (context, provider, _) {
          if (provider.status == SendMoneyStatus.completedOnline ||
              provider.status == SendMoneyStatus.queuedOffline) {
            return _buildResultView(context, provider);
          }

          return Column(
            children: [
              // Step Progress Indicator
              _buildStepIndicator(provider.currentStep),
              const Divider(height: 1, color: AppColors.borderLight),

              // Step Content Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildRecipientStep(context, provider),
                    _buildAmountStep(context, provider),
                    _buildConfirmStep(context, provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepIndicator(int currentStep) {
    final steps = ['Recipient', 'Amount', 'Confirm'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCompleted = currentStep > index;
          final isCurrent = currentStep == index;

          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: isCurrent || isCompleted
                      ? AppColors.accent
                      : AppColors.borderLight,
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? Colors.white
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isCurrent
                            ? AppColors.textPrimaryLight
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
                if (index < steps.length - 1)
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.0),
                      child: Divider(
                        color: AppColors.borderLight,
                        thickness: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 1: Recipient
  // -------------------------------------------------------------
  Widget _buildRecipientStep(BuildContext context, SendMoneyProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _recipientFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Who are you sending to?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter the destination bank and 10-digit NUBAN account number.',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedBankCode,
              decoration: const InputDecoration(
                labelText: 'Destination Bank',
                prefixIcon: Icon(Icons.account_balance_rounded),
              ),
              items: _supportedBanks.map((b) {
                return DropdownMenuItem(
                  value: b['code'],
                  child: Text(b['name']!, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedBankCode = val;
                    _selectedBankName = _supportedBanks.firstWhere(
                      (b) => b['code'] == val,
                    )['name']!;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Account Number Field
            TextFormField(
              controller: _accountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                LengthLimitingTextInputFormatter(10),
              ],
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Account Number',
                hintText: '10-digit NUBAN',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
              validator: (v) {
                if (v == null ||
                    v.trim().length != 10 ||
                    !RegExp(r'^\d{10}$').hasMatch(v.trim())) {
                  return 'Enter valid 10-digit account number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Account Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g. Chioma Chukwu',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                suffixIcon: Semantics(
                  label: 'Generate random recipient name',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    tooltip: 'Generate random name',
                    onPressed: () {
                      setState(() {
                        _nameController.text = _resolveRandomRecipientName();
                      });
                    },
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Account name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Continue Button
            Semantics(
              label: 'Continue to enter transfer amount',
              button: true,
              child: ElevatedButton(
                onPressed: () {
                  if (_recipientFormKey.currentState?.validate() ?? false) {
                    provider.setRecipient(
                      accountNumber: _accountController.text.trim(),
                      bankCode: _selectedBankCode,
                      bankName: _selectedBankName,
                      name: _nameController.text.trim(),
                    );
                    provider.goToStep(1);
                    _nextPage();
                  }
                },
                child: const Text('Continue to Amount'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 2: Amount & Narration
  // -------------------------------------------------------------
  Widget _buildAmountStep(BuildContext context, SendMoneyProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _amountFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How much would you like to send?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Sending to ${provider.recipientName} (${provider.recipientBankName})',
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // Amount Input Field
            TextFormField(
              controller: _amountNairaController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              ],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Amount (₦)',
                hintText: '0',
                prefixText: '₦ ',
                prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final naira = int.tryParse(v.trim());
                if (naira == null || naira <= 0) {
                  return 'Enter a valid positive integer amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Quick Preset Chips
            Wrap(
              spacing: 8,
              children: [1000, 5000, 10000, 20000, 50000].map((presetNaira) {
                final presetMoney = Money.fromNaira(presetNaira);
                return ActionChip(
                  label: Text('+${presetMoney.formatToNaira(showKobo: false)}'),
                  onPressed: () {
                    final current =
                        int.tryParse(_amountNairaController.text.trim()) ?? 0;
                    _amountNairaController.text = '${current + presetNaira}';
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Narration
            TextFormField(
              controller: _narrationController,
              decoration: const InputDecoration(
                labelText: 'Narration (Optional)',
                hintText: 'What is this transfer for?',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 32),

            // Review Transfer Button
            Semantics(
              label: 'Review transfer summary',
              button: true,
              child: ElevatedButton(
                onPressed: () {
                  if (_amountFormKey.currentState?.validate() ?? false) {
                    final naira =
                        int.tryParse(_amountNairaController.text.trim()) ?? 0;
                    final money = Money.fromNaira(naira);

                    provider.setAmountAndNarration(
                      amount: money,
                      narration: _narrationController.text.trim(),
                    );
                    provider.goToStep(2);
                    _nextPage();
                  }
                },
                child: const Text('Review Transfer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 3: Confirm & Summary
  // -------------------------------------------------------------
  Widget _buildConfirmStep(BuildContext context, SendMoneyProvider provider) {
    final amount = provider.amount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirm Transfer Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Please verify recipient details before sending.',
            style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Error banner if any
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

          // Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  'Recipient Name',
                  provider.recipientName,
                  isBold: true,
                ),
                const Divider(height: 24, color: AppColors.borderLight),
                _buildSummaryRow('Bank Name', provider.recipientBankName),
                const Divider(height: 24, color: AppColors.borderLight),
                _buildSummaryRow(
                  'Account Number',
                  provider.recipientAccountNumber,
                ),
                const Divider(height: 24, color: AppColors.borderLight),
                _buildSummaryRow(
                  'Transfer Amount',
                  amount.formatToNaira(),
                  isAccent: true,
                ),
                const Divider(height: 24, color: AppColors.borderLight),
                _buildSummaryRow('Transaction Fee', '₦0.00 (Free)'),
                if (provider.narration.isNotEmpty) ...[
                  const Divider(height: 24, color: AppColors.borderLight),
                  _buildSummaryRow('Narration', provider.narration),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Confirm & Send Button
          Semantics(
            label: 'Confirm and send ${amount.formatToNaira()}',
            button: true,
            child: ElevatedButton(
              onPressed: provider.isSubmitting
                  ? null
                  : () {
                      provider.submitTransfer();
                    },
              child: provider.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Confirm & Send ${amount.formatToNaira()}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isAccent = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondaryLight,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isAccent ? 16 : 14,
              fontWeight: isBold || isAccent
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: isAccent
                  ? AppColors.accentDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }

  // RESULT VIEW (Online Success OR Offline Queued)

  Widget _buildResultView(BuildContext context, SendMoneyProvider provider) {
    final isOfflineQueued = provider.status == SendMoneyStatus.queuedOffline;
    final result = provider.submissionResult;

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: isOfflineQueued
                ? const Color(0xFFFEF3C7)
                : AppColors.accent.withValues(alpha: 0.15),
            child: Icon(
              isOfflineQueued
                  ? Icons.cloud_queue_rounded
                  : Icons.check_circle_rounded,
              size: 48,
              color: isOfflineQueued
                  ? const Color(0xFFD97706)
                  : AppColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isOfflineQueued
                ? 'Pending — will send when back online'
                : 'Transfer Successful!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isOfflineQueued
                ? 'Your transfer of ${provider.amount.formatToNaira()} has been securely queued in the offline database. It will automatically replay once your connection is restored.'
                : 'Your transfer of ${provider.amount.formatToNaira()} to ${provider.recipientName} has been processed.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondaryLight,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (result != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                'Ref: ${result.reference}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          const SizedBox(height: 36),
          Semantics(
            label: 'Return to wallet home',
            button: true,
            child: ElevatedButton(
              onPressed: () {
                provider.reset();
                Navigator.pop(context);
              },
              child: const Text('Back to Wallet Home'),
            ),
          ),
        ],
      ),
    );
  }
}
