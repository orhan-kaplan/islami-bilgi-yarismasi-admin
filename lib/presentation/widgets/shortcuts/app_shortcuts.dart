import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

// =============================================================================
// Intents
// =============================================================================

/// Intent to trigger undo action.
class UndoIntent extends Intent {
  const UndoIntent();
}

/// Intent to trigger redo action.
class RedoIntent extends Intent {
  const RedoIntent();
}

/// Intent to trigger the connectivity-aware save action (Ctrl/Cmd+S):
/// flushes pending saves to the server when connected, exports a ZIP
/// otherwise.
class ExportIntent extends Intent {
  const ExportIntent();
}

/// Intent to trigger an unconditional ZIP export (Ctrl/Cmd+E), regardless
/// of server connectivity.
class ExportZipIntent extends Intent {
  const ExportZipIntent();
}

/// Intent to focus the search input field.
class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

/// Intent to show the keyboard shortcuts help dialog.
class ShowHelpIntent extends Intent {
  const ShowHelpIntent();
}

// =============================================================================
// AppShortcuts Widget
// =============================================================================

/// A widget that wraps its child with global keyboard shortcuts.
///
/// Accepts callback functions for each action so it can be wired up
/// when integrated into the app shell. Detects text field focus to
/// suppress undo/redo/? shortcuts when text input is focused.
///
/// Also prevents default browser behavior for intercepted key combinations
/// (Ctrl/Cmd+S, Ctrl/Cmd+E, Ctrl/Cmd+F) via a `keydown` event listener.
class AppShortcuts extends ConsumerStatefulWidget {
  const AppShortcuts({
    super.key,
    required this.child,
    required this.isSearchScreenActive,
    this.onUndo,
    this.onRedo,
    this.onExport,
    this.onExportZip,
    this.onFocusSearch,
    this.onShowHelp,
  });

  final Widget child;

  /// Whether the currently active screen has a search field for Ctrl/Cmd+F
  /// to focus. When false, the browser's native "Find" is left alone instead
  /// of being suppressed for a shortcut that would have nothing to focus.
  final bool isSearchScreenActive;

  /// Called when Ctrl/Cmd+Z is pressed (and no text field is focused).
  final VoidCallback? onUndo;

  /// Called when Ctrl/Cmd+Shift+Z is pressed (and no text field is focused).
  final VoidCallback? onRedo;

  /// Called when Ctrl/Cmd+S is pressed: save to server if connected, ZIP
  /// export otherwise.
  final VoidCallback? onExport;

  /// Called when Ctrl/Cmd+E is pressed: always a ZIP export, regardless of
  /// server connectivity.
  final VoidCallback? onExportZip;

  /// Called when Ctrl/Cmd+F is pressed.
  final VoidCallback? onFocusSearch;

  /// Called when "?" is pressed (and no text field is focused).
  final VoidCallback? onShowHelp;

