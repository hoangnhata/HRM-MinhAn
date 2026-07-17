import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import EditCalendarOutlinedIcon from '@mui/icons-material/EditCalendarOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import WbSunnyOutlinedIcon from '@mui/icons-material/WbSunnyOutlined';
import WbTwilightIcon from '@mui/icons-material/WbTwilight';
import { Box, Grid, InputAdornment, Stack, TextField, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as att from '../services/attendanceService';
import * as employeeService from '../services/employeeService';
import { DatePickerField, TimePickerField, dateTimeFieldSx } from '../components/ui/DateTimeFields';
import {
  FormSection,
  InfoBanner,
  SelectableChip,
  WorkRequestDialogShell,
} from './work/WorkRequestFormUi';
import { scheduleForDate, formatPunchTime } from '../utils/shiftSchedule';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  defaultDate?: string;
  attendanceRow?: Record<string, unknown> | null;
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
  accent,
  existingIn,
  existingOut,
  missingIn,
  missingOut,
  inValue,
  outValue,
  onInChange,
  onOutChange,
}: {
  accent: string;
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
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = theme.palette.primary.main;

  const [workDate, setWorkDate] = useState(defaultDate ?? new Date().toISOString().slice(0, 10));
  const [updateKind, setUpdateKind] = useState<string>('MORNING_SUPPLEMENT');
  const [reason, setReason] = useState('');
  const [morningStart, setMorningStart] = useState('07:00');
  const [morningEnd, setMorningEnd] = useState('12:00');
  const [afternoonStart, setAfternoonStart] = useState('14:00');
  const [afternoonEnd, setAfternoonEnd] = useState('17:00');
  const [departmentName, setDepartmentName] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [scenario, setScenario] = useState<att.UpdateScenario | null>(null);

  const isFullDay = updateKind === 'FULL_DAY_SUPPLEMENT';
  const forgotUnits = scenario?.forgotUnits ?? att.forgotFineUnitsForUpdateKind(updateKind);
  const kindLocked = Boolean(scenario?.locked);

  useEffect(() => {
    if (!open) return;
    const wd = defaultDate ?? new Date().toISOString().slice(0, 10);
    const sch = scheduleForDate(wd);
    const detected = att.detectUpdateFromRow(attendanceRow);
    setWorkDate(wd);
    setUpdateKind(detected.updateKind);
    setScenario(detected);
    setReason('');
    setErr(null);
    setMorningStart(detected.existingMorningIn ?? sch.morningStart);
    setMorningEnd(detected.existingMorningOut ?? sch.morningEnd);
    setAfternoonStart(detected.existingAfternoonIn ?? sch.afternoonStart);
    setAfternoonEnd(detected.existingAfternoonOut ?? sch.afternoonEnd);
    employeeService
      .fetchMe()
      .then((me) => setDepartmentName(me.departmentName ?? ''))
      .catch(() => setDepartmentName(''));
  }, [open, defaultDate, attendanceRow]);

  useEffect(() => {
    if (!open || kindLocked) return;
    const sch = scheduleForDate(workDate);
    setMorningStart(sch.morningStart);
    setMorningEnd(sch.morningEnd);
    setAfternoonStart(sch.afternoonStart);
    setAfternoonEnd(sch.afternoonEnd);
  }, [workDate, open, kindLocked]);

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
        shiftScope: shiftScopeFromKind(updateKind),
        updateKind: updateKind as att.SubmitWorkRequest['updateKind'],
        reason: reason.trim(),
      };
      if (isFullDay) {
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
      await att.submitWorkRequest(payload);
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Gửi đơn thất bại. Kiểm tra ngày đã có đơn chờ duyệt hoặc thiếu thông tin.');
    } finally {
      setLoading(false);
    }
  }

  const sch = scheduleForDate(workDate);
  const scheduleHint =
    isFullDay
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
      maxWidth="md"
      icon={<EditCalendarOutlinedIcon />}
      overline="Đề nghị cập nhật"
      title="Cập nhật công"
      description="Dành cho trường hợp quên chấm công hoặc thiếu ca. Đơn qua lãnh đạo rồi HCNS duyệt."
      formId="att-update-form"
      submitLabel="Gửi đơn cập nhật"
      error={err}
      onSubmit={submit}
    >
      <InfoBanner>
        Sau khi được duyệt, hệ thống cập nhật giờ công theo khung thời gian bạn đề nghị. Mỗi ngày chỉ gửi một đơn
        đang chờ duyệt. Nếu HCNS duyệt có trừ tiền quên chấm: đơn này trừ{' '}
        <strong>{forgotUnits} lần</strong>
        {scenario?.partial ? ` (thiếu ${forgotUnits} mốc chấm)` : ''} theo bậc phạt tháng.
      </InfoBanner>

      <FormSection title="Người nộp đơn">
        <Grid container spacing={1.5}>
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              size="small"
              label="Họ và tên"
              value={user?.fullName ?? ''}
              disabled
              sx={fieldSx}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <PersonOutlineIcon fontSize="small" color="action" />
                  </InputAdornment>
                ),
              }}
            />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              size="small"
              label="Phòng ban"
              value={departmentName || '—'}
              disabled
              sx={fieldSx}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <BusinessOutlinedIcon fontSize="small" color="action" />
                  </InputAdornment>
                ),
              }}
            />
          </Grid>
        </Grid>
      </FormSection>

      <FormSection title="Ngày & loại cập nhật" subtitle={scheduleHint}>
        <DatePickerField
          label="Ngày cần cập nhật"
          required
          value={workDate}
          onChange={setWorkDate}
          sx={fieldSx}
        />
        <Stack spacing={1}>
          {kindLocked ? (
            <SelectableChip
              selected
              label={`${att.UPDATE_KIND_OPTIONS.find((o) => o.value === updateKind)?.label ?? 'Cập nhật'} · trừ ${forgotUnits} lần quên chấm`}
              onClick={() => {}}
            />
          ) : (
            att.UPDATE_KIND_OPTIONS.map((o) => (
              <SelectableChip
                key={o.value}
                selected={updateKind === o.value}
                label={`${o.label} · trừ ${o.forgotUnits} lần quên chấm`}
                onClick={() => setUpdateKind(o.value)}
              />
            ))
          )}
        </Stack>
      </FormSection>

      <FormSection title="Khung giờ đề nghị" subtitle="Điều chỉnh nếu khác với lịch ca mặc định.">
        <Box
          sx={{
            p: 2,
            borderRadius: 2.5,
            bgcolor: alpha(accent, 0.05),
            border: `1px dashed ${alpha(accent, 0.25)}`,
          }}
        >
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 2 }}>
            <WbTwilightIcon sx={{ fontSize: 18, color: accent }} />
            <Typography variant="body2" color="text.secondary">
              {scheduleHint}
            </Typography>
          </Stack>

          {isFullDay ? (
            scenario?.partial ? (
              <Grid container spacing={2}>
                <Grid item xs={12} md={6}>
                  <Stack spacing={1}>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <WbSunnyOutlinedIcon sx={{ fontSize: 18, color: accent }} />
                      <Typography variant="subtitle2">Ca sáng</Typography>
                    </Stack>
                    <PartialShiftFields
                      accent={accent}
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
                      accent={accent}
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
                accent={accent}
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
              accent={accent}
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
          placeholder="Ví dụ: quên chấm công ca chiều, máy chấm lỗi…"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
