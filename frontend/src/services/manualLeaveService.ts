import api from './api';

/** Phép năm đã nghỉ ngoài hệ thống do admin gắn (tay hoặc Excel). */
export type ManualLeave = {
  id: number;
  employeeId: number;
  employeeName: string;
  employeeCode?: string | null;
  idCardNumber?: string | null;
  departmentName?: string | null;
  fromDate: string;
  toDate: string;
  days: number;
  note?: string | null;
  createdBy?: string | null;
  createdAt?: string | null;
};

export type LeaveBalance = {
  employeeId: number;
  year: number;
  entitlementDays: number;
  usedDays: number;
  pendingDays: number;
  remainingDays: number;
  overLimit: boolean;
  warning?: string;
};

export type ManualLeaveImportRowStatus = 'OK' | 'CREATED' | 'DUPLICATE' | 'ERROR';

export type ManualLeaveImportRow = {
  row: number;
  name: string;
  cccd: string;
  note?: string;
  fromDate?: string | null;
  toDate?: string | null;
  days?: number;
  employeeId?: number;
  employeeName?: string;
  employeeCode?: string;
  departmentName?: string;
  warning?: string | null;
  status: ManualLeaveImportRowStatus;
  message: string;
  id?: number;
};

export type ManualLeaveImportResult = {
  applied: boolean;
  total: number;
  ready: number;
  created: number;
  duplicate: number;
  error: number;
  rows: ManualLeaveImportRow[];
};

const BASE = '/v1/attendance/manual-leaves';

export async function listManualLeaves(year: number) {
  const { data } = await api.get<ManualLeave[]>(BASE, { params: { year } });
  return data;
}

export async function attachManualLeave(payload: {
  employeeId: number;
  fromDate: string;
  toDate: string;
  note?: string;
  applyAttendance: boolean;
}) {
  const { data } = await api.post<ManualLeave & { balance: LeaveBalance }>(BASE, payload);
  return data;
}

export async function deleteManualLeave(id: number) {
  const { data } = await api.delete<{ id: number; revertedDays: number; balance: LeaveBalance }>(
    `${BASE}/${id}`,
  );
  return data;
}

export async function fetchLeaveBalance(employeeId: number, year: number) {
  const { data } = await api.get<LeaveBalance>(
    `/v1/attendance/employees/${employeeId}/leave-balance`,
    {
      params: { year },
    },
  );
  return data;
}

/** apply=false: chỉ kiểm tra; apply=true: ghi nhận các dòng hợp lệ. */
export async function importManualLeaves(file: File, apply: boolean, applyAttendance: boolean) {
  const fd = new FormData();
  fd.append('file', file);
  const { data } = await api.post<ManualLeaveImportResult>(`${BASE}/import`, fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
    params: { apply, applyAttendance },
    timeout: 300000,
  });
  return data;
}

export async function downloadManualLeaveTemplate() {
  const res = await api.get(`${BASE}/template`, { responseType: 'blob' });
  const blob = new Blob([res.data], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'MAU-GAN-PHEP-NGOAI-HE-THONG.xlsx';
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
