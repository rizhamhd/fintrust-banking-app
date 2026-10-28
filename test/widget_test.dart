import 'dart:ui' show Tristate;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintrust_banking_app/main.dart';

late Map<String, dynamic> capturedScenes;

Future<void> loadFonts() async {
  await rootBundle.loadString('assets/glyphs.json');
  capturedScenes = jsonDecode(
    await rootBundle.loadString('assets/design.json'),
  ) as Map<String, dynamic>;
  await (FontLoader(
    'Inter',
  )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
  await (FontLoader(
    'Instrument Sans',
  )..addFont(rootBundle.load('assets/fonts/InstrumentSans-Italic.ttf'))).load();
}

Future<void> open(
  WidgetTester tester,
  String id, {
  Size size = const Size(440, 956),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(FinTrustApp(key: UniqueKey(), initialScreen: id));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pump();
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    final layers = capturedScenes[id]['layers'] as List;
    await Future.wait(
      layers.where((l) => l['type'] == 'image').map((l) {
        final asset = (l['asset'] as String).replaceAll('.svg', '.png');
        return precacheImage(AssetImage(asset), context);
      }),
    );
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);
  testWidgets(
    'transfer validates amount, preserves edits, and confirms only after review',
    (tester) async {
      await open(tester, '211:512');
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.tap(find.bySemanticsLabel('Continue').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
      expect(find.text('Transfer Details'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '2500');
      await tester.enterText(find.byType(TextField).last, 'Coursework');
      await tester.tap(find.bySemanticsLabel('Continue').last);
      await tester.pumpAndSettle();
      expect(find.text('Review Transfer'), findsOneWidget);
      expect(find.text('LKR 2,500'), findsOneWidget);
      expect(find.text('Coursework'), findsOneWidget);
      expect(find.text('Transfer Successful'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Confirm transfer').last);
      await tester.pumpAndSettle();
      expect(find.text('Transfer Successful'), findsOneWidget);
      expect(find.text('LKR 2,500.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reload requires an operator, phone number and amount', (
    tester,
  ) async {
    await open(tester, '211:601');
    await tester.tap(find.bySemanticsLabel('Continue reload'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Select an operator and amount'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Select Airtel'));
    await tester.tap(find.bySemanticsLabel('Select LKR 500'));
    await tester.enterText(find.byType(TextField), '0771234567');
    await tester.tap(find.bySemanticsLabel('Continue reload'));
    await tester.pumpAndSettle();
    expect(find.text('Review mobile reload'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('0771234567'),
      ),
      findsOneWidget,
    );
  });
  testWidgets('card settings toggle independently', (tester) async {
    await open(tester, '211:651');
    final freeze = find.bySemanticsLabel('Freeze card');
    expect(
      tester.getSemantics(freeze).flagsCollection.isToggled,
      Tristate.isFalse,
    );
    await tester.tap(freeze);
    await tester.pump();
    expect(
      tester.getSemantics(freeze).flagsCollection.isToggled,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Online payments'))
          .flagsCollection
          .isToggled,
      Tristate.isTrue,
    );
  });
  testWidgets('small screen can scroll to dashboard navigation', (
    tester,
  ) async {
    await open(tester, '211:1046', size: const Size(360, 640));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Cards$')).last);
    await tester.pumpAndSettle();
    expect(find.text('My Cards'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('login validates credentials and verification before dashboard', (
    tester,
  ) async {
    await open(tester, '211:995');
    await tester.tap(find.bySemanticsLabel('Log in').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, 'student@example.com');
    await tester.enterText(find.byType(TextField).last, 'demo-password');
    await tester.tap(find.bySemanticsLabel('Log in').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(6));
    await tester.tap(find.bySemanticsLabel('Verify code').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byType(TextField).at(i), '${i + 1}');
    }
    await tester.tap(find.bySemanticsLabel('Verify code').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Maybe later').last);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Cards$')), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('saved beneficiary appears on transfer and review', (
    tester,
  ) async {
    await open(tester, '211:1564');
    await tester.tap(find.bySemanticsLabel('Save beneficiary').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).at(0), 'Test Recipient');
    await tester.enterText(find.byType(TextField).at(1), '1234567890');
    await tester.tap(find.bySemanticsLabel('Save beneficiary').last);
    await tester.pumpAndSettle();
    expect(find.text('Test Recipient'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.tap(find.bySemanticsLabel('Continue').last);
    await tester.pumpAndSettle();
    expect(find.text('Test Recipient'), findsOneWidget);
    expect(find.text('Review Transfer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('login remains usable on a phone with its keyboard open', (
    tester,
  ) async {
    await open(tester, '211:995', size: const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'student@example.com');
    await tester.enterText(find.byType(TextField).last, 'demo');
    final login = find.bySemanticsLabel('Log in').last;
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });
  testWidgets('desktop navigation works in a wide resizable window', (
    tester,
  ) async {
    await open(tester, '211:1046', size: const Size(1280, 800));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Cards$')).last);
    await tester.pumpAndSettle();
    expect(find.text('My Cards'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('all captured frames render with bundled assets', (tester) async {
    final scenes = capturedScenes;
    for (final id in scenes.keys) {
      await open(tester, id);
      expect(tester.takeException(), isNull, reason: 'Render $id');
      await expectLater(
        find.byType(BankingPrototype),
        matchesGoldenFile('previews/${id.replaceAll(':', '_')}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    }
  }, tags: 'golden');
}
