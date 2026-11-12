import 'dart:js_interop';

@JS('viajelistoInstalled')
external bool _installed();

@JS('viajelistoCanInstall')
external bool _canInstall();

@JS('viajelistoInstall')
external JSPromise<JSString> _install();

@JS('viajelistoAskNotify')
external JSPromise<JSString> _askNotify();

@JS('viajelistoNotify')
external bool _notify(String title, String body);

bool appIsInstalled() {
  try {
    return _installed();
  } catch (_) {
    return false;
  }
}

bool appCanPromptInstall() {
  try {
    return _canInstall();
  } catch (_) {
    return false;
  }
}

Future<String> promptInstall() async {
  try {
    final result = await _install().toDart;
    return result.toDart;
  } catch (_) {
    return 'manual';
  }
}

Future<bool> requestAlerts() async {
  try {
    final result = await _askNotify().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

Future<void> showAlert(String title, String body) async {
  try {
    _notify(title, body);
  } catch (_) {}
}