  @override
  ConsumerState<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends ConsumerState<AppShortcuts> {
  JSFunction? _keydownHandler;

  @override
  void initState() {
    super.initState();
    _registerBrowserKeydownHandler();
  }

  @override
  void dispose() {
    _removeBrowserKeydownHandler();
    super.dispose();
  }

  /// Registers a browser-level keydown listener to preventDefault on
  /// shortcuts we intercept (Ctrl/Cmd+S, Ctrl/Cmd+E, Ctrl/Cmd+F).
  void _registerBrowserKeydownHandler() {
    _keydownHandler = ((web.KeyboardEvent event) {
      final ctrlOrMeta = event.ctrlKey || event.metaKey;
      if (!ctrlOrMeta) return;

      final key = event.key.toLowerCase();
      // Prevent default for shortcuts we always handle
      if (key == 's' || key == 'e') {
        event.preventDefault();
      }
      // Ctrl/Cmd+F only has something to focus on screens with a search
      // field — elsewhere, leave the browser's native "Find" alone instead
      // of silently swallowing it.
      if (key == 'f' && widget.isSearchScreenActive) {
        event.preventDefault();
      }
      // Prevent default for Ctrl/Cmd+Z (undo) and Ctrl/Cmd+Shift+Z (redo)
      // only when no text field is focused
      if (key == 'z' && !_isTextFieldFocused()) {
        event.preventDefault();
      }
    }).toJS;
    web.window.document.addEventListener('keydown', _keydownHandler!);
  }

  void _removeBrowserKeydownHandler() {
    if (_keydownHandler == null) return;
    web.window.document.removeEventListener('keydown', _keydownHandler!);
    _keydownHandler = null;
  }

  /// Returns true if the currently focused widget is a text input field.
  static bool _isTextFieldFocused() {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null) return false;

    // Walk up the focus tree context to check for EditableText
    final context = focusNode.context;
    if (context == null) return false;

    bool isEditable = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText || element.widget is TextField) {
        isEditable = true;
        return false; // stop visiting
      }
      return true; // continue visiting
    });
    return isEditable;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Undo: Ctrl+Z / Cmd+Z
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            const UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            const UndoIntent(),
        // Redo: Ctrl+Shift+Z / Cmd+Shift+Z
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true): const RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ,
            meta: true, shift: true): const RedoIntent(),
        // Export: Ctrl+S / Cmd+S
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const ExportIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            const ExportIntent(),
        // Export ZIP (always, regardless of connectivity): Ctrl+E / Cmd+E
        const SingleActivator(LogicalKeyboardKey.keyE, control: true):
            const ExportZipIntent(),
        const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
            const ExportZipIntent(),
        // Focus Search: Ctrl+F / Cmd+F
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const FocusSearchIntent(),
        // Show Help: ? key
        const SingleActivator(LogicalKeyboardKey.question):
            const ShowHelpIntent(),
        // Also handle shift+/ which produces ? on US keyboards
        const SingleActivator(LogicalKeyboardKey.slash, shift: true):
            const ShowHelpIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          UndoIntent: _ConditionalCallbackAction<UndoIntent>(
            onInvoke: widget.onUndo,
            suppressWhenTextFocused: true,
          ),
          RedoIntent: _ConditionalCallbackAction<RedoIntent>(
            onInvoke: widget.onRedo,
            suppressWhenTextFocused: true,
          ),
          ExportIntent: _CallbackAction<ExportIntent>(
            onInvoke: widget.onExport,
          ),
          ExportZipIntent: _CallbackAction<ExportZipIntent>(
            onInvoke: widget.onExportZip,
          ),
          FocusSearchIntent: _CallbackAction<FocusSearchIntent>(
            onInvoke: widget.onFocusSearch,
          ),
          ShowHelpIntent: _ConditionalCallbackAction<ShowHelpIntent>(
            onInvoke: widget.onShowHelp,
            suppressWhenTextFocused: true,
          ),
        },
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// Action Helpers
// =============================================================================

/// An action that invokes a callback. Always enabled.
class _CallbackAction<T extends Intent> extends Action<T> {
  _CallbackAction({required this.onInvoke});

  final VoidCallback? onInvoke;

  @override
  Object? invoke(T intent) {
    onInvoke?.call();
    return null;
  }
}

/// An action that checks text field focus before invoking.
/// When [suppressWhenTextFocused] is true and a text field is focused,
/// the action is disabled (returns false from isEnabled), allowing the
/// native text editing behavior to proceed.
class _ConditionalCallbackAction<T extends Intent> extends Action<T> {
  _ConditionalCallbackAction({
    required this.onInvoke,
    this.suppressWhenTextFocused = false,
  });

  final VoidCallback? onInvoke;
  final bool suppressWhenTextFocused;

  @override
  bool get isActionEnabled {
    if (suppressWhenTextFocused && _AppShortcutsState._isTextFieldFocused()) {
      return false;
    }
    return true;
  }

  @override
  Object? invoke(T intent) {
    onInvoke?.call();
    return null;
  }
}
