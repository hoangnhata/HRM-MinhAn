import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import EditCalendarOutlinedIcon from '@mui/icons-material/EditCalendarOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import TimelineIcon from '@mui/icons-material/Timeline';
import WbSunnyOutlinedIcon from '@mui/icons-material/WbSunnyOutlined';
import WbTwilightIcon from '@mui/icons-material/WbTwilight';
import { Box, Grid, Stack, TextField, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as att from '../services/attendanceService';
import * as employeeService from '../services/employeeService';
import { DatePickerField, TimePickerField, dateTimeFieldSx } from '../components/ui/DateTimeFields';
import {
  FormSection,
  InfoBanner,
  ReadonlyFact,
  RequestFlowSteps,
  SelectableChip,
  WorkRequestDialogShell,
} from './work/WorkRequestFormUi';
import {
  continuousShiftRange,
  formatPunchTime,
  scheduleForDate,
  type ShiftScheduleInfo,
} from '../utils/shiftSchedule';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  defaultDate?: string;
  attendanceRow?: Record<string, unknown> | null;
  /** Nhân viên cần lấy lịch ca; nếu thiếu, API dùng nhân viên của tài khoản hiện tại. */
  employeeId?: number | null;
  /** Ngày đang mở thuộc ca thông tầm (ưu tiên hơn lịch tháng). */
  continuousShift?: boolean;
  editRequest?: att.WorkRequest | null;
};

const fieldSx = dateTimeFieldSx;

function ShiftTimeBlock({
  title,
  icon,
  accent,
  startLabel,
  endLabel,
  start,
  end,
  onStartChange,
  onEndChange,
}: {
  title: string;
  icon: React.ReactNode;
  accent: string;
  startLabel: string;
  endLabel: string;
  start: string;
  end: string;
  onStartChange: (v: string) => void;
  onEndChange: (v: string) => void;
}) {
  return (
    <Box
      sx={{
        p: 1.75,
        borderRadius: 2,
        bgcolor: alpha(accent, 0.04),
        border: `1px solid ${alpha(accent, 0.16)}`,
        height: '100%',
      }}
    >
      <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.5 }}>
        {icon}
        <Typography variant="subtitle2" fontWeight={700}>
          {title}
        </Typography>
      </Stack>
      <Grid container spacing={1.5}>
        <Grid item xs={12} sm={6}>
          <TimePickerField required label={startLabel} value={start} onChange={onStartChange} sx={fieldSx} />
        </Grid>
        <Grid item xs={12} sm={6}>
          <TimePickerField required label={endLabel} value={end} onChange={onEndChange} sx={fieldSx} />
        </Grid>
      </Grid>
    </Box>
  );
}

function PartialShiftFields({
  existingIn,
  existingOut,
  missingIn,
  missingOut,
  inValue,
  outValue,
  onInChange,
  onOutChange,
}: {
  existingIn?: string;
  existingOut?: string;
  missingIn?: boolean;
  missingOut?: boolean;
  inValue: string;
  outValue: string;
  onInChange: (v: string) => void;
  onOutChange: (v: string) => void;
}) {
  return (
    <Stack spacing={1.5}>
      {existingIn && !missingIn && (
        <TextField
          fullWidth
          size="small"
          label="Giờ vào (đã chấm)"
          value={formatPunchTime(existingIn)}
          disabled
          sx={fieldSx}
        />
      )}
      {missingIn && (
        <TimePickerField required label="Giờ vào (cần bổ sung)" value={inValue} onChange={onInChange} sx={fieldSx} />
      )}
      {existingOut && !missingOut && (
        <TextField
          fullWidth
          size="small"
          label="Giờ ra (đã chấm)"
          value={formatPunchTime(existingOut)}
          disabled
          sx={fieldSx}
        />
      )}
      {missingOut && (
        <TimePickerField required label="Giờ ra (cần bổ sung)" value={outValue} onChange={onOutChange} sx={fieldSx} />
      )}
    </Stack>
  );
}

