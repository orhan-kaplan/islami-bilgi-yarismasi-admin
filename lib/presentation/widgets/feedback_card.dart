import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../data/models/feedback_models.dart';
import '../providers/feedback_content_providers.dart';
import 'emoji_picker_dialog.dart';
import 'lottie_picker_dialog.dart';
import 'preview/feedback_preview_dialog.dart';
import '../../core/constants/asset_server_config.dart';

/// A card widget displaying a single feedback message with live Lottie preview.
///
/// Shows:
/// - Live Lottie animation preview (respects [FeedbackMessageModel.shouldRepeat]
///   for loop/oneshot playback)
/// - Title, message, and emoji fields
/// - Edit and Delete icon buttons
/// - Placeholder icon when no Lottie animation is assigned
///
/// Supports inline editing mode:
/// - Toggle to edit mode on Edit button press
/// - Editable TextFields for title, message, emoji
/// - Switch for shouldRepeat
/// - Save (check) and Cancel (close) buttons
///
/// Accepts callback [onDelete] for delete action handling.
class FeedbackCard extends ConsumerStatefulWidget {
  const FeedbackCard({
    super.key,
    required this.message,
    required this.index,
    required this.category,
    this.subcategory,
    this.onEdit,
    this.onDelete,
  });

  /// The feedback message model to display.
  final FeedbackMessageModel message;

  /// The index of this message within its category/subcategory list.
  final int index;

  /// The category key (e.g. 'quiz', 'speed_quiz', 'time').
  final String category;

  /// The subcategory key (e.g. 'perfect', 'morning'), null for flat lists.
  final String? subcategory;

  /// Called when the edit button is pressed (optional external callback).
  final VoidCallback? onEdit;

  /// Called when the delete button is pressed.
  final VoidCallback? onDelete;

