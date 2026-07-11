import 'dart:html' as html;
import 'dart:js_util' as js_util;

Future<String> promptAppInstall() async {
  try {
    final raw = js_util.callMethod<Object?>(
      html.window,
      'ujustbuyInstallApp',
      const [],
    );
    if (raw == null) return 'unavailable';

    final result = await js_util.promiseToFuture<Object?>(raw);
    return result?.toString() ?? 'unavailable';
  } catch (_) {
    return 'failed';
  }
}
