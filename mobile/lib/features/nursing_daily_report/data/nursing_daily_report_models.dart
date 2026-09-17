class NursingDailyDepartment {
  const NursingDailyDepartment({
    required this.id,
    required this.name,
    this.code,
  });

  final int id;
  final String name;
  final String? code;

  factory NursingDailyDepartment.fromJson(Map<String, dynamic> json) =>
      NursingDailyDepartment(
        id: _integer(json['id']),
        name: _string(json['name']),
        code: _nullableString(json['code']),
      );
}

class NursingDailyReport {
  const NursingDailyReport({
    required this.id,
    required this.departmentId,
    required this.departmentName,
    required this.reportDate,
    required this.totalStaff,
    required this.workingStaff,
    required this.plannedLeave,
    required this.unplannedLeave,
    required this.maternityLeave,
    required this.longLeave,
    required this.dutyAfternoonOff,
    required this.externalMission,
    required this.inpatients,
    required this.inpatientsCareLevel1,
    required this.inpatientsCareLevel2,
    required this.inpatientsCareLevel3,
    required this.outpatients,
    required this.paraclinical,
    required this.surgery,
    required this.dischargedYesterday,
    required this.actualBeds,
    required this.plannedBeds,
    required this.inpatientTreatmentDays,
    required this.falls,
    required this.newPressureUlcers,
    required this.idMixups,
    required this.medicationErrors,
    this.departmentCode,
    this.createdByUsername,
    this.updatedByUsername,
    this.createdAt,
    this.updatedAt,
    this.status = 'SUBMITTED',
    this.submittedAt,
    this.canEdit = false,
    this.canRecall = false,
  });

  final int id;
  final int departmentId;
  final String? departmentCode;
  final String departmentName;
  final String reportDate;
  final int totalStaff;
  final int workingStaff;
  final int plannedLeave;
  final int unplannedLeave;
  final int maternityLeave;
  final int longLeave;
  final int dutyAfternoonOff;
  final int externalMission;
  final int inpatients;
  final int inpatientsCareLevel1;
  final int inpatientsCareLevel2;
  final int inpatientsCareLevel3;
  final int outpatients;
  final int paraclinical;
  final int surgery;
  final int dischargedYesterday;
  final int actualBeds;
  final int plannedBeds;
  final int inpatientTreatmentDays;
  final int falls;
  final int newPressureUlcers;
  final int idMixups;
  final int medicationErrors;
  final String? createdByUsername;
  final String? updatedByUsername;
  final String? createdAt;
  final String? updatedAt;
  final String status;
  final String? submittedAt;
  final bool canEdit;
  final bool canRecall;

  int get staffAccounted =>
      workingStaff +
      plannedLeave +
      unplannedLeave +
      maternityLeave +
      longLeave +
      dutyAfternoonOff +
      externalMission;

  int get safetyIncidents =>
      falls + newPressureUlcers + idMixups + medicationErrors;

  Map<String, int> get values => {
    'totalStaff': totalStaff,
    'workingStaff': workingStaff,
    'plannedLeave': plannedLeave,
    'unplannedLeave': unplannedLeave,
    'maternityLeave': maternityLeave,
    'longLeave': longLeave,
    'dutyAfternoonOff': dutyAfternoonOff,
    'externalMission': externalMission,
    'inpatients': inpatients,
    'inpatientsCareLevel1': inpatientsCareLevel1,
    'inpatientsCareLevel2': inpatientsCareLevel2,
    'inpatientsCareLevel3': inpatientsCareLevel3,
    'outpatients': outpatients,
    'paraclinical': paraclinical,
    'surgery': surgery,
    'dischargedYesterday': dischargedYesterday,
    'actualBeds': actualBeds,
    'plannedBeds': plannedBeds,
    'inpatientTreatmentDays': inpatientTreatmentDays,
    'falls': falls,
    'newPressureUlcers': newPressureUlcers,
    'idMixups': idMixups,
    'medicationErrors': medicationErrors,
  };

  factory NursingDailyReport.fromJson(Map<String, dynamic> json) =>
      NursingDailyReport(
        id: _integer(json['id']),
        departmentId: _integer(json['departmentId']),
        departmentCode: _nullableString(json['departmentCode']),
        departmentName: _string(json['departmentName']),
        reportDate: _string(json['reportDate']),
        totalStaff: _integer(json['totalStaff']),
        workingStaff: _integer(json['workingStaff']),
        plannedLeave: _integer(json['plannedLeave']),
        unplannedLeave: _integer(json['unplannedLeave']),
        maternityLeave: _integer(json['maternityLeave']),
        longLeave: _integer(json['longLeave']),
        dutyAfternoonOff: _integer(json['dutyAfternoonOff']),
        externalMission: _integer(json['externalMission']),
        inpatients: _integer(json['inpatients']),
        inpatientsCareLevel1: _integer(json['inpatientsCareLevel1']),
        inpatientsCareLevel2: _integer(json['inpatientsCareLevel2']),
        inpatientsCareLevel3: _integer(json['inpatientsCareLevel3']),
        outpatients: _integer(json['outpatients']),
        paraclinical: _integer(json['paraclinical']),
        surgery: _integer(json['surgery']),
        dischargedYesterday: _integer(json['dischargedYesterday']),
        actualBeds: _integer(json['actualBeds']),
        plannedBeds: _integer(json['plannedBeds']),
        inpatientTreatmentDays: _integer(json['inpatientTreatmentDays']),
        falls: _integer(json['falls']),
        newPressureUlcers: _integer(json['newPressureUlcers']),
        idMixups: _integer(json['idMixups']),
        medicationErrors: _integer(json['medicationErrors']),
        createdByUsername: _nullableString(json['createdByUsername']),
        updatedByUsername: _nullableString(json['updatedByUsername']),
        createdAt: _nullableString(json['createdAt']),
        updatedAt: _nullableString(json['updatedAt']),
        status: _string(json['status']).isEmpty
            ? 'SUBMITTED'
            : _string(json['status']),
        submittedAt: _nullableString(json['submittedAt']),
        canEdit: json['canEdit'] == true,
        canRecall: json['canRecall'] == true,
      );
}

class NursingDailyReportRow {
  const NursingDailyReportRow({
    required this.departmentId,
    required this.departmentName,
    required this.reportDate,
    required this.submitted,
    required this.canEdit,
    this.canRecall = false,
    this.hasDraft = false,
    this.departmentCode,
    this.report,
  });

  final int departmentId;
  final String? departmentCode;
  final String departmentName;
  final String reportDate;
  final bool submitted;
  final bool canEdit;
  final bool canRecall;
  final bool hasDraft;
  final NursingDailyReport? report;

  factory NursingDailyReportRow.fromJson(Map<String, dynamic> json) {
    final rawReport = json['report'];
    return NursingDailyReportRow(
      departmentId: _integer(json['departmentId']),
      departmentCode: _nullableString(json['departmentCode']),
      departmentName: _string(json['departmentName']),
      reportDate: _string(json['reportDate']),
      submitted: json['submitted'] == true,
      canEdit: json['canEdit'] == true,
      canRecall: json['canRecall'] == true,
      hasDraft: json['hasDraft'] == true,
      report: rawReport is Map
          ? NursingDailyReport.fromJson(
              rawReport.map((key, value) => MapEntry('$key', value)),
            )
          : null,
    );
  }
}

String _string(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
