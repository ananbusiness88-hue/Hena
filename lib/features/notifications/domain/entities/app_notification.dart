class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'system',
      data: map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : <String, dynamic>{},
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      readAt: map['read_at'] == null
          ? null
          : DateTime.parse(map['read_at'] as String),
    );
  }
}
