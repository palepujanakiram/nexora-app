import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// In-memory WebView for widget tests: records the loaded URL and lets a test
/// play the navigation callbacks a real browser would fire.
class FakeWebViewPlatform extends WebViewPlatform {
  FakeWebViewController? controller;
  FakeNavigationDelegate? delegate;

  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) =>
      controller = FakeWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      delegate = FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      _FakeWebViewWidget(params);

  /// What the page decides for a navigation to [url].
  Future<NavigationDecision> navigate(String url) async =>
      await delegate!.onNavigationRequest!(NavigationRequest(url: url, isMainFrame: true));
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  Uri? loaded;
  JavaScriptMode? javaScriptMode;

  @override
  Future<void> loadRequest(LoadRequestParams params) async => loaded = params.uri;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async => this.javaScriptMode = javaScriptMode;

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageStarted;
  UrlChangeCallback? onUrlChange;
  ProgressCallback? onProgress;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async =>
      this.onNavigationRequest = onNavigationRequest;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async => this.onPageStarted = onPageStarted;

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async => this.onUrlChange = onUrlChange;

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async => this.onProgress = onProgress;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback onWebResourceError) async {}

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback onHttpAuthRequest) async {}

  @override
  Future<void> setOnSSlAuthError(SslAuthErrorCallback onSslAuthError) async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand(child: Text('fake browser'));
}
