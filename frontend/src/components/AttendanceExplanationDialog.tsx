import LoginIcon from '@mui/icons-material/Login';
import LogoutIcon from '@mui/icons-material/Logout';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import { Box, Stack, TextField, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import * as att from '../services/attendanceService';
import { DatePickerField, TimePickerField, dateTimeFieldSx } from '../components/ui/DateTimeFields';
import {
  ExplainToggleCard,
  FormSection,
  InfoBanner,
  RequestFlowSteps,
  WorkRequestDialogShell,
} from './work/WorkRequestFormUi';
import { scheduleForDate, type ShiftScheduleInfo } from '../utils/shiftSchedule';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  defaultDate?: string;
  attendanceRow?: Record<string, unknown> | null;
  continuousShift?: boolean;
  /** Lịch ca NV (ưu tiên); nếu thiếu sẽ tải theo employeeId + ngày */
  schedule?: ShiftScheduleInfo | null;
  employeeId?: number | null;
  /** Prefill: chỉ tích các khung này (vd. từ chi tiết ngày) */
  initialSelectedKeys?: att.ExplanationSlotKey[];
  editRequest?: att.WorkRequest | null;
};

const fieldSx = dateTimeFieldSx;

type SlotEdits = Partial<Record<att.ExplanationSlotKey, string>>;
type SlotSelected = Partial<Record<att.ExplanationSlotKey, boolean>>;

