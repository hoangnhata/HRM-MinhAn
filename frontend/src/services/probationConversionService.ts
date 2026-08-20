import { formatDateTimeVi, formatDateVi } from '../utils/dateFormat';
import api from './api';

export type ProbationFormType = 'DOCTOR' | 'NURSE' | 'STAFF';

export type ProbationCriterion = {
  code: string;
  label: string;
  maxScore: number;
  detail: string;
};

export type ProbationFormTypeInfo = {
  employeeId: number;
  employeeName: string;
  positionTitle?: string | null;
  formType: ProbationFormType;
  formTypeLabel: string;
  requiresScoring: boolean;
  maxScore?: number | null;
  criteria: ProbationCriterion[];
};

export type ProbationConversion = {
  id: number;
  employeeId: number;
  employeeCode?: string | null;
  employeeName: string;
  employeeStatus?: string | null;
  positionTitle?: string | null;
  departmentId?: number | null;
  departmentName?: string | null;
  officialDate: string;
  reason: string;
  formType?: ProbationFormType;
  formTypeLabel?: string;
  requiresScoring?: boolean;
  mentorComment?: string | null;
  headDeptComment?: string | null;
  wardNurseHeadComment?: string | null;
  hospitalNurseHeadComment?: string | null;
  scoresJson?: string | null;
  totalScore?: number | null;
  maxScore?: number | null;
  gradeLabel?: string | null;
  hrDocsComplete?: string | null;
  hrDocsNote?: string | null;
  hrTrainingJoined?: string | null;
  hrRuleCompliance?: string | null;
  hrDeptFeedback?: string | null;
  hrProposal?: string | null;
  status: string;
  requestedByUsername?: string | null;
  hrReviewerUsername?: string | null;
  hrComment?: string | null;
  hrReviewedAt?: string | null;
  hrSignatureUrl?: string | null;
  nursingHeadReviewerUsername?: string | null;
  nursingHeadComment?: string | null;
  nursingHeadReviewedAt?: string | null;
  nursingHeadSignatureUrl?: string | null;
  directorReviewerUsername?: string | null;
  directorComment?: string | null;
  directorReviewedAt?: string | null;
  directorSignatureUrl?: string | null;
  appliedAt?: string | null;
  createdAt?: string | null;
};

export type CreateConversionPayload = {
  employeeId: number;
  officialDate: string;
  reason: string;
  formType?: ProbationFormType;
  mentorComment?: string;
  headDeptComment?: string;
  wardNurseHeadComment?: string;
  hospitalNurseHeadComment?: string;
  scores?: Record<string, number>;
};

export type HrReviewPayload = {
  approved: boolean;
  comment?: string;
};

export const CONVERSION_STATUS_LABEL: Record<string, string> = {
  PENDING_NURSING_HEAD: 'Chờ Trưởng phòng Điều dưỡng',
  NURSING_HEAD_REJECTED: 'Trưởng phòng Điều dưỡng từ chối',
  PENDING_HR: 'Chờ HCNS duyệt',
  PENDING_DIRECTOR: 'Chờ Giám đốc duyệt',
  HR_REJECTED: 'HCNS từ chối',
  HR_EXTEND_PROBATION: 'HCNS đề xuất gia hạn thử việc',
  HR_STOP_COOPERATION: 'HCNS đề xuất ngừng hợp tác',
  DIRECTOR_REJECTED: 'Giám đốc từ chối',
  APPROVED: 'Đã duyệt — chờ ngày lên chính thức',
  APPLIED: 'Đã lên chính thức',
  CANCELLED: 'Đã hủy',
};

export const FORM_TYPE_LABEL: Record<ProbationFormType, string> = {
  DOCTOR: 'Bác sĩ',
  NURSE: 'Điều dưỡng',
  STAFF: 'Nhân viên',
};

export const HR_PROPOSAL_LABEL: Record<string, string> = {
  KY_HD: 'Ký HĐ chính thức',
  GIA_HAN: 'Gia hạn thử việc',
  NGUNG: 'Ngừng hợp tác',
};

