import 'package:web/web.dart' as web;

class GoogleReply {
  const GoogleReply({this.idToken, this.error});

  final String? idToken;
  final String? error;
}

const _storageKey = 'viajelisto_google_hash';

GoogleReply takeGoogleReply() {
  final stored = web.window.sessionStorage.getItem(_storageKey);
  final raw = (stored != null && stored.isNotEmpty)
      ? stored
      : _hashBody(web.window.location.hash);
  if (stored != null) web.window.sessionStorage.removeItem(_storageKey);
  if (raw == null || raw.isEmpty) return const GoogleReply();
  if (stored == null) {
    final path = web.window.location.pathname;
    final search = web.window.location.search;
    web.window.history.replaceState(null, '', '$path$search');
  }
  final params = Uri.splitQueryString(raw);
  final token = params['id_token'];
  if (token != null && token.isNotEmpty) return GoogleReply(idToken: token);
  final reason = params['error'];
  if (reason == null || reason.isEmpty) return const GoogleReply();
  return GoogleReply(
    error: reason == 'access_denied'
        ? 'Google no dejó entrar con esa cuenta.'
        : 'Google no dejó entrar.',
  );
}

String? _hashBody(String hash) {
  if (hash.length < 2) return null;
  return hash.substring(1);
}

void forgetGoogleSession() {
  web.window.sessionStorage.removeItem(_storageKey);
}

void openGoogleSignIn(String clientId) {
  final nonce = '${DateTime.now().microsecondsSinceEpoch}';
  final uri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId,
    'redirect_uri': web.window.location.origin,
    'response_type': 'id_token',
    'scope': 'openid email profile',
    'nonce': nonce,
    'prompt': 'select_account',
  });
  web.window.location.assign(uri.toString());
}
