import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/core/theme/app_theme.dart';
import 'package:scaleezy/core/widgets/async_state.dart';
import 'package:scaleezy/core/widgets/no_access_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, [ThemeData? theme]) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('a 403 is a closed door, not a failure', (tester) async {
    var retries = 0;
    await pump(
      tester,
      ErrorView.fromError(
        const ApiException('You cannot see suppliers.', statusCode: 403),
        what: 'suppliers',
        onRetry: () => retries++,
      ),
    );
    expect(find.byType(NoAccessView), findsOneWidget);
    expect(find.text('Not part of your role'), findsOneWidget);
    expect(find.text('You cannot see suppliers.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'a failed load names what it was loading (${theme.brightness.name})',
      (tester) async {
        var retries = 0;
        await pump(
          tester,
          ErrorView.fromError(
            const ApiException('Could not reach the server.'),
            what: 'customers',
            onRetry: () => retries++,
          ),
          theme,
        );
        expect(find.text('Could not load customers.'), findsOneWidget);
        expect(find.text('Could not reach the server.'), findsOneWidget);
        expect(
          find.text(
            'This is not the same as having none — nothing has been lost.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Try again'));
        expect(retries, 1);
      },
    );
  }

  testWidgets('older callers keep their look', (tester) async {
    await pump(tester, const ErrorView(message: 'No orders yet.'));
    expect(find.byType(EmptyState), findsOneWidget);

    await pump(tester, ErrorView(message: 'Offline.', onRetry: () {}));
    expect(find.text('Offline.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('NoAccess names what the person wanted to do', (tester) async {
    await pump(
      tester,
      const NoAccessView(what: 'pick orders', permission: 'shelf:putaway'),
      AppTheme.dark,
    );
    expect(find.text('You cannot pick orders'), findsOneWidget);
    expect(
      find.text(
        'Ask whoever manages your team for the permission to put stock away and move it.',
      ),
      findsOneWidget,
    );
  });
}
