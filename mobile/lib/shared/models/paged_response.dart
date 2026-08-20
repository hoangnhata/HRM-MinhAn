/// Mirror Spring Data `Page<T>` — dung cho cac danh sach co phan trang.
class PagedResponse<T> {
  PagedResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
    required this.last,
  });

  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;
  final bool last;

  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawContent = (json['content'] as List<dynamic>? ?? []);
    return PagedResponse(
      content: rawContent.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      number: (json['number'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      last: json['last'] as bool? ?? true,
    );
  }
}
