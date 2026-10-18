import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart' as mobile;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_windows/webview_windows.dart' as windows;

import 'browser_controller.dart';
import 'browser_navigation_controller.dart';

final class NativeBrowserSurface extends StatefulWidget {
  const NativeBrowserSurface({
    required this.url,
    required this.onUrlChanged,
    required this.navigationController,
    super.key,
  });

  final Uri url;
  final ValueChanged<Uri> onUrlChanged;
  final BrowserNavigationController navigationController;

  @override
  State<NativeBrowserSurface> createState() => _NativeBrowserSurfaceState();
}

final class _NativeBrowserSurfaceState extends State<NativeBrowserSurface> {
  mobile.WebViewController? _mobile;
  windows.WebviewController? _windows;
  StreamSubscription<String>? _windowsUrlSubscription;
  Uri? _lastBrowserUrl;
  Object? _error;

  void _reportBrowserUrl(Uri uri) {
    _lastBrowserUrl = uri;
    widget.onUrlChanged(uri);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (Platform.isAndroid) {
        final controller = mobile.WebViewController()
          ..setJavaScriptMode(mobile.JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            mobile.NavigationDelegate(
              onNavigationRequest: (request) {
                try {
                  BrowserController.resolveInput(request.url);
                  return mobile.NavigationDecision.navigate;
                } on FormatException {
                  return mobile.NavigationDecision.prevent;
                }
              },
              onUrlChange: (change) {
                final uri = Uri.tryParse(change.url ?? '');
                if (uri != null) _reportBrowserUrl(uri);
              },
            ),
          );
        final androidController = controller.platform;
        final cookieManager = mobile.WebViewCookieManager().platform;
        if (androidController is AndroidWebViewController &&
            cookieManager is AndroidWebViewCookieManager) {
          await cookieManager.setAcceptThirdPartyCookies(
            androidController,
            true,
          );
        }
        await controller.loadRequest(widget.url);
        _mobile = controller;
        widget.navigationController.attach(
          back: () async {
            if (await controller.canGoBack()) await controller.goBack();
          },
          forward: () async {
            if (await controller.canGoForward()) await controller.goForward();
          },
          reload: controller.reload,
        );
      } else if (Platform.isWindows) {
        final controller = windows.WebviewController();
        await controller.initialize();
        await controller.setPopupWindowPolicy(
          windows.WebviewPopupWindowPolicy.deny,
        );
        _windowsUrlSubscription = controller.url.listen((value) {
          final uri = Uri.tryParse(value);
          if (uri != null && uri.scheme == 'https') _reportBrowserUrl(uri);
        });
        await controller.loadUrl(widget.url.toString());
        _windows = controller;
        widget.navigationController.attach(
          back: controller.goBack,
          forward: controller.goForward,
          reload: controller.reload,
        );
      } else {
        throw UnsupportedError(
          'Native browser is unavailable on this platform',
        );
      }
      if (mounted) {
        setState(() {});
        if (Platform.isAndroid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              const MethodChannel('app.downbeat/browser')
                  .invokeMethod<void>('configureBrowser')
                  .then((_) => _mobile?.reload()),
            );
          });
        }
      }
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error);
    } on UnsupportedError catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void didUpdateWidget(covariant NativeBrowserSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    if (widget.url == _lastBrowserUrl) return;
    if (_mobile != null) unawaited(_mobile!.loadRequest(widget.url));
    if (_windows != null) unawaited(_windows!.loadUrl(widget.url.toString()));
  }

  @override
  void dispose() {
    widget.navigationController.detach();
    unawaited(_windowsUrlSubscription?.cancel());
    _windows?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Browser engine unavailable: $_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_mobile != null) return mobile.WebViewWidget(controller: _mobile!);
    if (_windows != null) return windows.Webview(_windows!);
    return const Center(child: CircularProgressIndicator());
  }
}
