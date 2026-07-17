import api from './api';

export type ProbationConversion = {
  id: number;
  employeeId: number;
  employeeCode?: string | null;
  employeeName: string;
  employeeStatus?: string | null;
  departmentId?: number | null;
  departmentName?: string | null;
  officialDate: string;
  reason: string;
  status: string;
  requestedByUsername?: string | null;
  hrReviewerUsername?: string | null;
  hrComment?: string | null;
  hrReviewedAt?: string | null;
  directorReviewerUsername?: string | null;
  directorComment?: string | null;
  directorReviewedAt?: string | null;
  appliedAt?: string | null;
  createdAt?: string | null;
};

export const CONVERSION_STATUS_LABEL: Record<string, string> = {
  PENDING_HR: 'Chờ HCNS duyệt',
  PENDING_DIRECTOR: 'Chờ Giám đốc duyệt',
  HR_REJECTED: 'HCNS từ chối',
  DIRECTOR_REJECTED: 'Giám đốc từ chối',
  APPROVED: 'Đã duyệt — chờ ngày lên chính thức',
  APPLIED: 'Đã lên chính thức',
  CANCELLED: 'Đã hủy',
};

export function conversionStatusColor(
  status: string,
): 'default' | 'warning' | 'success' | 'error' | 'info' {
  if (status === 'PENDING_HR' || status === 'PENDING_DIRECTOR') return 'warning';
  if (status === 'APPROVED') return 'info';
  if (status === 'APPLIED') return 'success';
  if (status === 'HR_REJECTED' || status === 'DIRECTOR_REJECTED' || status === 'CANCELLED') return 'error';
  return 'default';
}

export function formatConversionDate(iso?: string | null) {
  if (!iso) return '—';
  const d = iso.slice(0, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(d)) {
    return d.split('-').reverse().join('/');
  }
  return iso;
}

export function formatConversionDateTime(iso?: string | null) {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('vi-VN');
  } catch {
    return iso;
  }
}

export async function createConversion(body: {
  employeeId: number;
  officialDate: string;
  reason: string;
}) {
  const { data } = await api.post<ProbationConversion>('/v1/probation-conversions', body);
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

export async function fetchConversionDetail(id: number) {
  const { data } = await api.get<ProbationConversion>(`/v1/probation-conversions/${id}`);
  return data;
}

export async function hrReviewConversion(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<ProbationConversion>(`/v1/probation-conversions/${id}/hr-review`, {
    approved,
    comment: comment || undefined,
  });
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

export async function cancelConversion(id: number) {
  const { data } = await api.post<ProbationConversion>(`/v1/probation-conversions/${id}/cancel`);
  return data;
}
