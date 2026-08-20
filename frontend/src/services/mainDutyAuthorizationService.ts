import { formatDateVi } from '../utils/dateFormat';
import api from './api';

export type MainDutyAuthorization = {
  id: number;
  employeeId: number;
  employeeCode?: string | null;
  employeeName: string;
  dateOfBirth?: string | null;
  positionTitle?: string | null;
  departmentName?: string | null;
  formType: 'DOCTOR' | 'NURSE';
  formTypeLabel: string;
  accompanyingFrom: string;
  accompanyingTo: string;
  accompanyingPeriod?: string | null;
  effectiveFrom: string;
  phone?: string | null;
  address?: string | null;
  gender?: string | null;
  degree?: string | null;
  reason?: string | null;
  status: string;
  requestedByUsername?: string | null;
  headReviewerUsername?: string | null;
  headComment?: string | null;
  headReviewedAt?: string | null;
  headSignatureUrl?: string | null;
  nursingHeadReviewerUsername?: string | null;
  nursingHeadComment?: string | null;
  nursingHeadReviewedAt?: string | null;
  nursingHeadSignatureUrl?: string | null;
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

export type CreateMainDutyAuthorizationPayload = {
  employeeId: number;
  accompanyingFrom: string;
  accompanyingTo: string;
  effectiveFrom: string;
  phone?: string;
  address?: string;
  gender?: string;
  degree?: string;
  reason?: string;
};

export const MAIN_DUTY_STATUS_LABEL: Record<string, string> = {
  PENDING_HEAD: 'Chờ Trưởng khoa duyệt',
  PENDING_NURSING_HEAD: 'Chờ Trưởng phòng Điều dưỡng',
  PENDING_HR: 'Chờ HCNS duyệt',
  PENDING_DIRECTOR: 'Chờ Giám đốc duyệt',
  HEAD_REJECTED: 'Trưởng khoa từ chối',
  NURSING_HEAD_REJECTED: 'Trưởng phòng Điều dưỡng từ chối',
  HR_REJECTED: 'HCNS từ chối',
  DIRECTOR_REJECTED: 'Giám đốc từ chối',
  APPROVED: 'Đã duyệt',
  CANCELLED: 'Đã hủy',
};

export function mainDutyStatusColor(
  status: string,
): 'default' | 'warning' | 'success' | 'error' | 'info' {
  if (
    status === 'PENDING_HEAD' ||
    status === 'PENDING_NURSING_HEAD' ||
    status === 'PENDING_HR' ||
    status === 'PENDING_DIRECTOR'
  ) {
    return 'warning';
  }
  if (status === 'APPROVED') return 'success';
  if (status.endsWith('REJECTED')) return 'error';
  return 'default';
}

export function formatMainDutyDate(iso?: string | null) {
  return formatDateVi(iso);
}

export async function createMainDutyAuthorization(body: CreateMainDutyAuthorizationPayload) {
  const { data } = await api.post<MainDutyAuthorization>('/v1/main-duty-authorizations', body);
  return data;
}

export async function fetchPendingHeadMainDutyAuthorizations() {
  const { data } = await api.get<MainDutyAuthorization[]>('/v1/main-duty-authorizations/pending-head');
  return data;
}

export async function fetchPendingNursingHeadMainDutyAuthorizations() {
  const { data } = await api.get<MainDutyAuthorization[]>(
    '/v1/main-duty-authorizations/pending-nursing-head',
  );
  return data;
}

export async function fetchPendingHrMainDutyAuthorizations() {
  const { data } = await api.get<MainDutyAuthorization[]>('/v1/main-duty-authorizations/pending-hr');
  return data;
}

export async function fetchPendingDirectorMainDutyAuthorizations() {
  const { data } = await api.get<MainDutyAuthorization[]>(
    '/v1/main-duty-authorizations/pending-director',
  );
  return data;
}

export async function fetchMainDutyAuthorizationHistory() {
  const { data } = await api.get<MainDutyAuthorization[]>('/v1/main-duty-authorizations/history');
  return data;
}

export async function fetchMyMainDutyAuthorizations() {
  const { data } = await api.get<MainDutyAuthorization[]>('/v1/main-duty-authorizations/mine');
  return data;
}

export async function fetchRelatedMainDutyAuthorizations() {
  const { data } = await api.get<MainDutyAuthorization[]>('/v1/main-duty-authorizations/related-to-me');
  return data;
}

export async function fetchMainDutyAuthorizationsByEmployee(employeeId: number) {
  const { data } = await api.get<MainDutyAuthorization[]>(
    `/v1/main-duty-authorizations/employee/${employeeId}`,
  );
  return data;
}

export async function fetchMainDutyAuthorizationDetail(id: number) {
  const { data } = await api.get<MainDutyAuthorization>(`/v1/main-duty-authorizations/${id}`);
  return data;
}

export async function headReviewMainDutyAuthorization(
  id: number,
  approved: boolean,
  comment?: string,
) {
  const { data } = await api.post<MainDutyAuthorization>(
    `/v1/main-duty-authorizations/${id}/head-review`,
    { approved, comment: comment || undefined },
  );
  return data;
}

export async function nursingHeadReviewMainDutyAuthorization(
  id: number,
  approved: boolean,
  comment?: string,
) {
  const { data } = await api.post<MainDutyAuthorization>(
    `/v1/main-duty-authorizations/${id}/nursing-head-review`,
    { approved, comment: comment || undefined },
  );
  return data;
}

export async function hrReviewMainDutyAuthorization(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<MainDutyAuthorization>(
    `/v1/main-duty-authorizations/${id}/hr-review`,
    { approved, comment: comment || undefined },
  );
  return data;
}

export async function directorReviewMainDutyAuthorization(
  id: number,
  approved: boolean,
  comment?: string,
) {
  const { data } = await api.post<MainDutyAuthorization>(
    `/v1/main-duty-authorizations/${id}/director-review`,
    { approved, comment: comment || undefined },
  );
  return data;
}

export async function updateMainDutyAuthorization(id: number, body: CreateMainDutyAuthorizationPayload) {
  const { data } = await api.put<MainDutyAuthorization>(`/v1/main-duty-authorizations/${id}`, body);
  return data;
}

export async function cancelMainDutyAuthorization(id: number) {
  const { data } = await api.post<MainDutyAuthorization>(
    `/v1/main-duty-authorizations/${id}/cancel`,
  );
  return data;
}
