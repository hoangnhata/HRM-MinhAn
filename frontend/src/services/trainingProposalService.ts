import { formatDateTimeVi, formatDateVi } from '../utils/dateFormat';
import api from './api';

export type TrainingProposal = {
  id: number;
  employeeId: number;
  employeeCode?: string | null;
  employeeName: string;
  dateOfBirth?: string | null;
  positionTitle?: string | null;
  departmentName?: string | null;
  proposingDepartment: string;
  courseName: string;
  location: string;
  plannedPeriod: string;
  tuitionFee?: string | null;
  monthlySupport?: string | null;
  postCourseCommitment?: string | null;
  trainingGoal: string;
  reason: string;
  employeeCommitmentAck?: boolean;
  departmentCommitmentAck?: boolean;
  status: string;
  requestedByUsername?: string | null;
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

export type CreateTrainingProposalPayload = {
  employeeId: number;
  proposingDepartment: string;
  courseName: string;
  location: string;
  plannedPeriod: string;
  tuitionFee?: string;
  trainingGoal: string;
  reason: string;
  employeeCommitmentAck: boolean;
  departmentCommitmentAck: boolean;
};

export const TRAINING_STATUS_LABEL: Record<string, string> = {
  PENDING_HR: 'Chờ HCNS duyệt',
  PENDING_DIRECTOR: 'Chờ Giám đốc duyệt',
  HR_REJECTED: 'HCNS từ chối',
  DIRECTOR_REJECTED: 'Giám đốc từ chối',
  APPROVED: 'Đã duyệt',
  COMPLETED: 'Đã hoàn thành',
  CANCELLED: 'Đã hủy',
};

export function trainingStatusColor(
  status: string,
): 'default' | 'warning' | 'success' | 'error' | 'info' {
  if (status === 'PENDING_HR' || status === 'PENDING_DIRECTOR') return 'warning';
  if (status === 'APPROVED' || status === 'COMPLETED') return 'success';
  if (status === 'HR_REJECTED' || status === 'DIRECTOR_REJECTED' || status === 'CANCELLED') {
    return 'error';
  }
  return 'default';
}

export function formatTrainingDate(iso?: string | null) {
  return formatDateVi(iso);
}

export function formatTrainingDateTime(iso?: string | null) {
  return formatDateTimeVi(iso);
}

export async function updateTrainingProposal(id: number, body: CreateTrainingProposalPayload) {
  const { data } = await api.put<TrainingProposal>(`/v1/training-proposals/${id}`, body);
  return data;
}

export async function createTrainingProposal(body: CreateTrainingProposalPayload) {
  const { data } = await api.post<TrainingProposal>('/v1/training-proposals', body);
  return data;
}

export async function fetchPendingHrTrainingProposals() {
  const { data } = await api.get<TrainingProposal[]>('/v1/training-proposals/pending-hr');
  return data;
}

export async function fetchPendingDirectorTrainingProposals() {
  const { data } = await api.get<TrainingProposal[]>('/v1/training-proposals/pending-director');
  return data;
}

export async function fetchTrainingProposalHistory() {
  const { data } = await api.get<TrainingProposal[]>('/v1/training-proposals/history');
  return data;
}

export async function fetchMyTrainingProposals() {
  const { data } = await api.get<TrainingProposal[]>('/v1/training-proposals/mine');
  return data;
}

export async function fetchTrainingProposalsByEmployee(employeeId: number) {
  const { data } = await api.get<TrainingProposal[]>(`/v1/training-proposals/employee/${employeeId}`);
  return data;
}

export async function fetchRelatedTrainingProposals() {
  const { data } = await api.get<TrainingProposal[]>('/v1/training-proposals/related-to-me');
  return data;
}

export async function fetchTrainingProposalDetail(id: number) {
  const { data } = await api.get<TrainingProposal>(`/v1/training-proposals/${id}`);
  return data;
}

export async function hrReviewTrainingProposal(
  id: number,
  approved: boolean,
  comment?: string,
  monthlySupport?: string,
  postCourseCommitment?: string,
) {
  const { data } = await api.post<TrainingProposal>(`/v1/training-proposals/${id}/hr-review`, {
    approved,
    comment: comment || undefined,
    monthlySupport: approved ? monthlySupport?.trim() || undefined : undefined,
    postCourseCommitment: approved ? postCourseCommitment?.trim() || undefined : undefined,
  });
  return data;
}

export async function directorReviewTrainingProposal(
  id: number,
  approved: boolean,
  comment?: string,
) {
  const { data } = await api.post<TrainingProposal>(`/v1/training-proposals/${id}/director-review`, {
    approved,
    comment: comment || undefined,
  });
  return data;
}

export async function cancelTrainingProposal(id: number) {
  const { data } = await api.post<TrainingProposal>(`/v1/training-proposals/${id}/cancel`);
  return data;
}

export async function completeTrainingProposal(id: number) {
  const { data } = await api.post<TrainingProposal>(`/v1/training-proposals/${id}/complete`);
  return data;
}
