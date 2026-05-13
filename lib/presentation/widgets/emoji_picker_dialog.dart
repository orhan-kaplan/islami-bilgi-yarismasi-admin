import 'package:flutter/material.dart';

/// Shows a dialog with a grid of commonly used emojis for feedback messages.
///
/// Returns the selected emoji as a [String], or `null` if cancelled.
Future<String?> showEmojiPickerDialog(BuildContext context, {String? currentEmoji}) {
  return showDialog<String?>(
    context: context,
    builder: (context) => _EmojiPickerDialog(currentEmoji: currentEmoji),
  );
}

class _EmojiPickerDialog extends StatelessWidget {
  const _EmojiPickerDialog({this.currentEmoji});

  final String? currentEmoji;

  // Emojiler kategorilere ayrılmış
  static const _categories = <_EmojiCategory>[
    _EmojiCategory('Başarı & Kutlama', [
      '🌟', '✨', '🏆', '🎉', '🎯', '👏', '💫', '⭐', '🥇', '🏅',
      '👑', '💎', '🔥', '💪', '🚀', '⚡', '🌈', '🎊', '✅', '💯',
    ]),
    _EmojiCategory('Dini & Manevi', [
      '🤲', '🕊️', '🕌', '🕯️', '📿', '☪️', '🌙', '🌅', '🙏', '💚',
      '🤍', '📖', '🕋', '🌱', '🌿', '🍃', '☀️', '🌤️', '🧎', '🫶',
    ]),
    _EmojiCategory('Eğitim & Bilgi', [
      '📚', '🧠', '🎓', '📝', '✏️', '📖', '💡', '🔍', '📐', '🗂️',
      '📋', '🏫', '👨‍🏫', '👩‍🎓', '🤓', '📕', '📗', '📘', '📙', '📓',
    ]),
    _EmojiCategory('Duygular & İfadeler', [
      '😊', '🤗', '😇', '🥰', '😌', '🙂', '😄', '😃', '🤩', '😎',
      '🥺', '😢', '😅', '🫡', '🤔', '😮', '👋', '🫂', '❤️', '💖',
    ]),
    _EmojiCategory('Doğa & Zaman', [
      '🌙', '☀️', '🌅', '🌄', '🌃', '🌆', '🦉', '🐢', '🏃‍♂️', '🏋️',
      '☕', '🍂', '🌸', '🌺', '🏔️', '🌊', '⏰', '⌛', '🕐', '📅',
    ]),
    _EmojiCategory('Semboller', [
      '🚶', '🔄', '➡️', '⬆️', '🔔', '💬', '📌', '🏷️', '🎵', '🎶',
      '❌', '⚠️', 'ℹ️', '❓', '❗', '🔑', '🛡️', '⚙️', '🧩', '🎲',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('Emoji Seç'),
          const Spacer(),
          if (currentEmoji != null && currentEmoji!.isNotEmpty)
            Chip(
              label: Text('Mevcut: $currentEmoji'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 400,
        child: ListView.builder(
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: category.emojis.map((emoji) {
                    final isSelected = emoji == currentEmoji;
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(emoji),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('İptal'),
        ),
      ],
    );
  }
}

class _EmojiCategory {
  final String name;
  final List<String> emojis;

  const _EmojiCategory(this.name, this.emojis);
}
