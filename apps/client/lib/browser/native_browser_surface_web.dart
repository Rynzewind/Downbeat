import 'package:flutter/material.dart';

final class NativeBrowserSurface extends StatelessWidget {
  const NativeBrowserSurface({
    required this.url,
    required this.onUrlChanged,
    super.key,
  });

  final Uri url;
  final ValueChanged<Uri> onUrlChanged;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(url.host, style: Theme.of(context).textTheme.headlineSmall),
  );
}
