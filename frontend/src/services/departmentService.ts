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

export type WorkUnitRow = {
  id: number;
  departmentId: number;
  departmentName: string;
  name: string;
  description: string | null;
  createdAt?: string;
  updatedAt?: string | null;
};

export type WorkUnitPayload = {
  name: string;
  description?: string | null;
};

export async function fetchDepartments() {
  try {
    const { data } = await api.get<DepartmentRow[]>('/v1/departments');
    return data;
  } catch (departmentError) {
    // ADMIN/HR: dashboard stats; HEAD_NURSING: nursing-stats theo khối.
    try {
      const { data } = await api.get<{
        employeesByDepartment?: Array<{ departmentId: number; departmentName: string }>;
      }>('/v1/dashboard/stats');
      const fallback: DepartmentRow[] = (data.employeesByDepartment ?? [])
        .filter((item) => item.departmentId != null && item.departmentName?.trim())
        .map((item) => ({
          id: item.departmentId,
          code: `DEPT-${item.departmentId}`,
          name: item.departmentName.trim(),
          description: null,
        }))
        .sort((a, b) => a.name.localeCompare(b.name, 'vi'));
      if (fallback.length > 0) return fallback;
    } catch {
      // ignore
    }
    try {
      const { data } = await api.get<{
        byDepartment?: Array<{ departmentId?: number | null; departmentName: string }>;
      }>('/v1/dashboard/nursing-stats');
      const fallback: DepartmentRow[] = (data.byDepartment ?? [])
        .filter((item) => item.departmentId != null && item.departmentName?.trim())
        .map((item) => ({
          id: Number(item.departmentId),
          code: `DEPT-${item.departmentId}`,
          name: item.departmentName.trim(),
          description: null,
        }))
        .sort((a, b) => a.name.localeCompare(b.name, 'vi'));
      if (fallback.length > 0) return fallback;
    } catch {
      // Giữ lỗi gốc của API danh mục nếu cả nguồn dự phòng cũng thất bại.
    }
    throw departmentError;
  }
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

export async function fetchWorkUnits(departmentId: number) {
  const { data } = await api.get<WorkUnitRow[]>(`/v1/departments/${departmentId}/work-units`);
  return data;
}

export async function fetchAllWorkUnits() {
  const { data } = await api.get<WorkUnitRow[]>('/v1/departments/work-units');
  return data;
}

export async function createWorkUnit(departmentId: number, body: WorkUnitPayload) {
  const { data } = await api.post<WorkUnitRow>(`/v1/departments/${departmentId}/work-units`, {
    name: body.name,
    description: body.description ?? null,
  });
  return data;
}

export async function updateWorkUnit(departmentId: number, workUnitId: number, body: WorkUnitPayload) {
  const { data } = await api.put<WorkUnitRow>(
    `/v1/departments/${departmentId}/work-units/${workUnitId}`,
    {
      name: body.name,
      description: body.description ?? null,
    },
  );
  return data;
}

export async function deleteWorkUnit(departmentId: number, workUnitId: number) {
  await api.delete(`/v1/departments/${departmentId}/work-units/${workUnitId}`);
}
