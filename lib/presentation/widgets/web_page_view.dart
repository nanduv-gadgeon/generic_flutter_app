import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/validation/link_rules.dart';
import '../auth/auth_form.dart';
import '../../l10n/l10n.dart';

/// Opens [url] in a tall sheet over the current screen, titled [title], with a close button.
Future<void> showWebPageSheet(BuildContext context, {required String title, required String url}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Dragging would fight the page's own scrolling; the close button dismisses it.
      enableDrag: false,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(child: WebPageView(url: url)),
          ],
        ),
      ),
    );

/// A web page (the customer's privacy policy or terms of use) with a loading spinner and an
/// error message.
///
/// This loads the page over the network even when isCloud is false: an agreed exception to the
/// "no network calls in Phase 1" rule, recorded in docs/tasks/1.1.11-profile.md.
class WebPageView extends StatefulWidget {
  const WebPageView({super.key, required this.url});

  final String url;

  @override
  State<WebPageView> createState() => _WebPageViewState();
}

class _WebPageViewState extends State<WebPageView> {
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final url = Uri.tryParse(widget.url);
    if (url == null || !isSecureWebLink(url)) {
      _loading = false;
      _failed = true;
      return;
    }
    // JavaScript stays off (the default): policy pages are plain text.
    _controller = WebViewController()
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => isSecureWebLink(Uri.parse(request.url))
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) => _update(loading: false),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) _update(loading: false, failed: true);
          },
        ),
      )
      ..loadRequest(url);
  }

  void _update({required bool loading, bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _loading = loading;
      _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      children: [
        if (controller != null && !_failed) WebViewWidget(controller: controller),
        if (_loading)
          Center(
            child: Semantics(
              label: context.l10n.profileLoadingPage,
              child: const CircularProgressIndicator(),
            ),
          ),
        if (_failed)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AuthErrorMessage(context.l10n.profilePageFailed),
            ),
          ),
      ],
    );
  }
}
