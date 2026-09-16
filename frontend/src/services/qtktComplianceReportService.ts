import api from './api';

export type ComplianceKpi = {
  total: number;
  passed: number;
  failed: number;
  complianceRate: number | null;
  hasData: boolean;
  complianceRateLabel: string;
};

export type ComplianceBucket = {
  departmentId?: number;
  departmentName?: string;
  procedureCode?: string;
  procedureName?: string;
  checkContextCode?: string;
  checkContextLabel?: string;
  total: number;
  passed: number;
  failed: number;
  complianceRate: number | null;
  hasData: boolean;
  isTotal?: boolean;
  byProcedure?: ComplianceBucket[];
};

export type ComplianceTrendPoint = {
  bucketKey: string;
  label: string;
  total: number;
  passed: number;
  failed: number;
  complianceRate: number | null;
  hasData: boolean;
};

export type ComplianceDetailRow = {
  id: number;
  evalDate: string;
  evalDateLabel: string;
  departmentId: number;
  departmentName: string;
  employeeId: number;
  employeeName: string;
  employeeCode: string;
  procedureCode: string;
  procedureName: string;
  checkContextCode?: string;
  checkContextLabel?: string;
  patientCode?: string | null;
  totalScore: number;
  maxScore: number;
  passed: boolean;
  result: string;
};

export type ComplianceReport = {
  reportKind: string;
  reportTitle: string;
  formulaNote?: string;
  from: string;
  to: string;
  yearMonth: string;
  departmentId?: number | null;
  departmentName: string;
  employeeId?: number | null;
  employeeName?: string;
  procedureCode?: string | null;
  kpi: ComplianceKpi;
  byDepartment: ComplianceBucket[];
  byCheckContext?: ComplianceBucket[];
  byProcedure?: ComplianceBucket[];
  trend: ComplianceTrendPoint[];
  trendGranularity: 'DAY' | 'WEEK' | 'MONTH';
  trendByProcedure?: Record<string, ComplianceTrendPoint[]>;
  details: {
    items: ComplianceDetailRow[];
    total: number;
    page: number;
    size: number;
    totalPages: number;
  };
  filters: {
    search: string;
    resultFilter: string;
    sortDir: string;
  };
};

export type ComplianceFilterEmployee = {
  id: number;
  fullName: string;
  employeeCode: string;
  departmentId?: number | null;
  departmentName?: string | null;
};

export type ComplianceFilterDepartment = {
  id: number;
  code: string;
  name: string;
};

export type ComplianceQuery = {
  from?: string;
  to?: string;
  yearMonth?: string;
  departmentId?: number;
  employeeId?: number;
  procedureCode?: string;
  search?: string;
  resultFilter?: 'ALL' | 'PASS' | 'FAIL';
  sortDir?: 'ASC' | 'DESC';
  page?: number;
  size?: number;
};

function buildParams(q: ComplianceQuery) {
  const p: Record<string, string | number> = {};
  if (q.from) p.from = q.from;
  if (q.to) p.to = q.to;
  if (q.yearMonth) p.yearMonth = q.yearMonth;
  if (q.departmentId) p.departmentId = q.departmentId;
  if (q.employeeId) p.employeeId = q.employeeId;
  if (q.procedureCode) p.procedureCode = q.procedureCode;
  if (q.search) p.search = q.search;
  if (q.resultFilter && q.resultFilter !== 'ALL') p.resultFilter = q.resultFilter;
  if (q.sortDir) p.sortDir = q.sortDir;
  if (q.page != null) p.page = q.page;
  if (q.size != null) p.size = q.size;
  return p;
}

function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

export async function fetchComplianceDepartments(reportKind?: string) {
  const { data } = await api.get<ComplianceFilterDepartment[]>('/v1/qtkt-compliance-reports/departments', {
    params: reportKind ? { reportKind } : undefined,
  });
  return data;
}

export async function fetchComplianceEmployees(departmentId?: number) {
  const { data } = await api.get<ComplianceFilterEmployee[]>('/v1/qtkt-compliance-reports/employees', {
    params: departmentId ? { departmentId } : undefined,
  });
  return data;
}

export async function fetchHandHygieneReport(query: ComplianceQuery) {
  const { data } = await api.get<ComplianceReport>('/v1/qtkt-compliance-reports/hand-hygiene', {
    params: buildParams(query),
  });
  return data;
}

export async function fetchTechnicalComplianceReport(query: ComplianceQuery) {
  const { data } = await api.get<ComplianceReport>('/v1/qtkt-compliance-reports/technical-procedures', {
    params: buildParams(query),
  });
  return data;
}

export async function downloadHandHygieneExcel(query: ComplianceQuery) {
  const res = await api.get('/v1/qtkt-compliance-reports/hand-hygiene/excel', {
    params: buildParams(query),
    responseType: 'blob',
  });
  triggerDownload(res.data, 'bao-cao-ve-sinh-tay.xlsx');
}

export async function downloadHandHygienePdf(query: ComplianceQuery) {
  const res = await api.get('/v1/qtkt-compliance-reports/hand-hygiene/pdf', {
    params: buildParams(query),
    responseType: 'blob',
  });
  triggerDownload(res.data, 'bao-cao-ve-sinh-tay.pdf');
}

export async function downloadTechnicalComplianceExcel(query: ComplianceQuery) {
  const res = await api.get('/v1/qtkt-compliance-reports/technical-procedures/excel', {
    params: buildParams(query),
    responseType: 'blob',
  });
  triggerDownload(res.data, 'bao-cao-tuan-thu-qtk.xlsx');
}

export async function downloadTechnicalCompliancePdf(query: ComplianceQuery) {
  const res = await api.get('/v1/qtkt-compliance-reports/technical-procedures/pdf', {
    params: buildParams(query),
    responseType: 'blob',
  });
  triggerDownload(res.data, 'bao-cao-tuan-thu-qtk.pdf');
}

export async function fetchGdskCounselingReport(query: ComplianceQuery) {
  const { data } = await api.get<ComplianceReport>('/v1/qtkt-compliance-reports/gdsk-counseling', {
    params: buildParams(query),
  });
  return data;
}

export async function downloadGdskCounselingExcel(query: ComplianceQuery) {
  const res = await api.get('/v1/qtkt-compliance-reports/gdsk-counseling/excel', {
    params: buildParams(query),
    responseType: 'blob',
  });
  triggerDownload(res.data, 'bao-cao-tu-van-gdsk.xlsx');
}

export async function downloadGdskCounselingPdf(query: ComplianceQuery) {
  const res = await api.get('/v1/qtkt-compliance-reports/gdsk-counseling/pdf', {
    params: buildParams(query),
    responseType: 'blob',
  });
  triggerDownload(res.data, 'bao-cao-tu-van-gdsk.pdf');
}

export function formatComplianceRate(rate: number | null | undefined) {
  if (rate == null) return 'Chưa có dữ liệu';
  return `${rate.toFixed(2)}%`;
}

export function currentYearMonth() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}
