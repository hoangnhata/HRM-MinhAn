import api from './api';

export type ImportWorkforceResult = {
  created: number;
  updated: number;
  errors: Array<{ row: number; message: string; sheet?: string }>;
  sheetsProcessed?: string[];
};

export type ImportAccompanyingDutyResult = {
  rowsRead: number;
  listMatched: number;
  tkOnlySet: number;
  preservedAuthorized: number;
  fullAccessSet: number;
  errors: Array<{ row: number; message: string; sheet?: string }>;
  sheetsProcessed?: string[];
};

export type ImportCheckInOutResult = {
  rawPunches: number;
  dailyRecords: number;
  upserted: number;
  skippedNoEmployee: number;
  skippedProtectedDays?: number;
  reappliedApprovedRequests?: number;
  unmappedEnrollCount: number;
  unmappedEnrollNumbers: string[];
  fromDate?: string;
  source?: string;
};

export type CheckInOutSyncStatus = {
  enabled: boolean;
  connected: boolean;
  autoSyncEnabled?: boolean;
  autoSyncTime?: string;
  autoSyncIntervalMinutes?: number;
  lastAutoSyncAt?: string | null;
  lastSyncAt?: string | null;
  lastFromDate?: string | null;
  lastMessage?: string | null;
  lastResult?: ImportCheckInOutResult | null;
};

export type ChamcongSyncSchedulePayload = {
  autoSyncEnabled: boolean;
  intervalMinutes: number;
  syncTime?: string;
};

export type SalaryImportResult = {
  totalRows: number;
  successCount: number;
  createdCount: number;
  updatedCount: number;
  errorCount: number;
  notFoundCount: number;
  warnings: Array<Record<string, unknown>>;
  errors: Array<Record<string, unknown>>;
};

export async function importWorkforceExcel(file: File) {
  const fd = new FormData();
  fd.append('file', file);
  const { data } = await api.post<ImportWorkforceResult>('/v1/import/workforce', fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return data;
}

export async function importAccompanyingDutyExcel(file: File) {
  const fd = new FormData();
  fd.append('file', file);
  const { data } = await api.post<ImportAccompanyingDutyResult>('/v1/import/accompanying-duty', fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return data;
}

/** Xuất Excel nhân lực đúng cấu trúc file nhập (chính thức + thử việc/thực tập). */
export async function downloadWorkforceExcel() {
  const res = await api.get('/v1/import/workforce/export', {
    responseType: 'blob',
    timeout: 300000,
  });
  const blob = new Blob([res.data], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  const stamp = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, '');
  a.download = `NHAN-LUC-BENH-VIEN-MINH-AN-${stamp}.xlsx`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

export async function importCheckInOutSql(file: File) {
  const fd = new FormData();
  fd.append('file', file);
  const { data } = await api.post<ImportCheckInOutResult>('/v1/import/check-in-out', fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
    timeout: 600000,
  });
  return data;
}

export async function fetchCheckInOutSyncStatus() {
  const { data } = await api.get<CheckInOutSyncStatus>('/v1/import/check-in-out/sync-status');
  return data;
}

export async function syncCheckInOut(fromDate?: string) {
  const { data } = await api.post<ImportCheckInOutResult>('/v1/import/check-in-out/sync', null, {
    params: fromDate ? { fromDate } : undefined,
    timeout: 600000,
  });
  return data;
}

export async function updateCheckInOutSyncSchedule(payload: ChamcongSyncSchedulePayload) {
  const { data } = await api.put<CheckInOutSyncStatus>('/v1/import/check-in-out/sync-schedule', payload);
  return data;
}

export type AttendanceCodeSyncResult = {
  deviceUsers: number;
  missingBefore: number;
  updated: number;
  skippedNoMatch: number;
  skippedAmbiguous: number;
  skippedConflict: number;
  samples: Array<{ employeeId: number; fullName: string; attendanceCode: string; deviceName: string }>;
  ambiguous: Array<{ employeeId: number; fullName: string; candidates: string[] }>;
  unmatched: Array<{ employeeId: number; fullName: string }>;
};

/** Đồng bộ mã chấm công từ chamcong.dbo.UserInfo cho NV còn thiếu mã. */
export async function syncAttendanceCodesFromDevice() {
  const { data } = await api.post<AttendanceCodeSyncResult>('/v1/import/attendance-codes/sync', null, {
    timeout: 300000,
  });
  return data;
}

export async function importSalaryScaleExcel(file: File) {
  const fd = new FormData();
  fd.append('file', file);
  const { data } = await api.post<SalaryImportResult>('/v1/import/salary-scale', fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
    timeout: 300000,
  });
  return data;
}
