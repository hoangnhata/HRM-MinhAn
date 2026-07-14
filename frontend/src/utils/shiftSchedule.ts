export type PunchWindowConfig = {
  morningInBeforeMin: number;
  morningInAfterMin: number;
  morningOutBeforeMin: number;
  morningOutAfterMin: number;
  afternoonInBeforeMin: number;
  afternoonInAfterMin: number;
  afternoonOutBeforeMin: number;
  afternoonOutAfterMin: number;
};

export const DEFAULT_PUNCH_WINDOWS: PunchWindowConfig = {
  morningInBeforeMin: 60,
  morningInAfterMin: 120,
  morningOutBeforeMin: 60,
  morningOutAfterMin: 30,
  afternoonInBeforeMin: 30,
  afternoonInAfterMin: 60,
  afternoonOutBeforeMin: 60,
  afternoonOutAfterMin: 60,
};

export type ShiftScheduleInfo = {
  summer: boolean;
  seasonLabel: string;
  periodLabel: string;
  morningStart: string;
  morningEnd: string;
  afternoonStart: string;
  afternoonEnd: string;
  morningHours: number;
  afternoonHours: number;
  totalHours?: number;
  morningUnits: number;
  afternoonUnits: number;
  morningUnitsLabel?: string;
  afternoonUnitsLabel?: string;
  referenceDate?: string;
  continuousShift?: boolean;
  continuousLabel?: string;
  youngChild?: boolean;
  youngChildLabel?: string;
  effectiveDayHours?: number;
  periodYear?: number;
  periodMonth?: number;
};

export type ShiftSeasonConfig = {
  morningStart: string;
  morningEnd: string;
  afternoonStart: string;
  afternoonEnd: string;
  morningUnits: number;
  afternoonUnits: number;
  morningHours: number;
  afternoonHours: number;
  punchWindows?: PunchWindowConfig;
};

export type ShiftConfigAdminView = {
  summer: ShiftSeasonConfig;
  winter: ShiftSeasonConfig;
  periodLabels: { summer: string; winter: string };
};

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Parse YYYY-MM-DD theo giờ địa phương (tránh lệch múi giờ). */
export function parseLocalDate(iso: string): Date | null {
  if (!iso || !ISO_DATE.test(iso)) return null;
  const d = new Date(`${iso}T12:00:00`);
  return Number.isNaN(d.getTime()) ? null : d;
}

