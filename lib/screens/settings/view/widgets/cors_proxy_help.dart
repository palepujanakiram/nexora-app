import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/cors_proxy_guide.dart';

/// Step-by-step guide for creating the Cloudflare Worker proxy, with a
/// button that copies the bundled worker code.
class CorsProxyHelp extends StatefulWidget {
  const CorsProxyHelp({super.key, required this.loadWorkerScript, this.initiallyExpanded = false});

  final Future<String> Function() loadWorkerScript;
  final bool initiallyExpanded;

  @override
  State<CorsProxyHelp> createState() => _CorsProxyHelpState();
}

class _CorsProxyHelpState extends State<CorsProxyHelp> {
  String? _code;

  @override
  void initState() {
    super.initState();
    // Loaded up front: browsers (Safari especially) only allow clipboard
    // writes that happen straight away in the click, not after an await.
    widget.loadWorkerScript().then((code) {
      if (mounted) setState(() => _code = code);
    });
  }

  Future<void> _copyCode(String code) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: code));
      messenger.showSnackBar(const SnackBar(content: Text('Proxy code copied — paste it into the Cloudflare editor')));
    } catch (_) {
      if (mounted) _showCode(code);
    }
  }

  /// Fallback when the browser blocks the clipboard: let the user select it.
  void _showCode(String code) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Proxy code'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your browser blocked copying. Select all of the code below, copy it, '
                    'and paste it into the Cloudflare editor.'),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = _code;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        leading: Icon(Icons.help_outline, color: theme.colorScheme.primary),
        title: const Text('How to create the proxy (free Cloudflare Worker)'),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, step) in CorsProxyGuide.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 24, child: Text('${i + 1}.')),
                  Expanded(child: Text(step)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: code == null ? null : () => _copyCode(code),
                icon: const Icon(Icons.code),
                label: const Text('Copy proxy code'),
              ),
              TextButton(
                onPressed: code == null ? null : () => _showCode(code),
                child: const Text('View code'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(CorsProxyGuide.defaultsNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final link in CorsProxyGuide.links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.open_in_new),
              title: Text(link.label),
              onTap: () => launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
            ),
          Text(CorsProxyGuide.cliNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
