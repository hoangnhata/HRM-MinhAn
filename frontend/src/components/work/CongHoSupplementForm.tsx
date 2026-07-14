import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import HowToRegOutlinedIcon from '@mui/icons-material/HowToRegOutlined';
import SaveOutlinedIcon from '@mui/icons-material/SaveOutlined';
import WbSunnyOutlinedIcon from '@mui/icons-material/WbSunnyOutlined';
import WbTwilightIcon from '@mui/icons-material/WbTwilight';
import { Alert, Box, Button, Chip, CircularProgress, Grid, Stack, TextField, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { DatePickerField, TimePickerField, dateTimeFieldSx } from '../ui/DateTimeFields';
import { FormSection, InfoBanner, SelectableChip } from './WorkRequestFormUi';
import * as att from '../../services/attendanceService';
import { scheduleForDate } from '../../utils/shiftSchedule';

type Props = {
  open: boolean;
  employeeId: number;
  employeeName: string;
  workDate: string;
  onClose: () => void;
  onSaved?: () => void;
};

const fieldSx = dateTimeFieldSx;

function timeShort(v?: string): string {
  if (!v) return '';
  return v.length >= 5 ? v.slice(0, 5) : v;
}

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

export function CongHoSupplementForm({
  open,
  employeeId,
  employeeName,
  workDate: initialWorkDate,
  onClose,
  onSaved,
}: Props) {
  const theme = useTheme();
  const accent = theme.palette.success.main;

  const [workDate, setWorkDate] = useState(initialWorkDate);
  const [updateKind, setUpdateKind] = useState<string>('MORNING_SUPPLEMENT');
  const [reason, setReason] = useState('');
  const [morningStart, setMorningStart] = useState('07:00');
  const [morningEnd, setMorningEnd] = useState('12:00');
  const [afternoonStart, setAfternoonStart] = useState('14:00');
  const [afternoonEnd, setAfternoonEnd] = useState('17:00');
  const [loading, setLoading] = useState(false);
  const [loadingExisting, setLoadingExisting] = useState(false);
  const [existing, setExisting] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [skipScheduleReset, setSkipScheduleReset] = useState(false);

  const isFullDay = updateKind === 'FULL_DAY_SUPPLEMENT';

  useEffect(() => {
    if (!open) return;
    setWorkDate(initialWorkDate);
    setErr(null);
    setExisting(false);
    setLoadingExisting(true);
    const sch = scheduleForDate(initialWorkDate);
    setUpdateKind('MORNING_SUPPLEMENT');
    setReason('');
    setMorningStart(sch.morningStart);
    setMorningEnd(sch.morningEnd);
    setAfternoonStart(sch.afternoonStart);
    setAfternoonEnd(sch.afternoonEnd);

    let cancelled = false;
    att
      .fetchCongHoSupplement(employeeId, initialWorkDate)
      .then((info) => {
        if (cancelled) return;
        if (!info.exists) {
          setExisting(false);
          return;
        }
        setExisting(true);
        setSkipScheduleReset(true);
        if (info.updateKind) setUpdateKind(info.updateKind);
        setReason(info.reason ?? '');
        if (info.morningCheckIn) setMorningStart(timeShort(info.morningCheckIn));
        if (info.morningCheckOut) setMorningEnd(timeShort(info.morningCheckOut));
        if (info.afternoonCheckIn) setAfternoonStart(timeShort(info.afternoonCheckIn));
        if (info.afternoonCheckOut) setAfternoonEnd(timeShort(info.afternoonCheckOut));
      })
      .catch(() => {
        if (!cancelled) setExisting(false);
      })
      .finally(() => {
        if (!cancelled) setLoadingExisting(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, initialWorkDate, employeeId]);

  useEffect(() => {
    if (!open || skipScheduleReset) {
      setSkipScheduleReset(false);
      return;
    }
    const sch = scheduleForDate(workDate);
    setMorningStart(sch.morningStart);
    setMorningEnd(sch.morningEnd);
    setAfternoonStart(sch.afternoonStart);
    setAfternoonEnd(sch.afternoonEnd);
  }, [workDate, updateKind]);

  async function handleSave() {
    setLoading(true);
    setErr(null);
    try {
      const payload: att.CongHoSupplementBody = {
        workDate,
        updateKind: updateKind as att.CongHoSupplementBody['updateKind'],
        reason: reason.trim(),
        requestedStart: updateKind === 'AFTERNOON_SUPPLEMENT' ? afternoonStart : morningStart,
        requestedEnd: updateKind === 'AFTERNOON_SUPPLEMENT' ? afternoonEnd : morningEnd,
      };
      if (isFullDay) {
        payload.requestedStart = morningStart;
        payload.requestedEnd = morningEnd;
        payload.requestedAfternoonStart = afternoonStart;
        payload.requestedAfternoonEnd = afternoonEnd;
      }
      await att.applyCongHoSupplement(employeeId, payload);
      onSaved?.();
      onClose();
    } catch {
      setErr('Không lưu được công hộ. Kiểm tra quyền ADMIN/HCNS và dữ liệu nhập.');
    } finally {
      setLoading(false);
    }
  }

  async function handleDelete() {
    if (!existing) return;
    if (!window.confirm('Xóa công hộ ngày này? Giờ chấm công bổ sung sẽ bị gỡ.')) return;
    setLoading(true);
    setErr(null);
    try {
      await att.deleteCongHoSupplement(employeeId, workDate);
      onSaved?.();
      onClose();
    } catch {
      setErr('Không xóa được công hộ.');
    } finally {
      setLoading(false);
    }
  }

  if (!open) return null;

  const sch = scheduleForDate(workDate);
  const scheduleHint =
    isFullDay
      ? `${sch.seasonLabel}: ${sch.morningStart}–${sch.morningEnd} · ${sch.afternoonStart}–${sch.afternoonEnd}`
      : updateKind === 'AFTERNOON_SUPPLEMENT'
        ? `Ca chiều: ${sch.afternoonStart} – ${sch.afternoonEnd}`
        : `Ca sáng: ${sch.morningStart} – ${sch.morningEnd}`;

  return (
    <Stack spacing={2.5}>
      <InfoBanner>
        {existing ? (
          <>
            Đang <strong>sửa</strong> công hộ của <strong>{employeeName}</strong>. Có thể đổi ca/giờ rồi lưu,
            hoặc xóa công ngày này.
          </>
        ) : (
          <>
            Bổ sung <strong>công hộ</strong> cho <strong>{employeeName}</strong> (không chấm vân tay). Áp dụng trực
            tiếp, <strong>không</strong> trừ phạt quên chấm. Chỉ tài khoản <strong>Admin / HCNS</strong> được thao tác.
          </>
        )}
      </InfoBanner>

      {existing && (
        <Chip
          size="small"
          color="warning"
          variant="outlined"
          label="Đã có công hộ — đang chỉnh sửa"
          sx={{ width: 'fit-content', fontWeight: 600 }}
        />
      )}

      {loadingExisting ? (
        <Box sx={{ display: 'grid', placeItems: 'center', py: 4 }}>
          <CircularProgress size={28} />
        </Box>
      ) : (
        <>
          <FormSection title="Ngày & loại bổ sung" subtitle={scheduleHint}>
            <DatePickerField
              label="Ngày công hộ"
              required
              value={workDate}
              onChange={setWorkDate}
              sx={fieldSx}
            />
            <Stack spacing={1}>
              {att.CONG_HO_KIND_OPTIONS.map((o) => (
                <SelectableChip
                  key={o.value}
                  selected={updateKind === o.value}
                  label={o.label}
                  onClick={() => setUpdateKind(o.value)}
                />
              ))}
            </Stack>
          </FormSection>

          <FormSection title="Khung giờ công" subtitle="Điều chỉnh nếu khác với lịch ca mặc định.">
            <Box
              sx={{
                p: 2,
                borderRadius: 2.5,
                bgcolor: alpha(accent, 0.05),
                border: `1px dashed ${alpha(accent, 0.25)}`,
              }}
            >
              <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 2 }}>
                <HowToRegOutlinedIcon sx={{ fontSize: 18, color: accent }} />
                <Typography variant="body2" color="text.secondary">
                  {scheduleHint}
                </Typography>
              </Stack>

              {isFullDay ? (
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
              ) : updateKind === 'AFTERNOON_SUPPLEMENT' ? (
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

          <FormSection title="Lý do bổ sung" subtitle="Tuỳ chọn">
            <TextField
              fullWidth
              size="small"
              multiline
              minRows={3}
              placeholder="Ví dụ: Lãnh đạo không chấm vân tay, hỗ trợ công tác đặc biệt…"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              sx={fieldSx}
            />
          </FormSection>
        </>
      )}

      {err && (
        <Alert severity="error" variant="outlined" onClose={() => setErr(null)} sx={{ borderRadius: 2 }}>
          {err}
        </Alert>
      )}

      <Stack direction="row" spacing={1.5} alignItems="center">
        {existing ? (
          <Button
            color="error"
            variant="outlined"
            onClick={handleDelete}
            disabled={loading || loadingExisting}
            startIcon={<DeleteOutlineIcon />}
            sx={{ borderRadius: 2, mr: 'auto' }}
          >
            Xóa công hộ
          </Button>
        ) : (
          <Box sx={{ mr: 'auto' }} />
        )}
        <Button
          variant="contained"
          onClick={handleSave}
          disabled={loading || loadingExisting}
          startIcon={loading ? <CircularProgress size={18} color="inherit" /> : <SaveOutlinedIcon />}
          sx={{ borderRadius: 2, px: 2.5 }}
        >
          {loading ? 'Đang lưu…' : existing ? 'Cập nhật công hộ' : 'Lưu công hộ'}
        </Button>
      </Stack>
    </Stack>
  );
}
