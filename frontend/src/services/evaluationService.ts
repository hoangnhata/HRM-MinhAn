import api from './api';

export type EvaluationRow = Record<string, unknown>;

export async function fetchEvaluations(employeeId: number) {
  const { data } = await api.get<EvaluationRow[]>(`/v1/evaluations/employees/${employeeId}`);
  return data;
}

export type EvaluationCreatePayload = {
  employeeId: number;
  periodYear: number;
  periodMonth?: number;
  quarter?: number;
  score: number;
  grade: string;
  comments?: string;
};

export async function createEvaluation(payload: EvaluationCreatePayload) {
  const { data } = await api.post<EvaluationRow>('/v1/evaluations', payload);
  return data;
}
