import { formatDateTimeVi, formatDateVi } from '../utils/dateFormat';
import api from './api';

export type SeminarProposal = {
  id: number;
  employeeId: number;
  employeeCode?: string | null;
  employeeName: string;
  dateOfBirth?: string | null;
  positionTitle?: string | null;
  departmentName?: string | null;
  proposingDepartment: string;
  seminarName: string;
  location: string;
  startDate: string;
  endDate: string;
  attendanceScope: 'MORNING' | 'AFTERNOON' | 'FULL_DAY';
  plannedPeriod?: string | null;
  reason: string;
  employeeCommitmentAck?: boolean;
  departmentCommitmentAck?: boolean;
  status: string;
  withPay?: boolean | null;
  supportAmount?: string | null;
  requestedByUsername?: string | null;
  requesterSignatureUrl?: string | null;
  attachments?: SeminarAttachment[];
  hrReviewerUsername?: string | null;
  hrComment?: string | null;
  hrReviewedAt?: string | null;
  hrSignatureUrl?: string | null;
  directorReviewerUsername?: string | null;
  directorComment?: string | null;
  directorReviewedAt?: string | null;
  directorSignatureUrl?: string | null;
  createdAt?: string | null;
};

export type SeminarAttachment = {
  id: number;
  originalName: string;
  contentType?: string | null;
  fileSize?: number | null;
  url: string;
};

export type CreateSeminarProposalPayload = {
  employeeId: number;
  proposingDepartment: string;
  seminarName: string;
  location: string;
  startDate: string;
  endDate: string;
  attendanceScope: 'MORNING' | 'AFTERNOON' | 'FULL_DAY';
  reason: string;
  employeeCommitmentAck: boolean;
  departmentCommitmentAck: boolean;
};

export const SEMINAR_STATUS_LABEL: Record<string, string> = {
  PENDING_HR: 'Chờ HCNS duyệt',
  PENDING_DIRECTOR: 'Chờ Giám đốc duyệt',
  HR_REJECTED: 'HCNS từ chối',
  DIRECTOR_REJECTED: 'Giám đốc từ chối',
  APPROVED: 'Đã duyệt',
  COMPLETED: 'Đã hoàn thành',
  CANCELLED: 'Đã hủy',
};

export function seminarStatusColor(
  status: string,
): 'default' | 'warning' | 'success' | 'error' | 'info' {
  if (status === 'PENDING_HR' || status === 'PENDING_DIRECTOR') return 'warning';
  if (status === 'APPROVED' || status === 'COMPLETED') return 'success';
  if (status === 'HR_REJECTED' || status === 'DIRECTOR_REJECTED') return 'error';
  return 'default';
}

export function formatSeminarDate(iso?: string | null) {
  return formatDateVi(iso);
}

export function formatSeminarDateTime(iso?: string | null) {
  return formatDateTimeVi(iso);
}

export function seminarScopeLabel(scope?: string | null) {
  if (scope === 'MORNING') return 'Buổi sáng';
  if (scope === 'AFTERNOON') return 'Buổi chiều';
  return 'Cả ngày';
}

const SEMINAR_BLOCKING_STATUSES = new Set(['PENDING_HR', 'PENDING_DIRECTOR', 'APPROVED']);

export function dateRangesOverlap(fromA: string, toA: string, fromB: string, toB: string) {
  return fromA <= toB && toA >= fromB;
}

export function findSeminarDateOverlap(
  proposals: SeminarProposal[],
  startDate: string,
  endDate: string,
  excludeId?: number,
) {
  return proposals.find(
    (p) =>
      p.id !== excludeId
      && SEMINAR_BLOCKING_STATUSES.has(p.status)
      && dateRangesOverlap(startDate, endDate, p.startDate, p.endDate),
  );
}

function seminarFormData(body: CreateSeminarProposalPayload, files: File[]) {
  const form = new FormData();
  form.append('request', new Blob([JSON.stringify(body)], { type: 'application/json' }));
  for (const file of files) form.append('files', file);
  return form;
}

const multipartConfig = {
  headers: { 'Content-Type': undefined as unknown as string },
};

