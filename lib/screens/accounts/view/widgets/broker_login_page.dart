import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../common/presentation/widgets/info_banner.dart';
import '../../model/login_redirect.dart';

/// The broker's login page in an in-app browser. When the broker redirects
/// back with the login code, the page closes and returns that address, so the
/// user never has to copy it. Returns null if the user closes the page.
///
/// When the broker's page fails (an HTTP error such as Upstox refusing the
/// client id or redirect URI, or no connection), a banner says so above the
/// page instead of leaving it blank.
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

  /// Why the page didn't load, and where it stopped; null while it's fine.
  String? _error;
  String? _errorUrl;

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
        onHttpError: (error) {
          final status = error.response?.statusCode;
          _fail('The broker\'s page answered with an error${status == null ? '' : ' (HTTP $status)'}.',
              (error.request?.uri ?? error.response?.uri)?.toString());
        },
        onWebResourceError: (error) {
          // Images or scripts that fail don't stop the login page itself.
          if (error.isForMainFrame == false) return;
          _fail('The broker\'s page didn\'t load: ${error.description}', error.url);
        },
      ));
    _load();
  }

  void _load() => _controller.loadRequest(Uri.parse(widget.loginUrl));

  void _fail(String message, String? url) {
    if (mounted) {
      setState(() {
        _error = message;
        _errorUrl = url;
      });
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _errorUrl = null;
      _progress = 0;
    });
    _load();
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
        body: Column(
          children: [
            if (_error != null) _errorBanner(context),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      );

  Widget _errorBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InfoBanner(
        color: theme.colorScheme.errorContainer,
        text: [
          _error!,
          ?_errorUrl,
          'If the broker says the client id or redirect URI is wrong, the account\'s API key and redirect URI '
              'must match your broker app exactly. Delete the account and add it again to change them.',
        ].join('\n\n'),
        action: TextButton(onPressed: _retry, child: const Text('Try again')),
      ),
    );
  }
}
