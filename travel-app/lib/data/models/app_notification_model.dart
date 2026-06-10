/// Modèle de notification in-app reçue depuis l'API Laravel.
class AppNotificationModel {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id:        (json['id'] as num).toInt(),
      userId:    (json['user_id'] as num).toInt(),
      type:      json['type'] as String,
      title:     json['title'] as String,
      body:      json['body'] as String,
      data:      json['data'] as Map<String, dynamic>?,
      readAt:    json['read_at'] != null
                     ? DateTime.parse(json['read_at'] as String)
                     : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotificationModel copyWith({bool? isRead}) {
    return AppNotificationModel(
      id:        id,
      userId:    userId,
      type:      type,
      title:     title,
      body:      body,
      data:      data,
      readAt:    isRead == true ? (readAt ?? DateTime.now()) : readAt,
      createdAt: createdAt,
    );
  }
}

/// Réponse paginée de l'API pour la liste des notifications.
class NotificationsPage {
  final List<AppNotificationModel> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int unreadCount;

  const NotificationsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.unreadCount,
  });

  bool get hasNextPage => currentPage < lastPage;

  factory NotificationsPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>;
    final meta = json['meta'] as Map<String, dynamic>? ?? json;

    return NotificationsPage(
      items:       data
          .map((e) => AppNotificationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage:    (meta['last_page'] as num?)?.toInt() ?? 1,
      total:       (meta['total'] as num?)?.toInt() ?? 0,
      unreadCount: 0, // rempli par le provider via l'endpoint /unread-count
    );
  }
}
