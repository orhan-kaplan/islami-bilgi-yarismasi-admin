import 'package:glados/glados.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';

/// Turkish characters and emoji pool for generating realistic content.
const turkishChars =
    'abcçdefgğhıijklmnoöprsştuüvyzABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ';
const emojiPool = [
  '🕌',
  '📖',
  '👑',
  '🎓',
  '⭐',
  '🌙',
  '📚',
  '🤲',
  '💫',
  '🏆'
];
const questionTypes = [
  'multiple_choice',
  'true_false',
  'matching',
  'sorting'
];
const correctOptions = ['A', 'B', 'C', 'D'];

/// Extension on [Any] to provide custom generators for all content models.
extension ContentGenerators on Any {
  /// Generates a non-empty Turkish-flavored string with special characters.
  Generator<String> get turkishString => simple(
        generate: (random, size) {
          final length = random.nextInt(size.clamp(1, 40)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            final choice = random.nextInt(10);
            if (choice < 7) {
              buffer.write(
                  turkishChars[random.nextInt(turkishChars.length)]);
            } else if (choice < 9) {
              buffer.write(' ');
            } else {
              buffer.write("'");
            }
          }
          // Ensure non-empty after trim by prepending a char if needed
          final result = buffer.toString();
          if (result.trim().isEmpty) {
            return turkishChars[random.nextInt(turkishChars.length)] + result;
          }
          return result;
        },
        shrink: (input) sync* {
          if (input.length > 1) {
            yield input.substring(0, input.length ~/ 2);
          }
        },
      );