export function AttendanceExplanationDialog({
  open,
  onClose,
  onSubmitted,
  defaultDate,
  attendanceRow,
  continuousShift,
  schedule: scheduleProp,
  employeeId,
  initialSelectedKeys,
  editRequest,
}: Props) {
  const theme = useTheme();
  const accent = theme.palette.warning.main;
  const isEditing = Boolean(editRequest);

  const [workDate, setWorkDate] = useState(defaultDate ?? new Date().toISOString().slice(0, 10));
  const [daySchedule, setDaySchedule] = useState<ShiftScheduleInfo | null>(scheduleProp ?? null);
  const [selected, setSelected] = useState<SlotSelected>({});
  const [edits, setEdits] = useState<SlotEdits>({});
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    const wd = editRequest?.workDate ?? defaultDate ?? new Date().toISOString().slice(0, 10);
    setWorkDate(wd);
    setErr(null);

    if (editRequest) {
      setReason(editRequest.reason || '');
      const sel: SlotSelected = {};
      const ed: SlotEdits = {};
      const slotMap: Array<[att.ExplanationSlotKey, string | undefined]> = [
        ['morningIn', editRequest.explainedMorningIn],
        ['morningOut', editRequest.explainedMorningOut],
        ['afternoonIn', editRequest.explainedAfternoonIn],
        ['afternoonOut', editRequest.explainedAfternoonOut],
      ];
      for (const [key, val] of slotMap) {
        if (val?.trim()) {
          sel[key] = true;
          ed[key] = val.slice(0, 5);
        }
      }
      setSelected(sel);
      setEdits(ed);

      let cancelled = false;
      const targetEmployeeId = employeeId ?? editRequest.employeeId;
      if (targetEmployeeId != null) {
        att
          .fetchShiftSchedule(wd, targetEmployeeId)
          .then((s) => {
            if (!cancelled) setDaySchedule(s);
          })
          .catch(() => {
            if (!cancelled) setDaySchedule(scheduleProp ?? scheduleForDate(wd));
          });
      } else {
        setDaySchedule(scheduleProp ?? scheduleForDate(wd));
      }
      return () => {
        cancelled = true;
      };
    }

    setReason('');

    let cancelled = false;
    const applySchedule = (sch: ShiftScheduleInfo | null) => {
      if (cancelled) return;
      setDaySchedule(sch);
      const nextSlots = att.detectExplanationPenaltySlots(
        attendanceRow,
        wd,
        continuousShift,
        sch,
      );
      const prefer = initialSelectedKeys?.length
        ? new Set(initialSelectedKeys)
        : null;
      const sel: SlotSelected = {};
      const ed: SlotEdits = {};
      for (const s of nextSlots) {
        // Nhiều khung: mặc định bỏ tích — NV chỉ tích khung muốn giải trình.
        // Một khung hoặc có prefill: tự tích.
        const on = prefer
          ? prefer.has(s.key)
          : nextSlots.length === 1;
        sel[s.key] = on;
        ed[s.key] = s.expected;
      }
      setSelected(sel);
      setEdits(ed);
    };

    if (employeeId != null) {
      att
        .fetchShiftSchedule(wd, employeeId)
        .then((s) => applySchedule(s))
        .catch(() => applySchedule(scheduleProp ?? scheduleForDate(wd)));
    } else {
      applySchedule(scheduleProp ?? scheduleForDate(wd));
    }

    return () => {
      cancelled = true;
    };
  }, [open, defaultDate, attendanceRow, continuousShift, scheduleProp, employeeId, initialSelectedKeys, editRequest]);

  const slots = useMemo(() => {
    const detected = att.detectExplanationPenaltySlots(
      attendanceRow,
      workDate,
      continuousShift,
      daySchedule,
    );
    if (!isEditing || !editRequest || detected.length > 0) return detected;

    const sch = daySchedule ?? scheduleForDate(workDate);
    const built: att.ExplanationPenaltySlot[] = [];
    const addSlot = (
      key: att.ExplanationSlotKey,
      label: string,
      val: string | undefined,
      expected: string,
      kind: 'LATE' | 'EARLY',
    ) => {
      if (!val?.trim()) return;
      built.push({
        key,
        label,
        kind,
        kindLabel: kind === 'LATE' ? 'Đi muộn' : 'Về sớm',
        current: '—',
        expected,
        minutes: 0,
      });
    };
    addSlot(
      'morningIn',
      'Vào ca sáng',
      editRequest.explainedMorningIn,
      sch.morningStart,
      'LATE',
    );
    addSlot(
      'morningOut',
      'Ra ca sáng',
      editRequest.explainedMorningOut,
      sch.morningEnd,
      'EARLY',
    );
    addSlot(
      'afternoonIn',
      'Vào ca chiều',
      editRequest.explainedAfternoonIn,
      sch.afternoonStart,
      'LATE',
    );
    addSlot(
      'afternoonOut',
      'Ra ca chiều',
      editRequest.explainedAfternoonOut,
      sch.afternoonEnd,
      'EARLY',
    );
    return built;
  }, [attendanceRow, workDate, continuousShift, daySchedule, isEditing, editRequest]);

  function toggleSlot(key: att.ExplanationSlotKey, expected: string) {
    setSelected((prev) => {
      const next = !prev[key];
      if (next) {
        setEdits((e) => ({ ...e, [key]: e[key] || expected }));
      }
      return { ...prev, [key]: next };
    });
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!reason.trim()) {
      setErr('Nhập lý do giải trình.');
      return;
    }
    const chosen = slots.filter((s) => selected[s.key]);
    if (chosen.length === 0) {
      setErr('Tích chọn ít nhất một khung giờ cần giải trình.');
      return;
    }
    for (const s of chosen) {
      if (!edits[s.key]) {
        setErr(`Nhập giờ thay thế cho: ${s.label}`);
        return;
      }
    }
    setLoading(true);
    setErr(null);
    try {
      const body: att.SubmitWorkRequest = {
        requestType: 'EXPLANATION',
        ...(employeeId != null ? { employeeId } : {}),
        workDate,
        shiftScope: att.shiftScopeFromExplanationSlots(chosen.map((s) => s.key)),
        reason: reason.trim(),
      };
      for (const s of chosen) {
        const t = edits[s.key]!;
        if (s.key === 'morningIn') body.explainedMorningIn = t;
        if (s.key === 'morningOut') body.explainedMorningOut = t;
        if (s.key === 'afternoonIn') body.explainedAfternoonIn = t;
        if (s.key === 'afternoonOut') body.explainedAfternoonOut = t;
      }
      if (isEditing && editRequest) {
        await att.updateWorkRequest(editRequest.id, body);
      } else {
        await att.submitWorkRequest(body);
      }
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Gửi giải trình thất bại.');
    } finally {
      setLoading(false);
    }
  }

  const sch = daySchedule ?? scheduleForDate(workDate);
  const cont = continuousShift || sch.continuousShift
    ? { start: sch.continuousStart ?? sch.morningStart, end: sch.continuousEnd ?? sch.afternoonEnd }
    : null;
  const scheduleHint =
    (continuousShift || sch.continuousShift) && cont
      ? `Ca thông tầm: ${cont.start.slice(0, 5)} – ${cont.end.slice(0, 5)}`
      : `Lịch: sáng ${sch.morningStart.slice(0, 5)}–${sch.morningEnd.slice(0, 5)}, chiều ${sch.afternoonStart.slice(0, 5)}–${sch.afternoonEnd.slice(0, 5)}`;

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={accent}
      maxWidth="lg"
      icon={<ScheduleOutlinedIcon />}
      overline={isEditing ? 'Chỉnh sửa đơn' : 'Đơn giải trình'}
      title={isEditing ? 'Chỉnh sửa giải trình' : 'Giải trình đi muộn / về sớm'}
      description="Chỉ tích các khung giờ bị trừ tiền mà bạn muốn điều chỉnh. Khung giờ đi muộn/về sớm thật thì bỏ tích."
      formId="att-explain-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi giải trình'}
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
        {continuousShift || sch.continuousShift ? (
          <>
            Ngày này là <strong>ca thông tầm</strong> — chỉ xét giờ vào đầu ngày và giờ ra cuối ngày. Tích khung
            đang bị trừ tiền cần sửa, rồi nhập <strong>giờ thay thế</strong>. Đơn qua lãnh đạo → HCNS → Giám đốc
            quyết định trừ tiền muộn/sớm.
          </>
        ) : (
          <>
            Hệ thống liệt kê các mốc đang bị tính phạt theo <strong>lịch ca của bạn</strong>. Tích chọn khung cần
            sửa (có thể chỉ 1 khung, ví dụ đi muộn sáng nhưng không giải trình về sớm chiều), rồi nhập{' '}
            <strong>giờ thay thế</strong>. Đơn qua lãnh đạo → HCNS → Giám đốc quyết định trừ tiền muộn/sớm.
          </>
        )}
      </InfoBanner>

      <FormSection title="Ngày giải trình" subtitle={scheduleHint}>
        <DatePickerField
          label="Ngày"
          required
          value={workDate}
          onChange={setWorkDate}
          sx={fieldSx}
          disabled
        />
      </FormSection>

      <FormSection
        title="Khung giờ bị trừ tiền"
        subtitle={
          slots.length === 0
            ? 'Không phát hiện mốc muộn/về sớm trên ngày này.'
            : `${slots.length} khung giờ — tích chọn khung cần giải trình`
        }
      >
        {slots.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            Không có khung giờ nào đang bị tính muộn/về sớm theo lịch ca hiện tại.
          </Typography>
        ) : (
          slots.map((s) => {
            const isOn = Boolean(selected[s.key]);
            const icon =
              s.kind === 'LATE' ? <LoginIcon fontSize="small" /> : <LogoutIcon fontSize="small" />;
            const cardAccent = s.kind === 'LATE' ? theme.palette.warning.dark : theme.palette.error.main;
            return (
              <ExplainToggleCard
                key={s.key}
                selected={isOn}
                title={`${s.kindLabel} · ${s.label}`}
                subtitle={`${s.minutes} phút · lịch ${s.expected}`}
                icon={icon}
                accent={cardAccent}
                onToggle={() => toggleSlot(s.key, s.expected)}
              >
                <Stack spacing={1.5}>
                  <Box
                    sx={{
                      display: 'grid',
                      gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
                      gap: 1.25,
                    }}
                  >
                    <Box
                      sx={{
                        p: 1.25,
                        borderRadius: 2,
                        bgcolor: alpha(theme.palette.grey[500], 0.08),
                        border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                      }}
                    >
                      <Typography variant="caption" color="text.secondary" display="block">
                        Giờ máy chấm (hiện tại)
                      </Typography>
                      <Typography variant="h6" fontWeight={800} sx={{ mt: 0.25, fontVariantNumeric: 'tabular-nums' }}>
                        {s.current}
                      </Typography>
                    </Box>
                    <TimePickerField
                      required={isOn}
                      disabled={!isOn}
                      label="Giờ thay thế (muốn sửa thành)"
                      helperText={isOn ? `Gợi ý theo lịch: ${s.expected}` : 'Tích chọn khung để nhập giờ thay thế'}
                      value={edits[s.key] ?? ''}
                      onChange={(v) => setEdits((prev) => ({ ...prev, [s.key]: v }))}
                      sx={fieldSx}
                    />
                  </Box>
                </Stack>
              </ExplainToggleCard>
            );
          })
        )}
      </FormSection>

      <FormSection title="Lý do giải trình">
        <TextField
          fullWidth
          size="small"
          required
          multiline
          minRows={3}
          placeholder="Mô tả ngắn gọn lý do…"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
