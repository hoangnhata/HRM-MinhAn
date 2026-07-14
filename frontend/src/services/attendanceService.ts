import api from './api';

export type AttendanceDay = {
  id: number;
  workDate: string;
  status: string;
  morningCheckIn: string;
  morningCheckOut: string;
  afternoonCheckIn: string;
  afternoonCheckOut: string;
  morningWorkUnits: number;
  afternoonWorkUnits: number;
  totalWorkUnits: number;
  lateMinutes: number;
  lateMinutesExempt: boolean;
  forgotShifts: string;
  checkIn: string;
  checkOut: string;
  punchTimes?: string[];
  note: string;
};

export type MonthSummary = {
  employeeId: number;
  fullName: string;
  periodYear: number;
  periodMonth: number;
  totalWorkUnits: number;
  attendanceWorkUnits?: number;
  lateMinutesTotal: number;
  latePenalty: number;
  latePenaltyTier: string;
  requiresDiscipline: boolean;
  forgotFineCount: number;
  forgotPenalty: number;
  dutyBonusTotal?: number;
  dutyPostPayTotal?: number;
  dutyWorkUnitsTotal?: number;
  dutyShiftCount?: number;
  mealAllowance?: number;
  mealAllowanceUnits?: number;
  mealAllowancePresentDays?: number;
  mealAllowanceMorningDays?: number;
  mealAllowanceDutyUnits?: number;
  days?: AttendanceDay[];
  requests?: WorkRequest[];
};

export type DeptSummaryRow = {
  employeeId: number;
  employeeCode: string;
  fullName: string;
  department: string;
  totalWorkUnits: number;
  latePenalty: number;
  forgotPenalty: number;
  lateMinutesTotal: number;
  forgotFineCount: number;
  requiresDiscipline: boolean;
};

export type WorkRequest = {
  id: number;
  employeeId: number;
  employeeName: string;
  department: string;
  requestType: 'EXPLANATION' | 'UPDATE' | 'LEAVE' | 'BUSINESS_TRIP' | 'DEPLOYMENT';
  workDate: string;
  endDate?: string;
  leaveDays?: number;
  tripDays?: number;
  shiftScope: string;
  updateKind: string;
  reason: string;
  location?: string;
  deploymentActualHours?: number;
  deploymentCreditedHours?: number;
  deploymentCoefficient?: number;
  requestedStart: string;
  requestedEnd: string;
  requestedAfternoonStart?: string;
  requestedAfternoonEnd?: string;
  explanationKind: string;
  explainedTime: string;
  explainedDepartureTime: string;
  explainedMorningIn?: string;
  explainedMorningOut?: string;
  explainedAfternoonIn?: string;
  explainedAfternoonOut?: string;
  status: string;
  headComment: string;
  hrComment: string;
  headReviewedAt?: string;
  hrReviewedAt?: string;
  hrWaiveForgotFine: boolean;
  forgotFineUnits?: number;
  createdAt: string;
};

import type { ShiftConfigAdminView, ShiftScheduleInfo } from '../utils/shiftSchedule';
import { scheduleForDate } from '../utils/shiftSchedule';

export async function fetchShiftSchedule(date?: string, employeeId?: number) {
  const { data } = await api.get<ShiftScheduleInfo>('/v1/attendance/schedule', {
    params: {
      ...(date ? { date } : {}),
      ...(employeeId != null ? { employeeId } : {}),
    },
  });
  return data;
}

export async function fetchShiftConfigAdmin() {
  const { data } = await api.get<ShiftConfigAdminView>('/v1/attendance/schedule/config');
  return data;
}

export type ShiftConfigUpdatePayload = {
  morningStart: string;
  morningEnd: string;
  afternoonStart: string;
  afternoonEnd: string;
  morningUnits: number;
  afternoonUnits: number;
  morningInBeforeMin: number;
  morningInAfterMin: number;
  morningOutBeforeMin: number;
  morningOutAfterMin: number;
  afternoonInBeforeMin: number;
  afternoonInAfterMin: number;
  afternoonOutBeforeMin: number;
  afternoonOutAfterMin: number;
};

export async function updateShiftConfig(season: 'SUMMER' | 'WINTER', body: ShiftConfigUpdatePayload) {
  const { data } = await api.put<ShiftConfigAdminView>(`/v1/attendance/schedule/config/${season}`, body);
  return data;
}

export async function setEmployeeContinuousShift(
  employeeId: number,
  year: number,
  month: number,
  continuousShift: boolean,
) {
  const { data } = await api.put<{
    employeeId: number;
    periodYear: number;
    periodMonth: number;
    continuousShift: boolean;
    recalculated: number;
    recalculateWarning?: string;
  }>(`/v1/attendance/employees/${employeeId}/continuous-shift`, {
    year,
    month,
    continuousShift,
  });
  return data;
}

