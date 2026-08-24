import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oddlet/features/egg/egg_view.dart';
import 'package:oddlet/features/egg/home_screen.dart';

void main() {
  testWidgets('home screen shows the wordmark and the egg', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('ODDLET'), findsOneWidget);
    expect(find.byType(EggView), findsOneWidget);
  });

  testWidgets('egg keeps animating without settling', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // A repeating idle animation never settles; pumpAndSettle would time out.
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.hasRunningAnimations, isTrue);
  });
}
