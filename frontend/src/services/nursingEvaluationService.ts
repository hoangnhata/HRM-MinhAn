import api from './api';

/** Mẫu đồng bộ Bộ tiêu chí ĐD-KTV-HS MA 2026 (cùng cấu trúc tiêu chí JSON). */
export const MA2026_EVAL_TEMPLATE_CODE = 'DD_KTV_HS_MA_2026';

export type CriterionOption = { label: string; points: number };
export type CriterionGroup = {
  id: string;
  /** Nhóm I/II/III... như mẫu Excel (optional) */
  section?: string;
  /** Tổng điểm của nhóm (optional) */
  sectionPoints?: number;
  /** Số thứ tự trong nhóm (optional) */
  no?: string;
  title: string;
  maxPoints: number | null;
  options: CriterionOption[];
};

export type NursingTemplate = {
  code: string;
  name: string;
  version: number;
  criteriaGroups: CriterionGroup[];
  gradingScale: Array<{ min: number; label: string; proposal: string }>;
};

export type NursingEvalRow = Record<string, unknown>;

/** Tên hiển thị người chấm: họ tên nhân viên (nếu có) hoặc tên đăng nhập. */
export function formatChannelEvaluatorName(slot: {
  displayName?: string | null;
  username?: string | null;
} | null | undefined): string {
  const dn = (slot?.displayName ?? '').trim();
  if (dn) return dn;
  const u = (slot?.username ?? '').trim();
  return u || '';
}

/** Chuỗi thời gian ISO từ server → ngày giờ đọc được (Việt Nam). */
export function formatChannelEvalSavedAt(iso: string | null | undefined): string {
  if (iso == null || iso === '') return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'short',
    timeStyle: 'short',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).format(d);
}

export async function fetchNursingTemplate(code: string) {
  const { data } = await api.get<NursingTemplate>(`/v1/nursing-evaluations/templates/${code}`);
  return data;
}

export async function fetchNursingHistory(employeeId: number) {
  const { data } = await api.get<NursingEvalRow[]>(`/v1/nursing-evaluations/employees/${employeeId}`);
  return data;
}

export type CriterionScorePayload = {
  truongKhoa: number;
  ddt: number;
  /** Hội đồng 30 điểm */
  hd?: number;
  truongKhoaNote?: string;
  ddtNote?: string;
  hdNote?: string;
};

export type NursingSubmitBody = {
  employeeId: number;
  periodYear: number;
  periodMonth: number;
  templateCode: string;
  scores: Record<string, CriterionScorePayload>;
  comments?: string;
};

export async function submitNursingEvaluation(body: NursingSubmitBody) {
  const { data } = await api.post<NursingEvalRow>('/v1/nursing-evaluations', body);
  return data;
}

export type NursingChannelSubmitBody = {
  employeeId: number;
  periodYear: number;
  periodMonth: number;
  templateCode: string;
  channel: 'truongKhoa' | 'ddt' | 'hd';
  scores: Record<string, number>;
  /** Ghi chú theo từng tiêu chí (id), cùng kênh đang lưu */
  notes?: Record<string, string>;
  comments?: string;
};

export async function submitNursingEvaluationChannel(body: NursingChannelSubmitBody) {
  const { data } = await api.post<NursingEvalRow>('/v1/nursing-evaluations/channel', body);
  return data;
}

export type MonthlyEvalSummaryRow = {
  evaluationId: number;
  employeeId: number;
  employeeCode?: string | null;
  fullName: string;
  departmentName: string;
  periodYear: number;
  periodMonth: number;
  totalTruongKhoa: number | null;
  totalDdt: number | null;
  gradeTruongKhoa: string | null;
  gradeDdt: string | null;
  /** Điểm phần 70: TB hai cột nếu đủ cả hai; một cột nếu chỉ một bên chấm */
  deptAvg70: number | null;
  /** Điểm Hội đồng 30 */
  hdTotal30: number | null;
  hdGrade: string | null;
  /** Tổng hợp 100 = deptAvg70 + hdTotal30 */
  total100: number | null;
  overallGrade: string | null;
  evaluatorUsername: string;
};

export async function fetchNursingMonthlySummary(year: number, month: number, templateCode: string) {
  const { data } = await api.get<MonthlyEvalSummaryRow[]>('/v1/nursing-evaluations/summary', {
    params: { year, month, templateCode },
  });
  return data;
}

export async function fetchNursingEvaluationRecord(evaluationId: number) {
  const { data } = await api.get<NursingEvalRow>(`/v1/nursing-evaluations/records/${evaluationId}`);
  return data;
}

export type NursingPeriodStatusRow = {
  employeeId: number;
  hasTruongKhoa: boolean;
  hasDdt: boolean;
  hasHd: boolean;
};

export async function fetchNursingPeriodStatus(year: number, month: number, templateCode: string) {
  const { data } = await api.get<NursingPeriodStatusRow[]>('/v1/nursing-evaluations/period-status', {
    params: { year, month, templateCode },
  });
  return data;
}
