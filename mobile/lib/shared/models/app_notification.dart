class AppNotification {
  AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.message,
    required this.read,
    this.createdAt,
    this.relatedEmployeeId,
    this.relatedRequestId,
    this.sensitive = false,
    this.actionPath,
  });

  final int id;
  final String category;
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;
  final int? relatedEmployeeId;
  final int? relatedRequestId;
  final bool sensitive;
  final String? actionPath;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] as num).toInt(),
      category: json['category'] as String? ?? 'SYSTEM',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      relatedEmployeeId: (json['relatedEmployeeId'] as num?)?.toInt(),
      relatedRequestId: (json['relatedRequestId'] as num?)?.toInt(),
      sensitive: json['sensitive'] as bool? ?? false,
      actionPath: json['actionPath'] as String?,
    );
  }
}
