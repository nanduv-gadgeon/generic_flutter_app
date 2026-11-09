// Rules for the web pages the app shows (privacy policy, terms of use). Pure functions.

/// Only https pages with a host may load; anything else (http, file, javascript, intents) is
/// blocked, including links tapped inside the page.
bool isSecureWebLink(Uri url) => url.scheme == 'https' && url.host.isNotEmpty;
