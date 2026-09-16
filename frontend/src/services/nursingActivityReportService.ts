import api from './api';

export type PeriodType = 'MONTH' | 'QUARTER' | 'HALF_YEAR' | 'YEAR' | 'DAY' | 'CUSTOM';

export type CompareMetric =
  | 'FALL_RATE'
  | 'FALL_FREQUENCY'
  | 'PRESSURE_RATE'
  | 'PRESSURE_FREQUENCY'
  | 'NURSE_BED'
  | 'ID_MIXUP_FREQUENCY'
  | 'MEDICATION_RATE';

export type MetricKind =
  | 'overview'
  | 'falls'
  | 'pressure-ulcers'
  | 'nurse-bed'
  | 'id-mixups'
  | 'medication-errors';

export type ActivityReportQuery = {
  periodType?: PeriodType;
  from?: string;
  to?: string;
  yearMonth?: string;
  year?: number;
  quarter?: number;
  half?: number;
  departmentId?: number;
  compareMetric?: CompareMetric;
  sortBy?: 'RATE' | 'FREQUENCY';
  sortDir?: 'ASC' | 'DESC';
};

export type DeptMetrics = {
  departmentId: number;
  departmentName: string;
  falls: number;
  newPressureUlcers: number;
  idMixups: number;
  medicationErrors: number;
  inpatients: number;
  inpatientTreatmentDays: number;
  totalStaff: number;
  workingStaff: number;
  actualBeds: number;
  reportDays: number;
  fallRate: number | null;
  fallRateLabel: string;
  fallFrequency: number | null;
  fallFrequencyLabel: string;
  pressureUlcerRate: number | null;
  pressureUlcerRateLabel: string;
  pressureUlcerFrequency: number | null;
  pressureUlcerFrequencyLabel: string;
  nurseBedRatio: number | null;
  nurseBedRatioLabel: string;
  idMixupFrequency: number | null;
  idMixupFrequencyLabel: string;
  medicationErrorRate: number | null;
  medicationErrorRateLabel: string;
  hasData: boolean;
};

export type TrendPoint = DeptMetrics & {
  bucketKey: string;
  label: string;
  primaryValue?: number | null;
  secondaryValue?: number | null;
};

export type ActivityReport = {
  reportKind: string;
  reportTitle: string;
  from: string;
  to: string;
  fromLabel: string;
  toLabel: string;
  yearMonth: string;
  departmentId?: number | null;
  departmentName: string;
  kpi: Record<string, unknown>;
  overviewKpi?: Record<string, Record<string, unknown>>;
  byDepartment: DeptMetrics[];
  summaryTable: DeptMetrics[];
  trend: TrendPoint[];
  trendGranularity: 'DAY' | 'WEEK' | 'MONTH';
  compareChart: { departmentId: number; departmentName: string; value: number; valueLabel: string }[];
  compareMetric: string;
  reportDays: number;
  actorRole: string;
};

export type DepartmentDetailReport = {
  reportTitle: string;
  from: string;
  to: string;
  fromLabel: string;
  toLabel: string;
  departmentId: number;
  departmentName: string;
  rawTotals: Record<string, number>;
  metrics: DeptMetrics;
  dailyRows: {
    reportDate: string;
    reportDateLabel: string;
    inpatients: number;
    inpatientTreatmentDays: number;
    falls: number;
    newPressureUlcers: number;
    idMixups: number;
    medicationErrors: number;
    totalStaff: number;
    workingStaff: number;
    actualBeds: number;
    metrics: DeptMetrics;
  }[];
};

export type FilterDepartment = { id: number; code: string; name: string };

function buildParams(q: ActivityReportQuery) {
  const p: Record<string, string | number> = {};
  if (q.periodType) p.periodType = q.periodType;
  if (q.from) p.from = q.from;
  if (q.to) p.to = q.to;
  if (q.yearMonth) p.yearMonth = q.yearMonth;
  if (q.year != null) p.year = q.year;
  if (q.quarter != null) p.quarter = q.quarter;
  if (q.half != null) p.half = q.half;
  if (q.departmentId != null) p.departmentId = q.departmentId;
  if (q.compareMetric) p.compareMetric = q.compareMetric;
  if (q.sortBy) p.sortBy = q.sortBy;
  if (q.sortDir) p.sortDir = q.sortDir;
  return p;
}

export function currentYearMonth() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

export function currentYear() {
  return new Date().getFullYear();
}

export async function fetchFilterDepartments() {
  const { data } = await api.get<FilterDepartment[]>('/v1/nursing-activity-reports/departments');
  return data;
}

export async function fetchOverview(q: ActivityReportQuery) {
  const { data } = await api.get<ActivityReport>('/v1/nursing-activity-reports/overview', { params: buildParams(q) });
  return data;
}

export async function fetchFallsReport(q: ActivityReportQuery) {
  const { data } = await api.get<ActivityReport>('/v1/nursing-activity-reports/falls', { params: buildParams(q) });
  return data;
}

export async function fetchPressureUlcerReport(q: ActivityReportQuery) {
  const { data } = await api.get<ActivityReport>('/v1/nursing-activity-reports/pressure-ulcers', { params: buildParams(q) });
  return data;
}

export async function fetchNurseBedReport(q: ActivityReportQuery) {
  const { data } = await api.get<ActivityReport>('/v1/nursing-activity-reports/nurse-bed', { params: buildParams(q) });
  return data;
}

export async function fetchIdMixupReport(q: ActivityReportQuery) {
  const { data } = await api.get<ActivityReport>('/v1/nursing-activity-reports/id-mixups', { params: buildParams(q) });
  return data;
}

export async function fetchMedicationErrorReport(q: ActivityReportQuery) {
  const { data } = await api.get<ActivityReport>('/v1/nursing-activity-reports/medication-errors', { params: buildParams(q) });
  return data;
}

export async function fetchDepartmentDetail(departmentId: number, q: ActivityReportQuery) {
  const { data } = await api.get<DepartmentDetailReport>(
    `/v1/nursing-activity-reports/departments/${departmentId}/detail`,
    { params: buildParams(q) },
  );
  return data;
}

async function download(kind: MetricKind, ext: 'excel' | 'pdf', q: ActivityReportQuery) {
  const { data } = await api.get<Blob>(`/v1/nursing-activity-reports/${kind}/${ext}`, {
    params: buildParams(q),
    responseType: 'blob',
  });
  const url = URL.createObjectURL(data);
  const a = document.createElement('a');
  a.href = url;
  a.download = `bao-cao-hoat-dong-dieu-duong.${ext === 'excel' ? 'xlsx' : 'pdf'}`;
  a.click();
  URL.revokeObjectURL(url);
}

export function downloadExcel(kind: MetricKind, q: ActivityReportQuery) {
  return download(kind, 'excel', q);
}

export function downloadPdf(kind: MetricKind, q: ActivityReportQuery) {
  return download(kind, 'pdf', q);
}

export async function fetchReportByKind(kind: MetricKind, q: ActivityReportQuery) {
  switch (kind) {
    case 'overview': return fetchOverview(q);
    case 'falls': return fetchFallsReport(q);
    case 'pressure-ulcers': return fetchPressureUlcerReport(q);
    case 'nurse-bed': return fetchNurseBedReport(q);
    case 'id-mixups': return fetchIdMixupReport(q);
    case 'medication-errors': return fetchMedicationErrorReport(q);
  }
}
