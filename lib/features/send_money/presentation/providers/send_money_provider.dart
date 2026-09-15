import 'package:flutter/foundation.dart';
import 'package:nova_wallet_mobile/core/money/money.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/entities/transfer_request.dart';
import 'package:nova_wallet_mobile/features/send_money/domain/usecases/send_money_usecase.dart';

enum SendMoneyStatus { initial, submitting, success, error }

class SendMoneyProvider extends ChangeNotifier {
  final SendMoneyUseCase sendMoneyUseCase;

  SendMoneyProvider({required this.sendMoneyUseCase});

  SendMoneyStatus _status = SendMoneyStatus.initial;
  String? _transactionReference;
  String? _errorMessage;

  SendMoneyStatus get status => _status;
  String? get transactionReference => _transactionReference;
  String? get errorMessage => _errorMessage;

  void reset() {
    _status = SendMoneyStatus.initial;
    _transactionReference = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> sendMoney({
    required String recipientAccountNumber,
    required String recipientBankCode,
    required String recipientName,
    required Money amount,
    String narration = '',
  }) async {
    _status = SendMoneyStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    final request = TransferRequest(
      recipientAccountNumber: recipientAccountNumber,
      recipientBankCode: recipientBankCode,
      recipientName: recipientName,
      amount: amount,
      narration: narration,
    );

    final result = await sendMoneyUseCase(request);
    return result.fold(
      onSuccess: (ref) {
        _transactionReference = ref;
        _status = SendMoneyStatus.success;
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
}
