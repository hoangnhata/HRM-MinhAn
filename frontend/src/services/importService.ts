import api from './api';

export type ImportWorkforceResult = {
  created: number;
  updated: number;
  errors: Array<{ row: number; message: string }>;
};

export async function importWorkforceExcel(file: File) {
  const fd = new FormData();
  fd.append('file', file);
  const { data } = await api.post<ImportWorkforceResult>('/v1/import/workforce', fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return data;
}
