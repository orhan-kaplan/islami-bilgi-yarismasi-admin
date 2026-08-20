import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book_model.dart';
import '../../data/models/content_state.dart';
import '../../data/models/hadith_model.dart';
import '../../data/models/level_model.dart';
import '../../data/models/question_model.dart';
import '../../data/models/reward_model.dart';
import '../../data/models/series_model.dart';

/// StateNotifier managing all content state with CRUD operations,
/// deletion guards, reordering, and auto-ID generation.
class ContentNotifier extends StateNotifier<ContentState> {
  ContentNotifier([ContentState? initialState])
      : super(initialState ?? ContentState.empty());

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Replaces the entire state with a new imported state.
  void importContent(ContentState newState) {
    state = newState;
  }

  // ---------------------------------------------------------------------------
  // Series CRUD
  // ---------------------------------------------------------------------------

  void addSeries(SeriesModel series) {
    if (state.series.any((s) => s.id == series.id)) return;
    state = state.copyWith(series: [...state.series, series]);
  }

  void updateSeries(SeriesModel updated) {
    state = state.copyWith(
      series: state.series.map((s) => s.id == updated.id ? updated : s).toList(),
    );
  }

  /// Deletes a series by ID. Returns false if the series has books (blocked).
  ///
  /// Remaining series are renumbered 1..N: a gap in sort_order is an
  /// error-level validation issue, which would block auto-save for
  /// series.json and keep the deletion from ever reaching disk.
  bool deleteSeries(int seriesId) {
    final hasBooks = state.books.any((b) => b.seriesId == seriesId);
    if (hasBooks) return false;
    final remaining = state.series.where((s) => s.id != seriesId).toList();
    state = state.copyWith(series: _compactSeriesSortOrder(remaining));
    return true;
  }