export async function setEmployeeYoungChild(
  employeeId: number,
  year: number,
  month: number,
  youngChild: boolean,
) {
  const { data } = await api.put<{
    employeeId: number;
    periodYear: number;
    periodMonth: number;
    youngChild: boolean;
    recalculated: number;
    recalculateWarning?: string;
  }>(`/v1/attendance/employees/${employeeId}/young-child`, {
    year,
    month,
    youngChild,
  });
  return data;
}

export type ForgotPenaltyConfig = {
  tier1Amount: number;
  tier2Min: number;
  tier2Max: number;
  tier2Amount: number;
  tier3Amount: number;
  tiers?: Array<{ label: string; minOccurrence: number; maxOccurrence: number | string; amountPerTime: number }>;
  updatedAt?: string;
};

export async function fetchForgotPenaltyConfig() {
  const { data } = await api.get<ForgotPenaltyConfig>('/v1/attendance/penalty/forgot-config');
  return data;
}

export async function updateForgotPenaltyConfig(body: Omit<ForgotPenaltyConfig, 'tiers' | 'updatedAt'>) {
  const { data } = await api.put<ForgotPenaltyConfig>('/v1/attendance/penalty/forgot-config', body);
  return data;
}

export type LatePenaltyTier = {
  sortOrder: number;
  minMinutes: number;
  maxMinutes: number | '';
  amount: number;
  requiresDiscipline: boolean;
  note?: string;
  label?: string;
};

export type LatePenaltyConfig = {
  exemptBelowMinutes: number;
  tiers: LatePenaltyTier[];
  updatedAt?: string;
};

export async function fetchLatePenaltyConfig() {
  const { data } = await api.get<LatePenaltyConfig>('/v1/attendance/penalty/late-config');
  return data;
}

export async function updateLatePenaltyConfig(body: { tiers: Array<Omit<LatePenaltyTier, 'label'>> }) {
  const { data } = await api.put<LatePenaltyConfig>('/v1/attendance/penalty/late-config', body);
  return data;
}

export type HolidayWorkDaysConfig = {
  year: number;
  month: number;
  dates: string[];
};

export async function fetchHolidayWorkDays(year: number, month: number) {
  const { data } = await api.get<HolidayWorkDaysConfig>('/v1/attendance/holiday-work-days', {
    params: { year, month },
  });
  return data;
}

export async function updateHolidayWorkDays(year: number, month: number, dates: string[]) {
  const { data } = await api.put<HolidayWorkDaysConfig>('/v1/attendance/holiday-work-days', {
    year,
    month,
    dates,
  });
  return data;
}

export async function fetchAttendance(employeeId: number, from: string, to: string) {
  const { data } = await api.get<Record<string, unknown>[]>(`/v1/attendance/employees/${employeeId}`, {
    params: { from, to },
  });
  return data;
}

export async function fetchMonthSummary(employeeId: number, year: number, month: number) {
  const { data } = await api.get<MonthSummary>(`/v1/attendance/employees/${employeeId}/summary`, {
    params: { year, month },
  });
  return data;
}

export async function fetchMonthDetail(employeeId: number, year: number, month: number) {
  const { data } = await api.get<MonthSummary>(`/v1/attendance/employees/${employeeId}/detail`, {
    params: { year, month },
  });
  return data;
}

export async function fetchDepartmentSummary(year: number, month: number, departmentId?: number) {
  const { data } = await api.get<DeptSummaryRow[]>('/v1/attendance/summary', {
    params: { year, month, departmentId },
  });
  return data;
}

export async function notifyAttendanceMonth(employeeId: number, year: number, month: number) {
  await api.post('/v1/attendance/notify-month', { employeeId, year, month });
}

export async function recalculateMonth(year: number, month: number) {
  const { data } = await api.post<{ recalculated: number }>('/v1/attendance/recalculate', null, {
    params: { year, month },
  });
  return data;
}

export async function recalculateEmployeeMonth(employeeId: number, year: number, month: number) {
  const { data } = await api.post<{ recalculated: number; employeeId: number }>(
    `/v1/attendance/employees/${employeeId}/recalculate`,
    null,
    { params: { year, month } },
  );
  return data;
}

export type SubmitWorkRequest = {
  requestType: 'EXPLANATION' | 'UPDATE' | 'LEAVE' | 'BUSINESS_TRIP' | 'DEPLOYMENT';
  /** Nhân viên được điều động (DEPLOYMENT). */
  employeeId?: number;
  workDate: string;
  endDate?: string;
  shiftScope: 'MORNING' | 'AFTERNOON' | 'FULL_DAY';
  updateKind?: 'MORNING_SUPPLEMENT' | 'AFTERNOON_SUPPLEMENT' | 'FULL_DAY_SUPPLEMENT';
  reason: string;
  location?: string;
  requestedStart?: string;
  requestedEnd?: string;
  requestedAfternoonStart?: string;
  requestedAfternoonEnd?: string;
  explanationKind?: 'LATE_ARRIVAL' | 'EARLY_DEPARTURE';
  /** Giờ vào thực tế (đi muộn) — legacy. */
  explainedTime?: string;
  /** Giờ ra thực tế (về sớm) — legacy. */
  explainedDepartureTime?: string;
  explainedMorningIn?: string;
  explainedMorningOut?: string;
  explainedAfternoonIn?: string;
  explainedAfternoonOut?: string;
};