function toLocalIso(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function resolveDate(input?: Date | string): Date {
  if (typeof input === 'string') {
    return parseLocalDate(input) ?? new Date();
  }
  if (input instanceof Date && !Number.isNaN(input.getTime())) {
    return input;
  }
  return new Date();
}

export function isSummer(date: Date): boolean {
  const m = date.getMonth() + 1;
  const d = date.getDate();
  if (m < 4 || m > 10) return false;
  if (m > 4 && m < 10) return true;
  if (m === 4) return d >= 15;
  return d < 16;
}

export function scheduleForDate(input?: Date | string): ShiftScheduleInfo {
  const refIso = typeof input === 'string' && parseLocalDate(input) ? input : undefined;
  const date = resolveDate(input);
  const summer = isSummer(date);
  return {
    summer,
    seasonLabel: summer ? 'Mùa hè' : 'Mùa đông',
    periodLabel: summer ? '15/4 – 15/10' : '16/10 – 14/4',
    morningStart: summer ? '07:00' : '07:30',
    morningEnd: '12:00',
    afternoonStart: '14:00',
    afternoonEnd: summer ? '17:00' : '17:30',
    morningHours: summer ? 5 : 4.5,
    afternoonHours: summer ? 3 : 3.5,
    morningUnits: 2 / 3,
    afternoonUnits: 1 / 3,
    morningUnitsLabel: '0,67 công',
    afternoonUnitsLabel: '0,33 công',
    referenceDate: refIso ?? toLocalIso(date),
  };
}
/** Số giờ giữa hai mốc HH:mm (cùng ngày). */
export function hoursBetweenTimes(start: string, end: string): number {
  const [sh, sm] = start.split(':').map(Number);
  const [eh, em] = end.split(':').map(Number);
  if ([sh, sm, eh, em].some((n) => Number.isNaN(n))) return 0;
  return (eh * 60 + em - (sh * 60 + sm)) / 60;
}

/** Ca thông tầm: tổng giờ từ giờ vào đầu ngày đến giờ ra cuối ngày (không trừ nghỉ trưa). */
export function continuousShiftHours(
  schedule: Pick<ShiftScheduleInfo, 'morningStart' | 'afternoonEnd'>,
): number {
  return hoursBetweenTimes(schedule.morningStart, schedule.afternoonEnd);
}

/** Hiển thị HH:mm → dạng dễ đọc (7h00, 14h30). */
export function formatShiftTime(time: string): string {
  const [h, m] = time.split(':').map(Number);
  if (Number.isNaN(h)) return time;
  const mm = Number.isNaN(m) ? '00' : String(m).padStart(2, '0');
  return `${h}h${mm}`;
}

export function scheduleSummaryLine(s: ShiftScheduleInfo): string {
  return `Ca sáng ${formatShiftTime(s.morningStart)}–${formatShiftTime(s.morningEnd)} (${s.morningHours}h, ${s.morningUnitsLabel ?? '0,67 công'}) · Ca chiều ${formatShiftTime(s.afternoonStart)}–${formatShiftTime(s.afternoonEnd)} (${s.afternoonHours}h, ${s.afternoonUnitsLabel ?? '0,33 công'})`;
}

/** Quy đổi đơn vị công ca → số giờ làm thực tế. */
export function workedHoursFromUnits(workUnits: number, shiftUnits: number, scheduledHours: number): number {
  if (!workUnits || workUnits <= 0 || !shiftUnits) return 0;
  return (workUnits / shiftUnits) * scheduledHours;
}

/**
 * Giờ hiển thị trên bảng công.
 * - Trong trần ca: quy theo giờ ca (2/3 → 5h mùa hè).
 * - Vượt trần / chỉ điều động: quy theo giờ ngày (công × tổng giờ ngày),
 *   vì công điều động = (giờ × 1,5) / giờ ngày.
 */
export function displayHoursFromUnits(
  workUnits: number,
  shiftUnits: number,
  scheduledHours: number,
  dayHours: number,
  opts?: { hasPunch?: boolean },
): number {
  if (!workUnits || workUnits <= 0) return 0;
  const dayH = dayHours > 0 ? dayHours : scheduledHours || 8;
  const hasPunch = opts?.hasPunch === true;
  if (!hasPunch || workUnits > shiftUnits + 0.001) {
    // Điều động / làm thêm lưu theo phân số ngày
    if (!hasPunch) {
      return workUnits * dayH;
    }
    // Có chấm + vượt trần: giờ ca + phần vượt × giờ ngày
    const base = scheduledHours > 0 ? scheduledHours : workedHoursFromUnits(shiftUnits, shiftUnits, scheduledHours);
    return base + (workUnits - shiftUnits) * dayH;
  }
  return workedHoursFromUnits(workUnits, shiftUnits, scheduledHours);
}

export function formatWorkedHours(hours: number): string {
  if (!hours || hours <= 0) return '—';
  const rounded = Math.round(hours * 10) / 10;
  if (Math.abs(rounded - Math.round(rounded)) < 0.05) {
    return `${Math.round(rounded)}h`;
  }
  return `${rounded.toFixed(1).replace('.', ',')}h`;
}

/**
 * Chuẩn hóa công về bội số của 1/3 khi gần đúng (tính tổng chính xác 2/3+1/3=1).
 */
export function normalizeWorkUnits(n: number): number {
  if (!Number.isFinite(n) || n === 0) return 0;
  const thirds = Math.round(n * 3);
  if (Math.abs(n * 3 - thirds) < 0.05) return thirds / 3;
  return n;
}

/**
 * Hiển thị công dạng thập phân như cũ (0,67 / 0,33 / 1,00).
 * Tính toán bên trong vẫn dùng 2/3 và 1/3.
 */
export function formatWorkUnits(n: number | null | undefined, opts?: { suffix?: boolean }): string {
  if (n == null || Number.isNaN(Number(n))) return '—';
  const v = normalizeWorkUnits(Number(n));
  const s = v.toFixed(2).replace('.', ',');
  return opts?.suffix ? `${s} công` : s;
}

export function formatPunchTime(raw: string | null | undefined): string {
  if (!raw || !String(raw).trim()) return '—';
  const t = String(raw).slice(0, 5);
  return formatShiftTime(t);
}