export function conversionStatusColor(
  status: string,
): 'default' | 'warning' | 'success' | 'error' | 'info' {
  if (status === 'PENDING_NURSING_HEAD' || status === 'PENDING_HR' || status === 'PENDING_DIRECTOR')
    return 'warning';
  if (status === 'APPROVED') return 'info';
  if (status === 'APPLIED') return 'success';
  if (
    status === 'HR_REJECTED' ||
    status === 'NURSING_HEAD_REJECTED' ||
    status === 'DIRECTOR_REJECTED' ||
    status === 'CANCELLED' ||
    status === 'HR_STOP_COOPERATION'
  ) {
    return 'error';
  }
  if (status === 'HR_EXTEND_PROBATION') return 'info';
  return 'default';
}

export function formatConversionDate(iso?: string | null) {
  return formatDateVi(iso);
}

export function formatConversionDateTime(iso?: string | null) {
  return formatDateTimeVi(iso);
}

export function parseScoresJson(raw?: string | null): Record<string, number> {
  if (!raw) return {};
  try {
    const obj = JSON.parse(raw) as Record<string, unknown>;
    const out: Record<string, number> = {};
    for (const [k, v] of Object.entries(obj)) {
      if (typeof v === 'number') out[k] = v;
    }
    return out;
  } catch {
    return {};
  }
}

export async function fetchConversionFormType(employeeId: number) {
  const { data } = await api.get<ProbationFormTypeInfo>(
    `/v1/probation-conversions/form-type/${employeeId}`,
  );
  return data;
}

export async function createConversion(body: CreateConversionPayload) {
  const { data } = await api.post<ProbationConversion>('/v1/probation-conversions', body);
  return data;
}

export async function fetchPendingNursingHeadConversions() {
  const { data } = await api.get<ProbationConversion[]>(
    '/v1/probation-conversions/pending-nursing-head',
  );
  return data;
}

export async function fetchPendingHrConversions() {
  const { data } = await api.get<ProbationConversion[]>('/v1/probation-conversions/pending-hr');
  return data;
}

export async function fetchPendingDirectorConversions() {
  const { data } = await api.get<ProbationConversion[]>('/v1/probation-conversions/pending-director');
  return data;
}

export async function fetchConversionHistory() {
  const { data } = await api.get<ProbationConversion[]>('/v1/probation-conversions/history');
  return data;
}

export async function fetchMyConversions() {
  const { data } = await api.get<ProbationConversion[]>('/v1/probation-conversions/mine');
  return data;
}

export async function fetchRelatedConversions() {
  const { data } = await api.get<ProbationConversion[]>('/v1/probation-conversions/related-to-me');
  return data;
}

export async function fetchConversionDetail(id: number) {
  const { data } = await api.get<ProbationConversion>(`/v1/probation-conversions/${id}`);
  return data;
}

export async function nursingHeadReviewConversion(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<ProbationConversion>(
    `/v1/probation-conversions/${id}/nursing-head-review`,
    { approved, comment: comment || undefined },
  );
  return data;
}

export async function hrReviewConversion(id: number, payload: HrReviewPayload) {
  const { data } = await api.post<ProbationConversion>(
    `/v1/probation-conversions/${id}/hr-review`,
    payload,
  );
  return data;
}

export async function directorReviewConversion(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<ProbationConversion>(
    `/v1/probation-conversions/${id}/director-review`,
    {
      approved,
      comment: comment || undefined,
    },
  );
  return data;
}

export async function updateConversion(id: number, body: CreateConversionPayload) {
  const { data } = await api.put<ProbationConversion>(`/v1/probation-conversions/${id}`, body);
  return data;
}

export async function cancelConversion(id: number) {
  const { data } = await api.post<ProbationConversion>(`/v1/probation-conversions/${id}/cancel`);
  return data;
}
