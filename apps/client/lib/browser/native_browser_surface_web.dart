import 'package:flutter/material.dart';

import 'browser_navigation_controller.dart';

final class NativeBrowserSurface extends StatelessWidget {
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
  Widget build(BuildContext context) => Center(
    child: Text(url.host, style: Theme.of(context).textTheme.headlineSmall),
  );
}