export function AttendanceUpdateRequestDialog({
  open,
  onClose,
  onSubmitted,
  defaultDate,
  attendanceRow,
  employeeId,
  continuousShift,
  editRequest,
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = theme.palette.primary.main;
  const isEditing = Boolean(editRequest);

  const [workDate, setWorkDate] = useState(defaultDate ?? new Date().toISOString().slice(0, 10));
  const [updateKind, setUpdateKind] = useState<string>('MORNING_SUPPLEMENT');
  const [reason, setReason] = useState('');
  const [morningStart, setMorningStart] = useState('07:00');
  const [morningEnd, setMorningEnd] = useState('12:00');
  const [afternoonStart, setAfternoonStart] = useState('14:00');
  const [afternoonEnd, setAfternoonEnd] = useState('17:00');
  const [daySchedule, setDaySchedule] = useState<ShiftScheduleInfo>(() => scheduleForDate(defaultDate));
  const [departmentName, setDepartmentName] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [scenario, setScenario] = useState<att.UpdateScenario | null>(null);
  const [continuousDay, setContinuousDay] = useState(Boolean(continuousShift));

  const isContinuous = continuousDay || Boolean(scenario?.continuous);
  const isFullDay = updateKind === 'FULL_DAY_SUPPLEMENT';
  const forgotUnits = att.forgotUnitsForUpdateChoice(updateKind, scenario);
  const kindLocked = Boolean(scenario?.locked) || isContinuous || isEditing;
  const showKindHint =
    Boolean(scenario) &&
    !kindLocked &&
    !isContinuous &&
    (scenario?.missingMorningIn ||
      scenario?.missingMorningOut ||
      scenario?.missingAfternoonIn ||
      scenario?.missingAfternoonOut);

  function applyScheduleTimes(
    sch: ShiftScheduleInfo,
    detected: att.UpdateScenario,
    continuous: boolean,
  ) {
    if (continuous) {
      const range = continuousShiftRange(sch);
      setMorningStart(detected.existingMorningIn ?? range.start.slice(0, 5));
      setMorningEnd(detected.existingAfternoonOut ?? range.end.slice(0, 5));
      return;
    }
    setMorningStart(detected.existingMorningIn ?? sch.morningStart);
    setMorningEnd(detected.existingMorningOut ?? sch.morningEnd);
    setAfternoonStart(detected.existingAfternoonIn ?? sch.afternoonStart);
    setAfternoonEnd(detected.existingAfternoonOut ?? sch.afternoonEnd);
  }

  useEffect(() => {
    if (!open) return;
    const wd = editRequest?.workDate ?? defaultDate ?? new Date().toISOString().slice(0, 10);
    const fallbackSchedule = scheduleForDate(wd);

    if (editRequest) {
      const continuous = Boolean(editRequest.continuousShift);
      setWorkDate(wd);
      setUpdateKind(editRequest.updateKind || 'MORNING_SUPPLEMENT');
      setScenario(null);
      setContinuousDay(continuous);
      setReason(editRequest.reason || '');
      setErr(null);
      setDaySchedule(fallbackSchedule);
      setMorningStart(editRequest.requestedStart?.slice(0, 5) || fallbackSchedule.morningStart);
      setMorningEnd(editRequest.requestedEnd?.slice(0, 5) || fallbackSchedule.morningEnd);
      setAfternoonStart(
        editRequest.requestedAfternoonStart?.slice(0, 5) || fallbackSchedule.afternoonStart,
      );
      setAfternoonEnd(
        editRequest.requestedAfternoonEnd?.slice(0, 5) || fallbackSchedule.afternoonEnd,
      );

      let cancelled = false;
      att
        .fetchShiftSchedule(wd, employeeId ?? editRequest.employeeId ?? undefined)
        .then((sch) => {
          if (cancelled) return;
          setDaySchedule(sch);
          setContinuousDay(Boolean(editRequest.continuousShift || sch.continuousShift));
        })
        .catch(() => {});
      employeeService
        .fetchMe()
        .then((me) => setDepartmentName(me.departmentName ?? ''))
        .catch(() => setDepartmentName(''));
      return () => {
        cancelled = true;
      };
    }

    const initialContinuous = Boolean(continuousShift);
    const detected = att.detectUpdateFromRow(attendanceRow, initialContinuous);
    setWorkDate(wd);
    setUpdateKind(detected.updateKind);
    setScenario(detected);
    setContinuousDay(initialContinuous);
    setReason('');
    setErr(null);
    setDaySchedule(fallbackSchedule);
    applyScheduleTimes(fallbackSchedule, detected, initialContinuous);

    let cancelled = false;
    att.fetchShiftSchedule(wd, employeeId ?? undefined)
      .then((sch) => {
        if (cancelled) return;
        const continuous = Boolean(continuousShift || sch.continuousShift);
        const next = att.detectUpdateFromRow(attendanceRow, continuous);
        setDaySchedule(sch);
        setContinuousDay(continuous);
        setUpdateKind(next.updateKind);
        setScenario(next);
        applyScheduleTimes(sch, next, continuous);
      })
      .catch(() => {
        // Giữ lịch mặc định theo mùa nếu không tải được cấu hình.
      });
    employeeService
      .fetchMe()
      .then((me) => setDepartmentName(me.departmentName ?? ''))
      .catch(() => setDepartmentName(''));
    return () => {
      cancelled = true;
    };
  }, [open, defaultDate, attendanceRow, employeeId, continuousShift, editRequest]);

  function handleWorkDateChange(nextDate: string) {
    setWorkDate(nextDate);
    const fallbackSchedule = scheduleForDate(nextDate);
    setDaySchedule(fallbackSchedule);

    att.fetchShiftSchedule(nextDate, employeeId ?? undefined)
      .then((sch) => {
        const continuous = Boolean(sch.continuousShift);
        const next = att.detectUpdateFromRow(null, continuous);
        setDaySchedule(sch);
        setContinuousDay(continuous);
        if (!kindLocked) {
          setUpdateKind(next.updateKind);
          setScenario(next);
          applyScheduleTimes(sch, next, continuous);
        } else if (continuous) {
          applyScheduleTimes(sch, scenario ?? next, true);
        }
      })
      .catch(() => {
        if (kindLocked) return;
        setMorningStart(fallbackSchedule.morningStart);
        setMorningEnd(fallbackSchedule.morningEnd);
        setAfternoonStart(fallbackSchedule.afternoonStart);
        setAfternoonEnd(fallbackSchedule.afternoonEnd);
      });
  }

  function shiftScopeFromKind(kind: string): 'MORNING' | 'AFTERNOON' | 'FULL_DAY' {
    if (kind === 'AFTERNOON_SUPPLEMENT') return 'AFTERNOON';
    if (kind === 'FULL_DAY_SUPPLEMENT') return 'FULL_DAY';
    return 'MORNING';
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!reason.trim()) {
      setErr('Nhập lý do cập nhật công.');
      return;
    }
    setLoading(true);
    try {
      const payload: att.SubmitWorkRequest = {
        requestType: 'UPDATE',
        workDate,
        shiftScope: isContinuous ? 'FULL_DAY' : shiftScopeFromKind(updateKind),
        updateKind: (isContinuous ? 'FULL_DAY_SUPPLEMENT' : updateKind) as att.SubmitWorkRequest['updateKind'],
        reason: reason.trim(),
      };
      if (isContinuous) {
        payload.requestedStart =
          scenario?.missingMorningIn === false && scenario?.existingMorningIn
            ? scenario.existingMorningIn
            : morningStart;
        payload.requestedEnd =
          scenario?.missingAfternoonOut === false && scenario?.existingAfternoonOut
            ? scenario.existingAfternoonOut
            : morningEnd;
      } else if (isFullDay) {
        payload.requestedStart =
          scenario?.missingMorningIn === false && scenario?.existingMorningIn
            ? scenario.existingMorningIn
            : morningStart;
        payload.requestedEnd =
          scenario?.missingMorningOut === false && scenario?.existingMorningOut
            ? scenario.existingMorningOut
            : morningEnd;
        payload.requestedAfternoonStart =
          scenario?.missingAfternoonIn === false && scenario?.existingAfternoonIn
            ? scenario.existingAfternoonIn
            : afternoonStart;
        payload.requestedAfternoonEnd =
          scenario?.missingAfternoonOut === false && scenario?.existingAfternoonOut
            ? scenario.existingAfternoonOut
            : afternoonEnd;
      } else if (updateKind === 'AFTERNOON_SUPPLEMENT') {
        payload.requestedStart = scenario?.missingAfternoonIn === false && scenario?.existingAfternoonIn
          ? scenario.existingAfternoonIn
          : afternoonStart;
        payload.requestedEnd = scenario?.missingAfternoonOut === false && scenario?.existingAfternoonOut
          ? scenario.existingAfternoonOut
          : afternoonEnd;
      } else {
        payload.requestedStart = scenario?.missingMorningIn === false && scenario?.existingMorningIn
          ? scenario.existingMorningIn
          : morningStart;
        payload.requestedEnd = scenario?.missingMorningOut === false && scenario?.existingMorningOut
          ? scenario.existingMorningOut
          : morningEnd;
      }
      if (isEditing && editRequest) {
        await att.updateWorkRequest(editRequest.id, payload);
      } else {
        await att.submitWorkRequest(payload);
      }
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Gửi đơn thất bại. Kiểm tra ngày đã có đơn chờ duyệt hoặc thiếu thông tin.');
    } finally {
      setLoading(false);
    }
  }

  const sch = daySchedule;
  const continuousRange = continuousShiftRange(sch);
  const scheduleHint = isContinuous
    ? `Ca thông tầm: ${continuousRange.start.slice(0, 5)} – ${continuousRange.end.slice(0, 5)} (không nghỉ trưa)`
    : isFullDay
      ? `${sch.seasonLabel}: ${sch.morningStart}–${sch.morningEnd} · ${sch.afternoonStart}–${sch.afternoonEnd}`
      : updateKind === 'AFTERNOON_SUPPLEMENT'
        ? `Ca chiều: ${sch.afternoonStart} – ${sch.afternoonEnd}`
        : `Ca sáng: ${sch.morningStart} – ${sch.morningEnd}`;

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={accent}
      maxWidth="lg"
      icon={<EditCalendarOutlinedIcon />}
      overline={isEditing ? 'Chỉnh sửa đơn' : 'Đề nghị cập nhật'}
      title={isEditing ? 'Chỉnh sửa cập nhật công' : 'Cập nhật công'}
      description="Dành cho trường hợp quên chấm công hoặc thiếu ca. Đơn qua lãnh đạo → HCNS → Giám đốc quyết định trừ tiền."
      formId="att-update-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi đơn cập nhật'}
      error={err}
      onSubmit={submit}
    >
      <RequestFlowSteps
        accent={accent}
        steps={[
          { label: 'Gửi đơn', hint: 'Nhân viên' },
          { label: 'Lãnh đạo duyệt', hint: 'Trưởng khoa / ĐD trưởng' },
          { label: 'HCNS duyệt', hint: 'Hành chính nhân sự' },
          { label: 'Giám đốc duyệt', hint: 'Quyết định trừ tiền' },
        ]}
      />

      <InfoBanner>
        {isContinuous ? (
          <>
            Ngày này đang xếp <strong>ca thông tầm</strong> (chỉ giờ vào đầu ngày và giờ ra cuối ngày, không nghỉ
            trưa). Sau khi Giám đốc duyệt, hệ thống cập nhật 2 mốc đó. Mỗi ngày chỉ gửi một đơn đang chờ duyệt. Nếu
            Giám đốc chọn trừ tiền quên chấm: đơn này trừ <strong>{forgotUnits} lần</strong>
            {scenario?.partial ? ` (thiếu ${forgotUnits} mốc chấm)` : ''}.
          </>
        ) : (
          <>
            Sau khi Giám đốc duyệt, hệ thống cập nhật giờ công theo khung bạn đề nghị. Mỗi ngày chỉ gửi một đơn đang
            chờ duyệt. Nếu Giám đốc chọn trừ tiền quên chấm: đơn này trừ <strong>{forgotUnits} lần</strong>
            {scenario?.partial && updateKind === scenario.updateKind
              ? ` (thiếu ${forgotUnits} mốc chấm)`
              : ''}{' '}
            theo bậc phạt tháng.
            {showKindHint ? (
              <>
                {' '}
                <strong>Chỉ đi làm một ca</strong> (ca kia nghỉ): chọn «Bổ sung ca sáng» hoặc «Bổ sung ca chiều» —
                không cần bổ sung ca nghỉ.
              </>
            ) : null}
          </>
        )}
      </InfoBanner>

      <FormSection title="Người nộp đơn">
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
            gap: 1.25,
          }}
        >
          <ReadonlyFact
            accent={accent}
            icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
            label="Họ và tên"
            value={user?.fullName ?? ''}
          />
          <ReadonlyFact
            accent={accent}
            icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
            label="Phòng ban"
            value={departmentName}
          />
        </Box>
      </FormSection>

      <FormSection title="Ngày & loại cập nhật" subtitle={scheduleHint}>
        <DatePickerField
          label="Ngày cần cập nhật"
          required
          value={workDate}
          onChange={handleWorkDateChange}
          sx={fieldSx}
        />
        <Stack spacing={1}>
          {kindLocked ? (
            <SelectableChip
              selected
              label={`${isContinuous ? att.CONTINUOUS_UPDATE_KIND.label : (att.UPDATE_KIND_OPTIONS.find((o) => o.value === updateKind)?.label ?? 'Cập nhật')} · trừ ${forgotUnits} lần quên chấm`}
              onClick={() => {}}
            />
          ) : (
            <>
              {showKindHint && (
                <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                  Chọn đúng ca cần bổ sung. Ca nghỉ (không đi làm) thì không chọn — tránh bị trừ quên chấm ca đó.
                </Typography>
              )}
              {att.UPDATE_KIND_OPTIONS.map((o) => {
                const units = att.forgotUnitsForUpdateChoice(o.value, scenario);
                return (
                  <SelectableChip
                    key={o.value}
                    selected={updateKind === o.value}
                    label={`${o.label} · trừ ${units} lần quên chấm`}
                    onClick={() => setUpdateKind(o.value)}
                  />
                );
              })}
            </>
          )}
        </Stack>
      </FormSection>

      <FormSection
        title="Khung giờ đề nghị"
        subtitle={
          isContinuous
            ? 'Chỉ nhập giờ vào đầu ngày và giờ ra cuối ngày theo ca thông tầm.'
            : isFullDay
              ? 'Điều chỉnh nếu khác lịch ca mặc định. Chỉ cần nhập đủ cả hai ca khi chọn bổ sung cả ngày.'
              : updateKind === 'AFTERNOON_SUPPLEMENT'
                ? 'Chỉ bổ sung ca chiều — ca sáng không thay đổi.'
                : 'Chỉ bổ sung ca sáng — ca chiều (nghỉ / không làm) không cần nhập.'
        }
      >
        <Box
          sx={{
            p: 2,
            borderRadius: 2.5,
            bgcolor: alpha(accent, 0.05),
            border: `1px dashed ${alpha(accent, 0.25)}`,
          }}
        >
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 2 }}>
            {isContinuous ? (
              <TimelineIcon sx={{ fontSize: 18, color: accent }} />
            ) : (
              <WbTwilightIcon sx={{ fontSize: 18, color: accent }} />
            )}
            <Typography variant="body2" color="text.secondary">
              {scheduleHint}
            </Typography>
          </Stack>

          {isContinuous ? (
            scenario?.partial ? (
              <PartialShiftFields
                existingIn={scenario.existingMorningIn}
                existingOut={scenario.existingAfternoonOut}
                missingIn={scenario.missingMorningIn}
                missingOut={scenario.missingAfternoonOut}
                inValue={morningStart}
                outValue={morningEnd}
                onInChange={setMorningStart}
                onOutChange={setMorningEnd}
              />
            ) : (
              <ShiftTimeBlock
                title="Ca thông tầm"
                icon={<TimelineIcon sx={{ fontSize: 18, color: accent }} />}
                accent={accent}
                startLabel="Giờ vào"
                endLabel="Giờ ra"
                start={morningStart}
                end={morningEnd}
                onStartChange={setMorningStart}
                onEndChange={setMorningEnd}
              />
            )
          ) : isFullDay ? (
            scenario?.partial ? (
              <Grid container spacing={2}>
                <Grid item xs={12} md={6}>
                  <Stack spacing={1}>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <WbSunnyOutlinedIcon sx={{ fontSize: 18, color: accent }} />
                      <Typography variant="subtitle2">Ca sáng</Typography>
                    </Stack>
                    <PartialShiftFields
                      existingIn={scenario.existingMorningIn}
                      existingOut={scenario.existingMorningOut}
                      missingIn={scenario.missingMorningIn}
                      missingOut={scenario.missingMorningOut}
                      inValue={morningStart}
                      outValue={morningEnd}
                      onInChange={setMorningStart}
                      onOutChange={setMorningEnd}
                    />
                  </Stack>
                </Grid>
                <Grid item xs={12} md={6}>
                  <Stack spacing={1}>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <WbTwilightIcon sx={{ fontSize: 18, color: accent }} />
                      <Typography variant="subtitle2">Ca chiều</Typography>
                    </Stack>
                    <PartialShiftFields
                      existingIn={scenario.existingAfternoonIn}
                      existingOut={scenario.existingAfternoonOut}
                      missingIn={scenario.missingAfternoonIn}
                      missingOut={scenario.missingAfternoonOut}
                      inValue={afternoonStart}
                      outValue={afternoonEnd}
                      onInChange={setAfternoonStart}
                      onOutChange={setAfternoonEnd}
                    />
                  </Stack>
                </Grid>
              </Grid>
            ) : (
              <Grid container spacing={2}>
                <Grid item xs={12} md={6}>
                  <ShiftTimeBlock
                    title="Ca sáng"
                    icon={<WbSunnyOutlinedIcon sx={{ fontSize: 18, color: accent }} />}
                    accent={accent}
                    startLabel="Vào ca"
                    endLabel="Ra ca"
                    start={morningStart}
                    end={morningEnd}
                    onStartChange={setMorningStart}
                    onEndChange={setMorningEnd}
                  />
                </Grid>
                <Grid item xs={12} md={6}>
                  <ShiftTimeBlock
                    title="Ca chiều"
                    icon={<WbTwilightIcon sx={{ fontSize: 18, color: accent }} />}
                    accent={accent}
                    startLabel="Vào ca"
                    endLabel="Ra ca"
                    start={afternoonStart}
                    end={afternoonEnd}
                    onStartChange={setAfternoonStart}
                    onEndChange={setAfternoonEnd}
                  />
                </Grid>
              </Grid>
            )
          ) : updateKind === 'AFTERNOON_SUPPLEMENT' ? (
            scenario?.partial ? (
              <PartialShiftFields
                existingIn={scenario.existingAfternoonIn}
                existingOut={scenario.existingAfternoonOut}
                missingIn={scenario.missingAfternoonIn}
                missingOut={scenario.missingAfternoonOut}
                inValue={afternoonStart}
                outValue={afternoonEnd}
                onInChange={setAfternoonStart}
                onOutChange={setAfternoonEnd}
              />
            ) : (
              <ShiftTimeBlock
                title="Ca chiều"
                icon={<WbTwilightIcon sx={{ fontSize: 18, color: accent }} />}
                accent={accent}
                startLabel="Vào ca"
                endLabel="Ra ca"
                start={afternoonStart}
                end={afternoonEnd}
                onStartChange={setAfternoonStart}
                onEndChange={setAfternoonEnd}
              />
            )
          ) : scenario?.partial ? (
            <PartialShiftFields
              existingIn={scenario.existingMorningIn}
              existingOut={scenario.existingMorningOut}
              missingIn={scenario.missingMorningIn}
              missingOut={scenario.missingMorningOut}
              inValue={morningStart}
              outValue={morningEnd}
              onInChange={setMorningStart}
              onOutChange={setMorningEnd}
            />
          ) : (
            <ShiftTimeBlock
              title="Ca sáng"
              icon={<WbSunnyOutlinedIcon sx={{ fontSize: 18, color: accent }} />}
              accent={accent}
              startLabel="Vào ca"
              endLabel="Ra ca"
              start={morningStart}
              end={morningEnd}
              onStartChange={setMorningStart}
              onEndChange={setMorningEnd}
            />
          )}
        </Box>
      </FormSection>

      <FormSection title="Lý do cập nhật">
        <TextField
          fullWidth
          size="small"
          required
          multiline
          minRows={3}
          placeholder={
            isContinuous
              ? 'Ví dụ: quên chấm giờ vào/ra ca thông tầm, máy chấm lỗi…'
              : 'Ví dụ: quên chấm công ca chiều, máy chấm lỗi…'
          }
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
