import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A data class representing a single keyboard shortcut entry.
class _ShortcutEntry {
  const _ShortcutEntry({
    required this.windowsKeys,
    required this.macKeys,
    required this.description,
  });

  final String windowsKeys;
  final String macKeys;
  final String description;
}

/// All keyboard shortcuts available in the application.
const _shortcuts = <_ShortcutEntry>[
  _ShortcutEntry(
    windowsKeys: 'Ctrl + Z',
    macKeys: 'Cmd + Z',
    description: 'Undo',
  ),
  _ShortcutEntry(
    windowsKeys: 'Ctrl + Shift + Z',
    macKeys: 'Cmd + Shift + Z',
    description: 'Redo',
  ),
  _ShortcutEntry(
    windowsKeys: 'Ctrl + S',
    macKeys: 'Cmd + S',
    description: 'Save to server (Export ZIP when offline)',
  ),
  _ShortcutEntry(
    windowsKeys: 'Ctrl + E',
    macKeys: 'Cmd + E',
    description: 'Export ZIP',
  ),
  _ShortcutEntry(
    windowsKeys: 'Ctrl + F',
    macKeys: 'Cmd + F',
    description: 'Focus Search',
  ),
  _ShortcutEntry(
    windowsKeys: '?',
    macKeys: '?',
    description: 'Show this help',
  ),
];

/// A dialog widget that displays all available keyboard shortcuts.
///
/// Shows both Windows/Linux (Ctrl) and macOS (Cmd) key combinations
/// in a clean, readable table layout.
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard, size: 24),
          SizedBox(width: 8),
          Text('Keyboard Shortcuts'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Shortcut',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!isMacOS)
                    Expanded(
                      flex: 3,
                      child: Text(
                        'macOS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Action',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 4),
            // Shortcut rows
            ...List.generate(_shortcuts.length, (index) {
              final entry = _shortcuts[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _KeyCombo(
                        keys: isMacOS ? entry.macKeys : entry.windowsKeys,
                      ),
                    ),
                    if (!isMacOS)
                      Expanded(
                        flex: 3,
                        child: _KeyCombo(keys: entry.macKeys),
                      ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Renders a keyboard key combination with styled key caps.
class _KeyCombo extends StatelessWidget {
  const _KeyCombo({required this.keys});

  final String keys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = keys.split(' + ');

    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Text(
              '+',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              parts[i].trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shows the keyboard shortcuts help dialog.
///
/// This is a convenience function that can be called from the
/// [AppShortcuts] widget's `onShowHelp` callback.
void showShortcutsHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const ShortcutsHelpDialog(),
  );
}
