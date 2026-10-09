import AccessTimeOutlinedIcon from '@mui/icons-material/AccessTimeOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import SwapHorizOutlinedIcon from '@mui/icons-material/SwapHorizOutlined';
import {
  Alert,
  Box,
  Chip,
  Grid,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import * as att from '../services/attendanceService';
import { DatePickerField, TimePickerField, dateTimeFieldSx } from './ui/DateTimeFields';
import { FormSection, InfoBanner, RequestFlowSteps, SelectableChip, WorkRequestDialogShell } from './work/WorkRequestFormUi';
import { scheduleForDate, type ShiftScheduleInfo } from '../utils/shiftSchedule';
import { deploymentFlowSteps, isNursingBlockTitle } from '../utils/nursingBlock';
import { endOfMonthLocalIso, startOfMonthLocalIso, todayLocalIso } from '../utils/dateFormat';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  employeeId: number;
  employeeName: string;
  /** Chức danh — dùng để hiện bước Trưởng phòng ĐD (khối ĐD–KTV–HS–Thư ký). */
  positionTitle?: string | null;
  departmentName?: string | null;
  workDate: string;
  schedule?: ShiftScheduleInfo | null;
  /** Ngày này đã gắn ca thông tầm trên bảng công. */
  continuousShift?: boolean;
  /** Tháng đang xem trên bảng công — giới hạn chọn ngày trong dialog. */
  periodYear?: number;
  periodMonth?: number;
  /** null / ABSENT / LEAVE / BUSINESS_TRIP = ngày nghỉ hoặc chưa có → được điều động trong ca. */
  getDayStatus?: (date: string) => string | null | undefined;
  editRequest?: att.WorkRequest | null;
};

type TimeMode = 'OUTSIDE' | 'INSIDE' | 'MIXED';
type InsideScope = 'MORNING' | 'AFTERNOON' | 'FULL_DAY';

const fieldSx = dateTimeFieldSx;
const COEFF = 1.5;

function toMinutes(t: string): number {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + (m || 0);
}

/** Số giờ — hỗ trợ qua đêm (vd 22:00–06:00 = 8h). */
function overtimeHours(start: string, end: string): number {
  if (!start || !end) return 0;
  let mins = toMinutes(end) - toMinutes(start);
  if (mins === 0) return 0;
  if (mins < 0) mins += 24 * 60;
  return mins / 60;
}

function rangesOverlap(a0: number, a1: number, b0: number, b1: number): boolean {
  return a0 < b1 && b0 < a1;
}

function overlapsPrimarySchedule(
  start: string,
  end: string,
  morningStart: string,
  morningEnd: string,
  afternoonStart: string,
  afternoonEnd: string,
): boolean {
  const s = toMinutes(start);
  const e = toMinutes(end);
  const primary: [number, number][] = [
    [toMinutes(morningStart), toMinutes(morningEnd)],
    [toMinutes(afternoonStart), toMinutes(afternoonEnd)],
  ];
  const segments: [number, number][] =
    e > s ? [[s, e]] : e === s ? [] : [[s, 24 * 60], [0, e]];
  for (const [x0, x1] of segments) {
    for (const [y0, y1] of primary) {
      if (rangesOverlap(x0, x1, y0, y1)) return true;
    }
  }
  return false;
}

function fmtHours(h: number): string {
  if (!h) return '0';
  return (Math.round(h * 100) / 100).toString().replace('.', ',');
}

function fmtTime(t: string): string {
  return t.slice(0, 5);
}

const INSIDE_MORNING_UNITS = 1;
const INSIDE_AFTERNOON_UNITS = 0.5;

function hoursBetween(start: string, end: string): number {
  if (!start || !end) return 0;
  const mins = toMinutes(end) - toMinutes(start);
  return mins > 0 ? mins / 60 : 0;
}

function withinShift(start: string, end: string, shiftStart: string, shiftEnd: string): boolean {
  if (!start || !end) return false;
  const s = toMinutes(start);
  const e = toMinutes(end);
  return e > s && s >= toMinutes(shiftStart) && e <= toMinutes(shiftEnd);
}

function prorateInsideUnits(start: string, end: string, shiftStart: string, shiftEnd: string, shiftHours: number, full: number): number {
  if (fmtTime(start) === fmtTime(shiftStart) && fmtTime(end) === fmtTime(shiftEnd)) return full;
  const h = hoursBetween(start, end);
  if (h <= 0 || shiftHours <= 0) return 0;
  return Math.round(full * Math.min(1, h / shiftHours) * 100) / 100;
}

function continuousDayStart(sch: ShiftScheduleInfo): string {
  return (sch.continuousStart ?? sch.morningStart).slice(0, 5);
}

function continuousDayEnd(sch: ShiftScheduleInfo): string {
  return (sch.continuousEnd ?? sch.afternoonEnd).slice(0, 5);
}

function continuousDayHours(sch: ShiftScheduleInfo): number {
  if (sch.continuousHours && sch.continuousHours > 0) return sch.continuousHours;
  if (sch.effectiveDayHours && sch.effectiveDayHours > 0) return sch.effectiveDayHours;
  return hoursBetween(continuousDayStart(sch), continuousDayEnd(sch)) || 8;
}

function overlapsContinuousSchedule(
  start: string,
  end: string,
  dayStart: string,
  dayEnd: string,
): boolean {
  return overlapsPrimarySchedule(start, end, dayStart, dayEnd, dayStart, dayEnd);
}

type SpanKind = 'INSIDE' | 'OUTSIDE' | 'MIXED' | 'INVALID';

