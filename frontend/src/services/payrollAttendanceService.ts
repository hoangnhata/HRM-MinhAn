import api from './api';

export async function fetchAttendance(employeeId: number, from: string, to: string) {
  const { data } = await api.get(`/v1/attendance/employees/${employeeId}`, {
    params: { from, to },
  });
  return data as Record<string, unknown>[];
}

export async function fetchPayrollForEmployee(employeeId: number) {
  const { data } = await api.get(`/v1/payroll/employees/${employeeId}`);
  return data as Record<string, unknown>[];
}

export async function notifyAttendanceMonth(employeeId: number, year: number, month: number) {
  await api.post('/v1/attendance/notify-month', { employeeId, year, month });
}