export async function submitWorkRequest(body: SubmitWorkRequest) {
  const { data } = await api.post<WorkRequest>('/v1/attendance/requests', body);
  return data;
}

export async function fetchMyWorkRequests() {
  const { data } = await api.get<WorkRequest[]>('/v1/attendance/requests/mine');
  return data;
}

export async function fetchPendingWorkRequests() {
  const { data } = await api.get<WorkRequest[]>('/v1/attendance/requests/pending');
  return data;
}

export async function fetchReviewHistoryWorkRequests() {
  const { data } = await api.get<WorkRequest[]>('/v1/attendance/requests/review-history');
  return data;
}

export async function headReviewRequest(id: number, approved: boolean, comment?: string) {
  const { data } = await api.post<WorkRequest>(`/v1/attendance/requests/${id}/head-review`, {
    approved,
    comment,
  });
  return data;
}

export async function hrReviewRequest(
  id: number,
  approved: boolean,
  options?: { comment?: string; waiveForgotFine?: boolean },
) {
  const { data } = await api.post<WorkRequest>(`/v1/attendance/requests/${id}/hr-review`, {
    approved,
    comment: options?.comment,
    waiveForgotFine: options?.waiveForgotFine ?? false,
  });
  return data;
}

export function formatMoney(n: number | null | undefined) {
  if (n == null || Number.isNaN(n)) return '—';
  return `${Number(n).toLocaleString('vi-VN')} đ`;
}

/** Phạt muộn/sớm của ngày = phần phân bổ theo tỷ lệ phút ngày / tổng phút tháng (mức phạt tính theo bậc tháng). */
export function dayLatePenalty(
  lateMinutes: number,
  lateMinutesExempt: boolean,
  summary: MonthSummary | null | undefined
): { amount: number; display: string } {
  if (lateMinutesExempt || lateMinutes <= 0 || !summary) {
    return { amount: 0, display: '—' };
  }
  if (summary.requiresDiscipline) {
    return { amount: 0, display: 'Kiểm điểm' };
  }
  const totalMin = Number(summary.lateMinutesTotal ?? 0);
  const monthPenalty = Number(summary.latePenalty ?? 0);
  if (totalMin < 15 || monthPenalty <= 0) {
    return { amount: 0, display: '—' };
  }
  const amount = Math.round((monthPenalty * lateMinutes) / totalMin);
  return { amount, display: formatMoney(amount) };
}

export const EXPLANATION_KIND_OPTIONS = [
  { value: 'LATE_ARRIVAL', label: 'Đi muộn' },
  { value: 'EARLY_DEPARTURE', label: 'Về sớm' },
] as const;

export const UPDATE_KIND_OPTIONS = [
  { value: 'MORNING_SUPPLEMENT', label: 'Bổ sung ca sáng', forgotUnits: 2 },
  { value: 'AFTERNOON_SUPPLEMENT', label: 'Bổ sung ca chiều', forgotUnits: 2 },
  { value: 'FULL_DAY_SUPPLEMENT', label: 'Bổ sung cả ngày', forgotUnits: 4 },
] as const;

export type UpdateScenario = {
  updateKind: 'MORNING_SUPPLEMENT' | 'AFTERNOON_SUPPLEMENT' | 'FULL_DAY_SUPPLEMENT';
  forgotUnits: number;
  partial?: boolean;
  locked?: boolean;
  missingMorningIn?: boolean;
  missingMorningOut?: boolean;
  missingAfternoonIn?: boolean;
  missingAfternoonOut?: boolean;
  existingMorningIn?: string;
  existingMorningOut?: string;
  existingAfternoonIn?: string;
  existingAfternoonOut?: string;
};

function punchStr(v: unknown): string {
  return v != null && String(v).trim() !== '' ? String(v).slice(0, 5) : '';
}

