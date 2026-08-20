import api from './api';

export type YoungChildRequest = {
  id: number;
  employeeId: number;
  employeeCode?: string | null;
  employeeName: string;
  positionTitle?: string | null;
  departmentName?: string | null;
  startDate: string;
  endDate: string;
  /** Dữ liệu cũ để tương thích các đơn trước migration. */
  year: number;
  month: number;
  enabled: boolean;
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

export const YOUNG_CHILD_STATUS_LABEL: Record<string, string> = {
  PENDING_HR: 'Chờ HCNS duyệt',
  APPROVED: 'Đã duyệt',
  REJECTED: 'Từ chối',
  CANCELLED: 'Đã hủy',
};

export async function createYoungChildRequest(body: {
  employeeId: number;
  startDate: string;
  endDate: string;
  enabled: boolean;
  reason?: string;
}) {
  const { data } = await api.post<YoungChildRequest>('/v1/young-child-requests', body);
  return data;
}

export async function fetchPendingYoungChildRequests() {
  const { data } = await api.get<YoungChildRequest[]>('/v1/young-child-requests/pending');
  return data;
}

export async function fetchYoungChildRequestHistory() {
  const { data } = await api.get<YoungChildRequest[]>('/v1/young-child-requests/history');
  return data;
}

export async function fetchMyYoungChildRequests() {
  const { data } = await api.get<YoungChildRequest[]>('/v1/young-child-requests/mine');
  return data;
}

export async function fetchRelatedYoungChildRequests() {
  const { data } = await api.get<YoungChildRequest[]>('/v1/young-child-requests/related-to-me');
  return data;
}

export async function fetchPendingYoungChildForEmployee(employeeId: number, fromDate: string, toDate: string) {
  const { data } = await api.get<YoungChildRequest | null>(
    `/v1/young-child-requests/employee/${employeeId}/pending`,
    { params: { fromDate, toDate } },
  );
  return data;
}

export async function fetchYoungChildRequestDetail(id: number) {
  const { data } = await api.get<YoungChildRequest>(`/v1/young-child-requests/${id}`);
  return data;
}

export async function hrReviewYoungChildRequest(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<YoungChildRequest>(`/v1/young-child-requests/${id}/hr-review`, {
    approved,
    comment: comment || undefined,
  });
  return data;
}

export async function updateYoungChildRequest(id: number, body: {
  employeeId: number;
  startDate: string;
  endDate: string;
  enabled: boolean;
  reason?: string;
}) {
  const { data } = await api.put<YoungChildRequest>(`/v1/young-child-requests/${id}`, body);
  return data;
}

export async function cancelYoungChildRequest(id: number) {
  const { data } = await api.post<YoungChildRequest>(`/v1/young-child-requests/${id}/cancel`);
  return data;
}

export async function revokeYoungChildRequest(id: number) {
  await api.delete(`/v1/young-child-requests/${id}`);
}
