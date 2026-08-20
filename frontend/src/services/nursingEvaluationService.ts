import api from './api';

/** Mẫu đồng bộ tiêu chí ĐD (Excel MA 2026). */
export const MA2026_EVAL_TEMPLATE_CODE = 'DD_KTV_HS_MA_2026';

export type CriterionOption = { label: string; points: number };
export type CriterionGroup = {
  id: string;
  section?: string;
  sectionPoints?: number;
  no?: string;
  title: string;
  maxPoints: number | null;
  options: CriterionOption[];
  bonus?: boolean;
  penalty?: boolean;
};

export type NursingTemplate = {
  code: string;
  name: string;
  version: number;
  baseMaxPoints?: number;
  note?: string;
  criteriaGroups: CriterionGroup[];
  gradingScale: Array<{ min: number; label: string; proposal: string }>;
};

export type NursingEvalRow = Record<string, unknown>;

export const NURSING_EVAL_STATUS_LABEL: Record<string, string> = {
  DRAFT: 'Nháp',
  PENDING_NURSING_HEAD: 'Chờ Trưởng phòng ĐD',
  NURSING_HEAD_REJECTED: 'Trưởng phòng ĐD từ chối',
  PENDING_HR: 'Chờ HCNS',
  HR_REJECTED: 'HCNS từ chối',
  PENDING_DIRECTOR: 'Chờ Giám đốc',
  DIRECTOR_REJECTED: 'Giám đốc từ chối',
  APPROVED: 'Đã duyệt',
  CANCELLED: 'Đã thu hồi',
};

export type NursingEvalStatusColor =
  | 'default'
  | 'primary'
  | 'secondary'
  | 'error'
  | 'info'
  | 'success'
  | 'warning';

export function nursingEvalStatusColor(status?: string | null): NursingEvalStatusColor {
  switch (status) {
    case 'APPROVED':
      return 'success';
    case 'PENDING_NURSING_HEAD':
    case 'PENDING_HR':
    case 'PENDING_DIRECTOR':
      return 'warning';
    case 'NURSING_HEAD_REJECTED':
    case 'HR_REJECTED':
    case 'DIRECTOR_REJECTED':
      return 'error';
    case 'DRAFT':
      return 'info';
    case 'CANCELLED':
      return 'default';
    default:
      return 'default';
  }
}

/** Bộ lọc trạng thái gộp theo bước — không tách chờ / từ chối. */
export const NURSING_EVAL_STATUS_FILTER_GROUPS: Array<{
  value: string;
  label: string;
  statuses: string[];
}> = [
  { value: 'DRAFT', label: 'Nháp', statuses: ['DRAFT'] },
  {
    value: 'NURSING_HEAD',
    label: 'Trưởng phòng ĐD',
    statuses: ['PENDING_NURSING_HEAD', 'NURSING_HEAD_REJECTED'],
  },
  {
    value: 'HR',
    label: 'HCNS',
    statuses: ['PENDING_HR', 'HR_REJECTED'],
  },
  {
    value: 'DIRECTOR',
    label: 'Giám đốc',
    statuses: ['PENDING_DIRECTOR', 'DIRECTOR_REJECTED'],
  },
  { value: 'APPROVED', label: 'Đã duyệt', statuses: ['APPROVED'] },
  { value: 'CANCELLED', label: 'Đã thu hồi', statuses: ['CANCELLED'] },
];

export const NURSING_EVAL_STATUS_FILTER_OPTIONS = NURSING_EVAL_STATUS_FILTER_GROUPS.map(
  ({ value, label }) => ({ value, label }),
);

export const NURSING_EVAL_ROSTER_STATUS_OPTIONS = [
  { value: 'NONE', label: 'Chưa có phiếu' },
  ...NURSING_EVAL_STATUS_FILTER_OPTIONS,
];

/** Map trạng thái chi tiết → nhóm lọc. */
export function nursingEvalStatusFilterGroup(status?: string | null): string {
  const raw = (status || '').trim() || 'NONE';
  if (raw === 'NONE') return 'NONE';
  for (const g of NURSING_EVAL_STATUS_FILTER_GROUPS) {
    if (g.statuses.includes(raw)) return g.value;
  }
  return raw;
}

