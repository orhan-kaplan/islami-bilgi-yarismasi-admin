import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/search_engine.dart';
import 'content_providers.dart';

// =============================================================================
// Search Providers
// =============================================================================

/// Holds the current search query string entered by the user.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Computes search results by filtering content state with the current query.
/// Returns null when the query is empty (no filtering applied).
final searchResultProvider = Provider<SearchResult?>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return null;
  final state = ref.watch(contentStateProvider);
  return SearchEngine.filter(state, query);
});

/// Provides a FocusNode for the search text field, enabling keyboard shortcut
/// (Ctrl+F) to request focus on the search input.
final searchFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode();
  ref.onDispose(() => node.dispose());
  return node;
});
