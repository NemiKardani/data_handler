/// Post model class.
class Post {
  final int userId;
  final int id;
  final String title;
  final String body;
  final bool isFavorite;

  Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
    this.isFavorite = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      userId: json['userId'] as int? ?? 0,
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Post copyWith({
    int? userId,
    int? id,
    String? title,
    String? body,
    bool? isFavorite,
  }) {
    return Post(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isFavorite == other.isFavorite &&
          title == other.title &&
          body == other.body;

  @override
  int get hashCode => Object.hash(id, isFavorite, title, body);
}

