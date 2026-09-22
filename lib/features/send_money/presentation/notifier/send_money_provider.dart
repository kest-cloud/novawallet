import 'package:flutter/foundation.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/usecases/send_money_usecase.dart';
import 'package:uuid/uuid.dart';

enum SendMoneyStatus {
  initial,
  submitting,
  completedOnline,
  queuedOffline,
  error,
}

class SendMoneyProvider extends ChangeNotifier {
  final SendMoneyUseCase sendMoneyUseCase;

  SendMoneyProvider({required this.sendMoneyUseCase}) {
    _generateAttemptIdempotencyKey();
  }

  int _currentStep = 0;
  SendMoneyStatus _status = SendMoneyStatus.initial;
  String _recipientAccountNumber = '';
  String _recipientBankCode = '011';
  String _recipientBankName = 'FirstBank of Nigeria';
  String _recipientName = '';
  Money _amount = Money.zero;
  String _narration = '';
  String? _errorMessage;
  TransferSubmissionResult? _submissionResult;

  // Single idempotency key generated once per user-initiated transfer attempt.
  // CRITICAL: Guaranteed to never regenerate on widget rebuilds.
  late String _activeIdempotencyKey;

  int get currentStep => _currentStep;
  SendMoneyStatus get status => _status;
  String get recipientAccountNumber => _recipientAccountNumber;
  String get recipientBankCode => _recipientBankCode;
  String get recipientBankName => _recipientBankName;
  String get recipientName => _recipientName;
  Money get amount => _amount;
  String get narration => _narration;
  String? get errorMessage => _errorMessage;
  TransferSubmissionResult? get submissionResult => _submissionResult;
  String get activeIdempotencyKey => _activeIdempotencyKey;

  bool get isSubmitting => _status == SendMoneyStatus.submitting;

  void _generateAttemptIdempotencyKey() {
    const uuid = Uuid();
    _activeIdempotencyKey = uuid.v4();
    debugPrint(
      '[SendMoneyProvider] Generated transfer idempotencyKey: $_activeIdempotencyKey',
    );
    debugPrint(
      '[SendMoneyProvider] Generated transfer idempotencyKey: $_activeIdempotencyKey',
    );
  }

  void setRecipient({
    required String accountNumber,
    required String bankCode,
    required String bankName,
    required String name,
  }) {
    _recipientAccountNumber = accountNumber;
    _recipientBankCode = bankCode;
    _recipientBankName = bankName;
    _recipientName = name;
    _errorMessage = null;
    notifyListeners();
  }

  void setAmountAndNarration({required Money amount, String narration = ''}) {
    _amount = amount;
    _narration = narration;
    _errorMessage = null;
    notifyListeners();
  }

  void goToStep(int step) {
    _currentStep = step;
    _errorMessage = null;
    notifyListeners();
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<bool> submitTransfer() async {
    _status = SendMoneyStatus.submitting;
    _errorMessage = null;
    debugPrint(
      '[SendMoneyProvider] Submitting transfer with idempotencyKey: $_activeIdempotencyKey (amount: ${_amount.formatToNaira()}, recipient: $_recipientAccountNumber)',
    );
    debugPrint(
      '[SendMoneyProvider] Submitting transfer with idempotencyKey: $_activeIdempotencyKey (amount: ${_amount.formatToNaira()}, recipient: $_recipientAccountNumber)',
    );
    notifyListeners();

    final request = TransferRequest(
      recipientAccountNumber: recipientAccountNumber,
      recipientBankCode: recipientBankCode,
      recipientBankName: recipientBankName,
      recipientName: recipientName,
      amount: amount,
      narration: narration,
      idempotencyKey: _activeIdempotencyKey,
    );

    final result = await sendMoneyUseCase(request);
    return result.fold(
      onSuccess: (subResult) {
        _submissionResult = subResult;
        if (subResult.isQueuedOffline) {
          _status = SendMoneyStatus.queuedOffline;
        } else {
          _status = SendMoneyStatus.completedOnline;
        }
        notifyListeners();
        return true;
      },
      onError: (failure) {
        _errorMessage = failure.message;
        _status = SendMoneyStatus.error;
        notifyListeners();
        return false;
      },
    );
  }

  void reset() {
    _currentStep = 0;
    _status = SendMoneyStatus.initial;
    _recipientAccountNumber = '';
    _recipientBankCode = '011';
    _recipientBankName = 'FirstBank of Nigeria';
    _recipientName = '';
    _amount = Money.zero;
    _narration = '';
    _errorMessage = null;
    _submissionResult = null;
    _generateAttemptIdempotencyKey();
    notifyListeners();
  }
}