/** Tự chọn loại cập nhật và số lần trừ quên chấm theo giờ đã/ chưa có trên bảng công. */
export function detectUpdateFromRow(row: Record<string, unknown> | null | undefined): UpdateScenario {
  const mIn = punchStr(row?.morningCheckIn);
  const mOut = punchStr(row?.morningCheckOut);
  const aIn = punchStr(row?.afternoonCheckIn);
  const aOut = punchStr(row?.afternoonCheckOut);
  const morningComplete = Boolean(mIn && mOut);
  const afternoonComplete = Boolean(aIn && aOut);
  const anyPunch = Boolean(mIn || mOut || aIn || aOut);

  if (!anyPunch) {
    return { updateKind: 'FULL_DAY_SUPPLEMENT', forgotUnits: 4, locked: false };
  }

  if (morningComplete && !afternoonComplete) {
    const missing = (!aIn ? 1 : 0) + (!aOut ? 1 : 0);
    return {
      updateKind: 'AFTERNOON_SUPPLEMENT',
      forgotUnits: missing || 2,
      partial: missing === 1,
      locked: true,
      missingAfternoonIn: !aIn,
      missingAfternoonOut: !aOut,
      existingAfternoonIn: aIn || undefined,
      existingAfternoonOut: aOut || undefined,
    };
  }

  if (!morningComplete && afternoonComplete) {
    const missing = (!mIn ? 1 : 0) + (!mOut ? 1 : 0);
    return {
      updateKind: 'MORNING_SUPPLEMENT',
      forgotUnits: missing || 2,
      partial: missing === 1,
      locked: true,
      missingMorningIn: !mIn,
      missingMorningOut: !mOut,
      existingMorningIn: mIn || undefined,
      existingMorningOut: mOut || undefined,
    };
  }

  if (!morningComplete && !afternoonComplete) {
    const mMissing = (!mIn ? 1 : 0) + (!mOut ? 1 : 0);
    const aMissing = (!aIn ? 1 : 0) + (!aOut ? 1 : 0);
    if (mMissing > 0 && aMissing > 0) {
      return { updateKind: 'FULL_DAY_SUPPLEMENT', forgotUnits: 4, locked: true };
    }
    if (mMissing > 0) {
      return {
        updateKind: 'MORNING_SUPPLEMENT',
        forgotUnits: mMissing,
        partial: mMissing === 1,
        locked: true,
        missingMorningIn: !mIn,
        missingMorningOut: !mOut,
        existingMorningIn: mIn || undefined,
        existingMorningOut: mOut || undefined,
      };
    }
    return {
      updateKind: 'AFTERNOON_SUPPLEMENT',
      forgotUnits: aMissing,
      partial: aMissing === 1,
      locked: true,
      missingAfternoonIn: !aIn,
      missingAfternoonOut: !aOut,
      existingAfternoonIn: aIn || undefined,
      existingAfternoonOut: aOut || undefined,
    };
  }

  return { updateKind: 'MORNING_SUPPLEMENT', forgotUnits: 2, locked: false };
}

export function forgotFineUnitsForUpdateKind(kind: string): number {
  const opt = UPDATE_KIND_OPTIONS.find((o) => o.value === kind);
  return opt?.forgotUnits ?? 2;
}

export const REQUEST_STATUS_LABEL: Record<string, string> = {
  PENDING_HEAD: 'Chờ lãnh đạo',
  HEAD_REJECTED: 'Lãnh đạo từ chối',
  PENDING_HR: 'Chờ HCNS',
  HR_REJECTED: 'HCNS từ chối',
  APPROVED: 'Đã duyệt (có phạt quên chấm)',
  APPROVED_NO_FINE: 'Đã duyệt (không phạt quên chấm)',
  WITHDRAWN: 'Đã thu hồi',
};

/** Nhãn trạng thái theo loại đơn — phạt quên chấm chỉ áp dụng đơn cập nhật công. */
export function requestStatusLabel(
  status: string,
  requestType?: WorkRequest['requestType'],
): string {
  if (requestType === 'LEAVE' || requestType === 'EXPLANATION' || requestType === 'BUSINESS_TRIP' || requestType === 'DEPLOYMENT') {
    if (status === 'APPROVED' || status === 'APPROVED_NO_FINE') return 'Đã duyệt';
  }
  return REQUEST_STATUS_LABEL[status] ?? status;
}

export function requestTypeLabel(type: WorkRequest['requestType']): string {
  if (type === 'EXPLANATION') return 'Giải trình công';
  if (type === 'LEAVE') return 'Nghỉ phép';
  if (type === 'BUSINESS_TRIP') return 'Công tác';
  if (type === 'DEPLOYMENT') return 'Điều động';
  return 'Cập nhật công';
}

export function updateKindLabel(kind: string): string {
  return UPDATE_KIND_OPTIONS.find((o) => o.value === kind)?.label ?? 'Cập nhật công';
}

