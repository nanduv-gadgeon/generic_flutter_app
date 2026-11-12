import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/presentation/widgets/web_page_view.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../fixtures/fake_web_view.dart';
import '../../fixtures/l10n.dart';

void main() {
  late FakeWebViewPlatform platform;

  setUp(() => WebViewPlatform.instance = platform = FakeWebViewPlatform());

  Future<void> pumpView(WidgetTester tester, String url) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(body: WebPageView(url: url)),
      ),
    );
    await tester.pump();
  }

  testWidgets('loads the https page with a labelled spinner until it finishes', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpView(tester, 'https://example.com/privacy');

    expect(platform.loaded, [Uri.parse('https://example.com/privacy')]);
    expect(find.bySemanticsLabel('Loading page'), findsOneWidget);
    semantics.dispose();

    platform.delegate!.onPageFinished!('https://example.com/privacy');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('fake-web-view')), findsOneWidget);
  });

  testWidgets('a failed load shows an error with an icon', (tester) async {
    await pumpView(tester, 'https://example.com/privacy');

    platform.delegate!.onWebResourceError!(
      const WebResourceError(errorCode: -2, description: 'offline', isForMainFrame: true),
    );
    await tester.pump();

    expect(
      find.text("Couldn't load this page. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('a non-https link is never loaded', (tester) async {
    await pumpView(tester, 'http://example.com/privacy');

    expect(platform.loaded, isEmpty);
    expect(
      find.text("Couldn't load this page. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('links tapped inside the page may only go to https', (tester) async {
    await pumpView(tester, 'https://example.com/privacy');
    final decide = platform.delegate!.onNavigationRequest!;

    // url -> allowed
    final cases = {
      'https://example.com/other': NavigationDecision.navigate,
      'http://example.com/other': NavigationDecision.prevent,
      'intent://example.com#Intent;end': NavigationDecision.prevent,
      'javascript:alert(1)': NavigationDecision.prevent,
    };
    for (final MapEntry(key: url, value: decision) in cases.entries) {
      expect(await decide(NavigationRequest(url: url, isMainFrame: true)), decision, reason: url);
    }
  });

  testWidgets('showWebPageSheet shows the title over the page and closes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showWebPageSheet(context, title: 'Privacy policy', url: 'https://example.com/p'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    platform.delegate!.onPageFinished!('https://example.com/p'); // stops the spinner
    await tester.pumpAndSettle();

    expect(find.text('Privacy policy'), findsOneWidget);
    expect(platform.loaded, [Uri.parse('https://example.com/p')]);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy policy'), findsNothing);
  });
}
