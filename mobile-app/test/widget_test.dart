import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hirall_mobile_companion/main.dart';
import 'package:hirall_mobile_companion/core/models/cart_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MobileCartItem calculations', () {
    final item = MobileCartItem(
      id: '1',
      name: 'Test Milk',
      unitPrice: 100.0,
      quantity: 2.0,
      discountPercent: 10.0,
    );

    expect(item.grossTotal, equals(200.0));
    expect(item.discountAmount, equals(20.0));
    expect(item.netTotal, equals(180.0));
  });

  testWidgets('HirallMobileApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HirallMobileApp(),
      ),
    );

    expect(find.byType(HirallMobileApp), findsOneWidget);
  });
}
