import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/series_model.dart';
import '../../providers/content_providers.dart';
import '../../providers/history_providers.dart';

/// Form for creating or editing a [SeriesModel].
///
/// When [series] is null, the form is in "create" mode with auto-ID suggestion.
/// When [series] is provided, the form is in "edit" mode.
class SeriesForm extends ConsumerStatefulWidget {
  const SeriesForm({super.key, this.series});

  /// The series to edit, or null to create a new one.
  final SeriesModel? series;

  @override
  ConsumerState<SeriesForm> createState() => _SeriesFormState();
}

class _SeriesFormState extends ConsumerState<SeriesForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _iconEmojiController;
  late final TextEditingController _descriptionController;
  late bool _isLocked;

  bool get _isEditing => widget.series != null;

  @override
  void initState() {
    super.initState();
    final series = widget.series;
    final notifier = ref.read(contentStateProvider.notifier);

    _idController = TextEditingController(
      text: series != null ? series.id.toString() : notifier.nextSeriesId.toString(),
    );
    _nameController = TextEditingController(text: series?.name ?? '');
    // Sıra alanı disabled; sabit 1 ile açılınca ikinci seri ardışıklık
    // kuralını kırıp series.json'ın kaydını blokluyordu.
    final seriesCount = ref.read(contentStateProvider).series.length;
    _sortOrderController = TextEditingController(
      text: series?.sortOrder.toString() ?? '${seriesCount + 1}',
    );
    _iconEmojiController = TextEditingController(text: series?.iconEmoji ?? '');
    _descriptionController = TextEditingController(text: series?.description ?? '');
    _isLocked = series?.isLocked ?? false;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _sortOrderController.dispose();
    _iconEmojiController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Push current state to history before applying the change.
    ref.read(historyProvider.notifier).pushState(ref.read(contentStateProvider));

    final notifier = ref.read(contentStateProvider.notifier);
    final series = SeriesModel(
      id: int.parse(_idController.text),
      name: _nameController.text.trim(),
      sortOrder: int.parse(_sortOrderController.text),
      isLocked: _isLocked,
      iconEmoji: _iconEmojiController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (_isEditing) {
      notifier.updateSeries(series);
    } else {
      notifier.addSeries(series);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Series updated' : 'Series created')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Series' : 'New Series',
              style: Theme.of(context).textTheme.headlineSmall,
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
              validator: (value) {
                if (value == null || value.isEmpty) return 'ID is required';
                final id = int.tryParse(value);
                if (id == null || id <= 0) return 'ID must be a positive integer';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sortOrderController,
              decoration: const InputDecoration(
                labelText: 'Sort Order',
                helperText: 'Drag-drop ile ayarlanır',
              ),
              keyboardType: TextInputType.number,
              enabled: false,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Sort order is required';
                final order = int.tryParse(value);
                if (order == null || order <= 0) {
                  return 'Sort order must be a positive integer';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Is Locked'),
              value: _isLocked,
              onChanged: (value) => setState(() => _isLocked = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _iconEmojiController,
              decoration: const InputDecoration(
                labelText: 'Icon Emoji *',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Icon emoji must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update Series' : 'Create Series'),
            ),
          ],
        ),
      ),
    );
  }
}
