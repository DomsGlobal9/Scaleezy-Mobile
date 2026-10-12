import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/scanner/presentation/view_models/scanner_view_model.dart';

import 'scanner_fakes.dart';

Future<VariantItem?> neverAsked(List<VariantItem> _) =>
    throw StateError('should not ask');

void main() {
  test('an exact scan is shown, verified and remembered', () async {
    final repo = FakeProductRepository(
      (_) async => [piece('b'), piece('a')],
      found: (_) async => exactHits([piece('a')]),
    );
    final vm = ScannerViewModel(repo);

    expect(await vm.lookup('  890a ', choose: neverAsked), isNull);
    expect(repo.searched.single, '890a');
    // The piece's own stock and prices come from the variant search, on the matched code.
    expect(repo.calls.single, {'q': '890a', 'page': 1, 'limit': 10});
    expect(vm.scanned?.id, 'a');
    expect(vm.exactMatch, isTrue);
    expect(vm.recent.map((v) => v.id), ['a']);
    expect((vm.lookingUp, vm.error), (false, null));
  });

  test('an exact match ignores case and asks with the stored code', () async {
    final repo = FakeProductRepository(
      (_) async => [piece('a')],
      found: (_) async => exactHits([piece('a')]),
    );
    final vm = ScannerViewModel(repo);

    await vm.lookup('SKU-A', choose: neverAsked);
    expect(repo.calls.single['q'], 'SKU-a');
    expect((vm.scanned?.id, vm.exactMatch), ('a', true));
  });

  test(
    'a scanned code with no exact hit is not found, without guessing',
    () async {
      final repo = FakeProductRepository(
        (_) async => [piece('a')],
        // A title match from /search is not the tag that was scanned.
        found: (_) async => const SearchResults(
          variants: [SearchHit(id: 'a', label: 'Saree - Red', code: 'V-a')],
        ),
      );
      final vm = ScannerViewModel(repo);

      expect(await vm.lookup('saree', choose: neverAsked), isNull);
      expect(repo.calls, isEmpty);
      expect(vm.scanned, isNull);
      expect(vm.error, 'Nothing found for "saree". Check the barcode or SKU.');
    },
  );

  test('typed text with no exact hit falls back to the name search', () async {
    final repo = FakeProductRepository((_) async => [piece('a')]);
    final vm = ScannerViewModel(repo);

    await vm.lookup('saree', typed: true, choose: neverAsked);
    expect(repo.calls.single['q'], 'saree');
    expect(vm.scanned?.id, 'a');
    expect(vm.exactMatch, isFalse);
  });

  test('an exact product code opens the product', () async {
    final repo = FakeProductRepository(
      (_) async => [],
      found: (_) async => const SearchResults(
        products: [SearchHit(id: 'p1', label: 'Saree', code: 'SE-001')],
      ),
    );
    final vm = ScannerViewModel(repo);
    final shown = <String>[];

    await vm.lookup(
      'se-001',
      choose: neverAsked,
      openProduct: (p) async => shown.add(p.id),
    );
    expect(shown, ['p1']);
    expect((vm.scanned, vm.error, vm.lookingUp), (null, null, false));
  });

  test('no match clears the piece and says so', () async {
    final repo = FakeProductRepository((_) async => [piece('a')]);
    final vm = ScannerViewModel(repo);
    await vm.lookup('890a', typed: true, choose: neverAsked);

    repo.answer = (_) async => [];
    expect(await vm.lookup('nope', typed: true, choose: neverAsked), isNull);
    expect(vm.scanned, isNull);
    expect(vm.error, 'Nothing found for "nope". Check the barcode or SKU.');
  });

  test(
    'several matches ask which one; dismissing keeps the last piece',
    () async {
      final repo = FakeProductRepository((_) async => [piece('a')]);
      final vm = ScannerViewModel(repo);
      await vm.lookup('890a', typed: true, choose: neverAsked);

      repo.answer = (_) async => [piece('b'), piece('c')];
      await vm.lookup('kurta', typed: true, choose: (m) async => m.last);
      expect(vm.scanned?.id, 'c');
      expect(vm.recent.map((v) => v.id), ['c', 'a']);

      await vm.lookup('kurta', typed: true, choose: (_) async => null);
      expect(vm.scanned?.id, 'c');
      expect((vm.lookingUp, vm.error), (false, null));
    },
  );

  test('a server error keeps the piece and returns the message', () async {
    final repo = FakeProductRepository((_) async => [piece('a')]);
    final vm = ScannerViewModel(repo);
    await vm.lookup('890a', typed: true, choose: neverAsked);

    repo.found = (_) async => throw const ApiException('Server is down');
    expect(await vm.lookup('890b', choose: neverAsked), 'Server is down');
    expect(vm.error, 'Server is down');
    expect(vm.scanned?.id, 'a');
    expect(vm.lookingUp, isFalse);
  });

  test('the camera reporting the same tag again is ignored', () async {
    final repo = FakeProductRepository((_) async => [piece('a')]);
    final vm = ScannerViewModel(repo);

    expect(vm.wantsScan('890a'), isTrue);
    expect(vm.wantsScan('  '), isFalse);
    await vm.lookup('890a', typed: true, choose: neverAsked);
    expect(vm.wantsScan('890a'), isFalse);
    expect(vm.wantsScan('890b'), isTrue);

    // A miss leaves nothing on screen, so the same code may be tried again.
    repo.answer = (_) async => [];
    await vm.lookup('890x', choose: neverAsked);
    expect(vm.wantsScan('890x'), isTrue);
  });

  test('nothing new is looked up while a lookup runs', () async {
    final repo = FakeProductRepository((_) async => [piece('a')]);
    final vm = ScannerViewModel(repo);
    final pending = vm.lookup('890a', choose: neverAsked);
    expect(vm.lookingUp, isTrue);
    expect(vm.wantsScan('890b'), isFalse);
    await pending;
  });

  test('recent keeps the last eight, newest first, without repeats', () async {
    final repo = FakeProductRepository((q) async => [piece(q)]);
    final vm = ScannerViewModel(repo);
    for (var i = 0; i < 10; i++) {
      await vm.lookup('$i', typed: true, choose: neverAsked);
    }
    await vm.lookup('5', typed: true, choose: neverAsked);
    expect(vm.recent.map((v) => v.id), [
      '5',
      '9',
      '8',
      '7',
      '6',
      '4',
      '3',
      '2',
    ]);
  });
}