  @override
  ConsumerState<FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends ConsumerState<FeedbackCard> {
  bool _isEditing = false;

  late TextEditingController _titleController;
  late TextEditingController _messageController;
  late TextEditingController _emojiController;
  late bool _shouldRepeat;

  @override
  void initState() {
    super.initState();
    _initControllers();
    // Boş mesajlar direkt edit modunda açılsın
    if (_isEmptyMessage(widget.message)) {
      _isEditing = true;
    }
  }

  /// Mesajın "yeni eklenen boş mesaj" olup olmadığını kontrol eder.
  bool _isEmptyMessage(FeedbackMessageModel msg) {
    return msg.title.isEmpty && msg.message.isEmpty;
  }

  @override
  void didUpdateWidget(covariant FeedbackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the message changed externally while not editing, update controllers
    if (!_isEditing && oldWidget.message != widget.message) {
      _initControllers();
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.message.title);
    _messageController = TextEditingController(text: widget.message.message);
    _emojiController = TextEditingController(text: widget.message.emoji);
    _shouldRepeat = widget.message.shouldRepeat;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    setState(() {
      _titleController.text = widget.message.title;
      _messageController.text = widget.message.message;
      _emojiController.text = widget.message.emoji;
      _shouldRepeat = widget.message.shouldRepeat;
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    // Yeni oluşturulan boş mesaj iptal edildiğinde listeden kaldır
    if (_isEmptyMessage(widget.message)) {
      final notifier = ref.read(feedbackContentProvider.notifier);
      notifier.removeMessage(widget.category, widget.subcategory, widget.index);
      return;
    }
    setState(() {
      _isEditing = false;
    });
  }

  void _saveEdit() {
    final updatedMessage = widget.message.copyWith(
      title: _titleController.text,
      message: _messageController.text,
      emoji: _emojiController.text,
      shouldRepeat: _shouldRepeat,
    );

    ref.read(feedbackContentProvider.notifier).updateMessage(
          widget.category,
          widget.subcategory,
          widget.index,
          updatedMessage,
        );

    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _isEditing ? _buildEditMode(context) : _buildDisplayMode(context),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Display Mode
  // ---------------------------------------------------------------------------

  Widget _buildDisplayMode(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLottiePreview(context),
        const SizedBox(width: 12),
        _buildContent(context),
        _buildActions(context),
      ],
    );
  }

  /// Builds the Lottie animation preview or placeholder.
  /// Tappable — opens LottiePicker dialog to select/change animation.
  Widget _buildLottiePreview(BuildContext context) {
    final hasLottie =
        widget.message.lottieAsset != null && widget.message.lottieAsset!.isNotEmpty;

    return Tooltip(
      message: hasLottie ? 'Lottie değiştir' : 'Lottie ekle',
      child: InkWell(
        onTap: () => _pickLottie(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (hasLottie) _buildLottieAnimation() else _buildPlaceholder(),
              // Small edit indicator at bottom-right
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    hasLottie ? Icons.swap_horiz : Icons.add_photo_alternate_outlined,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the LottiePicker dialog and updates the message's lottieAsset.
  Future<void> _pickLottie(BuildContext context) async {
    final selectedPath = await showLottiePickerDialog(context);
    if (selectedPath == null) return;
    if (!mounted) return;

    final updatedMessage = widget.message.copyWith(
      lottieAsset: selectedPath,
    );

    ref.read(feedbackContentProvider.notifier).updateMessage(
          widget.category,
          widget.subcategory,
          widget.index,
          updatedMessage,
        );
  }

  /// Builds a live Lottie animation from the network URL.
  ///
  /// Respects [FeedbackMessageModel.shouldRepeat]:
  /// - `true`: loops the animation continuously
  /// - `false`: plays the animation once (oneshot)
  Widget _buildLottieAnimation() {
    final url =
        AssetServerConfig.fileUrl('lottie/${widget.message.lottieAsset}');

    return Lottie.network(
      url,
      fit: BoxFit.contain,
      repeat: widget.message.shouldRepeat,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: Colors.grey,
          ),
        );
      },
    );
  }

  /// Builds a placeholder when no Lottie animation is assigned.
  ///
  /// Shows the emoji if available, otherwise a generic animation icon.
  Widget _buildPlaceholder() {
    if (widget.message.emoji.isNotEmpty) {
      return Center(
        child: Text(
          widget.message.emoji,
          style: const TextStyle(fontSize: 28),
        ),
      );
    }

    return const Center(
      child: Icon(
        Icons.animation_outlined,
        size: 28,
        color: Colors.grey,
      ),
    );
  }

  /// Builds the message content section (title, message, emoji, metadata).
  Widget _buildContent(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.message.title.isEmpty ? '(Başlık yok)' : widget.message.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          // Message
          Text(
            widget.message.message.isEmpty ? '(Mesaj yok)' : widget.message.message,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Metadata row: emoji, lottie path, repeat indicator
          Row(
            children: [
              Text(
                'Emoji: ${widget.message.emoji}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              if (widget.message.lottieAsset != null &&
                  widget.message.lottieAsset!.isNotEmpty)
                Flexible(
                  child: Text(
                    'Lottie: ${widget.message.lottieAsset}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const Spacer(),
              Icon(
                widget.message.shouldRepeat ? Icons.repeat : Icons.repeat_one,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the Edit and Delete action buttons.
  Widget _buildActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined),
          tooltip: 'Önizle',
          onPressed: () {
            showFeedbackPreviewDialog(
              context,
              message: widget.message,
              category: widget.category,
              subcategory: widget.subcategory,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Düzenle',
          onPressed: () {
            _enterEditMode();
            widget.onEdit?.call();
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Theme.of(context).colorScheme.error,
          tooltip: 'Sil',
          onPressed: widget.onDelete,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Edit Mode
  // ---------------------------------------------------------------------------

  Widget _buildEditMode(BuildContext context) {
    final hasLottie =
        widget.message.lottieAsset != null && widget.message.lottieAsset!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lottie picker row
        Row(
          children: [
            // Current lottie preview (small)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasLottie
                  ? Lottie.network(
                      AssetServerConfig.fileUrl(
                          'lottie/${widget.message.lottieAsset}'),
                      fit: BoxFit.contain,
                      repeat: true,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 20),
                    )
                  : const Icon(Icons.animation_outlined, size: 20, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasLottie
                    ? widget.message.lottieAsset!
                    : 'Lottie atanmamış',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: hasLottie ? null : Colors.grey,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickLottie(context),
              icon: Icon(hasLottie ? Icons.swap_horiz : Icons.add, size: 16),
              label: Text(hasLottie ? 'Değiştir' : 'Lottie Ekle'),
            ),
            if (hasLottie) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  // Remove lottie
                  final updatedMessage = widget.message.copyWith(
                    clearLottieAsset: true,
                  );
                  ref.read(feedbackContentProvider.notifier).updateMessage(
                        widget.category,
                        widget.subcategory,
                        widget.index,
                        updatedMessage,
                      );
                },
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Lottie kaldır',
                style: IconButton.styleFrom(
                  minimumSize: const Size(28, 28),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Title field
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Başlık',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        // Message field (multiline)
        TextField(
          controller: _messageController,
          decoration: const InputDecoration(
            labelText: 'Mesaj',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 3,
          minLines: 2,
        ),
        const SizedBox(height: 8),
        // Emoji picker row
        Row(
          children: [
            Text(
              'Emoji:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 12),
            // Current emoji display
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Center(
                child: Text(
                  _emojiController.text.isEmpty ? '📝' : _emojiController.text,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showEmojiPickerDialog(
                  context,
                  currentEmoji: _emojiController.text,
                );
                if (selected != null && mounted) {
                  setState(() {
                    _emojiController.text = selected;
                  });
                }
              },
              icon: const Icon(Icons.emoji_emotions_outlined, size: 16),
              label: const Text('Değiştir'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // shouldRepeat switch
        Row(
          children: [
            const Text('Tekrar (shouldRepeat)'),
            const Spacer(),
            Switch(
              value: _shouldRepeat,
              onChanged: (value) {
                setState(() {
                  _shouldRepeat = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Save and Cancel buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _cancelEdit,
              icon: const Icon(Icons.close),
              label: const Text('İptal'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saveEdit,
              icon: const Icon(Icons.check),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ],
    );
  }
}
