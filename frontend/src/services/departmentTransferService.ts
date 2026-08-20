import { formatDateTimeVi, formatDateVi } from '../utils/dateFormat';
import api from './api';

export type DepartmentTransfer = {
  id: number;
  employeeId: number;
  employeeCode?: string | null;
  employeeName: string;
  positionTitle?: string | null;
  fromDepartmentId: number;
  fromDepartmentName: string;
  toDepartmentId: number;
  toDepartmentName: string;
  toPositionId?: number | null;
  toPositionTitle?: string | null;
  effectiveDate: string;
  reason: string;
  status: string;
  requestedByUsername?: string | null;
  directorReviewerUsername?: string | null;
  directorComment?: string | null;
  directorReviewedAt?: string | null;
  directorSignatureUrl?: string | null;
  appliedAt?: string | null;
  createdAt?: string | null;
};

export const TRANSFER_STATUS_LABEL: Record<string, string> = {
  PENDING_DIRECTOR: 'Chờ Giám đốc duyệt',
  REJECTED: 'Từ chối',
  APPROVED: 'Đã duyệt — chờ ngày hiệu lực',
  APPLIED: 'Đã chuyển phòng ban',
  CANCELLED: 'Đã hủy',
};

export function transferStatusColor(
  status: string,
): 'default' | 'warning' | 'success' | 'error' | 'info' {
  if (status === 'PENDING_DIRECTOR') return 'warning';
  if (status === 'APPROVED') return 'info';
  if (status === 'APPLIED') return 'success';
  if (status === 'REJECTED' || status === 'CANCELLED') return 'error';
  return 'default';
}

export function formatTransferDate(iso?: string | null) {
  return formatDateVi(iso);
}

export function formatTransferDateTime(iso?: string | null) {
  return formatDateTimeVi(iso);
}

export async function createTransfer(body: {
  employeeId: number;
  toDepartmentId: number;
  toPositionId?: number | null;
  effectiveDate: string;
  reason: string;
}) {
  const { data } = await api.post<DepartmentTransfer>('/v1/department-transfers', body);
  return data;
}

export async function fetchPendingTransfers() {
  const { data } = await api.get<DepartmentTransfer[]>('/v1/department-transfers/pending');
  return data;
}

export async function fetchTransferHistory() {
  const { data } = await api.get<DepartmentTransfer[]>('/v1/department-transfers/history');
  return data;
}

export async function fetchRelatedTransfers() {
  const { data } = await api.get<DepartmentTransfer[]>('/v1/department-transfers/related-to-me');
  return data;
}

export async function fetchTransferDetail(id: number) {
  const { data } = await api.get<DepartmentTransfer>(`/v1/department-transfers/${id}`);
  return data;
}

export async function directorReviewTransfer(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<DepartmentTransfer>(`/v1/department-transfers/${id}/director-review`, {
    approved,
    comment: comment || undefined,
  });
  return data;
}

export async function updateTransfer(id: number, body: {
  employeeId: number;
  toDepartmentId: number;
  toPositionId?: number;
  effectiveDate: string;
  reason: string;
}) {
  const { data } = await api.put<DepartmentTransfer>(`/v1/department-transfers/${id}`, body);
  return data;
}

export async function cancelTransfer(id: number) {
  const { data } = await api.post<DepartmentTransfer>(`/v1/department-transfers/${id}/cancel`);
  return data;
}
