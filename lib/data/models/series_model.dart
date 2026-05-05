/// Immutable data model representing a content series.
///
/// Maps to entries in `series.json` with snake_case JSON keys.
class SeriesModel {
  final int id;
  final String name;
  final int sortOrder;
  final bool isLocked;
  final String iconEmoji;
  final String? description;

  const SeriesModel({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isLocked,
    required this.iconEmoji,
    this.description,
  });

  factory SeriesModel.fromJson(Map<String, dynamic> json) {
    return SeriesModel(
      id: json['id'] as int,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int,
      isLocked: json['is_locked'] as bool,
      iconEmoji: json['icon_emoji'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'is_locked': isLocked,
      'icon_emoji': iconEmoji,
      'description': description,
    };
  }

  SeriesModel copyWith({
    int? id,
    String? name,
    int? sortOrder,
    bool? isLocked,
    String? iconEmoji,
    String? Function()? description,
  }) {
    return SeriesModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isLocked: isLocked ?? this.isLocked,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      description: description != null ? description() : this.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeriesModel &&
        other.id == id &&
        other.name == name &&
        other.sortOrder == sortOrder &&
        other.isLocked == isLocked &&
        other.iconEmoji == iconEmoji &&
        other.description == description;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, sortOrder, isLocked, iconEmoji, description);
  }

  @override
  String toString() {
    return 'SeriesModel(id: $id, name: $name, sortOrder: $sortOrder, '
        'isLocked: $isLocked, iconEmoji: $iconEmoji, description: $description)';
  }
}
