/// Immutable data model representing a book within a series.
///
/// Maps to entries in `books.json` with snake_case JSON keys.
class BookModel {
  final int id;
  final String title;
  final String description;
  final String assetImage;
  final int bookOrder;
  final int seriesId;
  final String contentFile;

  const BookModel({
    required this.id,
    required this.title,
    required this.description,
    required this.assetImage,
    required this.bookOrder,
    required this.seriesId,
    required this.contentFile,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      assetImage: json['asset_image'] as String,
      bookOrder: json['book_order'] as int,
      seriesId: json['series_id'] as int,
      contentFile: json['content_file'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'asset_image': assetImage,
      'book_order': bookOrder,
      'series_id': seriesId,
      'content_file': contentFile,
    };
  }

  BookModel copyWith({
    int? id,
    String? title,
    String? description,
    String? assetImage,
    int? bookOrder,
    int? seriesId,
    String? contentFile,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assetImage: assetImage ?? this.assetImage,
      bookOrder: bookOrder ?? this.bookOrder,
      seriesId: seriesId ?? this.seriesId,
      contentFile: contentFile ?? this.contentFile,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookModel &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.assetImage == assetImage &&
        other.bookOrder == bookOrder &&
        other.seriesId == seriesId &&
        other.contentFile == contentFile;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      description,
      assetImage,
      bookOrder,
      seriesId,
      contentFile,
    );
  }

  @override
  String toString() {
    return 'BookModel(id: $id, title: $title, description: $description, '
        'assetImage: $assetImage, bookOrder: $bookOrder, '
        'seriesId: $seriesId, contentFile: $contentFile)';
  }
}
