import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/broker_setup_guide.dart';

/// "Where do I get these keys?" steps and links for the selected broker.
class BrokerSetupHelp extends StatelessWidget {
  const BrokerSetupHelp({super.key, required this.guide});

  final BrokerSetupGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('How to get your ${guide.title} API keys', style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final (i, step) in guide.steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 24, child: Text('${i + 1}.', style: theme.textTheme.bodyMedium)),
                    Expanded(child: Text(step, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            for (final link in guide.links)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.open_in_new),
                title: Text(link.label),
                subtitle: Text(link.url),
                onTap: () => launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
                trailing: IconButton(
                  tooltip: 'Copy link',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link.url));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