export function formatWorkDate(dateStr: string): string {
  const parts = dateStr.split('-').map(Number);
  if (parts.length !== 3 || parts.some((n) => Number.isNaN(n))) return dateStr;
  return new Date(parts[0], parts[1] - 1, parts[2]).toLocaleDateString('vi-VN', {
    weekday: 'short',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

export function formatReviewTimestamp(iso?: string): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString('vi-VN', { dateStyle: 'short', timeStyle: 'short' });
}

export function formatRequestedTimes(r: WorkRequest): string {
  const shifts = resolveRequestShiftTimes(r);
  const parts: string[] = [];
  if (shifts.morning?.start && shifts.morning.end) {
    parts.push(`Sáng ${shifts.morning.start}–${shifts.morning.end}`);
  }
  if (shifts.afternoon?.start && shifts.afternoon.end) {
    parts.push(`Chiều ${shifts.afternoon.start}–${shifts.afternoon.end}`);
  }
  if (parts.length > 0) return parts.join(' · ');
  if (shifts.single?.start && shifts.single.end) {
    return `${shifts.single.start} – ${shifts.single.end}`;
  }
  return '';
}

export type RequestShiftTimes = {
  morning?: { start: string; end: string };
  afternoon?: { start: string; end: string };
  single?: { start: string; end: string; label: string };
};

function formatTimeShort(value?: string): string {
  if (!value) return '';
  return value.slice(0, 5);
}

function timeToMinutes(value: string): number {
  const [h, m] = value.split(':').map(Number);
  if (Number.isNaN(h) || Number.isNaN(m)) return 0;
  return h * 60 + m;
}

/** Bổ sung cả ngày: luôn trả 2 ca; suy ra ca chiều từ lịch nếu đơn cũ chưa lưu 4 mốc giờ. */
function resolveFullDayShiftTimes(r: WorkRequest): RequestShiftTimes {
  const sch = scheduleForDate(r.workDate);
  const start = formatTimeShort(r.requestedStart);
  const end = formatTimeShort(r.requestedEnd);
  const aftStart = formatTimeShort(r.requestedAfternoonStart);
  const aftEnd = formatTimeShort(r.requestedAfternoonEnd);

  if (start && end && aftStart && aftEnd) {
    return { morning: { start, end }, afternoon: { start: aftStart, end: aftEnd } };
  }

  if (!start) return {};

  const afternoonStartMin = timeToMinutes(sch.afternoonStart);
  const endMin = end ? timeToMinutes(end) : 0;

  // Đơn cũ gửi 07:00–17:00 trong 2 field
  if (end && endMin > afternoonStartMin) {
    return {
      morning: { start, end: sch.morningEnd },
      afternoon: { start: sch.afternoonStart, end },
    };
  }

  // Chỉ có ca sáng trong DB — bổ sung ca chiều theo lịch mặc định
  return {
    morning: { start, end: end || sch.morningEnd },
    afternoon: { start: sch.afternoonStart, end: sch.afternoonEnd },
  };
}

export function resolveRequestShiftTimes(r: WorkRequest): RequestShiftTimes {
  if (r.requestType !== 'UPDATE') return {};
  if (r.updateKind === 'FULL_DAY_SUPPLEMENT') {
    return resolveFullDayShiftTimes(r);
  }
  if (r.updateKind === 'AFTERNOON_SUPPLEMENT') {
    return {
      afternoon: {
        start: formatTimeShort(r.requestedStart),
        end: formatTimeShort(r.requestedEnd),
      },
    };
  }
  return {
    morning: {
      start: formatTimeShort(r.requestedStart),
      end: formatTimeShort(r.requestedEnd),
    },
  };
}

export function formatExplanationTimes(r: WorkRequest): string {
  const parts: string[] = [];
  const mIn = formatTimeShort(r.explainedMorningIn);
  const mOut = formatTimeShort(r.explainedMorningOut);
  const aIn = formatTimeShort(r.explainedAfternoonIn);
  const aOut = formatTimeShort(r.explainedAfternoonOut);
  if (mIn) parts.push(`Sáng vào → ${mIn}`);
  if (mOut) parts.push(`Sáng ra → ${mOut}`);
  if (aIn) parts.push(`Chiều vào → ${aIn}`);
  if (aOut) parts.push(`Chiều ra → ${aOut}`);
  if (parts.length > 0) return parts.join(' · ');

  if (r.explainedTime && r.explanationKind !== 'EARLY_DEPARTURE') {
    parts.push(`Đi muộn — vào ${r.explainedTime.slice(0, 5)}`);
  }
  if (r.explainedDepartureTime) {
    parts.push(`Về sớm — ra ${r.explainedDepartureTime.slice(0, 5)}`);
  }
  if (!r.explainedDepartureTime && r.explainedTime && r.explanationKind === 'EARLY_DEPARTURE') {
    parts.push(`Về sớm — ra ${r.explainedTime.slice(0, 5)}`);
  }
  return parts.join(' · ');
}

export type ExplanationSlotKey =
  | 'morningIn'
  | 'morningOut'
  | 'afternoonIn'
  | 'afternoonOut';

export type ExplanationPenaltySlot = {
  key: ExplanationSlotKey;
  label: string;
  kind: 'LATE' | 'EARLY';
  kindLabel: string;
  current: string;
  expected: string;
  minutes: number;
};

function punchHm(value: unknown): string {
  if (value == null) return '';
  const s = String(value).trim();
  return s.length >= 5 ? s.slice(0, 5) : s;
}

function parseHm(value: string): number | null {
  const m = /^(\d{1,2}):(\d{2})/.exec(value);
  if (!m) return null;
  return Number(m[1]) * 60 + Number(m[2]);
}

function minutesLate(actual: string, expected: string): number {
  const a = parseHm(actual);
  const e = parseHm(expected);
  if (a == null || e == null) return 0;
  return a > e ? a - e : 0;
}

function minutesEarly(actual: string, expected: string): number {
  const a = parseHm(actual);
  const e = parseHm(expected);
  if (a == null || e == null) return 0;
  return a < e ? e - a : 0;
}

/**
 * Các khung giờ đang bị tính muộn/về sớm (để giải trình).
 * Ca thông tầm: chỉ xét vào đầu ngày / ra cuối ngày.
 */
export function detectExplanationPenaltySlots(
  row: Record<string, unknown> | null | undefined,
  workDate: string,
  continuousShift?: boolean,
): ExplanationPenaltySlot[] {
  if (!row) return [];
  const sch = scheduleForDate(workDate);
  const slots: ExplanationPenaltySlot[] = [];

  if (continuousShift) {
    const dayIn = punchHm(row.morningCheckIn ?? row.checkIn);
    const dayOut = punchHm(row.afternoonCheckOut ?? row.checkOut);
    const late = dayIn ? minutesLate(dayIn, sch.morningStart) : 0;
    const early = dayOut ? minutesEarly(dayOut, sch.afternoonEnd) : 0;
    if (late > 0) {
      slots.push({
        key: 'morningIn',
        label: 'Giờ vào (thông tầm)',
        kind: 'LATE',
        kindLabel: 'Đi muộn',
        current: dayIn,
        expected: sch.morningStart,
        minutes: late,
      });
    }
    if (early > 0) {
      slots.push({
        key: 'afternoonOut',
        label: 'Giờ ra (thông tầm)',
        kind: 'EARLY',
        kindLabel: 'Về sớm',
        current: dayOut,
        expected: sch.afternoonEnd,
        minutes: early,
      });
    }
    return slots;
  }

  const mIn = punchHm(row.morningCheckIn);
  const mOut = punchHm(row.morningCheckOut);
  const aIn = punchHm(row.afternoonCheckIn);
  const aOut = punchHm(row.afternoonCheckOut);

  const lateM = mIn ? minutesLate(mIn, sch.morningStart) : 0;
  if (lateM > 0) {
    slots.push({
      key: 'morningIn',
      label: 'Ca sáng — giờ vào',
      kind: 'LATE',
      kindLabel: 'Đi muộn',
      current: mIn,
      expected: sch.morningStart,
      minutes: lateM,
    });
  }
  const earlyM = mOut ? minutesEarly(mOut, sch.morningEnd) : 0;
  if (earlyM > 0) {
    slots.push({
      key: 'morningOut',
      label: 'Ca sáng — giờ ra',
      kind: 'EARLY',
      kindLabel: 'Về sớm',
      current: mOut,
      expected: sch.morningEnd,
      minutes: earlyM,
    });
  }
  const lateA = aIn ? minutesLate(aIn, sch.afternoonStart) : 0;
  if (lateA > 0) {
    slots.push({
      key: 'afternoonIn',
      label: 'Ca chiều — giờ vào',
      kind: 'LATE',
      kindLabel: 'Đi muộn',
      current: aIn,
      expected: sch.afternoonStart,
      minutes: lateA,
    });
  }
  const earlyA = aOut ? minutesEarly(aOut, sch.afternoonEnd) : 0;
  if (earlyA > 0) {
    slots.push({
      key: 'afternoonOut',
      label: 'Ca chiều — giờ ra',
      kind: 'EARLY',
      kindLabel: 'Về sớm',
      current: aOut,
      expected: sch.afternoonEnd,
      minutes: earlyA,
    });
  }
  return slots;
}

export function shiftScopeFromExplanationSlots(keys: ExplanationSlotKey[]): 'MORNING' | 'AFTERNOON' | 'FULL_DAY' {
  const morning = keys.some((k) => k === 'morningIn' || k === 'morningOut');
  const afternoon = keys.some((k) => k === 'afternoonIn' || k === 'afternoonOut');
  if (morning && afternoon) return 'FULL_DAY';
  if (afternoon) return 'AFTERNOON';
  return 'MORNING';
}

export function requestStatusColor(
  status: string,
): 'default' | 'primary' | 'secondary' | 'error' | 'info' | 'success' | 'warning' {
  if (status === 'WITHDRAWN') return 'default';
  if (status.includes('REJECTED')) return 'error';
  if (status.includes('APPROVED')) return 'success';
  return 'warning';
}

export function isRequestPending(status: string): boolean {
  return status === 'PENDING_HEAD' || status === 'PENDING_HR';
}

export function isRequestWithdrawable(status: string): boolean {
  return isRequestPending(status);
}

export async function withdrawWorkRequest(id: number) {
  const { data } = await api.post<WorkRequest>(`/v1/attendance/requests/${id}/withdraw`);
  return data;
}

type AttendanceStatusRow = Pick<
  AttendanceDay,
  | 'status'
  | 'morningCheckIn'
  | 'morningCheckOut'
  | 'afternoonCheckIn'
  | 'afternoonCheckOut'
  | 'morningWorkUnits'
  | 'afternoonWorkUnits'
>;

function hasValue(v: unknown): boolean {
  return v != null && String(v).trim() !== '';
}

/** Buổi sáng đủ công (có cả giờ vào và giờ ra). */
export function hasMorningPunch(row: AttendanceStatusRow | Record<string, unknown>): boolean {
  return hasValue(row.morningCheckIn) && hasValue(row.morningCheckOut);
}

/** Buổi chiều đủ công (có cả giờ vào và giờ ra). */
export function hasAfternoonPunch(row: AttendanceStatusRow | Record<string, unknown>): boolean {
  return hasValue(row.afternoonCheckIn) && hasValue(row.afternoonCheckOut);
}

export function hasOvertimeUnits(row: AttendanceStatusRow | Record<string, unknown>): boolean {
  return Number(row.overtimeWorkUnits) > 0;
}

export function isDeploymentRow(row: AttendanceStatusRow | Record<string, unknown> | null | undefined): boolean {
  if (!row) return false;
  if (row.deployment === true) return true;
  const note = String(row.note ?? '');
  return note.includes('Điều động làm thêm') || note.includes('Điều động trong ca');
}

/** Nhãn ca đã chấm khi trạng thái PARTIAL — ví dụ ['Sáng'], ['Chiều']. */
export function partialStatusLabels(row: AttendanceStatusRow | Record<string, unknown>): string[] {
  const labels: string[] = [];
  if (Number(row.morningWorkUnits) > 0) labels.push('Sáng');
  if (Number(row.afternoonWorkUnits) > 0) labels.push('Chiều');
  if (hasOvertimeUnits(row)) labels.push('Ngoài giờ');
  if (labels.length === 0) {
    if (hasValue(row.morningCheckIn) || hasValue(row.morningCheckOut)) labels.push('Sáng (thiếu)');
    if (hasValue(row.afternoonCheckIn) || hasValue(row.afternoonCheckOut)) labels.push('Chiều (thiếu)');
  }
  return labels;
}

const ATTENDANCE_STATUS_LABEL: Record<string, string> = {
  PRESENT: 'Đủ công',
  PARTIAL: 'Thiếu ca',
  ABSENT: 'Vắng / chưa chấm',
  LEAVE: 'Phép',
  BUSINESS_TRIP: 'Công tác',
  DEPLOYMENT: 'Điều động',
};

export function attendanceStatusLabel(row: AttendanceStatusRow | Record<string, unknown> | null): string {
  if (!row) return 'Chưa có dữ liệu';
  const status = String(row.status ?? '');
  if (status === 'PARTIAL') {
    const parts = partialStatusLabels(row);
    return parts.length > 0 ? parts.join(' · ') : ATTENDANCE_STATUS_LABEL.PARTIAL;
  }
  return ATTENDANCE_STATUS_LABEL[status] ?? status;
}

/** Tải file Excel báo cáo công toàn viện theo tháng. */
export async function downloadMonthlyReport(year: number, month: number, departmentId?: number) {
  const res = await api.get('/v1/attendance/report/excel', {
    params: { year, month, ...(departmentId != null ? { departmentId } : {}) },
    responseType: 'blob',
    timeout: 300000,
  });
  const blob = new Blob([res.data], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `bao-cao-cong-${year}-${String(month).padStart(2, '0')}.xlsx`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

export type LeaveBalance = {
  employeeId: number;
  year: number;
  hireDate: string;
  yearsOfService: number;
  entitlementDays: number;
  usedDays: number;
  pendingDays: number;
  remainingDays: number;
  overLimit: boolean;
  warning: string;
};

export async function fetchMyLeaveBalance(year?: number) {
  const { data } = await api.get<LeaveBalance>('/v1/attendance/leave-balance', {
    params: year != null ? { year } : {},
  });
  return data;
}

export async function fetchEmployeeLeaveBalance(employeeId: number, year?: number) {
  const { data } = await api.get<LeaveBalance>(`/v1/attendance/employees/${employeeId}/leave-balance`, {
    params: year != null ? { year } : {},
  });
  return data;
}

export function formatLeaveRange(r: WorkRequest): string {
  if (r.requestType !== 'LEAVE' && r.requestType !== 'BUSINESS_TRIP') return '';
  const end = r.endDate && r.endDate !== r.workDate ? r.endDate : '';
  const from = formatWorkDate(r.workDate);
  if (!end) return from;
  return `${from} → ${formatWorkDate(end)}`;
}

export function formatTripRange(r: WorkRequest): string {
  return formatLeaveRange(r);
}

export type DutyShiftTypeOption = {
  code: string;
  label: string;
  grantsWorkUnits: boolean;
  roleTiers: { code: string; label: string }[];
};

export type DutyShiftEntry = {
  id: number;
  workDate: string;
  shiftTypeCode: string;
  shiftTypeLabel: string;
  roleTier: string;
  roleTierLabel: string;
  bonusAmount: number;
  workUnits: number;
  postDutyPay: number;
  note: string;
};

export type DutyShiftPreview = {
  shiftTypeCode: string;
  shiftTypeLabel: string;
  roleTier: string;
  roleTierLabel: string;
  bonusAmount: number;
  workUnits: number;
  postDutyPay: number;
  suggestedRoleTier: string;
  monthlyTotalSalary: number;
};

export async function fetchDutyShiftTypes() {
  const { data } = await api.get<DutyShiftTypeOption[]>('/v1/attendance/duty-shifts/types');
  return data;
}

export async function fetchDutyShifts(employeeId: number, from: string, to: string) {
  const { data } = await api.get<DutyShiftEntry[]>(`/v1/attendance/employees/${employeeId}/duty-shifts`, {
    params: { from, to },
  });
  return data;
}

export async function previewDutyShift(
  employeeId: number,
  workDate: string,
  shiftTypeCode: string,
  roleTierCode?: string,
) {
  const { data } = await api.get<DutyShiftPreview>(`/v1/attendance/employees/${employeeId}/duty-shifts/preview`, {
    params: { workDate, shiftTypeCode, ...(roleTierCode ? { roleTierCode } : {}) },
  });
  return data;
}

export async function upsertDutyShift(
  employeeId: number,
  body: { workDate: string; shiftTypeCode: string; roleTierCode?: string; note?: string },
) {
  const { data } = await api.put<DutyShiftEntry>(`/v1/attendance/employees/${employeeId}/duty-shifts`, body);
  return data;
}

export async function deleteDutyShift(employeeId: number, workDate: string) {
  await api.delete(`/v1/attendance/employees/${employeeId}/duty-shifts/${workDate}`);
}

export type QuangTrungSupplementBody = {
  workDate: string;
  updateKind: SubmitWorkRequest['updateKind'];
  reason: string;
  requestedStart: string;
  requestedEnd: string;
  requestedAfternoonStart?: string;
  requestedAfternoonEnd?: string;
};

export type QuangTrungSupplementInfo = {
  exists: boolean;
  workDate: string;
  updateKind?: SubmitWorkRequest['updateKind'];
  reason?: string;
  morningCheckIn?: string;
  morningCheckOut?: string;
  afternoonCheckIn?: string;
  afternoonCheckOut?: string;
  status?: string;
  note?: string;
};

export const QUANG_TRUNG_KIND_OPTIONS = UPDATE_KIND_OPTIONS.map((o) => ({
  value: o.value,
  label: o.label,
}));

export function isQuangTrungRow(row: Record<string, unknown> | null | undefined): boolean {
  if (!row) return false;
  if (row.quangTrung === true) return true;
  const note = String(row.note ?? '');
  return note.includes('Bổ sung công Quang Trung');
}

export async function fetchQuangTrungSupplement(employeeId: number, workDate: string) {
  const { data } = await api.get<QuangTrungSupplementInfo>(
    `/v1/attendance/employees/${employeeId}/quang-trung-supplement`,
    { params: { workDate } },
  );
  return data;
}

export async function applyQuangTrungSupplement(employeeId: number, body: QuangTrungSupplementBody) {
  const { data } = await api.put(`/v1/attendance/employees/${employeeId}/quang-trung-supplement`, body);
  return data;
}

export async function deleteQuangTrungSupplement(employeeId: number, workDate: string) {
  await api.delete(`/v1/attendance/employees/${employeeId}/quang-trung-supplement/${workDate}`);
}

export type CongHoSupplementBody = QuangTrungSupplementBody;
export type CongHoSupplementInfo = QuangTrungSupplementInfo;

export const CONG_HO_KIND_OPTIONS = QUANG_TRUNG_KIND_OPTIONS;

export function isCongHoRow(row: Record<string, unknown> | null | undefined): boolean {
  if (!row) return false;
  if (row.congHo === true) return true;
  const note = String(row.note ?? '');
  return note.includes('Bổ sung công hộ');
}

export async function fetchCongHoSupplement(employeeId: number, workDate: string) {
  const { data } = await api.get<CongHoSupplementInfo>(
    `/v1/attendance/employees/${employeeId}/cong-ho-supplement`,
    { params: { workDate } },
  );
  return data;
}

export async function applyCongHoSupplement(employeeId: number, body: CongHoSupplementBody) {
  const { data } = await api.put(`/v1/attendance/employees/${employeeId}/cong-ho-supplement`, body);
  return data;
}

export async function deleteCongHoSupplement(employeeId: number, workDate: string) {
  await api.delete(`/v1/attendance/employees/${employeeId}/cong-ho-supplement/${workDate}`);
}
