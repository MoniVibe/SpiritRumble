import 'package:flutter_test/flutter_test.dart';

import 'package:bullethole_cards/main.dart';

void main() {
  testWidgets('loads sprit rumble scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const SpritRumbleApp());

    expect(find.text('Sprit Rumble'), findsOneWidget);
    expect(find.text('Draft From Shared Pool'), findsOneWidget);
    expect(find.textContaining('Active: Shaman 1'), findsOneWidget);
  });
}
