import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/main.dart';

void main() {
  testWidgets('ScaleezyApp smoke test renders navigation and dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ScaleezyApp());
    await tester.pump(const Duration(milliseconds: 500));

    // Verify app brand and navigation tabs
    expect(find.text('ScaleEzy Boutique'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);

    // Verify Hero valuation title presence
    expect(find.text('TOTAL INVENTORY VALUATION'), findsOneWidget);
  });
}