/** Các nhóm lọc có mặt trong danh sách (theo status chi tiết). */
export function nursingEvalFilterOptionsPresent(statuses: Array<string | null | undefined>) {
  const present = new Set(
    statuses.map((s) => nursingEvalStatusFilterGroup(s || 'NONE')),
  );
  return NURSING_EVAL_STATUS_FILTER_OPTIONS.filter((o) => present.has(o.value));
}

export async function fetchNursingTemplate(code: string) {
  const { data } = await api.get<NursingTemplate>(`/v1/nursing-evaluations/templates/${code}`);
  return data;
}

export async function fetchNursingHistory(employeeId: number) {
  const { data } = await api.get<NursingEvalRow[]>(`/v1/nursing-evaluations/employees/${employeeId}`);
  return data;
}

export type NursingSubmitBody = {
  employeeId: number;
  periodYear: number;
  periodMonth: number;
  templateCode: string;
  scores: Record<string, number>;
  notes?: Record<string, string>;
  comments?: string;
  submitForReview: boolean;
};

export async function submitNursingEvaluation(body: NursingSubmitBody) {
  const { data } = await api.post<NursingEvalRow>('/v1/nursing-evaluations', body);
  return data;
}

export async function nursingHeadReviewNursingEvaluation(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<NursingEvalRow>(`/v1/nursing-evaluations/${id}/nursing-head-review`, {
    approved,
    comment,
  });
  return data;
}

export async function hrReviewNursingEvaluation(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<NursingEvalRow>(`/v1/nursing-evaluations/${id}/hr-review`, {
    approved,
    comment,
  });
  return data;
}

export async function directorReviewNursingEvaluation(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<NursingEvalRow>(`/v1/nursing-evaluations/${id}/director-review`, {
    approved,
    comment,
  });
  return data;
}

export async function cancelNursingEvaluation(id: number) {
  const { data } = await api.post<NursingEvalRow>(`/v1/nursing-evaluations/${id}/cancel`);
  return data;
}

export type MonthlyEvalSummaryRow = {
  evaluationId: number;
  employeeId: number;
  employeeCode?: string | null;
  fullName: string;
  departmentName: string;
  periodYear: number;
  periodMonth: number;
  status?: string | null;
  totalScore?: number | null;
  overallGrade?: string | null;
  total100?: number | null;
  totalTruongKhoa?: number | null;
  totalDdt?: number | null;
  gradeTruongKhoa?: string | null;
  gradeDdt?: string | null;
  deptAvg70?: number | null;
  hdTotal30?: number | null;
  hdGrade?: string | null;
  evaluatorUsername: string;
};

export async function fetchNursingMonthlySummary(year: number, month: number, templateCode: string) {
  const { data } = await api.get<MonthlyEvalSummaryRow[]>('/v1/nursing-evaluations/summary', {
    params: { year, month, templateCode },
  });
  return data;
}

export async function fetchNursingEvaluationRecord(evaluationId: number) {
  const { data } = await api.get<NursingEvalRow>(`/v1/nursing-evaluations/records/${evaluationId}`);
  return data;
}

/** Phiếu đã duyệt của chính tôi (sau khi Giám đốc duyệt). */
export async function fetchMyApprovedNursingEvaluations() {
  const { data } = await api.get<NursingEvalRow[]>('/v1/nursing-evaluations/mine');
  return data;
}

export async function fetchNursingPending() {
  const { data } = await api.get<NursingEvalRow[]>('/v1/nursing-evaluations/pending');
  return data;
}

export async function fetchNursingEvaluationHistory() {
  const { data } = await api.get<NursingEvalRow[]>('/v1/nursing-evaluations/history');
  return data;
}

export type NursingPeriodStatusRow = {
  employeeId: number;
  evaluationId?: number;
  status?: string | null;
  totalScore?: number | null;
  overallGrade?: string | null;
};

export async function fetchNursingPeriodStatus(year: number, month: number, templateCode: string) {
  const { data } = await api.get<NursingPeriodStatusRow[]>('/v1/nursing-evaluations/period-status', {
    params: { year, month, templateCode },
  });
  return data;
}

export function scorePointsFromRow(scores: unknown, criterionId: string): number | null {
  if (!scores || typeof scores !== 'object') return null;
  const part = (scores as Record<string, Record<string, unknown>>)[criterionId];
  if (!part || typeof part !== 'object') return null;
  const p = part.points ?? part.truongKhoa ?? part.ddt;
  if (p == null || p === '') return null;
  const n = Number(p);
  return Number.isFinite(n) ? n : null;
}
