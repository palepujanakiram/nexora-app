import 'package:flutter/material.dart';

import '../../../../common/domain/entities/app_settings.dart';

/// Row of colour swatches; the selected one shows a check mark.
class ThemeColorPicker extends StatelessWidget {
  const ThemeColorPicker({super.key, required this.selected, required this.onSelected});

  final ThemeColor selected;
  final ValueChanged<ThemeColor> onSelected;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.onSurface;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in ThemeColor.values)
          Tooltip(
            message: c.label,
            child: Semantics(
              button: true,
              selected: c == selected,
              label: '${c.label} theme',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onSelected(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(c.argb),
                    shape: BoxShape.circle,
                    border: Border.all(color: c == selected ? outline : Colors.transparent, width: 3),
                  ),
                  child: c == selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
