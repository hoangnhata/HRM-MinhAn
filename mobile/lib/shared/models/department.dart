class Department {
  Department({required this.id, required this.code, required this.name, this.headName});

  final int id;
  final String code;
  final String name;
  final String? headName;

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      headName: json['headName'] as String?,
    );
  }
}

class WorkUnit {
  WorkUnit({required this.id, required this.name, this.departmentId});

  final int id;
  final String name;
  final int? departmentId;

  factory WorkUnit.fromJson(Map<String, dynamic> json) {
    return WorkUnit(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? json['detail'] as String? ?? '',
      departmentId: (json['departmentId'] as num?)?.toInt(),
    );
  }
}