  /// Reorders series by assigning sequential sort_order values (1, 2, 3, ...)
  /// based on the provided list of IDs in the new order.
  ///
  /// IDs missing from [newOrder] are kept and appended after the listed ones,
  /// in their current sort_order. Dropping them would delete series through a
  /// path that bypasses the [deleteSeries] guard.
  void reorderSeries(List<int> newOrder) {
    final seriesMap = {for (final s in state.series) s.id: s};
    final placed = <int>{};
    final reordered = <SeriesModel>[];
    for (final id in newOrder) {
      final series = seriesMap[id];
      if (series != null && placed.add(id)) {
        reordered.add(series);
      }
    }
    final remaining = state.series.where((s) => !placed.contains(s.id)).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    reordered.addAll(remaining);

    state = state.copyWith(
      series: [
        for (var i = 0; i < reordered.length; i++)
          reordered[i].copyWith(sortOrder: i + 1),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Book CRUD
  // ---------------------------------------------------------------------------

  void addBook(BookModel book) {
    if (state.books.any((b) => b.id == book.id)) return;
    final updatedMap = Map<String, List<LevelModel>>.from(state.contentFiles);
    updatedMap.putIfAbsent(book.contentFile, () => const []);
    state = state.copyWith(
      books: [...state.books, book],
      contentFiles: updatedMap,
    );
  }

  void updateBook(BookModel updated) {
    final existing =
        state.books.where((b) => b.id == updated.id).firstOrNull;
    var next = updated;
    if (existing != null && existing.seriesId != updated.seriesId) {
      final destCount = state.books
          .where((b) => b.id != updated.id && b.seriesId == updated.seriesId)
          .length;
      next = updated.copyWith(bookOrder: destCount + 1);
    }
    var books = [
      for (final b in state.books) b.id == updated.id ? next : b,
    ];
    if (existing != null && existing.seriesId != updated.seriesId) {
      books = _compactBookOrder(books, existing.seriesId);
      books = _compactBookOrder(books, next.seriesId);
    }
    state = state.copyWith(books: books);
  }

  /// Deletes a book by ID. Returns false when the book still has levels in
  /// the contentFiles map, or when a reward still unlocks it (blocked).
  bool deleteBook(int bookId) {
    final book = state.books.firstWhere(
      (b) => b.id == bookId,
      orElse: () => throw StateError('Book not found: $bookId'),
    );
    final levels = state.contentFiles[book.contentFile];
    if (levels != null && levels.isNotEmpty) return false;
    // A reward's unlock_book_id error is reported against rewards.json, but
    // deleting a book only makes books.json dirty — per-file save gating would
    // never see the dangling reference and would write the deletion to disk.
    if (state.rewards.any((r) => r.unlockBookId == bookId)) return false;
    final updatedMap = Map<String, List<LevelModel>>.from(state.contentFiles);
    if (levels != null && levels.isEmpty) {
      updatedMap.remove(book.contentFile);
    }
    // Remaining books in this series are renumbered 1..N: a gap in
    // book_order is an error-level validation issue, which would block
    // auto-save for books.json and keep the deletion from ever reaching disk.
    final remaining = state.books.where((b) => b.id != bookId).toList();
    state = state.copyWith(
      books: _compactBookOrder(remaining, book.seriesId),
      contentFiles: updatedMap,
    );
    return true;
  }

  /// Reorders books within a series by assigning sequential book_order values
  /// (1, 2, 3, ...) based on the provided list of IDs in the new order.
  ///
  /// Books of the series missing from [newOrder] are kept and appended after
  /// the listed ones. Leaving their old book_order untouched made it collide
  /// with a freshly assigned one and broke the sequential rule.
  void reorderBooks(int seriesId, List<int> newOrder) {
    final seriesBooks = state.books.where((b) => b.seriesId == seriesId).toList()
      ..sort((a, b) => a.bookOrder.compareTo(b.bookOrder));
    final booksById = {for (final b in seriesBooks) b.id: b};
    final placed = <int>{};
    final ordered = <BookModel>[];
    for (final id in newOrder) {
      final book = booksById[id];
      if (book != null && placed.add(id)) {
        ordered.add(book);
      }
    }
    ordered.addAll(seriesBooks.where((b) => !placed.contains(b.id)));

    final orderById = {
      for (var i = 0; i < ordered.length; i++) ordered[i].id: i + 1,
    };
    state = state.copyWith(
      books: state.books.map((b) {
        final order = orderById[b.id];
        return order == null ? b : b.copyWith(bookOrder: order);
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Level CRUD
  // ---------------------------------------------------------------------------

  /// Adds a level to the specified content file's level list.
  void addLevel(String contentFile, LevelModel level) {
    final idTaken = state.contentFiles.values
        .expand((levels) => levels)
        .any((l) => l.id == level.id);
    if (idTaken) return;
    final currentLevels = state.contentFiles[contentFile] ?? [];
    final updatedMap = Map<String, List<LevelModel>>.from(state.contentFiles);
    updatedMap[contentFile] = [...currentLevels, level];
    state = state.copyWith(contentFiles: updatedMap);
  }

  /// Updates a level by ID within the specified content file.
  void updateLevel(String contentFile, LevelModel updated) {
    final currentLevels = state.contentFiles[contentFile];
    if (currentLevels == null) return;
    final updatedMap = Map<String, List<LevelModel>>.from(state.contentFiles);
    updatedMap[contentFile] =
        currentLevels.map((l) => l.id == updated.id ? updated : l).toList();
    state = state.copyWith(contentFiles: updatedMap);
  }

  /// Deletes a level and all its questions from the specified content file.
  /// Always succeeds.
  ///
  /// Remaining levels are renumbered 1..N: a gap in level_order is an
  /// error-level validation issue, which would block auto-save for the whole
  /// content file and keep the deletion from ever reaching disk.
  void deleteLevel(String contentFile, int levelId) {
    final currentLevels = state.contentFiles[contentFile];
    if (currentLevels == null) return;
    final remaining = currentLevels.where((l) => l.id != levelId).toList();
    final ranked = [...remaining]
      ..sort((a, b) => a.levelOrder.compareTo(b.levelOrder));
    final orderById = {
      for (var i = 0; i < ranked.length; i++) ranked[i].id: i + 1,
    };
    final updatedMap = Map<String, List<LevelModel>>.from(state.contentFiles);
    updatedMap[contentFile] = [
      for (final level in remaining)
        level.copyWith(levelOrder: orderById[level.id]),
    ];
    state = state.copyWith(contentFiles: updatedMap);
  }

  /// Reorders levels within a content file by assigning sequential level_order
  /// values (1, 2, 3, ...) based on the provided list of IDs in the new order.
  ///
  /// IDs missing from [newOrder] are kept and appended after the listed ones,
  /// in their current level_order — dropping them would delete levels (and
  /// their questions) without any confirmation.
  void reorderLevels(String contentFile, List<int> newOrder) {
    final currentLevels = state.contentFiles[contentFile];
    if (currentLevels == null) return;
    final levelMap = {for (final l in currentLevels) l.id: l};
    final placed = <int>{};
    final reordered = <LevelModel>[];
    for (final id in newOrder) {
      final level = levelMap[id];
      if (level != null && placed.add(id)) {
        reordered.add(level);
      }
    }
    final remaining =
        currentLevels.where((l) => !placed.contains(l.id)).toList()
          ..sort((a, b) => a.levelOrder.compareTo(b.levelOrder));
    reordered.addAll(remaining);

    final updatedMap = Map<String, List<LevelModel>>.from(state.contentFiles);
    updatedMap[contentFile] = [
      for (var i = 0; i < reordered.length; i++)
        reordered[i].copyWith(levelOrder: i + 1),
    ];
    state = state.copyWith(contentFiles: updatedMap);
  }

  // ---------------------------------------------------------------------------
  // Question CRUD
  // ---------------------------------------------------------------------------

  /// Adds a question to a level's question list within the specified content file.
  void addQuestion(String contentFile, int levelId, QuestionModel question) {
    final currentLevels = state.contentFiles[contentFile];
    if (currentLevels == null) return;
    final updatedMap = Map<String, List<LevelModel>>.from(state.contentFiles);
    updatedMap[contentFile] = currentLevels.map((l) {
      if (l.id == levelId) {
        return l.copyWith(questions: [...l.questions, question]);
      }
      return l;
    }).toList();
    state = state.copyWith(contentFiles: updatedMap);
  }

  /// Updates a question at the specified index within a level.
  void updateQuestion(
      String contentFile, int levelId, int questionIndex, QuestionModel updated) {
    final currentLevels = state.contentFiles[contentFile];
    if (currentLevels == null) return;
    final updatedMap = Map<String, List<LevelModel>>.from(state.contentFiles);
    updatedMap[contentFile] = currentLevels.map((l) {
      if (l.id == levelId) {
        final newQuestions = List<QuestionModel>.from(l.questions);
        if (questionIndex >= 0 && questionIndex < newQuestions.length) {
          newQuestions[questionIndex] = updated;
        }
        return l.copyWith(questions: newQuestions);
      }
      return l;
    }).toList();
    state = state.copyWith(contentFiles: updatedMap);
  }

  /// Removes a question at the specified index within a level.
  void deleteQuestion(String contentFile, int levelId, int questionIndex) {
    final currentLevels = state.contentFiles[contentFile];
    if (currentLevels == null) return;
    final updatedMap = Map<String, List<LevelModel>>.from(state.contentFiles);
    updatedMap[contentFile] = currentLevels.map((l) {
      if (l.id == levelId) {
        final newQuestions = List<QuestionModel>.from(l.questions);
        if (questionIndex >= 0 && questionIndex < newQuestions.length) {
          newQuestions.removeAt(questionIndex);
        }
        return l.copyWith(questions: newQuestions);
      }
      return l;
    }).toList();
    state = state.copyWith(contentFiles: updatedMap);
  }

  // ---------------------------------------------------------------------------
  // Reward CRUD
  // ---------------------------------------------------------------------------

  void addReward(RewardModel reward) {
    state = state.copyWith(rewards: [...state.rewards, reward]);
  }

  void updateReward(int index, RewardModel updated) {
    final newRewards = List<RewardModel>.from(state.rewards);
    if (index >= 0 && index < newRewards.length) {
      newRewards[index] = updated;
    }
    state = state.copyWith(rewards: newRewards);
  }

  void deleteReward(int index) {
    final newRewards = List<RewardModel>.from(state.rewards);
    if (index >= 0 && index < newRewards.length) {
      newRewards.removeAt(index);
    }
    state = state.copyWith(rewards: newRewards);
  }

  // ---------------------------------------------------------------------------
  // Hadith CRUD
  // ---------------------------------------------------------------------------

  void addHadith(HadithModel hadith) {
    state = state.copyWith(hadiths: [...state.hadiths, hadith]);
  }

  void updateHadith(int index, HadithModel updated) {
    final newHadiths = List<HadithModel>.from(state.hadiths);
    if (index >= 0 && index < newHadiths.length) {
      newHadiths[index] = updated;
    }
    state = state.copyWith(hadiths: newHadiths);
  }

  void deleteHadith(int index) {
    final newHadiths = List<HadithModel>.from(state.hadiths);
    if (index >= 0 && index < newHadiths.length) {
      newHadiths.removeAt(index);
    }
    state = state.copyWith(hadiths: newHadiths);
  }

  // ---------------------------------------------------------------------------
  // Order compaction
  // ---------------------------------------------------------------------------

  List<SeriesModel> _compactSeriesSortOrder(List<SeriesModel> series) {
    final ranked = [...series]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final orderById = {
      for (var i = 0; i < ranked.length; i++) ranked[i].id: i + 1,
    };
    return [
      for (final s in series) s.copyWith(sortOrder: orderById[s.id]),
    ];
  }

  List<BookModel> _compactBookOrder(List<BookModel> books, int seriesId) {
    final seriesBooks = books.where((b) => b.seriesId == seriesId).toList()
      ..sort((a, b) => a.bookOrder.compareTo(b.bookOrder));
    final orderById = {
      for (var i = 0; i < seriesBooks.length; i++) seriesBooks[i].id: i + 1,
    };
    return [
      for (final b in books)
        orderById.containsKey(b.id) ? b.copyWith(bookOrder: orderById[b.id]) : b,
    ];
  }

  // ---------------------------------------------------------------------------
  // Auto-ID Generation
  // ---------------------------------------------------------------------------

  /// Returns the next available series ID (max existing ID + 1, or 1 if empty).
  int get nextSeriesId {
    if (state.series.isEmpty) return 1;
    return state.series.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Returns the next available book ID (max existing ID + 1, or 1 if empty).
  int get nextBookId {
    if (state.books.isEmpty) return 1;
    return state.books.map((b) => b.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Returns the next available level ID (max ID across ALL content files + 1,
  /// or 1 if empty).
  int get nextLevelId {
    final allLevels =
        state.contentFiles.values.expand((levels) => levels).toList();
    if (allLevels.isEmpty) return 1;
    return allLevels.map((l) => l.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Core mutable state provider for all content.
final contentStateProvider =
    StateNotifierProvider<ContentNotifier, ContentState>(
  (ref) => ContentNotifier(),
);

/// Derived provider returning all series sorted by sortOrder.
final allSeriesProvider = Provider<List<SeriesModel>>((ref) {
  final state = ref.watch(contentStateProvider);
  final sorted = List<SeriesModel>.from(state.series)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return sorted;
});

/// Derived provider returning books for a specific series, sorted by bookOrder.
final booksForSeriesProvider =
    Provider.family<List<BookModel>, int>((ref, seriesId) {
  final state = ref.watch(contentStateProvider);
  final filtered = state.books.where((b) => b.seriesId == seriesId).toList()
    ..sort((a, b) => a.bookOrder.compareTo(b.bookOrder));
  return filtered;
});

/// Derived provider returning levels for a content file, sorted by levelOrder.
final levelsForBookProvider =
    Provider.family<List<LevelModel>, String>((ref, contentFile) {
  final state = ref.watch(contentStateProvider);
  final levels = state.contentFiles[contentFile] ?? [];
  final sorted = List<LevelModel>.from(levels)
    ..sort((a, b) => a.levelOrder.compareTo(b.levelOrder));
  return sorted;
});
