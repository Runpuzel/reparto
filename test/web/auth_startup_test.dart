import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web authentication startup has no remote passkeys dependency', () {
    final index = File('web/index.html').readAsStringSync();
    final bundle = File('web/passkeys_bundle.js');

    expect(bundle.existsSync(), isTrue);
    expect(bundle.readAsStringSync(), contains('PasskeyAuthenticator'));
    expect(index, contains('src="passkeys_bundle.js"'));
    expect(index, isNot(contains('github.com/corbado/flutter-passkeys')));
    expect(index, isNot(contains('Secure sign-in took too long')));
    expect(index, isNot(contains('loadPasskeys')));
  });
}
