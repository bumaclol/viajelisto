class GoogleReply {
  const GoogleReply({this.idToken, this.error});

  final String? idToken;
  final String? error;
}

GoogleReply takeGoogleReply() => const GoogleReply();

void openGoogleSignIn(String clientId) {}
