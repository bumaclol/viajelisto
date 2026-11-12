import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Future<bool> sharePlainText(String text) async {
  final navigator = web.window.navigator;
  if (!navigator.has('share')) return false;
  try {
    final data = {'text': text, 'title': 'Resumen del viaje'}.jsify();
    final result = navigator.callMethod<JSAny?>('share'.toJS, data);
    if (result != null && result.isA<JSPromise>()) {
      await (result as JSPromise).toDart;
    }
    return true;
  } catch (_) {
    return false;
  }
}
