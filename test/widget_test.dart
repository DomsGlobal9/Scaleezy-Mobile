import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/main.dart';

void main() {
  testWidgets('ScaleezyApp smoke test renders navigation and dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ScaleezyApp());
    await tester.pump(const Duration(milliseconds: 500));

    // Verify app brand and navigation tabs
    expect(find.text('ScaleEzy'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Scanner'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);

    // Verify KPI card presence
    expect(find.text('Inventory Value'), findsOneWidget);
  });
}
