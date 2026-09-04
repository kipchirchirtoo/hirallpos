import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hirall_pos/main.dart';

void main() {
  testWidgets('Hirall POS app smoke test - unactivated boot to ActivationScreen', (WidgetTester tester) async {
    // Set 1280x800 desktop POS viewport
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: HirallPosApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HirallPosApp), findsOneWidget);
    expect(find.text('HIRALL POS'), findsOneWidget);
    expect(find.text('Activate Store Terminal'), findsOneWidget);
    expect(find.text('Dark Theme'), findsOneWidget); // Default is Light Theme
  });

  testWidgets('Hirall POS app smoke test - activated store terminal with theme toggle', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: HirallPosApp(
          organizationName: 'Chandarana Supermarket',
          branchName: 'Westlands Branch',
          businessType: 'supermarket',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HirallPosApp), findsOneWidget);
    expect(find.text('Chandarana Supermarket'), findsOneWidget);
    expect(find.text('BackOffice Login'), findsOneWidget);
    expect(find.text('Dark Theme'), findsOneWidget); // Default is Primary Light Grey Theme

    // Tap theme toggle button
    await tester.tap(find.text('Dark Theme'));
    await tester.pumpAndSettle();

    expect(find.text('Light Theme'), findsOneWidget);
  });
}
