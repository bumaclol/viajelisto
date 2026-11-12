bool appIsInstalled() => false;

bool appCanPromptInstall() => false;

Future<String> promptInstall() async => 'manual';

Future<bool> requestAlerts() async => true;

Future<void> showAlert(String title, String body) async {}
