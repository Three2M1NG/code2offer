import 'package:flutter_test/flutter_test.dart';
import 'package:code2offer/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const Code2OfferApp());
    expect(find.text('Algorithm Coach'), findsOneWidget);
    expect(find.text('Problems'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
