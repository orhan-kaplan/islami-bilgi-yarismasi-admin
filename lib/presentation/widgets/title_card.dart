import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/feedback_models.dart';
import '../providers/feedback_content_providers.dart';
import 'preview/title_preview_dialog.dart';

/// A card widget displaying a single player title with inline editing support.
///
/// Shows:
/// - Title name, icon/emoji, required_books count, profile image path
/// - Edit and Delete icon buttons
///
/// Supports inline editing mode:
/// - Toggle to edit mode on Edit button press
/// - Editable TextFields for title, icon/emoji, required_books (numeric), profile_image
/// - Validates required_books uniqueness on save
/// - Save (check) and Cancel (close) buttons
///
/// Accepts callback [onDelete] for delete action handling.
class TitleCard extends ConsumerStatefulWidget {
  const TitleCard({
    super.key,
    required this.title,
    required this.index,
    this.onDelete,
  });

  /// The player title model to display.
  final PlayerTitleModel title;

  /// The index of this title within the titles list.
  final int index;

  /// Called when the delete button is pressed.
  final VoidCallback? onDelete;

  @override
  ConsumerState<TitleCard> createState() => _TitleCardState();
}

class _TitleCardState extends ConsumerState<TitleCard> {
  bool _isEditing = false;
  String? _errorMessage;

  late TextEditingController _titleController;
  late TextEditingController _iconController;
  late TextEditingController _requiredBooksController;
  late TextEditingController _profileImageController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant TitleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the title changed externally while not editing, update controllers
    if (!_isEditing && oldWidget.title != widget.title) {
      _initControllers();
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.title.title);
    _iconController = TextEditingController(text: widget.title.icon);
    _requiredBooksController =
        TextEditingController(text: widget.title.requiredBooks.toString());
    _profileImageController =
        TextEditingController(text: widget.title.profileImage);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _iconController.dispose();
    _requiredBooksController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    setState(() {
      _titleController.text = widget.title.title;
      _iconController.text = widget.title.icon;
      _requiredBooksController.text = widget.title.requiredBooks.toString();
      _profileImageController.text = widget.title.profileImage;
      _errorMessage = null;
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _errorMessage = null;
    });
  }

  void _saveEdit() {
    final newRequiredBooks =
        int.tryParse(_requiredBooksController.text.trim()) ?? 0;

    // Validate required_books uniqueness among existing titles
    final state = ref.read(feedbackContentProvider);
    final isDuplicate = state.titles.asMap().entries.any((entry) =>
        entry.key != widget.index &&
        entry.value.requiredBooks == newRequiredBooks);

    if (isDuplicate) {
      setState(() {
        _errorMessage =
            'Bu "Gerekli Kitap" değeri ($newRequiredBooks) başka bir ünvanda zaten kullanılıyor.';
      });
      return;
    }

    final updatedTitle = widget.title.copyWith(
      title: _titleController.text.trim(),
      icon: _iconController.text.trim(),
      requiredBooks: newRequiredBooks,
      profileImage: _profileImageController.text.trim(),
    );

    ref.read(feedbackContentProvider.notifier).updateTitle(
          widget.index,
          updatedTitle,
        );

    setState(() {
      _isEditing = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            _isEditing ? _buildEditMode(context) : _buildDisplayMode(context),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Display Mode
  // ---------------------------------------------------------------------------

  Widget _buildDisplayMode(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon/emoji avatar
        CircleAvatar(
          radius: 24,
          child: Text(
            widget.title.icon.isNotEmpty ? widget.title.icon : '🌟',
            style: const TextStyle(fontSize: 22),
          ),
        ),
        const SizedBox(width: 12),
        // Title info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title.title.isEmpty
                    ? '(Boş Ünvan)'
                    : widget.title.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gerekli Kitap: ${widget.title.requiredBooks}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (widget.title.profileImage.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Profil: ${widget.title.profileImage}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        // Action buttons
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Düzenle',
              onPressed: _enterEditMode,
            ),
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: 'Önizleme',
              onPressed: () => showTitlePreviewDialog(
                context,
                title: widget.title,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              tooltip: 'Sil',
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Edit Mode
  // ---------------------------------------------------------------------------

  Widget _buildEditMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title field
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Ünvan Adı',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        // Icon/emoji field
        TextField(
          controller: _iconController,
          decoration: const InputDecoration(
            labelText: 'İkon / Emoji',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        // Required books (numeric)
        TextField(
          controller: _requiredBooksController,
          decoration: InputDecoration(
            labelText: 'Gerekli Kitap Sayısı',
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: _errorMessage,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 8),
        // Profile image path
        TextField(
          controller: _profileImageController,
          decoration: const InputDecoration(
            labelText: 'Profil Görseli Yolu',
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'images/seed/profile_icon_seed.webp',
          ),
        ),
        const SizedBox(height: 12),
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
