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
  WorkRequestDialogShell,
} from './work/WorkRequestFormUi';
import { scheduleForDate } from '../utils/shiftSchedule';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  defaultDate?: string;
  attendanceRow?: Record<string, unknown> | null;
  continuousShift?: boolean;
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
}: Props) {
  const theme = useTheme();
  const accent = theme.palette.warning.main;

  const [workDate, setWorkDate] = useState(defaultDate ?? new Date().toISOString().slice(0, 10));
  const [selected, setSelected] = useState<SlotSelected>({});
  const [edits, setEdits] = useState<SlotEdits>({});
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const slots = useMemo(
    () => att.detectExplanationPenaltySlots(attendanceRow, workDate, continuousShift),
    [attendanceRow, workDate, continuousShift],
  );

  useEffect(() => {
    if (!open) return;
    const wd = defaultDate ?? new Date().toISOString().slice(0, 10);
    setWorkDate(wd);
    setReason('');
    setErr(null);
    const nextSlots = att.detectExplanationPenaltySlots(attendanceRow, wd, continuousShift);
    const sel: SlotSelected = {};
    const ed: SlotEdits = {};
    for (const s of nextSlots) {
      sel[s.key] = true;
      ed[s.key] = s.expected;
    }
    setSelected(sel);
    setEdits(ed);
  }, [open, defaultDate, attendanceRow, continuousShift]);

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
      await att.submitWorkRequest(body);
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Gửi giải trình thất bại.');
    } finally {
      setLoading(false);
    }
  }

  const sch = scheduleForDate(workDate);
  const cont = continuousShift
    ? { start: sch.continuousStart ?? sch.morningStart, end: sch.continuousEnd ?? sch.afternoonEnd }
    : null;
  const scheduleHint = continuousShift && cont
    ? `Ca thông tầm: ${cont.start} – ${cont.end}`
    : `Lịch: sáng ${sch.morningStart}–${sch.morningEnd}, chiều ${sch.afternoonStart}–${sch.afternoonEnd}`;

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={accent}
      maxWidth="md"
      icon={<ScheduleOutlinedIcon />}
      overline="Đơn giải trình"
      title="Giải trình đi muộn / về sớm"
      description="Chỉ tích các khung giờ bị trừ tiền mà bạn muốn điều chỉnh. Khung giờ đi muộn/về sớm thật thì bỏ tích."
      formId="att-explain-form"
      submitLabel="Gửi giải trình"
      error={err}
      onSubmit={submit}
    >
      <InfoBanner>
        Hệ thống liệt kê các mốc đang bị tính phạt. Với mỗi mốc: xem <strong>giờ máy chấm</strong>, tích chọn nếu
        cần sửa, rồi nhập <strong>giờ thay thế</strong>. Có thể chọn 1 hoặc nhiều khung (tối đa 4).
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
            Không có khung giờ nào đang bị tính muộn/về sớm.
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
                      required
                      label="Giờ thay thế (muốn sửa thành)"
                      helperText={`Gợi ý theo lịch: ${s.expected}`}
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
