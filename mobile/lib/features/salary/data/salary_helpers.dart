const kEmployeeQualifications = [
  'Đại học',
  'Cao đẳng, trung cấp',
  'Lao động phổ thông',
];

const kDoctorQualifications = [
  ('DK', 'Bác sỹ chưa có CCHN (ĐK)'),
  ('DKCT', 'Bác sỹ chưa có CCHN (ĐKCT)'),
  ('CCHN', 'Bác sỹ có CCHN'),
  ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)'),
  ('CK1', 'CK1'),
  ('CK2', 'CK2'),
  ('NOI_TRU', 'Nội trú'),
];

const kDefaultSeniorityAsOf = '2026-06-30';

int tierGroupFromQualification(String? qualification) {
  final q = (qualification ?? '').toLowerCase();
  if (q.contains('đại học') || q.contains('dai hoc')) return 1;
  if (q.contains('cao đẳng') ||
      q.contains('trung cấp') ||
      q.contains('cao dang') ||
      q.contains('trung cap')) {
    return 2;
  }
  return 3;
}

bool hasSeniorityMilestone({
  num? baseSeniorityYears,
  String? salaryScaleStartDate,
}) {
  if (baseSeniorityYears == null) return false;
  if (baseSeniorityYears == 0 &&
      (salaryScaleStartDate != null && salaryScaleStartDate.isNotEmpty)) {
    return false;
  }
  return true;
}

double yearsBetweenDays(String? startDate, [DateTime? endDate]) {
  if (startDate == null || startDate.isEmpty) return 0;
  final start = DateTime.tryParse(startDate.sliceDate);
  if (start == null) return 0;
  final end = endDate ?? DateTime.now();
  final a = DateTime(start.year, start.month, start.day);
  final b = DateTime(end.year, end.month, end.day);
  final days = b.difference(a).inDays;
  if (days <= 0) return 0;
  return days / 365;
}

double resolveLiveSeniorityYears({
  num? baseSeniorityYears,
  String? seniorityAsOfDate,
  String? salaryScaleStartDate,
  num? priorRaiseYears,
  num? degreeConversionYears,
  bool ldg = false,
}) {
  if (ldg) return 0;
  final prior = (priorRaiseYears ?? 0).toDouble().clamp(0, double.infinity);
  final degree =
      (degreeConversionYears ?? 0).toDouble().clamp(0, double.infinity);
  double years;
  if (hasSeniorityMilestone(
    baseSeniorityYears: baseSeniorityYears,
    salaryScaleStartDate: salaryScaleStartDate,
  )) {
    final asOf = (seniorityAsOfDate != null && seniorityAsOfDate.isNotEmpty)
        ? seniorityAsOfDate
        : kDefaultSeniorityAsOf;
    years = (baseSeniorityYears ?? 0).toDouble() + yearsBetweenDays(asOf);
  } else {
    years = yearsBetweenDays(salaryScaleStartDate);
  }
  return years + prior + degree;
}

String liveSeniorityPreview({
  num? baseSeniorityYears,
  String? seniorityAsOfDate,
  String? salaryScaleStartDate,
  num? priorRaiseYears,
  num? degreeConversionYears,
  bool ldg = false,
}) {
  if (ldg) return 'LĐG';
  final hasBase = hasSeniorityMilestone(
    baseSeniorityYears: baseSeniorityYears,
    salaryScaleStartDate: salaryScaleStartDate,
  );
  if (!hasBase &&
      (salaryScaleStartDate == null || salaryScaleStartDate.isEmpty)) {
    return 'Nhập mốc 30/06 hoặc ngày bắt đầu thang';
  }
  return '${resolveLiveSeniorityYears(
    baseSeniorityYears: baseSeniorityYears,
    seniorityAsOfDate: seniorityAsOfDate,
    salaryScaleStartDate: salaryScaleStartDate,
    priorRaiseYears: priorRaiseYears,
    degreeConversionYears: degreeConversionYears,
    ldg: ldg,
  ).toStringAsFixed(2)} năm';
}

extension on String {
  String get sliceDate => length >= 10 ? substring(0, 10) : this;
}
