import 'dart:js_interop';

@JS('ujustbuyInstallApp')
external JSPromise<JSString> _ujustbuyInstallApp();

Future<String> promptAppInstall() async {
  try {
    final result = await _ujustbuyInstallApp().toDart;
    return result.toDart;
  } catch (_) {
    return 'failed';
  }
}
