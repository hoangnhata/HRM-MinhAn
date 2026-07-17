import api from './api';

export type DocMeta = {
  id: number;
  originalName: string;
  docType: string;
  createdAt: string;
};

export async function fetchDocuments(employeeId: number) {
  const { data } = await api.get<DocMeta[]>(`/v1/documents/employees/${employeeId}`);
  return data;
}

export async function uploadEmployeePdf(employeeId: number, file: File, docType?: string) {
  const fd = new FormData();
  fd.append('file', file);
  const { data } = await api.post<DocMeta>(`/v1/documents/employees/${employeeId}`, fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
    ...(docType ? { params: { docType } } : {}),
  });
  return data;
}

export async function deleteAllEmployeeDocuments(employeeId: number) {
  await api.delete(`/v1/documents/employees/${employeeId}`);
}

export function documentDownloadUrl(id: number) {
  return `/j1-api/v1/documents/${id}/file`;
}
