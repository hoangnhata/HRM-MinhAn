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
import { FormSection, InfoBanner, SelectableChip, WorkRequestDialogShell } from './work/WorkRequestFormUi';
import { scheduleForDate, type ShiftScheduleInfo } from '../utils/shiftSchedule';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  employeeId: number;
  employeeName: string;
  workDate: string;
  schedule?: ShiftScheduleInfo | null;
  /** Tháng đang xem trên bảng công — giới hạn chọn ngày trong dialog. */
  periodYear?: number;
  periodMonth?: number;
  /** null / ABSENT / LEAVE / BUSINESS_TRIP = ngày nghỉ hoặc chưa có → được điều động trong ca. */
  getDayStatus?: (date: string) => string | null | undefined;
};

type TimeMode = 'OUTSIDE' | 'INSIDE';
type InsideScope = 'MORNING' | 'AFTERNOON' | 'FULL_DAY';

const fieldSx = dateTimeFieldSx;
const COEFF = 1.5;

function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

function endOfMonthIso(fromIso?: string): string {
  const base = fromIso ? new Date(`${fromIso}T12:00:00`) : new Date();
  const last = new Date(base.getFullYear(), base.getMonth() + 1, 0);
  return last.toISOString().slice(0, 10);
}

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

function insideDeploymentUnits(scope: InsideScope): { morning: number; afternoon: number; total: number } {
  if (scope === 'MORNING') return { morning: INSIDE_MORNING_UNITS, afternoon: 0, total: INSIDE_MORNING_UNITS };
  if (scope === 'AFTERNOON') return { morning: 0, afternoon: INSIDE_AFTERNOON_UNITS, total: INSIDE_AFTERNOON_UNITS };
  return {
    morning: INSIDE_MORNING_UNITS,
    afternoon: INSIDE_AFTERNOON_UNITS,
    total: INSIDE_MORNING_UNITS + INSIDE_AFTERNOON_UNITS,
  };
}

function isOffOrEmptyDay(status?: string | null): boolean {
  if (status == null || status === '') return true;
  const s = status.toUpperCase();
  return s === 'ABSENT' || s === 'LEAVE' || s === 'BUSINESS_TRIP';
}

function isWorkedDay(status?: string | null): boolean {
  if (status == null || status === '') return false;
  const s = status.toUpperCase();
  return s === 'PRESENT' || s === 'PARTIAL';
}

function monthStartIso(year: number, month: number): string {
  return `${year}-${String(month).padStart(2, '0')}-01`;
}

function deployMaxDate(periodYear?: number, periodMonth?: number): string {
  const today = todayIso();
  if (periodYear && periodMonth) {
    const monthEnd = endOfMonthIso(monthStartIso(periodYear, periodMonth));
    const [ty, tm] = today.split('-').map(Number);
    if (periodYear < ty || (periodYear === ty && periodMonth < tm)) {
      return monthEnd;
    }
    if (periodYear === ty && periodMonth === tm) {
      return endOfMonthIso(today);
    }
    return monthEnd;
  }
  return endOfMonthIso(today);
}

