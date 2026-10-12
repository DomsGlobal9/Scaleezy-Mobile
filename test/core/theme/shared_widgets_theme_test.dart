import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/brand_logo.dart';
import 'package:scaleezy/core/widgets/scan_sheet.dart';
import 'package:scaleezy/core/widgets/status_pill.dart';
import 'package:scaleezy/core/widgets/ui.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    group('$name theme', () {
      Future<void> pump(WidgetTester tester, Widget child) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(body: child),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
      }

      testWidgets('every shared widget renders', (tester) async {
        final search = TextEditingController(text: 'saree');
        addTearDown(search.dispose);
        await pump(
          tester,
          SingleChildScrollView(
            child: Column(
              children: [
                const PageHeader(title: 'Orders', subtitle: '12 open'),
                const SectionHeader(title: 'Recent', trailing: 'See all'),
                SearchField(
                  controller: search,
                  hint: 'Search',
                  onChanged: (_) {},
                ),
                const SurfaceCard(child: Text('Card')),
                const Skeleton(height: 20),
                const NetImage(url: null, width: 60, height: 60),
                QuantityStepper(value: 0, max: 3, onChanged: (_) {}),
                for (final tone in Tone.values) StatusPill(tone.name, tone),
                const StatusPill('Partly sent', Tone.warning, large: true),
                const BrandLogo(),
                const LoadingView(message: 'Loading'),
                const ErrorView(message: 'Server is down.', onRetry: _noop),
                const ErrorView(message: 'No orders yet.'),
                const EmptyState(
                  Icons.inbox_outlined,
                  'No returns',
                  text: 'Returns show up here.',
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Orders'), findsOneWidget);
        expect(find.text('LOADING'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
      });

      testWidgets('confirmAction answers Cancel and confirm', (tester) async {
        bool? answer;
        await pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => answer = await confirmAction(
                context,
                title: 'Cancel order?',
                message: 'The pieces go back on the shelf.',
                confirmLabel: 'Cancel order',
                danger: true,
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Cancel order?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(answer, isFalse);

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel order'));
        await tester.pumpAndSettle();
        expect(answer, isTrue);
      });

      testWidgets('showMessage shows a toast with its icon', (tester) async {
        await pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showMessage(context, 'Saved.', success: true),
              child: const Text('go'),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500)); // slid in
        expect(find.text('Saved.'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        await tester.pump(
          const Duration(milliseconds: 2100),
        ); // success lasts 2 s
        await tester.pumpAndSettle();
        expect(find.text('Saved.'), findsNothing);
      });

      testWidgets('scan sheet opens', (tester) async {
        await pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showScanSheet(context, title: 'Scan a tag'),
              child: const Text('scan'),
            ),
          ),
        );
        await tester.tap(find.text('scan'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1)); // slid up
        expect(find.text('Scan a tag'), findsOneWidget);
        expect(find.text('Or type the code'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Scan a tag'), findsNothing);
        await tester.pump(const Duration(seconds: 1));
      });
    });
  }
}

void _noop() {}
