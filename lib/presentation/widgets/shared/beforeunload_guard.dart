import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../providers/auto_save_providers.dart';

/// Widget that registers a browser `beforeunload` event listener when
/// there are unsaved changes ([hasUnsavedWorkProvider] is true).
///
/// When the state becomes clean, the listener is removed so the browser
/// tab can close without a confirmation dialog.
class BeforeUnloadGuard extends ConsumerStatefulWidget {
  const BeforeUnloadGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BeforeUnloadGuard> createState() => _BeforeUnloadGuardState();
}

class _BeforeUnloadGuardState extends ConsumerState<BeforeUnloadGuard> {
  JSFunction? _beforeUnloadHandler;

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _addListener() {
    if (_beforeUnloadHandler != null) return; // already registered
    _beforeUnloadHandler = ((web.BeforeUnloadEvent event) {
      event.preventDefault();
    }).toJS;
    web.window.addEventListener('beforeunload', _beforeUnloadHandler!);
  }

  void _removeListener() {
    if (_beforeUnloadHandler == null) return; // nothing to remove
    web.window.removeEventListener('beforeunload', _beforeUnloadHandler!);
    _beforeUnloadHandler = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDirty = ref.watch(hasUnsavedWorkProvider);

    if (isDirty) {
      _addListener();
    } else {
      _removeListener();
    }

    return widget.child;
  }
}
