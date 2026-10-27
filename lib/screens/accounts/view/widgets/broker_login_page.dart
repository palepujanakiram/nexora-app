import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../model/login_redirect.dart';

/// The broker's login page in an in-app browser. When the broker redirects
/// back with the login code, the page closes and returns that address, so the
/// user never has to copy it. Returns null if the user closes the page.
class BrokerLoginPage extends StatefulWidget {
  const BrokerLoginPage({super.key, required this.title, required this.loginUrl, required this.redirect});

  final String title;
  final String loginUrl;
  final LoginRedirect redirect;

  static Future<String?> open(BuildContext context,
          {required String title, required String loginUrl, required LoginRedirect redirect}) =>
      Navigator.of(context).push<String>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BrokerLoginPage(title: title, loginUrl: loginUrl, redirect: redirect),
      ));

  @override
  State<BrokerLoginPage> createState() => _BrokerLoginPageState();
}

class _BrokerLoginPageState extends State<BrokerLoginPage> {
  late final WebViewController _controller;
  var _progress = 0;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) =>
            _catchRedirect(request.url) ? NavigationDecision.prevent : NavigationDecision.navigate,
        // Backups for redirects that don't go through onNavigationRequest
        // (e.g. some server-side redirects on Android).
        onPageStarted: _catchRedirect,
        onUrlChange: (change) => _catchRedirect(change.url ?? ''),
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      ))
      ..loadRequest(Uri.parse(widget.loginUrl));
  }

  /// Closes the page with [url] if it's the broker's redirect.
  bool _catchRedirect(String url) {
    if (!widget.redirect.matches(url)) return false;
    if (!_finished && mounted) {
      _finished = true;
      Navigator.of(context).pop(url);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      );
}