  /// Generates an emoji from the pool.
  Generator<String> get emoji => simple(
        generate: (random, size) =>
            emojiPool[random.nextInt(emojiPool.length)],
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a positive integer ID (1+).
  Generator<int> get positiveId => simple(
        generate: (random, size) => random.nextInt(size.clamp(1, 1000)) + 1,
        shrink: (input) sync* {
          if (input > 1) yield input ~/ 2;
        },
      );

  /// Generates a non-negative integer.
  Generator<int> get nonNegativeInt => simple(
        generate: (random, size) => random.nextInt(size.clamp(1, 100)),
        shrink: (input) sync* {
          if (input > 0) yield input ~/ 2;
        },
      );

  /// Generates a question type string.
  Generator<String> get questionType => choose(questionTypes);

  /// Generates a correct option value (A, B, C, or D).
  Generator<String> get correctOption => choose(correctOptions);

  /// Generates a nullable Turkish string (null or non-empty string).
  Generator<String?> get nullableTurkishString => simple(
        generate: (random, size) {
          if (random.nextBool()) return null;
          final length = random.nextInt(size.clamp(1, 30)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer
                .write(turkishChars[random.nextInt(turkishChars.length)]);
          }
          return buffer.toString();
        },
        shrink: (input) sync* {
          if (input != null) yield null;
        },
      );

  /// Generates an asset image path.
  Generator<String> get assetImagePath => simple(
        generate: (random, size) {
          final bookId = random.nextInt(5) + 1;
          final levelId = random.nextInt(10) + 1;
          return 'assets/images/book_$bookId/level_$levelId.webp';
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a content file name.
  Generator<String> get contentFileName => simple(
        generate: (random, size) {
          final bookId = random.nextInt(10) + 1;
          return 'book_$bookId.json';
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a [SeriesModel] with optional description.
  Generator<SeriesModel> get seriesModel => combine6(
        positiveId,
        turkishString,
        positiveId,
        any.bool,
        emoji,
        nullableTurkishString,
        (int id, String name, int sortOrder, bool isLocked, String iconEmoji,
                String? description) =>
            SeriesModel(
          id: id,
          name: name,
          sortOrder: sortOrder,
          isLocked: isLocked,
          iconEmoji: iconEmoji,
          description: description,
        ),
      );

  /// Generates a [BookModel].
  Generator<BookModel> get bookModel => combine2(
        combine5(
          positiveId,
          turkishString,
          turkishString,
          assetImagePath,
          positiveId,
          (int id, String title, String description, String assetImage,
                  int bookOrder) =>
              (
            id: id,
            title: title,
            description: description,
            assetImage: assetImage,
            bookOrder: bookOrder,
          ),
        ),
        combine2(
          positiveId,
          contentFileName,
          (int seriesId, String contentFile) => (
            seriesId: seriesId,
            contentFile: contentFile,
          ),
        ),
        (first, second) => BookModel(
          id: first.id,
          title: first.title,
          description: first.description,
          assetImage: first.assetImage,
          bookOrder: first.bookOrder,
          seriesId: second.seriesId,
          contentFile: second.contentFile,
        ),
      );

  /// Generates a [QuestionModel] with type-appropriate options.
  Generator<QuestionModel> get questionModel => combine2(
        combine5(
          turkishString,
          turkishString,
          turkishString,
          turkishString,
          turkishString,
          (String questionText, String optA, String optB, String optC,
                  String optD) =>
              (
            questionText: questionText,
            optionA: optA,
            optionB: optB,
            optionC: optC,
            optionD: optD,
          ),
        ),
        combine3(
          correctOption,
          nullableTurkishString,
          questionType,
          (String correct, String? explanation, String type) => (
            correctOption: correct,
            explanation: explanation,
            type: type,
          ),
        ),
        (opts, meta) => QuestionModel(
          questionText: opts.questionText,
          optionA: opts.optionA,
          optionB: opts.optionB,
          optionC: opts.optionC,
          optionD: opts.optionD,
          correctOption: meta.correctOption,
          explanation: meta.explanation,
          type: meta.type,
        ),
      );

  /// Generates a [LevelModel] with 0-5 questions.
  Generator<LevelModel> get levelModel => combine2(
        combine5(
          positiveId,
          positiveId,
          turkishString,
          positiveId,
          turkishString,
          (int id, int bookId, String categoryName, int levelOrder,
                  String title) =>
              (
            id: id,
            bookId: bookId,
            categoryName: categoryName,
            levelOrder: levelOrder,
            title: title,
          ),
        ),
        combine3(
          nonNegativeInt,
          nullableTurkishString,
          listWithLengthInRange(0, 5, questionModel),
          (int unlockScore, String? assetImage,
                  List<QuestionModel> questions) =>
              (
            unlockScore: unlockScore,
            assetImage: assetImage,
            questions: questions,
          ),
        ),
        (first, second) => LevelModel(
          id: first.id,
          bookId: first.bookId,
          categoryName: first.categoryName,
          levelOrder: first.levelOrder,
          title: first.title,
          unlockScore: second.unlockScore,
          assetImage: second.assetImage,
          questions: second.questions,
        ),
      );

  /// Generates a [RewardModel].
  Generator<RewardModel> get rewardModel => combine4(
        turkishString,
        turkishString,
        assetImagePath,
        positiveId,
        (String title, String description, String assetImage,
                int unlockBookId) =>
            RewardModel(
          title: title,
          description: description,
          assetImage: assetImage,
          unlockBookId: unlockBookId,
        ),
      );

  /// Generates a [HadithModel].
  Generator<HadithModel> get hadithModel => combine2(
        turkishString,
        turkishString,
        (String text, String source) =>
            HadithModel(text: text, source: source),
      );

  /// Generates a [ContentState] with all entity types populated.
  Generator<ContentState> get contentState => combine5(
        listWithLengthInRange(1, 4, seriesModel),
        listWithLengthInRange(1, 4, bookModel),
        listWithLengthInRange(1, 5, levelModel),
        listWithLengthInRange(0, 3, rewardModel),
        listWithLengthInRange(0, 5, hadithModel),
        (List<SeriesModel> series, List<BookModel> books,
            List<LevelModel> levels, List<RewardModel> rewards,
            List<HadithModel> hadiths) {
          // Group levels into content files keyed by book contentFile names.
          final contentFiles = <String, List<LevelModel>>{};
          for (var i = 0; i < levels.length; i++) {
            final key = books[i % books.length].contentFile;
            contentFiles.putIfAbsent(key, () => []).add(levels[i]);
          }
          return ContentState(
            series: series,
            books: books,
            contentFiles: contentFiles,
            rewards: rewards,
            hadiths: hadiths,
          );
        },
      );
}
