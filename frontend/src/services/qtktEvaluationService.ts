import api from './api';

export type QtktStep = {
  id: string;
  no: number;
  /** Ý chính (hiển thị khi thu gọn) */
  title: string;
  /** Nội dung đầy đủ theo phiếu QTKT (mở rộng khi cần) */
  detail?: string;
  maxPoints: number;
  /** Tiêu chí bắt buộc đủ điểm (GDSK 12–14) */
  required?: boolean;
};

export type QtktSection = {
  id: string;
  title: string;
  steps: QtktStep[];
};

export type QtktCheckOption = {
  code: string;
  label: string;
};

export type QtktCheckOptions = {
  label: string;
  hint?: string;
  options: QtktCheckOption[];
};

export type QtktProcedure = {
  code: string;
  name: string;
  durationMinutes: number;
  maxTotal: number;
  note?: string;
  requiresPatientCode?: boolean;
  passMinScore?: number;
  requiredFullStepIds?: string[];
  allowedDepartmentKeys?: string[];
  checkOptions?: QtktCheckOptions;
  sections: QtktSection[];
};

export type QtktTemplate = {
  version: number;
  name: string;
  note?: string;
  procedures: QtktProcedure[];
};

export type QtktEmployee = {
  id: number;
  fullName: string;
  employeeCode?: string | null;
  departmentId?: number | null;
  departmentName?: string | null;
  positionTitle?: string | null;
};

export type QtktDepartment = {
  id: number;
  code?: string | null;
  name: string;
};

export type QtktEvaluation = {
  id: number;
  employeeId: number;
  employeeName: string;
  employeeCode?: string | null;
  departmentId: number;
  departmentName: string;
  procedureCode: string;
  procedureName: string;
  checkContextCode?: string | null;
  checkContextLabel?: string | null;
  patientCode?: string | null;
  evalDate: string;
  scores: Record<string, number>;
  totalScore: number;
  maxScore: number;
  note?: string | null;
  status: 'DRAFT' | 'SUBMITTED' | 'CANCELLED';
  submittedAt?: string | null;
  canEdit?: boolean;
  canRecall?: boolean;
  createdByUsername?: string | null;
  createdByName?: string | null;
  updatedByUsername?: string | null;
  updatedByName?: string | null;
  createdAt?: string | null;
  updatedAt?: string | null;
};

export type QtktUpsertPayload = {
  employeeId: number;
  procedureCode: string;
  checkContextCode?: string;
  patientCode?: string;
  evalDate: string;
  scores: Record<string, number>;
  note?: string;
  submit?: boolean;
};

export function qtktEvalDisplayLabel(
  ev: Pick<QtktEvaluation, 'procedureName' | 'checkContextLabel' | 'patientCode'>,
) {
  const parts = [ev.procedureName];
  if (ev.checkContextLabel) parts.push(ev.checkContextLabel);
  if (ev.patientCode) parts.push(`BN ${ev.patientCode}`);
  return parts.join(' · ');
}

/** Chuẩn hóa tên khoa để đối chiếu allowedDepartmentKeys (bỏ dấu). */
export function normalizeDeptKey(raw?: string | null): string {
  if (!raw) return '';
  return raw
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/gi, 'd')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

export function isProcedureAllowedForDepartment(
  procedure: Pick<QtktProcedure, 'allowedDepartmentKeys'>,
  departmentName?: string | null,
): boolean {
  const keys = procedure.allowedDepartmentKeys;
  if (!keys?.length) return true;
  const normalized = normalizeDeptKey(departmentName);
  if (!normalized) return false;
  return keys.some((k) => normalized.includes(normalizeDeptKey(k)));
}

export type QtktSummary = {
  yearMonth: string;
  from: string;
  to: string;
  totalSubmitted: number;
  byProcedure: {
    procedureCode: string;
    procedureName: string;
    count: number;
    avgScore: number;
    maxScore: number;
  }[];
  byDepartment: {
    departmentId: number;
    departmentName: string;
    count: number;
    avgScore: number;
  }[];
  byEmployee?: {
    employeeId: number;
    employeeName: string;
    employeeCode?: string | null;
    departmentId: number;
    departmentName: string;
    formCount: number;
    avgScore: number;
    maxScore: number;
  }[];
};

export async function fetchQtktTemplate() {
  const { data } = await api.get<QtktTemplate>('/v1/qtkt-evaluations/template');
  return data;
}

export async function fetchQtktEmployees() {
  const { data } = await api.get<QtktEmployee[]>('/v1/qtkt-evaluations/employees');
  return data;
}

export async function fetchQtktDepartments() {
  const { data } = await api.get<QtktDepartment[]>('/v1/qtkt-evaluations/departments');
  return data;
}

export async function fetchQtktEvaluations(params: {
  from?: string;
  to?: string;
  departmentId?: number;
  procedureCode?: string;
  status?: string;
}) {
  const { data } = await api.get<QtktEvaluation[]>('/v1/qtkt-evaluations', { params });
  return data;
}

export async function fetchQtktSummary(yearMonth?: string) {
  const { data } = await api.get<QtktSummary>('/v1/qtkt-evaluations/summary', {
    params: yearMonth ? { yearMonth } : {},
  });
  return data;
}

export async function fetchQtktEvaluation(id: number) {
  const { data } = await api.get<QtktEvaluation>(`/v1/qtkt-evaluations/${id}`);
  return data;
}

export async function createQtktEvaluation(body: QtktUpsertPayload) {
  const { data } = await api.post<QtktEvaluation>('/v1/qtkt-evaluations', body);
  return data;
}

export async function updateQtktEvaluation(id: number, body: QtktUpsertPayload) {
  const { data } = await api.put<QtktEvaluation>(`/v1/qtkt-evaluations/${id}`, body);
  return data;
}

export async function submitQtktEvaluation(id: number) {
  const { data } = await api.post<QtktEvaluation>(`/v1/qtkt-evaluations/${id}/submit`);
  return data;
}

export async function recallQtktEvaluation(id: number) {
  const { data } = await api.post<QtktEvaluation>(`/v1/qtkt-evaluations/${id}/recall`);
  return data;
}

/** @deprecated dùng recallQtktEvaluation */
export async function cancelQtktEvaluation(id: number) {
  return recallQtktEvaluation(id);
}
