import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/inventory/presentation/view_models/stock_movement_view_model.dart';
import 'package:scaleezy/features/inventory/presentation/widgets/stock_movement_dialog.dart';

import 'inventory_fakes.dart';

void main() {
  /// Opens the dialog over a blank page; the returned list receives its result.
  Future<List<bool?>> open(
    WidgetTester tester,
    StockMovementViewModel vm,
  ) async {
    final results = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showDialog<bool>(
                context: context,
                builder: (_) => StockMovementDialog(
                  title: 'Banarasi Saree (Red • M)',
                  sku: 'SKU-v1',
                  currentStock: '5',
                  variantId: 'v1',
                  isStockIn: vm.isStockIn,
                  viewModel: vm,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('receiving stock sends the typed values and closes with true', (
    tester,
  ) async {
    final repo = FakeInventoryRepository();
    final results = await open(
      tester,
      StockMovementViewModel(variantId: 'v1', isStockIn: true, inventory: repo),
    );

    await tester.tap(find.text('+5'));
    await tester.enterText(find.byType(TextField).last, '120');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Receive Stock'));
    await tester.pumpAndSettle();

    expect(repo.calls.single['quantity'], 6);
    expect(repo.calls.single['unitCost'], 120.0);
    expect(results, [true]);
    expect(find.byType(StockMovementDialog), findsNothing);
  });

  testWidgets('a server error stays in the dialog', (tester) async {
    final repo = FakeInventoryRepository()
      ..fail = const ApiException('Not enough stock');
    final results = await open(
      tester,
      StockMovementViewModel(
        variantId: 'v1',
        isStockIn: false,
        inventory: repo,
      ),
    );

    // No cost field when taking stock out.
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Issue Stock'));
    await tester.pumpAndSettle();

    expect(find.text('Not enough stock'), findsOneWidget);
    expect(find.byType(StockMovementDialog), findsOneWidget);
    expect(results, isEmpty);
  });
}