export async function updateSeminarProposal(
  id: number,
  body: CreateSeminarProposalPayload,
  files: File[] = [],
) {
  if (files.length === 0) {
    const { data } = await api.put<SeminarProposal>(`/v1/seminar-proposals/${id}`, body);
    return data;
  }
  const { data } = await api.put<SeminarProposal>(
    `/v1/seminar-proposals/${id}`,
    seminarFormData(body, files),
    multipartConfig,
  );
  return data;
}

export async function createSeminarProposal(body: CreateSeminarProposalPayload, files: File[] = []) {
  if (files.length === 0) {
    const { data } = await api.post<SeminarProposal>('/v1/seminar-proposals', body);
    return data;
  }
  const { data } = await api.post<SeminarProposal>(
    '/v1/seminar-proposals',
    seminarFormData(body, files),
    multipartConfig,
  );
  return data;
}

export async function deleteSeminarAttachment(proposalId: number, attachmentId: number) {
  await api.delete(`/v1/seminar-proposals/${proposalId}/attachments/${attachmentId}`);
}

export function seminarAttachmentApiPath(url: string) {
  const u = url.trim();
  if (u.startsWith('/j1-api')) return u.slice('/j1-api'.length) || '/';
  return u.startsWith('/') ? u : `/${u}`;
}

export async function openSeminarAttachment(attachment: SeminarAttachment) {
  const { data } = await api.get<Blob>(seminarAttachmentApiPath(attachment.url), {
    responseType: 'blob',
  });
  const objectUrl = URL.createObjectURL(data);
  const image = (attachment.contentType || '').startsWith('image/');
  const pdf = attachment.contentType === 'application/pdf';
  if (image || pdf) {
    window.open(objectUrl, '_blank', 'noopener');
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    return;
  }
  const link = document.createElement('a');
  link.href = objectUrl;
  link.download = attachment.originalName || 'cong-van';
  link.click();
  window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
}

export function formatAttachmentSize(bytes?: number | null) {
  if (bytes == null || bytes < 0) return '';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export async function fetchPendingHrSeminarProposals() {
  const { data } = await api.get<SeminarProposal[]>('/v1/seminar-proposals/pending-hr');
  return data;
}

export async function fetchPendingDirectorSeminarProposals() {
  const { data } = await api.get<SeminarProposal[]>('/v1/seminar-proposals/pending-director');
  return data;
}

export async function fetchSeminarProposalHistory(opts?: { fromDate?: string; toDate?: string }) {
  const { data } = await api.get<SeminarProposal[]>('/v1/seminar-proposals/history', {
    params: {
      fromDate: opts?.fromDate || undefined,
      toDate: opts?.toDate || undefined,
    },
  });
  return data;
}

export async function fetchMySeminarProposals() {
  const { data } = await api.get<SeminarProposal[]>('/v1/seminar-proposals/mine');
  return data;
}

export async function fetchSeminarProposalsByEmployee(employeeId: number) {
  const { data } = await api.get<SeminarProposal[]>(`/v1/seminar-proposals/employee/${employeeId}`);
  return data;
}

export async function fetchRelatedSeminarProposals() {
  const { data } = await api.get<SeminarProposal[]>('/v1/seminar-proposals/related-to-me');
  return data;
}

export async function fetchSeminarProposalDetail(id: number) {
  const { data } = await api.get<SeminarProposal>(`/v1/seminar-proposals/${id}`);
  return data;
}

export async function hrReviewSeminarProposal(
  id: number,
  approved: boolean,
  withPay?: boolean,
  comment?: string,
) {
  const { data } = await api.post<SeminarProposal>(`/v1/seminar-proposals/${id}/hr-review`, {
    approved,
    withPay: approved ? withPay : undefined,
    comment: comment || undefined,
  });
  return data;
}

export async function directorReviewSeminarProposal(
  id: number,
  approved: boolean,
  withPay?: boolean,
  supportAmount?: string,
  comment?: string,
) {
  const { data } = await api.post<SeminarProposal>(`/v1/seminar-proposals/${id}/director-review`, {
    approved,
    withPay: approved ? withPay : undefined,
    supportAmount: approved && supportAmount?.trim() ? supportAmount.trim() : undefined,
    comment: comment || undefined,
  });
  return data;
}

export async function cancelSeminarProposal(id: number) {
  const { data } = await api.post<SeminarProposal>(`/v1/seminar-proposals/${id}/cancel`);
  return data;
}
