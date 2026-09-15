import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet_mobile/core/di/injection_container.dart' as di;
import 'package:nova_wallet_mobile/main.dart';

void main() {
  setUp(() async {
    await di.initDependencies();
  });

  tearDown(() async {
    await di.sl.reset();
  });

  testWidgets('NovaWalletApp smoke test - renders wallet home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NovaWalletApp());
    await tester.pumpAndSettle();

    expect(find.text('NovaWallet Mobile'), findsOneWidget);
    expect(find.text('Total Available Balance'), findsOneWidget);
    expect(find.text('Send Money'), findsOneWidget);
    expect(find.text('Nova Save'), findsOneWidget);
  });
}
