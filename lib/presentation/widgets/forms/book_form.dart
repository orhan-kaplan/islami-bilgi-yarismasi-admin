import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book_model.dart';
import '../../providers/asset_server_providers.dart';
import '../../providers/content_providers.dart';
import '../../providers/history_providers.dart';
import '../shared/confirm_dialog.dart';
import 'inline_image_picker.dart';

/// Form for creating or editing a [BookModel].
///
/// When [book] is null, the form is in "create" mode with auto-ID suggestion.
/// When [book] is provided, the form is in "edit" mode.
class BookForm extends ConsumerStatefulWidget {
  const BookForm({super.key, this.book, this.seriesId, this.onDeleted});

  /// The book to edit, or null to create a new one.
  final BookModel? book;

  /// Optional series ID to pre-select when creating a new book.
  final int? seriesId;

  /// Called after the book is deleted so the caller can clear its selection.
  final VoidCallback? onDeleted;

  @override
  ConsumerState<BookForm> createState() => _BookFormState();
}

class _BookFormState extends ConsumerState<BookForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _assetImage;
  late final TextEditingController _bookOrderController;
  late final TextEditingController _contentFileController;
  late int? _selectedSeriesId;

  bool get _isEditing => widget.book != null;

  @override
  void initState() {
    super.initState();
    final book = widget.book;
    final notifier = ref.read(contentStateProvider.notifier);

    _idController = TextEditingController(
      text: book != null ? book.id.toString() : notifier.nextBookId.toString(),
    );
    _titleController = TextEditingController(text: book?.title ?? '');
    _descriptionController = TextEditingController(text: book?.description ?? '');
    _assetImage = book?.assetImage ?? '';
    // Sıra alanı disabled; sabit 1 ile açılınca serideki ikinci kitap
    // ardışıklık kuralını kırıp books.json'ın kaydını blokluyordu.
    final seriesBookCount = ref
        .read(contentStateProvider)
        .books
        .where((b) => b.seriesId == widget.seriesId)
        .length;
    _bookOrderController = TextEditingController(
      text: book?.bookOrder.toString() ?? '${seriesBookCount + 1}',
    );
    _contentFileController = TextEditingController(
      text: book?.contentFile ?? 'book_${_idController.text}.json',
    );
    _selectedSeriesId = book?.seriesId ?? widget.seriesId;
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _bookOrderController.dispose();
    _contentFileController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assetImage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset image is required')),
      );
      return;
    }

    // Push current state to history before applying the change.
    ref.read(historyProvider.notifier).pushState(ref.read(contentStateProvider));

    // Async gap'ten önce yakalanır: kullanıcı kayıt sürerken formu kapatırsa
    // context geçersiz olur ve ScaffoldMessenger.of(context) fırlatır.
    final messenger = ScaffoldMessenger.of(context);

    final notifier = ref.read(contentStateProvider.notifier);
    final book = BookModel(
      id: int.parse(_idController.text),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      assetImage: _assetImage,
      bookOrder: int.parse(_bookOrderController.text),
      seriesId: _selectedSeriesId!,
      contentFile: _contentFileController.text.trim(),
    );

    if (_isEditing) {
      notifier.updateBook(book);
    } else {
      notifier.addBook(book);
      // Create the book's image folder and sync pubspec.yaml
      try {
        final client = ref.read(assetServerClientProvider);
        await client.createFolder('images/book_${book.id}');
        await client.syncPubspec();
      } catch (_) {
        // Non-critical — folder may already exist or server may be offline
      }
    }

    messenger.showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Book updated' : 'Book created')),
    );
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Book',
      message: 'Are you sure you want to delete this book?',
      confirmLabel: 'Delete',
    );

    if (!confirmed || !mounted) return;

    // Guard'ı kırmadan dene: level'ı olan ya da bir ödülün açtığı kitap
    // silinirse geride dangling referanslar kalırdı.
    final currentState = ref.read(contentStateProvider);
    final deleted =
        ref.read(contentStateProvider.notifier).deleteBook(widget.book!.id);

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot delete: this book still has levels, or a reward unlocks '
            'it. Remove those first.',
          ),
        ),
      );
      return;
    }

    // Silme uygulandıktan sonra geçmişe yaz: guard bloklarsa yığın kirlenmesin.
    ref.read(historyProvider.notifier).pushState(currentState);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Book deleted')),
    );
    widget.onDeleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final allSeries = ref.watch(allSeriesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Book' : 'New Book',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Delete book',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'ID',
                helperText: 'Auto-generated',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: false,
              onChanged: (value) {
                // Auto-update content file name when ID changes in create mode
                if (!_isEditing && value.isNotEmpty) {
                  _contentFileController.text = 'book_$value.json';
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) return 'ID is required';
                final id = int.tryParse(value);
                if (id == null || id <= 0) return 'ID must be a positive integer';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Description must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                InlineImagePicker(
                  currentAppPath: _assetImage.isEmpty ? null : _assetImage,
                  defaultDirectory: 'images/book_${_idController.text}/',
                  targetFileName: 'book_${_idController.text}',
                  onPathChanged: (newPath) {
                    setState(() => _assetImage = newPath);
                    // Also update ContentState immediately if editing.
                    // Validasyondan geçmeden commit etmek boş bir zorunlu
                    // alanı diske yazıp dosyanın kaydını bloklardı.
                    if (_isEditing) {
                      if (!_formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Image uploaded. Fix the highlighted fields and '
                              'press Update Book to apply it.',
                            ),
                          ),
                        );
                        return;
                      }
                      ref.read(historyProvider.notifier).pushState(
                        ref.read(contentStateProvider),
                      );
                      final notifier = ref.read(contentStateProvider.notifier);
                      final updated = BookModel(
                        id: int.parse(_idController.text),
                        title: _titleController.text.trim(),
                        description: _descriptionController.text.trim(),
                        assetImage: newPath,
                        bookOrder: int.parse(_bookOrderController.text),
                        seriesId: _selectedSeriesId!,
                        contentFile: _contentFileController.text.trim(),
                      );
                      notifier.updateBook(updated);
                    }
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _assetImage.isEmpty ? 'No image selected' : _assetImage,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bookOrderController,
              decoration: const InputDecoration(
                labelText: 'Book Order',
                helperText: 'Drag-drop ile ayarlanır',
              ),
              keyboardType: TextInputType.number,
              enabled: false,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Book order is required';
                final order = int.tryParse(value);
                if (order == null || order <= 0) {
                  return 'Book order must be a positive integer';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedSeriesId,
              decoration: const InputDecoration(
                labelText: 'Series *',
              ),
              items: allSeries
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedSeriesId = value),
              validator: (value) {
                if (value == null) return 'Series must be selected';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentFileController,
              decoration: InputDecoration(
                labelText: 'Content File',
                helperText: _isEditing ? null : 'Auto-generated from Book ID',
              ),
              enabled: _isEditing,
              readOnly: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Content file must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update Book' : 'Create Book'),
            ),
          ],
        ),
      ),
    );
  }
}
