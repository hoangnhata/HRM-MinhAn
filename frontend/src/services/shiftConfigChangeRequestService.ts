import api from './api';

export type ShiftConfigChangeRequest = {
  id: number;
  employeeId: number;
  employeeCode?: string | null;
  employeeName: string;
  positionTitle?: string | null;
  departmentName?: string | null;
  season: 'SUMMER' | 'WINTER' | 'BOTH';
  seasonLabel?: string;
  morningStart: string;
  morningEnd: string;
  afternoonStart: string;
  afternoonEnd: string;
  winterMorningStart?: string | null;
  winterMorningEnd?: string | null;
  winterAfternoonStart?: string | null;
  winterAfternoonEnd?: string | null;
  morningUnits: number;
  afternoonUnits: number;
  reason?: string | null;
  status: string;
  requestedByUsername?: string | null;
  hrReviewerUsername?: string | null;
  hrComment?: string | null;
  hrReviewedAt?: string | null;
  hrSignatureUrl?: string | null;
  createdAt?: string | null;
  recalculated?: number;
  recalculateWarning?: string;
};

export const SHIFT_CONFIG_CHANGE_STATUS_LABEL: Record<string, string> = {
  PENDING_HR: 'Chờ HCNS duyệt',
  APPROVED: 'Đã duyệt',
  REJECTED: 'Từ chối',
  CANCELLED: 'Đã hủy',
};

export async function createShiftConfigChangeRequest(body: {
  employeeId: number;
  season: 'SUMMER' | 'WINTER' | 'BOTH';
  morningStart: string;
  morningEnd: string;
  afternoonStart: string;
  afternoonEnd: string;
  winterMorningStart?: string;
  winterMorningEnd?: string;
  winterAfternoonStart?: string;
  winterAfternoonEnd?: string;
  morningUnits?: number;
  afternoonUnits?: number;
  reason?: string;
}) {
  const { data } = await api.post<ShiftConfigChangeRequest>('/v1/shift-config-change-requests', body);
  return data;
}

export async function fetchPendingShiftConfigChangeRequests() {
  const { data } = await api.get<ShiftConfigChangeRequest[]>('/v1/shift-config-change-requests/pending');
  return data;
}

export async function fetchShiftConfigChangeRequestHistory() {
  const { data } = await api.get<ShiftConfigChangeRequest[]>('/v1/shift-config-change-requests/history');
  return data;
}

export async function fetchMyShiftConfigChangeRequests() {
  const { data } = await api.get<ShiftConfigChangeRequest[]>('/v1/shift-config-change-requests/mine');
  return data;
}

export async function fetchRelatedShiftConfigChangeRequests() {
  const { data } = await api.get<ShiftConfigChangeRequest[]>(
    '/v1/shift-config-change-requests/related-to-me',
  );
  return data;
}

export async function fetchShiftConfigChangeRequestDetail(id: number) {
  const { data } = await api.get<ShiftConfigChangeRequest>(`/v1/shift-config-change-requests/${id}`);
  return data;
}

export async function hrReviewShiftConfigChangeRequest(
  id: number,
  approved: boolean,
  comment?: string,
) {
  const { data } = await api.post<ShiftConfigChangeRequest>(
    `/v1/shift-config-change-requests/${id}/hr-review`,
    { approved, comment: comment || undefined },
  );
  return data;
}

export async function updateShiftConfigChangeRequest(id: number, body: Record<string, unknown>) {
  const { data } = await api.put<ShiftConfigChangeRequest>(
    `/v1/shift-config-change-requests/${id}`,
    body,
  );
  return data;
}

export async function cancelShiftConfigChangeRequest(id: number) {
  const { data } = await api.post<ShiftConfigChangeRequest>(
    `/v1/shift-config-change-requests/${id}/cancel`,
  );
  return data;
}

export async function revokeShiftConfigChangeRequest(id: number) {
  await api.delete(`/v1/shift-config-change-requests/${id}`);
}

export function formatShiftTimeRange(start?: string | null, end?: string | null) {
  const s = String(start || '').slice(0, 5);
  const e = String(end || '').slice(0, 5);
  if (!s && !e) return '—';
  return `${s || '—'} – ${e || '—'}`;
}

export function formatShiftConfigSummary(r: ShiftConfigChangeRequest) {
  const summer = `Hè: sáng ${formatShiftTimeRange(r.morningStart, r.morningEnd)} · chiều ${formatShiftTimeRange(r.afternoonStart, r.afternoonEnd)}`;
  if (r.season === 'BOTH') {
    return `${summer} · Đông: sáng ${formatShiftTimeRange(r.winterMorningStart, r.winterMorningEnd)} · chiều ${formatShiftTimeRange(r.winterAfternoonStart, r.winterAfternoonEnd)}`;
  }
  if (r.season === 'WINTER') {
    return `Đông: sáng ${formatShiftTimeRange(r.morningStart, r.morningEnd)} · chiều ${formatShiftTimeRange(r.afternoonStart, r.afternoonEnd)}`;
  }
  return summer;
}
