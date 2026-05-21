import api from './api';

export type DepartmentRow = {
  id: number;
  code: string;
  name: string;
  description: string | null;
  createdAt?: string;
  updatedAt?: string | null;
};

export type DepartmentPayload = {
  name: string;
  description?: string | null;
};

export async function fetchDepartments() {
  const { data } = await api.get<DepartmentRow[]>('/v1/departments');
  return data;
}

export async function createDepartment(body: DepartmentPayload) {
  const { data } = await api.post<DepartmentRow>('/v1/departments', {
    name: body.name,
    description: body.description ?? null,
  });
  return data;
}

export async function updateDepartment(id: number, body: DepartmentPayload) {
  const { data } = await api.put<DepartmentRow>(`/v1/departments/${id}`, {
    name: body.name,
    description: body.description ?? null,
  });
  return data;
}

export async function deleteDepartment(id: number) {
  await api.delete(`/v1/departments/${id}`);
}
