import 'package:flutter/material.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, required this.color, this.action});

  final String text;
  final Color color;

  /// Optional button shown at the end, e.g. "Retry".
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: action == null
            ? Text(text)
            : Row(children: [Expanded(child: Text(text)), action!]),
      );
}
