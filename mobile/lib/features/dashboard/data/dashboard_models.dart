/// Model thống kê dashboard — mirror payload `/v1/dashboard/stats`
/// và `/v1/dashboard/nursing-stats`.
class DashboardStats {
  const DashboardStats({
    required this.raw,
    required this.totalEmployees,
    required this.activeEmployees,
    required this.maternityLeave,
    required this.departments,
    required this.employeeRoleAccounts,
    required this.totalPdfDocuments,
    required this.salaryReviewsDueSoon,
    required this.status,
    required this.byDepartment,
    required this.hiresByMonth,
  });

  final Map<String, dynamic> raw;
  final int totalEmployees;
  final int activeEmployees;
  final int maternityLeave;
  final int departments;
  final int employeeRoleAccounts;
  final int totalPdfDocuments;
  final int salaryReviewsDueSoon;
  final StatusBreakdown status;
  final List<DepartmentCount> byDepartment;
  final List<HireMonth> hiresByMonth;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final breakdown = json['statusBreakdown'];
    StatusBreakdown status;
    if (breakdown is Map) {
      status = StatusBreakdown(
        working: _i(breakdown['working']),
        maternityLeave: _i(breakdown['maternityLeave']),
        trial: _i(breakdown['trial']),
        terminated: _i(breakdown['terminated']),
      );
    } else {
      final maternity = _i(json['maternityLeave']);
      final active = _i(json['activeEmployees']);
      final total = _i(json['totalEmployees']);
      final working = (active - maternity).clamp(0, active);
      status = StatusBreakdown(
        working: working,
        maternityLeave: maternity,
        trial: 0,
        terminated: (total - working - maternity).clamp(0, total),
      );
    }

    final depts = <DepartmentCount>[];
    final deptRaw = json['employeesByDepartment'];
    if (deptRaw is List) {
      for (final item in deptRaw) {
        if (item is Map) depts.add(DepartmentCount.fromJson(item));
      }
    }
    depts.sort((a, b) => b.count.compareTo(a.count));

    final hires = <HireMonth>[];
    final hireRaw = json['hiresByMonth'];
    if (hireRaw is List) {
      for (final item in hireRaw) {
        if (item is Map) hires.add(HireMonth.fromJson(item));
      }
    }

    return DashboardStats(
      raw: json,
      totalEmployees: _i(json['totalEmployees']),
      activeEmployees: _i(json['activeEmployees']),
      maternityLeave: _i(json['maternityLeave']),
      departments: _i(json['departments']),
      employeeRoleAccounts: _i(json['employeeRoleAccounts']),
      totalPdfDocuments: _i(json['totalPdfDocuments']),
      salaryReviewsDueSoon: _i(json['salaryReviewsDueSoon']),
      status: status,
      byDepartment: depts,
      hiresByMonth: hires,
    );
  }
}

class NursingDashboardStats {
  const NursingDashboardStats({
    required this.totalInBlock,
    required this.officialCount,
    required this.trialCount,
    required this.mainDutyAuthorized,
    required this.pendingTotal,
    required this.pendingDeployments,
    required this.pendingProbation,
    required this.pendingMainDuty,
    required this.departmentsCovered,
    required this.bySubGroup,
    required this.byDepartment,
  });

  final int totalInBlock;
  final int officialCount;
  final int trialCount;
  final int mainDutyAuthorized;
  final int pendingTotal;
  final int pendingDeployments;
  final int pendingProbation;
  final int pendingMainDuty;
  final int departmentsCovered;
  final List<SubGroupCount> bySubGroup;
  final List<DepartmentCount> byDepartment;

  factory NursingDashboardStats.fromJson(Map<String, dynamic> json) {
    final depts = <DepartmentCount>[];
    final deptRaw = json['byDepartment'];
    if (deptRaw is List) {
      for (final item in deptRaw) {
        if (item is Map) depts.add(DepartmentCount.fromJson(item));
      }
    }
    depts.sort((a, b) => b.count.compareTo(a.count));

    final subGroups = <SubGroupCount>[];
    final subRaw = json['bySubGroup'];
    if (subRaw is List) {
      for (final item in subRaw) {
        if (item is Map) subGroups.add(SubGroupCount.fromJson(item));
      }
    }
    subGroups.sort((a, b) => b.count.compareTo(a.count));

    return NursingDashboardStats(
      totalInBlock: _i(json['totalInBlock']),
      officialCount: _i(json['officialCount']),
      trialCount: _i(json['trialCount']),
      mainDutyAuthorized: _i(json['mainDutyAuthorized']),
      pendingTotal: _i(json['pendingTotal']),
      pendingDeployments: _i(json['pendingDeployments']),
      pendingProbation: _i(json['pendingProbation']),
      pendingMainDuty: _i(json['pendingMainDuty']),
      departmentsCovered: _i(json['departmentsCovered']),
      bySubGroup: subGroups,
      byDepartment: depts,
    );
  }
}

class SubGroupCount {
  const SubGroupCount({required this.label, required this.count});

  final String label;
  final int count;

  factory SubGroupCount.fromJson(Map<dynamic, dynamic> json) => SubGroupCount(
        label: json['label']?.toString() ?? '—',
        count: _i(json['count']),
      );
}

class StatusBreakdown {
  const StatusBreakdown({
    required this.working,
    required this.maternityLeave,
    required this.trial,
    required this.terminated,
  });

  final int working;
  final int maternityLeave;
  final int trial;
  final int terminated;

  int get total => working + maternityLeave + trial + terminated;
}

class DepartmentCount {
  const DepartmentCount({
    required this.departmentId,
    required this.departmentName,
    required this.count,
    required this.officialCount,
    required this.trialCount,
  });

  final int? departmentId;
  final String departmentName;
  final int count;
  final int officialCount;
  final int trialCount;

  factory DepartmentCount.fromJson(Map<dynamic, dynamic> json) =>
      DepartmentCount(
        departmentId: json['departmentId'] == null
            ? null
            : _i(json['departmentId']),
        departmentName: json['departmentName']?.toString() ?? '—',
        count: _i(json['count']),
        officialCount: _i(json['officialCount']),
        trialCount: _i(json['trialCount']),
      );
}

class HireMonth {
  const HireMonth({
    required this.year,
    required this.month,
    required this.label,
    required this.count,
    required this.officialCount,
    required this.trialCount,
  });

  final int year;
  final int month;
  final String label;
  final int count;
  final int officialCount;
  final int trialCount;

  factory HireMonth.fromJson(Map<dynamic, dynamic> json) {
    final year = _i(json['year']);
    final month = _i(json['month']);
    final label = json['label']?.toString();
    return HireMonth(
      year: year,
      month: month,
      label: (label != null && label.isNotEmpty)
          ? label
          : 'T$month/${year.toString().substring(2)}',
      count: _i(json['count']),
      officialCount: _i(json['officialCount']),
      trialCount: _i(json['trialCount']),
    );
  }
}

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
