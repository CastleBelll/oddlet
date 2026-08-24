import 'package:flutter_test/flutter_test.dart';

import 'package:oddlet/main.dart';

void main() {
  testWidgets('app boots and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const OddletApp());

    expect(find.text('ODDLET'), findsOneWidget);
  });
}