function hhmmFromMinutes(total: number): string {
  const h = Math.floor(total / 60);
  const m = total % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

/** Tách khung giờ ca thông tầm: phần giao với ca và phần trước/sau ca. */
function classifyContinuousSpan(start: string, end: string, dayStart: string, dayEnd: string) {
  const s = toMinutes(start);
  const e = toMinutes(end);
  const ds = toMinutes(dayStart);
  const de = toMinutes(dayEnd);
  if (!start || !end || e <= s || de <= ds) {
    return { kind: 'INVALID' as SpanKind, insideStart: '', insideEnd: '', outsideHours: 0 };
  }
  const insideStart = Math.max(s, ds);
  const insideEnd = Math.min(e, de);
  const hasInside = insideStart < insideEnd;
  let outside = 0;
  if (s < ds) outside += Math.min(e, ds) - s;
  if (e > de) outside += e - Math.max(s, de);
  const kind: SpanKind = hasInside && outside > 0 ? 'MIXED' : hasInside ? 'INSIDE' : 'OUTSIDE';
  return {
    kind,
    insideStart: hasInside ? hhmmFromMinutes(insideStart) : '',
    insideEnd: hasInside ? hhmmFromMinutes(insideEnd) : '',
    outsideHours: outside / 60,
    morningStart: '',
    morningEnd: '',
    afternoonStart: '',
    afternoonEnd: '',
  };
}

/** Ca sáng/chiều: phần trùng từng ca là trong ca; trước ca, nghỉ trưa và sau ca là ngoài ca. */
function classifySplitSpan(
  start: string,
  end: string,
  morningStart: string,
  morningEnd: string,
  afternoonStart: string,
  afternoonEnd: string,
) {
  const s = toMinutes(start);
  const e = toMinutes(end);
  if (!start || !end || e <= s) {
    return {
      kind: 'INVALID' as SpanKind,
      insideStart: '',
      insideEnd: '',
      outsideHours: 0,
      morningStart: '',
      morningEnd: '',
      afternoonStart: '',
      afternoonEnd: '',
    };
  }
  const clip = (w0: string, w1: string) => {
    const a = toMinutes(w0);
    const b = toMinutes(w1);
    if (!(b > a)) return null;
    const cs = Math.max(s, a);
    const ce = Math.min(e, b);
    if (ce <= cs) return null;
    return { start: cs, end: ce };
  };
  const morning = clip(morningStart, morningEnd);
  const afternoon = clip(afternoonStart, afternoonEnd);
  let inside = 0;
  if (morning) inside += morning.end - morning.start;
  if (afternoon) inside += afternoon.end - afternoon.start;
  const outside = Math.max(0, e - s - inside);
  const hasInside = inside > 0;
  const kind: SpanKind = hasInside && outside > 0 ? 'MIXED' : hasInside ? 'INSIDE' : 'OUTSIDE';
  return {
    kind,
    insideStart: '',
    insideEnd: '',
    outsideHours: outside / 60,
    morningStart: morning ? hhmmFromMinutes(morning.start) : '',
    morningEnd: morning ? hhmmFromMinutes(morning.end) : '',
    afternoonStart: afternoon ? hhmmFromMinutes(afternoon.start) : '',
    afternoonEnd: afternoon ? hhmmFromMinutes(afternoon.end) : '',
  };
}

function continuousInsideUnits(
  schedule: ShiftScheduleInfo,
  dayStart: string,
  dayEnd: string,
): { morning: number; afternoon: number; total: number } {
  const full = INSIDE_MORNING_UNITS + INSIDE_AFTERNOON_UNITS;
  const total = prorateInsideUnits(
    dayStart,
    dayEnd,
    continuousDayStart(schedule),
    continuousDayEnd(schedule),
    continuousDayHours(schedule),
    full,
  );
  const morning = Math.round(total * (INSIDE_MORNING_UNITS / full) * 100) / 100;
  const afternoon = Math.round((total - morning) * 100) / 100;
  return { morning, afternoon, total };
}

function insideDeploymentUnits(
  scope: InsideScope,
  schedule: ShiftScheduleInfo,
  morningStart: string,
  morningEnd: string,
  afternoonStart: string,
  afternoonEnd: string,
  continuous?: boolean,
): { morning: number; afternoon: number; total: number } {
  if (continuous) {
    return continuousInsideUnits(schedule, morningStart, morningEnd);
  }
  const mHours = schedule.morningHours || 1;
  const aHours = schedule.afternoonHours || 1;
  if (scope === 'MORNING') {
    const morning = prorateInsideUnits(
      morningStart,
      morningEnd,
      schedule.morningStart,
      schedule.morningEnd,
      mHours,
      INSIDE_MORNING_UNITS,
    );
    return { morning, afternoon: 0, total: morning };
  }
  if (scope === 'AFTERNOON') {
    const afternoon = prorateInsideUnits(
      afternoonStart,
      afternoonEnd,
      schedule.afternoonStart,
      schedule.afternoonEnd,
      aHours,
      INSIDE_AFTERNOON_UNITS,
    );
    return { morning: 0, afternoon, total: afternoon };
  }
  const morning = prorateInsideUnits(
    morningStart,
    morningEnd,
    schedule.morningStart,
    schedule.morningEnd,
    mHours,
    INSIDE_MORNING_UNITS,
  );
  const afternoon = prorateInsideUnits(
    afternoonStart,
    afternoonEnd,
    schedule.afternoonStart,
    schedule.afternoonEnd,
    aHours,
    INSIDE_AFTERNOON_UNITS,
  );
  return { morning, afternoon, total: Math.round((morning + afternoon) * 100) / 100 };
}

function isOffOrEmptyDay(status?: string | null): boolean {
  if (status == null || status === '') return true;
  const s = status.toUpperCase();
  return (
    s === 'ABSENT' ||
    s === 'LEAVE' ||
    s === 'UNPAID_LEAVE' ||
    s === 'PERSONAL_LEAVE' ||
    s === 'BUSINESS_TRIP' ||
    s === 'SEMINAR'
  );
}

function isWorkedDay(status?: string | null): boolean {
  if (status == null || status === '') return false;
  const s = status.toUpperCase();
  return s === 'PRESENT' || s === 'PARTIAL';
}

function monthStartIso(year: number, month: number): string {
  return startOfMonthLocalIso(year, month);
}

function deployMaxDate(periodYear?: number, periodMonth?: number): string {
  const today = todayLocalIso();
  if (periodYear && periodMonth) {
    const monthEnd = endOfMonthLocalIso(monthStartIso(periodYear, periodMonth));
    const [ty, tm] = today.split('-').map(Number);
    if (periodYear < ty || (periodYear === ty && periodMonth < tm)) {
      return monthEnd;
    }
    if (periodYear === ty && periodMonth === tm) {
      return endOfMonthLocalIso(today);
    }
    return monthEnd;
  }
  return endOfMonthLocalIso(today);
}

function deploymentModeFromRequest(r: att.WorkRequest): { timeMode: TimeMode; insideScope: InsideScope } {
  if (r.deploymentMixedShift) return { timeMode: 'MIXED', insideScope: 'FULL_DAY' };
  const inside =
    r.deploymentInsideShift === true ||
    (r.deploymentInsideShift !== false &&
      (r.shiftScope === 'MORNING' ||
        r.shiftScope === 'AFTERNOON' ||
        Boolean(r.requestedAfternoonStart?.trim()) ||
        Boolean(r.requestedAfternoonEnd?.trim())));
  if (!inside) {
    return { timeMode: 'OUTSIDE', insideScope: 'FULL_DAY' };
  }
  if (r.shiftScope === 'MORNING') return { timeMode: 'INSIDE', insideScope: 'MORNING' };
  if (r.shiftScope === 'AFTERNOON') return { timeMode: 'INSIDE', insideScope: 'AFTERNOON' };
  return { timeMode: 'INSIDE', insideScope: 'FULL_DAY' };
}

export function DeploymentRequestDialog({
  open,
  onClose,
  onSubmitted,
  employeeId,
  employeeName,
  positionTitle,
  departmentName,
  workDate: defaultDate,
  schedule: scheduleProp,
  continuousShift = false,
  periodYear,
  periodMonth,
  getDayStatus,
  editRequest,
}: Props) {
  const accent = '#0f766e';
  const isEditing = Boolean(editRequest);
  const resolvedEmployeeId = editRequest?.employeeId ?? employeeId;
  const resolvedEmployeeName = editRequest?.employeeName ?? employeeName;
  const resolvedPositionTitle = editRequest?.positionTitle ?? positionTitle;
  const resolvedDepartmentName = editRequest?.departmentName ?? departmentName;
  const nursingFlow = isNursingBlockTitle(resolvedPositionTitle, resolvedDepartmentName);
  const today = todayLocalIso();
  const minDate =
    periodYear && periodMonth ? monthStartIso(periodYear, periodMonth) : undefined;
  const maxDate = deployMaxDate(periodYear, periodMonth);

  const [workDate, setWorkDate] = useState(defaultDate);
  const [daySchedule, setDaySchedule] = useState<ShiftScheduleInfo | null>(null);
  const schedule = daySchedule ?? scheduleProp ?? scheduleForDate(workDate);

  const [timeMode, setTimeMode] = useState<TimeMode>('INSIDE');
  const [insideScope, setInsideScope] = useState<InsideScope>('FULL_DAY');
  const [startTime, setStartTime] = useState('18:00');
  const [endTime, setEndTime] = useState('21:00');
  const [morningStart, setMorningStart] = useState(schedule.morningStart);
  const [morningEnd, setMorningEnd] = useState(schedule.morningEnd);
  const [afternoonStart, setAfternoonStart] = useState(schedule.afternoonStart);
  const [afternoonEnd, setAfternoonEnd] = useState(schedule.afternoonEnd);
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const offDay = isOffOrEmptyDay(getDayStatus?.(workDate));
  const workedDay = isWorkedDay(getDayStatus?.(workDate));
  const dayContinuous = daySchedule
    ? Boolean(daySchedule.continuousShift)
    : continuousShift || Boolean(schedule.continuousShift);

  function clampDate(iso: string): string {
    let d = iso;
    if (minDate && d < minDate) d = minDate;
    if (d > maxDate) d = maxDate;
    return d;
  }

  function applyDaySchedule(d: string, sch: ShiftScheduleInfo, resetTimes: boolean) {
    setDaySchedule(sch);
    const cont = Boolean(sch.continuousShift);
    const cStart = continuousDayStart(sch);
    const cEnd = continuousDayEnd(sch);
    if (editRequest && resetTimes) {
      const requestedStart = editRequest.requestedStart?.slice(0, 5) || '';
      const requestedEnd = editRequest.requestedEnd?.slice(0, 5) || '';
      const singleRange = !editRequest.requestedAfternoonStart && !editRequest.requestedAfternoonEnd;
      const span = !singleRange
        ? null
        : cont
          ? classifyContinuousSpan(requestedStart, requestedEnd, cStart, cEnd)
          : classifySplitSpan(
              requestedStart,
              requestedEnd,
              sch.morningStart,
              sch.morningEnd,
              sch.afternoonStart,
              sch.afternoonEnd,
            );
      const inferred = deploymentModeFromRequest(editRequest);
      const mode: TimeMode =
        editRequest.deploymentMixedShift || span?.kind === 'MIXED'
          ? 'MIXED'
          : cont && span?.kind === 'INSIDE'
            ? 'INSIDE'
            : cont && span?.kind === 'OUTSIDE'
              ? 'OUTSIDE'
              : inferred.timeMode;
      setTimeMode(mode);
      setInsideScope(cont ? 'FULL_DAY' : inferred.insideScope);
      setReason(editRequest.reason || '');
      if (mode === 'MIXED' || mode === 'OUTSIDE') {
        setStartTime(requestedStart || (mode === 'OUTSIDE' ? '18:00' : cStart));
        setEndTime(requestedEnd || (mode === 'OUTSIDE' ? '21:00' : cEnd));
      }
      if (cont) {
        setMorningStart(mode === 'INSIDE' ? requestedStart || cStart : cStart);
        setMorningEnd(mode === 'INSIDE' ? requestedEnd || cEnd : cEnd);
      } else {
        setMorningStart(requestedStart || sch.morningStart);
        setMorningEnd(requestedEnd || sch.morningEnd);
        setAfternoonStart(editRequest.requestedAfternoonStart?.slice(0, 5) || sch.afternoonStart);
        setAfternoonEnd(editRequest.requestedAfternoonEnd?.slice(0, 5) || sch.afternoonEnd);
      }
      return;
    }
    if (!resetTimes) {
      if (cont) {
        setMorningStart(cStart);
        setMorningEnd(cEnd);
        setInsideScope('FULL_DAY');
      } else {
        setMorningStart(sch.morningStart);
        setMorningEnd(sch.morningEnd);
        setAfternoonStart(sch.afternoonStart);
        setAfternoonEnd(sch.afternoonEnd);
      }
      return;
    }
    const empty = isOffOrEmptyDay(getDayStatus?.(d));
    const worked = isWorkedDay(getDayStatus?.(d));
    setTimeMode(worked || empty ? 'INSIDE' : 'OUTSIDE');
    setInsideScope(cont ? 'FULL_DAY' : worked ? 'MORNING' : 'FULL_DAY');
    setStartTime('18:00');
    setEndTime('21:00');
    setMorningStart(cont ? cStart : sch.morningStart);
    setMorningEnd(cont ? cEnd : sch.morningEnd);
    setAfternoonStart(sch.afternoonStart);
    setAfternoonEnd(sch.afternoonEnd);
    setReason('');
  }

  useEffect(() => {
    if (!open) return;
    const initialDate = editRequest?.workDate ?? defaultDate;
    const d = clampDate(initialDate);
    setWorkDate(d);
    setErr(null);
    let cancelled = false;
    const fallback = scheduleProp ?? scheduleForDate(d);
    applyDaySchedule(d, fallback, true);
    att
      .fetchShiftSchedule(d, resolvedEmployeeId)
      .then((sch) => {
        if (!cancelled) applyDaySchedule(d, sch, true);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, defaultDate, minDate, maxDate, scheduleProp, editRequest, continuousShift, resolvedEmployeeId]);

  function onDateChange(next: string) {
    const clamped = clampDate(next);
    setWorkDate(clamped);
    const fallback = scheduleProp ?? scheduleForDate(clamped);
    applyDaySchedule(clamped, fallback, false);
    att
      .fetchShiftSchedule(clamped, resolvedEmployeeId)
      .then((sch) => applyDaySchedule(clamped, sch, false))
      .catch(() => {});
  }

  const actualHours = useMemo(() => {
    if (timeMode === 'INSIDE') return 0;
    return overtimeHours(startTime, endTime);
  }, [timeMode, startTime, endTime]);

  const insideUnits = useMemo(
    () =>
      timeMode === 'INSIDE'
        ? insideDeploymentUnits(
            insideScope,
            schedule,
            morningStart,
            morningEnd,
            afternoonStart,
            afternoonEnd,
            dayContinuous,
          )
        : null,
    [timeMode, insideScope, schedule, morningStart, morningEnd, afternoonStart, afternoonEnd, dayContinuous],
  );

  const creditedHours = timeMode === 'INSIDE' ? (insideUnits?.total ?? 0) : actualHours * COEFF;
  const dayHours = dayContinuous
    ? continuousDayHours(schedule)
    : (schedule.morningHours ?? 0) + (schedule.afternoonHours ?? 0) || 8;
  const mixedSpan = useMemo(() => {
    if (dayContinuous) {
      return classifyContinuousSpan(
        startTime,
        endTime,
        continuousDayStart(schedule),
        continuousDayEnd(schedule),
      );
    }
    return classifySplitSpan(
      startTime,
      endTime,
      schedule.morningStart,
      schedule.morningEnd,
      schedule.afternoonStart,
      schedule.afternoonEnd,
    );
  }, [dayContinuous, startTime, endTime, schedule]);
  const mixedInsideUnits =
    timeMode === 'MIXED' && mixedSpan?.kind === 'MIXED'
      ? dayContinuous
        ? continuousInsideUnits(schedule, mixedSpan.insideStart, mixedSpan.insideEnd)
        : {
            morning: mixedSpan.morningStart
              ? prorateInsideUnits(
                  mixedSpan.morningStart,
                  mixedSpan.morningEnd,
                  schedule.morningStart,
                  schedule.morningEnd,
                  schedule.morningHours || 1,
                  INSIDE_MORNING_UNITS,
                )
              : 0,
            afternoon: mixedSpan.afternoonStart
              ? prorateInsideUnits(
                  mixedSpan.afternoonStart,
                  mixedSpan.afternoonEnd,
                  schedule.afternoonStart,
                  schedule.afternoonEnd,
                  schedule.afternoonHours || 1,
                  INSIDE_AFTERNOON_UNITS,
                )
              : 0,
            total: 0,
          }
      : null;
  if (mixedInsideUnits && !dayContinuous) {
    mixedInsideUnits.total =
      Math.round((mixedInsideUnits.morning + mixedInsideUnits.afternoon) * 100) / 100;
  }
  const mixedOutsideUnits =
    timeMode === 'MIXED' && mixedSpan
      ? Math.round(((mixedSpan.outsideHours * COEFF) / dayHours) * 100) / 100
      : 0;

  const workUnits =
    timeMode === 'INSIDE'
      ? insideUnits?.total ?? 0
      : timeMode === 'MIXED'
        ? (mixedInsideUnits?.total ?? 0) + mixedOutsideUnits
        : Math.round((actualHours * COEFF) / dayHours * 100) / 100;

  const overlapsPrimary = useMemo(() => {
    if (timeMode !== 'OUTSIDE' || offDay) return false;
    if (dayContinuous) {
      return overlapsContinuousSchedule(
        startTime,
        endTime,
        continuousDayStart(schedule),
        continuousDayEnd(schedule),
      );
    }
    return overlapsPrimarySchedule(
      startTime,
      endTime,
      schedule.morningStart,
      schedule.morningEnd,
      schedule.afternoonStart,
      schedule.afternoonEnd,
    );
  }, [timeMode, offDay, startTime, endTime, schedule, dayContinuous]);

  const overnight =
    timeMode === 'OUTSIDE' && toMinutes(endTime) <= toMinutes(startTime) && actualHours > 0;

  const timeLabel = useMemo(() => {
    if (timeMode === 'INSIDE') {
      if (dayContinuous) {
        return `Ca thông tầm ${fmtTime(morningStart)}–${fmtTime(morningEnd)} · ${fmtHours(insideUnits?.total ?? 0)} công`;
      }
      if (insideScope === 'MORNING') {
        return `Ca sáng ${fmtTime(morningStart)}–${fmtTime(morningEnd)} · ${fmtHours(insideUnits?.morning ?? 0)} công`;
      }
      if (insideScope === 'AFTERNOON') {
        return `Ca chiều ${fmtTime(afternoonStart)}–${fmtTime(afternoonEnd)} · ${fmtHours(insideUnits?.afternoon ?? 0)} công`;
      }
      return `Cả ngày · ${fmtHours(insideUnits?.total ?? 0)} công`;
    }
    if (timeMode === 'OUTSIDE') {
      return `${fmtTime(startTime)} – ${fmtTime(endTime)}${overnight ? ' (+1 ngày)' : ''}`;
    }
    if (timeMode === 'MIXED' && mixedSpan?.kind === 'MIXED') {
      return `${fmtTime(startTime)}–${fmtTime(endTime)} · trong ca ${fmtTime(mixedSpan.insideStart)}–${fmtTime(mixedSpan.insideEnd)} · ngoài ca ${fmtHours(mixedSpan.outsideHours)}h`;
    }
    return '';
  }, [
    timeMode,
    insideScope,
    startTime,
    endTime,
    overnight,
    morningStart,
    morningEnd,
    afternoonStart,
    afternoonEnd,
    insideUnits,
    dayContinuous,
    mixedSpan,
  ]);

  function applyInsideScope(scope: InsideScope) {
    setInsideScope(scope);
    const sch = schedule;
    if (dayContinuous) {
      setMorningStart(continuousDayStart(sch));
      setMorningEnd(continuousDayEnd(sch));
      setInsideScope('FULL_DAY');
      return;
    }
    if (scope === 'MORNING' || scope === 'FULL_DAY') {
      setMorningStart(sch.morningStart);
      setMorningEnd(sch.morningEnd);
    }
    if (scope === 'AFTERNOON' || scope === 'FULL_DAY') {
      setAfternoonStart(sch.afternoonStart);
      setAfternoonEnd(sch.afternoonEnd);
    }
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!reason.trim()) {
      setErr('Nhập nội dung điều động.');
      return;
    }
    if (workDate > maxDate) {
      setErr(`Chỉ điều động đến ${maxDate}.`);
      return;
    }
    if (minDate && workDate < minDate) {
      setErr(`Chọn ngày trong tháng đang xem (từ ${minDate}).`);
      return;
    }
    if (workDate > today && workDate > endOfMonthLocalIso(today)) {
      setErr('Không điều động quá hết tháng hiện tại.');
      return;
    }
    if (timeMode === 'OUTSIDE' && actualHours <= 0) {
      setErr('Nhập khung giờ hợp lệ (có thể qua đêm, ví dụ 22:00–06:00).');
      return;
    }
    if (timeMode === 'MIXED') {
      if (!mixedSpan || mixedSpan.kind === 'INVALID') {
        setErr('Nhập một khung giờ trong ngày (giờ kết thúc sau giờ bắt đầu).');
        return;
      }
      if (mixedSpan.kind === 'INSIDE') {
        setErr('Khung này nằm trọn trong ca — chọn «Trong ca».');
        return;
      }
      if (mixedSpan.kind === 'OUTSIDE') {
        setErr('Khung này nằm trọn ngoài ca — chọn «Ngoài ca».');
        return;
      }
    }
    if (overlapsPrimary) {
      const cStart = continuousDayStart(schedule);
      const cEnd = continuousDayEnd(schedule);
      setErr(
        dayContinuous
          ? `Giờ điều động không được trùng ca thông tầm (${fmtTime(cStart)}–${fmtTime(cEnd)}).`
          : `Giờ điều động không được trùng ca chính (${fmtTime(schedule.morningStart)}–${fmtTime(schedule.morningEnd)}, ${fmtTime(schedule.afternoonStart)}–${fmtTime(schedule.afternoonEnd)}).`,
      );
      return;
    }
    if (timeMode === 'INSIDE') {
      if (dayContinuous) {
        const cStart = continuousDayStart(schedule);
        const cEnd = continuousDayEnd(schedule);
        if (!withinShift(morningStart, morningEnd, cStart, cEnd)) {
          setErr(
            `Giờ ca thông tầm phải nằm trong ${fmtTime(cStart)}–${fmtTime(cEnd)} (vd chỉ làm một phần ca).`,
          );
          return;
        }
      } else {
        if (insideScope === 'MORNING' || insideScope === 'FULL_DAY') {
          if (
            !withinShift(morningStart, morningEnd, schedule.morningStart, schedule.morningEnd)
          ) {
            setErr(
              `Giờ ca sáng phải nằm trong ${fmtTime(schedule.morningStart)}–${fmtTime(schedule.morningEnd)} (vd chỉ làm 07:00–09:00).`,
            );
            return;
          }
        }
        if (insideScope === 'AFTERNOON' || insideScope === 'FULL_DAY') {
          if (
            !withinShift(
              afternoonStart,
              afternoonEnd,
              schedule.afternoonStart,
              schedule.afternoonEnd,
            )
          ) {
            setErr(
              `Giờ ca chiều phải nằm trong ${fmtTime(schedule.afternoonStart)}–${fmtTime(schedule.afternoonEnd)}.`,
            );
            return;
          }
        }
      }
      if ((insideUnits?.total ?? 0) <= 0) {
        setErr('Khung giờ điều động trong ca không hợp lệ.');
        return;
      }
    }

    setLoading(true);
    try {
      let payload: att.SubmitWorkRequest;
      if (timeMode === 'OUTSIDE' || timeMode === 'MIXED') {
        payload = {
          requestType: 'DEPLOYMENT',
          employeeId: resolvedEmployeeId,
          workDate,
          shiftScope: 'FULL_DAY',
          reason: reason.trim(),
          requestedStart: startTime.slice(0, 5),
          requestedEnd: endTime.slice(0, 5),
        };
      } else if (dayContinuous) {
        // Ca thông tầm: một khung vào–ra cả ngày, không gửi giờ chiều
        payload = {
          requestType: 'DEPLOYMENT',
          employeeId: resolvedEmployeeId,
          workDate,
          shiftScope: 'FULL_DAY',
          reason: reason.trim(),
          requestedStart: morningStart.slice(0, 5),
          requestedEnd: morningEnd.slice(0, 5),
        };
      } else if (insideScope === 'MORNING') {
        payload = {
          requestType: 'DEPLOYMENT',
          employeeId: resolvedEmployeeId,
          workDate,
          shiftScope: 'MORNING',
          reason: reason.trim(),
          requestedStart: morningStart.slice(0, 5),
          requestedEnd: morningEnd.slice(0, 5),
        };
      } else if (insideScope === 'AFTERNOON') {
        payload = {
          requestType: 'DEPLOYMENT',
          employeeId: resolvedEmployeeId,
          workDate,
          shiftScope: 'AFTERNOON',
          reason: reason.trim(),
          requestedStart: afternoonStart.slice(0, 5),
          requestedEnd: afternoonEnd.slice(0, 5),
        };
      } else {
        payload = {
          requestType: 'DEPLOYMENT',
          employeeId: resolvedEmployeeId,
          workDate,
          shiftScope: 'FULL_DAY',
          reason: reason.trim(),
          requestedStart: morningStart.slice(0, 5),
          requestedEnd: morningEnd.slice(0, 5),
          requestedAfternoonStart: afternoonStart.slice(0, 5),
          requestedAfternoonEnd: afternoonEnd.slice(0, 5),
        };
      }
      if (isEditing && editRequest) {
        await att.updateWorkRequest(editRequest.id, payload);
      } else {
        await att.submitWorkRequest(payload);
      }
      onSubmitted?.();
      onClose();
    } catch (ex: unknown) {
      const msg =
        ex && typeof ex === 'object' && 'response' in ex
          ? String((ex as { response?: { data?: { message?: string } } }).response?.data?.message ?? '')
          : '';
      setErr(msg || 'Gửi đơn điều động thất bại.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={accent}
      maxWidth="md"
      icon={<SwapHorizOutlinedIcon />}
      overline={isEditing ? 'Chỉnh sửa đơn' : 'Điều động nhân sự'}
      title={isEditing ? 'Chỉnh sửa đơn điều động' : 'Đơn điều động'}
      description="Công ×1,5. Trong ca chỉ cập nhật khi đơn đã duyệt và có đủ giờ chấm vào/ra; ngoài ca giữ cách tính hiện tại."
      formId="deployment-request-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : nursingFlow ? 'Gửi Trưởng phòng ĐD duyệt' : 'Gửi HCNS duyệt'}
      error={err}
      onSubmit={submit}
    >
      <RequestFlowSteps accent={accent} steps={deploymentFlowSteps(resolvedPositionTitle, resolvedDepartmentName)} />

      <InfoBanner>
        {nursingFlow ? (
          <>
            Nhân viên khối <strong>ĐD–KTV–HS–Thư ký</strong>: sau khi lập, đơn chuyển{' '}
            <strong>Trưởng phòng Điều dưỡng</strong> → HCNS → Giám đốc.
          </>
        ) : dayContinuous ? (
          <>
            Ngày <strong>ca thông tầm</strong> ({fmtTime(continuousDayStart(schedule))}–
            {fmtTime(continuousDayEnd(schedule))}, không nghỉ trưa). <strong>Trong ca</strong> nằm trọn trong khung
            này; <strong>Ngoài ca</strong> không trùng khung này. Nếu một khung giờ liên tục cắt cả hai, chọn{' '}
            <strong>Trong ca &amp; ngoài ca</strong> — không cần tạo hai đơn. Công ×1,5.
          </>
        ) : workedDay ? (
          <>
            Ngày <strong>đã có công chấm máy</strong> — chọn <strong>Trong ca</strong> để thay công ca điều động
            (×1,5, theo buổi hoặc cả ngày) khi đủ giờ vào/ra. <strong>Ngoài ca</strong> chỉ cộng thêm giờ ngoài
            giờ (không trùng ca chính). <strong>Trong ca &amp; ngoài ca</strong> dùng khi một khung giờ liên tục
            cắt cả hai.
          </>
        ) : offDay ? (
          <>
            Ngày <strong>chưa có công / nghỉ</strong> — chọn <strong>ngoài ca</strong>, <strong>trong ca</strong>{' '}
            (sáng / chiều / cả ngày), hoặc <strong>trong ca &amp; ngoài ca</strong> nếu một khung giờ liên tục cắt
            cả hai. Công ×1,5. Có thể nhập lại các ngày trước.
          </>
        ) : (
          <>
            Có thể điều động <strong>mọi ngày đã qua</strong> trong tháng đang xem. Công ×1,5.
          </>
        )}
      </InfoBanner>

      <FormSection title="Nhân viên điều động">
        <TextField
          fullWidth
          size="small"
          label="Họ và tên"
          value={resolvedEmployeeName}
          disabled
          sx={fieldSx}
          InputProps={{
            startAdornment: (
              <Box sx={{ display: 'flex', alignItems: 'center', mr: 1, color: 'action.active' }}>
                <PersonOutlineIcon fontSize="small" />
              </Box>
            ),
          }}
        />
      </FormSection>

      <FormSection
        title="Ngày điều động"
        subtitle={
          minDate
            ? `Cho phép: ${minDate} → ${maxDate} (kể cả ngày đã qua)`
            : `Cho phép mọi ngày đã qua đến ${maxDate}`
        }
      >
        <DatePickerField label="Ngày" required value={workDate} onChange={onDateChange} sx={fieldSx} />
      </FormSection>

      <FormSection title="Kiểu giờ điều động">
        <Grid container spacing={1}>
          <Grid item xs={4}>
            <SelectableChip
              selected={timeMode === 'OUTSIDE'}
              label="Ngoài ca"
              onClick={() => setTimeMode('OUTSIDE')}
            />
          </Grid>
          <Grid item xs={4}>
            <SelectableChip
              selected={timeMode === 'INSIDE'}
              label="Trong ca"
              onClick={() => {
                setErr(null);
                setTimeMode('INSIDE');
              }}
            />
          </Grid>
          <Grid item xs={4}>
            <SelectableChip
              selected={timeMode === 'MIXED'}
              label="Trong ca & ngoài ca"
              onClick={() => {
                setErr(null);
                setTimeMode('MIXED');
                if (dayContinuous) {
                  const start = continuousDayStart(schedule);
                  const endMin = Math.min(toMinutes(continuousDayEnd(schedule)) + 120, 23 * 60 + 59);
                  setStartTime(start);
                  setEndTime(hhmmFromMinutes(endMin));
                } else {
                  setStartTime(fmtTime(schedule.morningStart));
                  const endMin = Math.min(toMinutes(schedule.afternoonEnd) + 120, 23 * 60 + 59);
                  setEndTime(hhmmFromMinutes(endMin));
                }
              }}
            />
          </Grid>
        </Grid>
        {!offDay && timeMode === 'OUTSIDE' && (
          <Alert severity="info" variant="outlined" sx={{ mt: 1.25, borderRadius: 2 }}>
            {dayContinuous ? (
              <>
                Ca thông tầm (không trùng khi chọn ngoài ca):{' '}
                <strong>
                  {fmtTime(continuousDayStart(schedule))}–{fmtTime(continuousDayEnd(schedule))}
                </strong>
              </>
            ) : (
              <>
                Ca chính (không trùng khi chọn ngoài ca):{' '}
                <strong>
                  {fmtTime(schedule.morningStart)}–{fmtTime(schedule.morningEnd)}
                </strong>{' '}
                ·{' '}
                <strong>
                  {fmtTime(schedule.afternoonStart)}–{fmtTime(schedule.afternoonEnd)}
                </strong>
              </>
            )}
          </Alert>
        )}
      </FormSection>

      {timeMode === 'OUTSIDE' || timeMode === 'MIXED' ? (
        <FormSection
          title={timeMode === 'MIXED' ? 'Khung giờ liên tục' : 'Giờ ngoài ca'}
          subtitle={
            timeMode === 'MIXED'
              ? dayContinuous
                ? `Một khung cắt qua ca thông tầm ${fmtTime(continuousDayStart(schedule))}–${fmtTime(continuousDayEnd(schedule))}. Phần giao với ca tính trong ca, phần trước và sau ca tính ngoài ca.`
                : `Một khung liên tục. Phần trùng ca sáng ${fmtTime(schedule.morningStart)}–${fmtTime(schedule.morningEnd)} và ca chiều ${fmtTime(schedule.afternoonStart)}–${fmtTime(schedule.afternoonEnd)} tính trong ca; trước ca, nghỉ trưa và sau ca tính ngoài ca.`
              : 'Nhập tự do — kể cả ban đêm (vd 22:00–06:00).'
          }
        >
          <Grid container spacing={1.5}>
            <Grid item xs={12} sm={6}>
              <TimePickerField label="Từ giờ" required value={startTime} onChange={setStartTime} sx={fieldSx} />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TimePickerField label="Đến giờ" required value={endTime} onChange={setEndTime} sx={fieldSx} />
            </Grid>
          </Grid>
          {overnight && (
            <Typography variant="caption" color="primary" display="block" sx={{ mt: 1, fontWeight: 600 }}>
              Qua đêm: kết thúc vào sáng hôm sau · {fmtHours(actualHours)} giờ
            </Typography>
          )}
          {timeMode === 'MIXED' && mixedSpan && (
            <Alert
              severity={mixedSpan.kind === 'MIXED' ? 'info' : 'warning'}
              sx={{ mt: 1.25, borderRadius: 2 }}
            >
              {mixedSpan.kind === 'MIXED' ? (
                <>
                  {dayContinuous ? (
                    <>
                      Trong ca <strong>{fmtTime(mixedSpan.insideStart)}–{fmtTime(mixedSpan.insideEnd)}</strong>
                    </>
                  ) : (
                    <>
                      {mixedSpan.morningStart ? (
                        <>
                          Sáng <strong>{fmtTime(mixedSpan.morningStart)}–{fmtTime(mixedSpan.morningEnd)}</strong>
                        </>
                      ) : null}
                      {mixedSpan.morningStart && mixedSpan.afternoonStart ? ' · ' : null}
                      {mixedSpan.afternoonStart ? (
                        <>
                          Chiều <strong>{fmtTime(mixedSpan.afternoonStart)}–{fmtTime(mixedSpan.afternoonEnd)}</strong>
                        </>
                      ) : null}
                    </>
                  )}
                  {' · '}
                  {fmtHours(mixedInsideUnits?.total ?? 0)} công (khi đủ giờ chấm). Ngoài ca{' '}
                  <strong>{fmtHours(mixedSpan.outsideHours)}h</strong>
                  {' · +'}
                  {fmtHours(mixedOutsideUnits)} công.
                </>
              ) : mixedSpan.kind === 'INSIDE' ? (
                'Khung này nằm trọn trong ca — chuyển «Trong ca».'
              ) : mixedSpan.kind === 'OUTSIDE' ? (
                'Khung này nằm trọn ngoài ca — chuyển «Ngoài ca».'
              ) : (
                'Giờ kết thúc phải sau giờ bắt đầu, trong cùng một ngày.'
              )}
            </Alert>
          )}
          {overlapsPrimary && (
            <Alert severity="warning" sx={{ mt: 1.25, borderRadius: 2 }}>
              {dayContinuous
                ? 'Khung giờ đang trùng ca thông tầm. Chọn giờ ngoài khung ca, chuyển «Trong ca», hoặc «Trong ca & ngoài ca» nếu muốn giữ một khung liên tục.'
                : 'Khung giờ đang trùng ca chính — hãy chọn giờ ngoài ca sáng/chiều.'}
            </Alert>
          )}
        </FormSection>
      ) : dayContinuous ? (
        <FormSection
          title="Giờ ca thông tầm"
          subtitle={`Một khung vào–ra trong ${fmtTime(continuousDayStart(schedule))}–${fmtTime(continuousDayEnd(schedule))} (có thể chỉ một phần ca). Tối đa 1,5 công.`}
        >
          <Grid container spacing={1.5}>
            <Grid item xs={12} sm={6}>
              <TimePickerField
                label="Từ giờ"
                required
                value={morningStart}
                onChange={setMorningStart}
                sx={fieldSx}
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TimePickerField
                label="Đến giờ"
                required
                value={morningEnd}
                onChange={setMorningEnd}
                sx={fieldSx}
              />
            </Grid>
          </Grid>
          <Alert severity="info" variant="outlined" sx={{ mt: 1.25, borderRadius: 2 }}>
            Làm cả ca → 1,5 công; làm một phần → công tỷ lệ theo giờ trong khung thông tầm.
          </Alert>
        </FormSection>
      ) : (
        <>
          <FormSection
            title="Ca điều động"
            subtitle="Chọn buổi rồi nhập giờ trong khung ca (có thể chỉ một phần, vd sáng 07:00–09:00)."
          >
            <Stack spacing={1}>
              <SelectableChip
                selected={insideScope === 'MORNING'}
                label="Ca sáng — tối đa 1 công"
                onClick={() => applyInsideScope('MORNING')}
              />
              <SelectableChip
                selected={insideScope === 'AFTERNOON'}
                label="Ca chiều — tối đa 0,5 công"
                onClick={() => applyInsideScope('AFTERNOON')}
              />
              <SelectableChip
                selected={insideScope === 'FULL_DAY'}
                label="Cả ngày — tối đa 1,5 công"
                onClick={() => applyInsideScope('FULL_DAY')}
              />
            </Stack>
            <Alert severity="info" variant="outlined" sx={{ mt: 1.25, borderRadius: 2 }}>
              Khung ca: sáng {fmtTime(schedule.morningStart)}–{fmtTime(schedule.morningEnd)} · chiều{' '}
              {fmtTime(schedule.afternoonStart)}–{fmtTime(schedule.afternoonEnd)}. Làm cả ca → đủ mức tối đa;
              làm một phần → công tỷ lệ theo giờ.
            </Alert>
          </FormSection>
          {(insideScope === 'MORNING' || insideScope === 'FULL_DAY') && (
            <FormSection title="Giờ ca sáng" subtitle={`Trong khoảng ${fmtTime(schedule.morningStart)}–${fmtTime(schedule.morningEnd)}`}>
              <Grid container spacing={1.5}>
                <Grid item xs={12} sm={6}>
                  <TimePickerField
                    label="Từ giờ"
                    required
                    value={morningStart}
                    onChange={setMorningStart}
                    sx={fieldSx}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <TimePickerField
                    label="Đến giờ"
                    required
                    value={morningEnd}
                    onChange={setMorningEnd}
                    sx={fieldSx}
                  />
                </Grid>
              </Grid>
            </FormSection>
          )}
          {(insideScope === 'AFTERNOON' || insideScope === 'FULL_DAY') && (
            <FormSection
              title="Giờ ca chiều"
              subtitle={`Trong khoảng ${fmtTime(schedule.afternoonStart)}–${fmtTime(schedule.afternoonEnd)}`}
            >
              <Grid container spacing={1.5}>
                <Grid item xs={12} sm={6}>
                  <TimePickerField
                    label="Từ giờ"
                    required
                    value={afternoonStart}
                    onChange={setAfternoonStart}
                    sx={fieldSx}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <TimePickerField
                    label="Đến giờ"
                    required
                    value={afternoonEnd}
                    onChange={setAfternoonEnd}
                    sx={fieldSx}
                  />
                </Grid>
              </Grid>
            </FormSection>
          )}
        </>
      )}

      <Box
        sx={{
          p: 1.75,
          borderRadius: 2.5,
          border: `1px solid ${alpha(accent, 0.2)}`,
          bgcolor: alpha(accent, 0.05),
        }}
      >
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap alignItems="center">
          <Chip
            size="small"
            icon={<AccessTimeOutlinedIcon sx={{ fontSize: '14px !important' }} />}
            label={timeLabel}
            sx={{ fontWeight: 700, bgcolor: alpha(accent, 0.12) }}
          />
          <Chip
            size="small"
            label={
              timeMode === 'MIXED'
                ? 'Trong ca & ngoài ca'
                : timeMode === 'OUTSIDE'
                  ? 'Ngoài ca'
                  : dayContinuous
                    ? 'Ca thông tầm'
                    : insideScope === 'FULL_DAY'
                      ? 'Cả ngày'
                      : insideScope === 'MORNING'
                        ? 'Ca sáng'
                        : 'Ca chiều'
            }
            variant="outlined"
          />
          {timeMode === 'MIXED' ? (
            <>
              <Chip
                size="small"
                label={`Trong ca ${fmtHours(mixedInsideUnits?.total ?? 0)} công`}
                variant="outlined"
              />
              <Chip
                size="small"
                label={`Ngoài ca ${fmtHours(mixedSpan?.outsideHours ?? 0)}h`}
                variant="outlined"
              />
              <Chip
                size="small"
                color="primary"
                label={`+ ${fmtHours(workUnits)} công`}
                sx={{ fontWeight: 700 }}
              />
            </>
          ) : timeMode === 'OUTSIDE' ? (
            <>
              <Chip size="small" label={`${fmtHours(actualHours)}h làm thêm`} variant="outlined" />
              <Chip
                size="small"
                color="primary"
                label={`×1,5 → ${fmtHours(creditedHours)}h công`}
                sx={{ fontWeight: 700 }}
              />
              <Chip size="small" label={`+ ${fmtHours(workUnits)} công`} variant="outlined" />
            </>
          ) : (
            <>
              {!dayContinuous && insideUnits && insideUnits.morning > 0 && (
                <Chip size="small" label={`Sáng ${fmtHours(insideUnits.morning)} công`} variant="outlined" />
              )}
              {!dayContinuous && insideUnits && insideUnits.afternoon > 0 && (
                <Chip size="small" label={`Chiều ${fmtHours(insideUnits.afternoon)} công`} variant="outlined" />
              )}
              <Chip
                size="small"
                color="primary"
                label={
                  workedDay
                    ? `thay → ${fmtHours(workUnits)} công`
                    : `+ ${fmtHours(workUnits)} công`
                }
                sx={{ fontWeight: 700 }}
              />
            </>
          )}
        </Stack>
        <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 1, lineHeight: 1.5 }}>
          {timeMode === 'MIXED'
            ? 'Phần trong ca chỉ cộng khi có đủ giờ chấm vào/ra đúng khung ca. Phần ngoài ca tính giờ ×1,5 ngay khi đơn được duyệt.'
            : timeMode === 'INSIDE'
              ? dayContinuous
                ? workedDay
                  ? 'Trong ca thông tầm: đủ giờ chấm vào đầu ngày / ra cuối ngày mới thay công (tối đa 1,5).'
                  : 'Trong ca thông tầm: đủ giờ chấm vào đầu ngày / ra cuối ngày mới cộng công (tối đa 1,5).'
                : workedDay
                  ? 'Trong ca: đủ giờ chấm vào/ra mới thay công theo khung đã duyệt (tối đa sáng 1 · chiều 0,5).'
                  : 'Trong ca: đủ giờ chấm vào/ra mới cộng công theo khung đã duyệt (tối đa sáng 1 · chiều 0,5).'
              : 'Ngoài ca: tính theo giờ ×1,5 rồi quy ra công.'}
        </Typography>
      </Box>

      <FormSection title="Nội dung điều động">
        <TextField
          fullWidth
          size="small"
          required
          multiline
          minRows={3}
          placeholder="Ví dụ: Hỗ trợ Khoa Cấp cứu…"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