export function DeploymentRequestDialog({
  open,
  onClose,
  onSubmitted,
  employeeId,
  employeeName,
  workDate: defaultDate,
  schedule: scheduleProp,
  periodYear,
  periodMonth,
  getDayStatus,
}: Props) {
  const accent = '#0f766e';
  const today = todayIso();
  const minDate =
    periodYear && periodMonth ? monthStartIso(periodYear, periodMonth) : undefined;
  const maxDate = deployMaxDate(periodYear, periodMonth);

  const [workDate, setWorkDate] = useState(defaultDate);
  const schedule = scheduleProp ?? scheduleForDate(workDate);

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

  function clampDate(iso: string): string {
    let d = iso;
    if (minDate && d < minDate) d = minDate;
    if (d > maxDate) d = maxDate;
    return d;
  }

  useEffect(() => {
    if (!open) return;
    const d = clampDate(defaultDate);
    const sch = scheduleProp ?? scheduleForDate(d);
    const empty = isOffOrEmptyDay(getDayStatus?.(d));
    const worked = isWorkedDay(getDayStatus?.(d));
    setWorkDate(d);
    setTimeMode(worked ? 'INSIDE' : empty ? 'INSIDE' : 'OUTSIDE');
    setInsideScope(worked ? 'MORNING' : 'FULL_DAY');
    setStartTime('18:00');
    setEndTime('21:00');
    setMorningStart(sch.morningStart);
    setMorningEnd(sch.morningEnd);
    setAfternoonStart(sch.afternoonStart);
    setAfternoonEnd(sch.afternoonEnd);
    setReason('');
    setErr(null);
    // Chỉ reset khi mở dialog / đổi ngày mặc định — không phụ thuộc getDayStatus (inline mỗi render)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, defaultDate, minDate, maxDate, scheduleProp]);

  function onDateChange(next: string) {
    const clamped = clampDate(next);
    setWorkDate(clamped);
    const sch = scheduleProp ?? scheduleForDate(clamped);
    setMorningStart(sch.morningStart);
    setMorningEnd(sch.morningEnd);
    setAfternoonStart(sch.afternoonStart);
    setAfternoonEnd(sch.afternoonEnd);
  }

  const actualHours = useMemo(() => {
    if (timeMode === 'INSIDE') return 0;
    return overtimeHours(startTime, endTime);
  }, [timeMode, startTime, endTime]);

  const insideUnits = useMemo(
    () => (timeMode === 'INSIDE' ? insideDeploymentUnits(insideScope) : null),
    [timeMode, insideScope],
  );

  const creditedHours = timeMode === 'INSIDE' ? (insideUnits?.total ?? 0) : actualHours * COEFF;
  const dayHours = (schedule.morningHours ?? 0) + (schedule.afternoonHours ?? 0) || 8;
  const workUnits =
    timeMode === 'INSIDE'
      ? insideUnits?.total ?? 0
      : Math.round((actualHours * COEFF) / dayHours * 100) / 100;

  const overlapsPrimary = useMemo(() => {
    if (timeMode !== 'OUTSIDE' || offDay) return false;
    return overlapsPrimarySchedule(
      startTime,
      endTime,
      schedule.morningStart,
      schedule.morningEnd,
      schedule.afternoonStart,
      schedule.afternoonEnd,
    );
  }, [timeMode, offDay, startTime, endTime, schedule]);

  const overnight =
    timeMode === 'OUTSIDE' && toMinutes(endTime) <= toMinutes(startTime) && actualHours > 0;

  const timeLabel = useMemo(() => {
    if (timeMode === 'INSIDE') {
      if (insideScope === 'MORNING') return 'Ca sáng — 1 công';
      if (insideScope === 'AFTERNOON') return 'Ca chiều — 0,5 công';
      return 'Cả ngày — 1,5 công (sáng 1 + chiều 0,5)';
    }
    if (timeMode === 'OUTSIDE') {
      return `${fmtTime(startTime)} – ${fmtTime(endTime)}${overnight ? ' (+1 ngày)' : ''}`;
    }
    return '';
  }, [timeMode, insideScope, startTime, endTime, overnight]);

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
    if (workDate > today && workDate > endOfMonthIso(today)) {
      setErr('Không điều động quá hết tháng hiện tại.');
      return;
    }
    if (timeMode === 'OUTSIDE' && actualHours <= 0) {
      setErr('Nhập khung giờ hợp lệ (có thể qua đêm, ví dụ 22:00–06:00).');
      return;
    }
    if (overlapsPrimary) {
      setErr(
        `Giờ điều động không được trùng ca chính (${fmtTime(schedule.morningStart)}–${fmtTime(schedule.morningEnd)}, ${fmtTime(schedule.afternoonStart)}–${fmtTime(schedule.afternoonEnd)}).`,
      );
      return;
    }

    setLoading(true);
    try {
      if (timeMode === 'OUTSIDE') {
        await att.submitWorkRequest({
          requestType: 'DEPLOYMENT',
          employeeId,
          workDate,
          shiftScope: 'FULL_DAY',
          reason: reason.trim(),
          requestedStart: startTime.slice(0, 5),
          requestedEnd: endTime.slice(0, 5),
        });
      } else if (insideScope === 'MORNING') {
        await att.submitWorkRequest({
          requestType: 'DEPLOYMENT',
          employeeId,
          workDate,
          shiftScope: 'MORNING',
          reason: reason.trim(),
          requestedStart: schedule.morningStart.slice(0, 5),
          requestedEnd: schedule.morningEnd.slice(0, 5),
        });
      } else if (insideScope === 'AFTERNOON') {
        await att.submitWorkRequest({
          requestType: 'DEPLOYMENT',
          employeeId,
          workDate,
          shiftScope: 'AFTERNOON',
          reason: reason.trim(),
          requestedStart: schedule.afternoonStart.slice(0, 5),
          requestedEnd: schedule.afternoonEnd.slice(0, 5),
        });
      } else {
        await att.submitWorkRequest({
          requestType: 'DEPLOYMENT',
          employeeId,
          workDate,
          shiftScope: 'FULL_DAY',
          reason: reason.trim(),
          requestedStart: schedule.morningStart.slice(0, 5),
          requestedEnd: schedule.morningEnd.slice(0, 5),
          requestedAfternoonStart: schedule.afternoonStart.slice(0, 5),
          requestedAfternoonEnd: schedule.afternoonEnd.slice(0, 5),
        });
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
      overline="Điều động nhân sự"
      title="Đơn điều động"
      description="Công ×1,5. Ngày đã chấm: chọn «Trong ca» để thay công ca sáng/chiều; «Ngoài ca» để cộng thêm ngoài giờ."
      formId="deployment-request-form"
      submitLabel="Gửi điều động"
      error={err}
      onSubmit={submit}
    >
      <InfoBanner>
        {workedDay ? (
          <>
            Ngày <strong>đã có công chấm máy</strong> — chọn <strong>Trong ca</strong> để thay công ca điều động
            (×1,5, theo buổi hoặc cả ngày). <strong>Ngoài ca</strong> chỉ cộng thêm giờ ngoài giờ (không trùng ca
            chính).
          </>
        ) : offDay ? (
          <>
            Ngày <strong>chưa có công / nghỉ</strong> — chọn <strong>ngoài ca</strong> hoặc <strong>trong ca</strong>{' '}
            (sáng / chiều / cả ngày). Công ×1,5. Có thể nhập lại các ngày trước.
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
          value={employeeName}
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
          <Grid item xs={6}>
            <SelectableChip
              selected={timeMode === 'OUTSIDE'}
              label="Ngoài ca"
              onClick={() => setTimeMode('OUTSIDE')}
            />
          </Grid>
          <Grid item xs={6}>
            <SelectableChip
              selected={timeMode === 'INSIDE'}
              label="Trong ca"
              onClick={() => {
                setErr(null);
                setTimeMode('INSIDE');
              }}
            />
          </Grid>
        </Grid>
        {!offDay && timeMode === 'OUTSIDE' && (
          <Alert severity="info" variant="outlined" sx={{ mt: 1.25, borderRadius: 2 }}>
            Ca chính (không trùng khi chọn ngoài ca):{' '}
            <strong>
              {fmtTime(schedule.morningStart)}–{fmtTime(schedule.morningEnd)}
            </strong>{' '}
            ·{' '}
            <strong>
              {fmtTime(schedule.afternoonStart)}–{fmtTime(schedule.afternoonEnd)}
            </strong>
          </Alert>
        )}
      </FormSection>

      {timeMode === 'OUTSIDE' ? (
        <FormSection
          title="Giờ ngoài ca"
          subtitle="Nhập tự do — kể cả ban đêm (vd 22:00–06:00)."
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
          {overlapsPrimary && (
            <Alert severity="warning" sx={{ mt: 1.25, borderRadius: 2 }}>
              Khung giờ đang trùng ca chính — hãy chọn giờ ngoài ca sáng/chiều.
            </Alert>
          )}
        </FormSection>
      ) : (
        <>
          <FormSection
            title="Ca điều động"
            subtitle="Trong ca: công cố định — sáng 1 · chiều 0,5 · cả ngày 1,5 (không tính giờ)"
          >
            <Stack spacing={1}>
              <SelectableChip
                selected={insideScope === 'MORNING'}
                label="Ca sáng — 1 công"
                onClick={() => setInsideScope('MORNING')}
              />
              <SelectableChip
                selected={insideScope === 'AFTERNOON'}
                label="Ca chiều — 0,5 công"
                onClick={() => setInsideScope('AFTERNOON')}
              />
              <SelectableChip
                selected={insideScope === 'FULL_DAY'}
                label="Cả ngày — 1,5 công"
                onClick={() => setInsideScope('FULL_DAY')}
              />
            </Stack>
            <Alert severity="info" variant="outlined" sx={{ mt: 1.25, borderRadius: 2 }}>
              Khung ca tham chiếu: sáng {fmtTime(schedule.morningStart)}–{fmtTime(schedule.morningEnd)} · chiều{' '}
              {fmtTime(schedule.afternoonStart)}–{fmtTime(schedule.afternoonEnd)}
            </Alert>
          </FormSection>
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
            label={timeMode === 'OUTSIDE' ? 'Ngoài ca' : insideScope === 'FULL_DAY' ? 'Cả ngày' : insideScope === 'MORNING' ? 'Ca sáng' : 'Ca chiều'}
            variant="outlined"
          />
          {timeMode === 'OUTSIDE' ? (
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
              {insideUnits && insideUnits.morning > 0 && (
                <Chip size="small" label={`Sáng ${fmtHours(insideUnits.morning)} công`} variant="outlined" />
              )}
              {insideUnits && insideUnits.afternoon > 0 && (
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
          {timeMode === 'INSIDE'
            ? workedDay
              ? 'Trong ca: thay công ca điều động (sáng 1 · chiều 0,5 · cả ngày 1,5).'
              : 'Trong ca: cộng công cố định theo ca (sáng 1 · chiều 0,5 · cả ngày 1,5).'
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
