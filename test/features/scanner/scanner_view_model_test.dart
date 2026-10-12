import 'package:flutter_test/flutter_test.dart';
import 'package:scaleezy/core/network/api_client.dart';
import 'package:scaleezy/features/products/data/product_models.dart';
import 'package:scaleezy/features/scanner/presentation/view_models/scanner_view_model.dart';

import 'scanner_fakes.dart';

Future<VariantItem?> neverAsked(List<VariantItem> _) =>
    throw StateError('should not ask');

void main() {
  test('one match is shown and remembered', () async {
    final repo = FakeProductRepository((_) async => [piece('a')]);
    final vm = ScannerViewModel(repo);

    expect(await vm.lookup('  890a ', choose: neverAsked), isNull);
    expect(repo.calls.single, {'q': '890a', 'page': 1, 'limit': 10});
    expect(vm.scanned?.id, 'a');
    expect(vm.recent.map((v) => v.id), ['a']);
    expect((vm.lookingUp, vm.error), (false, null));
  });

  test('no match clears the piece and says so', () async {
    final repo = FakeProductRepository((_) async => [piece('a')]);
    final vm = ScannerViewModel(repo);
    await vm.lookup('890a', choose: neverAsked);

    repo.answer = (_) async => [];
    expect(await vm.lookup('nope', choose: neverAsked), isNull);
    expect(vm.scanned, isNull);
    expect(vm.error, 'No product matches "nope".');
  });

  test(
    'several matches ask which one; dismissing keeps the last piece',
    () async {
      final repo = FakeProductRepository((_) async => [piece('a')]);
      final vm = ScannerViewModel(repo);
      await vm.lookup('890a', choose: neverAsked);

      repo.answer = (_) async => [piece('b'), piece('c')];
      await vm.lookup('kurta', choose: (m) async => m.last);
      expect(vm.scanned?.id, 'c');
      expect(vm.recent.map((v) => v.id), ['c', 'a']);

      await vm.lookup('kurta', choose: (_) async => null);
      expect(vm.scanned?.id, 'c');
      expect((vm.lookingUp, vm.error), (false, null));
    },
  );

  test('a server error keeps the piece and returns the message', () async {
    final repo = FakeProductRepository((_) async => [piece('a')]);
    final vm = ScannerViewModel(repo);
    await vm.lookup('890a', choose: neverAsked);

    repo.answer = (_) async => throw const ApiException('Server is down');
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
    await vm.lookup('890a', choose: neverAsked);
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
      await vm.lookup('$i', choose: neverAsked);
    }
    await vm.lookup('5', choose: neverAsked);
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
