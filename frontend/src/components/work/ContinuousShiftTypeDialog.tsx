import AddIcon from '@mui/icons-material/Add';
import CloseIcon from '@mui/icons-material/Close';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import EditOutlinedIcon from '@mui/icons-material/EditOutlined';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import TimelineIcon from '@mui/icons-material/Timeline';
import LoginOutlinedIcon from '@mui/icons-material/LoginOutlined';
import LogoutOutlinedIcon from '@mui/icons-material/LogoutOutlined';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogContent,
  Divider,
  IconButton,
  Paper,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import * as attendance from '../../services/attendanceService';
import type { ContinuousShiftKind, ContinuousShiftType } from '../../services/attendanceService';
import { TimePickerField } from '../ui/DateTimeFields';

type Props = {
  open: boolean;
  onClose: () => void;
};

type FormState = {
  kind: ContinuousShiftKind;
  name: string;
  startTime: string;
  endTime: string;
  morningStart: string;
  morningEnd: string;
  afternoonStart: string;
  afternoonEnd: string;
  checkInBeforeMin: string;
  checkInAfterMin: string;
  checkOutBeforeMin: string;
  checkOutAfterMin: string;
  morningOutBeforeMin: string;
  morningOutAfterMin: string;
  afternoonInBeforeMin: string;
  afternoonInAfterMin: string;
};

const blankForm: FormState = {
  kind: 'CONTINUOUS',
  name: '',
  startTime: '07:00',
  endTime: '15:00',
  morningStart: '07:00',
  morningEnd: '11:00',
  afternoonStart: '13:00',
  afternoonEnd: '17:00',
  checkInBeforeMin: '60',
  checkInAfterMin: '120',
  checkOutBeforeMin: '60',
  checkOutAfterMin: '60',
  morningOutBeforeMin: '60',
  morningOutAfterMin: '30',
  afternoonInBeforeMin: '30',
  afternoonInAfterMin: '60',
};

function shiftTime(value: string, deltaMinutes: number) {
  const [hour, minute] = value.split(':').map(Number);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return '—';
  const raw = hour * 60 + minute + deltaMinutes;
  const normalized = ((raw % 1440) + 1440) % 1440;
  return `${String(Math.floor(normalized / 60)).padStart(2, '0')}:${String(normalized % 60).padStart(2, '0')}`;
}

function windowLabel(anchor: string, before: string, after: string) {
  const beforeMin = Math.max(0, Number(before) || 0);
  const afterMin = Math.max(0, Number(after) || 0);
  return `${shiftTime(anchor, -beforeMin)} – ${shiftTime(anchor, afterMin)}`;
}

function minutesOf(value: string) {
  const [h, m] = value.split(':').map(Number);
  if (!Number.isFinite(h) || !Number.isFinite(m)) return null;
  return h * 60 + m;
}

function hoursBetween(a: string, b: string) {
  const ma = minutesOf(a);
  const mb = minutesOf(b);
  if (ma == null || mb == null || mb <= ma) return 0;
  return (mb - ma) / 60;
}

export function ContinuousShiftTypeDialog({ open, onClose }: Props) {
  const theme = useTheme();
  const accent = theme.palette.success.main;
  const [types, setTypes] = useState<ContinuousShiftType[]>([]);
  const [form, setForm] = useState<FormState>(blankForm);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const computedHours = useMemo(() => {
    if (form.kind === 'SPLIT') {
      return hoursBetween(form.morningStart, form.morningEnd)
        + hoursBetween(form.afternoonStart, form.afternoonEnd);
    }
    return hoursBetween(form.startTime, form.endTime);
  }, [form]);

  async function reload() {
    setLoading(true);
    try {
      setTypes(await attendance.fetchContinuousShiftTypes(true));
    } catch {
      setError('Không tải được danh sách khung ca.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!open) return;
    setForm(blankForm);
    setEditingId(null);
    setError(null);
    void reload();
  }, [open]);

  function edit(type: ContinuousShiftType) {
    const kind: ContinuousShiftKind = type.kind === 'SPLIT' ? 'SPLIT' : 'CONTINUOUS';
    setEditingId(type.id);
    setForm({
      kind,
      name: type.name,
      startTime: type.startTime.slice(0, 5),
      endTime: type.endTime.slice(0, 5),
      morningStart: (type.morningStart || type.startTime).slice(0, 5),
      morningEnd: (type.morningEnd || '11:00').slice(0, 5),
      afternoonStart: (type.afternoonStart || '13:00').slice(0, 5),
      afternoonEnd: (type.afternoonEnd || type.endTime).slice(0, 5),
      checkInBeforeMin: String(type.checkInBeforeMin ?? 60),
      checkInAfterMin: String(type.checkInAfterMin ?? 120),
      checkOutBeforeMin: String(type.checkOutBeforeMin ?? 60),
      checkOutAfterMin: String(type.checkOutAfterMin ?? 60),
      morningOutBeforeMin: String(type.morningOutBeforeMin ?? 60),
      morningOutAfterMin: String(type.morningOutAfterMin ?? 30),
      afternoonInBeforeMin: String(type.afternoonInBeforeMin ?? 30),
      afternoonInAfterMin: String(type.afternoonInAfterMin ?? 60),
    });
  }

  async function save() {
    setSaving(true);
    setError(null);
    const body =
      form.kind === 'SPLIT'
        ? {
            name: form.name.trim(),
            kind: 'SPLIT' as const,
            morningStart: `${form.morningStart}:00`,
            morningEnd: `${form.morningEnd}:00`,
            afternoonStart: `${form.afternoonStart}:00`,
            afternoonEnd: `${form.afternoonEnd}:00`,
            checkInBeforeMin: Number(form.checkInBeforeMin),
            checkInAfterMin: Number(form.checkInAfterMin),
            checkOutBeforeMin: Number(form.checkOutBeforeMin),
            checkOutAfterMin: Number(form.checkOutAfterMin),
            morningOutBeforeMin: Number(form.morningOutBeforeMin),
            morningOutAfterMin: Number(form.morningOutAfterMin),
            afternoonInBeforeMin: Number(form.afternoonInBeforeMin),
            afternoonInAfterMin: Number(form.afternoonInAfterMin),
            active: true,
          }
        : {
            name: form.name.trim(),
            kind: 'CONTINUOUS' as const,
            startTime: `${form.startTime}:00`,
            endTime: `${form.endTime}:00`,
            checkInBeforeMin: Number(form.checkInBeforeMin),
            checkInAfterMin: Number(form.checkInAfterMin),
            checkOutBeforeMin: Number(form.checkOutBeforeMin),
            checkOutAfterMin: Number(form.checkOutAfterMin),
            active: true,
          };
    try {
      if (editingId == null) await attendance.createContinuousShiftType(body);
      else await attendance.updateContinuousShiftType(editingId, body);
      setEditingId(null);
      setForm(blankForm);
      await reload();
    } catch (e: unknown) {
      setError(
        (e as { response?: { data?: { message?: string } } })?.response?.data?.message ||
          'Không lưu được ca. Tổng giờ làm phải tối thiểu 8 giờ.',
      );
    } finally {
      setSaving(false);
    }
  }

  async function remove(id: number) {
    if (!window.confirm('Xóa khung ca này? Thao tác không thể hoàn tác.')) return;
    setSaving(true);
    setError(null);
    try {
      await attendance.deleteContinuousShiftType(id);
      if (editingId === id) {
        setEditingId(null);
        setForm(blankForm);
      }
      await reload();
    } catch {
      setError('Không thể xóa ca này.');
    } finally {
      setSaving(false);
    }
  }

  const canSave =
    !!form.name.trim() &&
    (form.kind === 'CONTINUOUS'
      ? !!form.startTime && !!form.endTime
      : !!form.morningStart && !!form.morningEnd && !!form.afternoonStart && !!form.afternoonEnd);

  function punchWindowCard(opts: {
    title: string;
    icon: ReactNode;
    anchor: string;
    beforeKey: keyof FormState;
    afterKey: keyof FormState;
    color: string;
  }) {
    return (
      <Paper
        elevation={0}
        sx={{
          flex: 1,
          p: 1.5,
          borderRadius: 2.5,
          bgcolor: 'background.paper',
          border: `1px solid ${alpha(opts.color, 0.17)}`,
        }}
      >
        <Stack direction="row" spacing={1} alignItems="center">
          <Box
            sx={{
              width: 32,
              height: 32,
              borderRadius: 1.75,
              display: 'grid',
              placeItems: 'center',
              color: opts.color,
              bgcolor: alpha(opts.color, 0.1),
            }}
          >
            {opts.icon}
          </Box>
          <Box>
            <Typography variant="body2" fontWeight={800}>
              {opts.title}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              Mốc ca: {opts.anchor}
            </Typography>
          </Box>
        </Stack>
        <Stack direction="row" spacing={1} sx={{ mt: 1.25 }}>
          <TextField
            label="Trước"
            type="number"
            size="small"
            value={form[opts.beforeKey]}
            onChange={(e) => setForm((v) => ({ ...v, [opts.beforeKey]: e.target.value }))}
            inputProps={{ min: 0, step: 5 }}
            helperText="phút"
            sx={{ flex: 1 }}
          />
          <TextField
            label="Sau"
            type="number"
            size="small"
            value={form[opts.afterKey]}
            onChange={(e) => setForm((v) => ({ ...v, [opts.afterKey]: e.target.value }))}
            inputProps={{ min: 0, step: 5 }}
            helperText="phút"
            sx={{ flex: 1 }}
          />
        </Stack>
        <Box
          sx={{
            mt: 0.75,
            px: 1.25,
            py: 1,
            borderRadius: 2,
            textAlign: 'center',
            color: opts.color,
            bgcolor: alpha(opts.color, 0.07),
          }}
        >
          <Typography variant="caption" color="text.secondary" display="block">
            Khoảng giờ được nhận
          </Typography>
          <Typography variant="subtitle2" fontWeight={900} sx={{ letterSpacing: '0.04em' }}>
            {windowLabel(opts.anchor, String(form[opts.beforeKey]), String(form[opts.afterKey]))}
          </Typography>
        </Box>
      </Paper>
    );
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="md"
      fullWidth
      scroll="paper"
      PaperProps={{
        sx: {
          borderRadius: 4,
          overflow: 'hidden',
          width: 'min(960px, calc(100vw - 32px))',
          maxWidth: '960px',
          maxHeight: 'calc(100vh - 32px)',
          boxShadow: '0 24px 70px rgba(15, 23, 42, 0.22)',
        },
      }}
    >
      <Box
        sx={{
          px: { xs: 2.25, sm: 3 },
          py: 2.5,
          display: 'flex',
          alignItems: 'center',
          gap: 1.75,
          bgcolor: alpha(accent, 0.055),
          borderBottom: `1px solid ${alpha(accent, 0.14)}`,
        }}
      >
        <Box
          sx={{
            width: 46,
            height: 46,
            borderRadius: 2.5,
            display: 'grid',
            placeItems: 'center',
            color: accent,
            bgcolor: alpha(accent, 0.13),
            border: `1px solid ${alpha(accent, 0.18)}`,
            flexShrink: 0,
          }}
        >
          <TimelineIcon />
        </Box>
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <Typography variant="overline" color="success.dark" fontWeight={800} letterSpacing="0.09em">
            Cấu hình chấm công
          </Typography>
          <Typography variant="h6" fontWeight={800} lineHeight={1.2}>
            Danh mục ca theo ngày
          </Typography>
          <Typography variant="caption" color="text.secondary">
            Tạo khung ca thông tầm hoặc sáng–chiều để Trưởng khoa/Điều dưỡng trưởng xếp theo ngày.
          </Typography>
        </Box>
        <IconButton
          onClick={onClose}
          aria-label="Đóng"
          sx={{ bgcolor: alpha(theme.palette.text.primary, 0.045), '&:hover': { bgcolor: alpha(theme.palette.text.primary, 0.09) } }}
        >
          <CloseIcon />
        </IconButton>
      </Box>
      <DialogContent
        dividers
        sx={{
          px: { xs: 2.25, sm: 3 },
          py: 2.5,
          bgcolor: alpha(theme.palette.background.default, 0.35),
          borderColor: alpha(theme.palette.divider, 0.7),
        }}
      >
        {error && (
          <Alert severity="error" sx={{ mb: 2, borderRadius: 2.5 }}>
            {error}
          </Alert>
        )}

        <Paper
          variant="outlined"
          sx={{
            p: { xs: 1.75, sm: 2.25 },
            borderRadius: 3,
            borderColor: alpha(accent, editingId == null ? 0.18 : 0.38),
            bgcolor: editingId == null ? alpha(accent, 0.025) : alpha(accent, 0.055),
          }}
        >
          <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1.5 }} flexWrap="wrap" useFlexGap spacing={1}>
            <Box>
              <Typography variant="subtitle2" fontWeight={800}>
                {editingId == null ? 'Thêm khung ca mới' : 'Chỉnh sửa khung ca'}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Tổng giờ làm tối thiểu 8 giờ · hiện {computedHours.toFixed(1).replace(/\.0$/, '')} giờ
              </Typography>
            </Box>
            {editingId != null && <Chip label="Đang chỉnh sửa" size="small" color="success" variant="outlined" />}
          </Stack>

          <ToggleButtonGroup
            exclusive
            size="small"
            value={form.kind}
            onChange={(_, value: ContinuousShiftKind | null) => {
              if (!value) return;
              setForm((v) => ({ ...v, kind: value }));
            }}
            sx={{ mb: 1.75 }}
          >
            <ToggleButton value="CONTINUOUS" sx={{ textTransform: 'none', fontWeight: 700, px: 2 }}>
              Ca thông tầm
            </ToggleButton>
            <ToggleButton value="SPLIT" sx={{ textTransform: 'none', fontWeight: 700, px: 2 }}>
              Ca sáng–chiều
            </ToggleButton>
          </ToggleButtonGroup>

          <TextField
            label="Tên ca"
            placeholder={
              form.kind === 'SPLIT'
                ? 'Ví dụ: Ca sáng–chiều 7h–11h / 13h–17h'
                : 'Ví dụ: Ca hành chính 7h–15h'
            }
            size="small"
            fullWidth
            value={form.name}
            onChange={(e) => setForm((v) => ({ ...v, name: e.target.value }))}
            sx={{ mb: 1.5 }}
          />

          {form.kind === 'CONTINUOUS' ? (
            <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5}>
              <TimePickerField
                label="Giờ vào"
                value={form.startTime}
                onChange={(value) => setForm((v) => ({ ...v, startTime: value }))}
                minuteStep={5}
                sx={{ flex: 1 }}
              />
              <TimePickerField
                label="Giờ ra"
                value={form.endTime}
                onChange={(value) => setForm((v) => ({ ...v, endTime: value }))}
                minuteStep={5}
                sx={{ flex: 1 }}
              />
            </Stack>
          ) : (
            <Stack spacing={1.5}>
              <Typography variant="caption" color="text.secondary" fontWeight={700}>
                Buổi sáng
              </Typography>
              <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5}>
                <TimePickerField
                  label="Sáng vào"
                  value={form.morningStart}
                  onChange={(value) => setForm((v) => ({ ...v, morningStart: value }))}
                  minuteStep={5}
                  sx={{ flex: 1 }}
                />
                <TimePickerField
                  label="Sáng ra"
                  value={form.morningEnd}
                  onChange={(value) => setForm((v) => ({ ...v, morningEnd: value }))}
                  minuteStep={5}
                  sx={{ flex: 1 }}
                />
              </Stack>
              <Typography variant="caption" color="text.secondary" fontWeight={700}>
                Buổi chiều
              </Typography>
              <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5}>
                <TimePickerField
                  label="Chiều vào"
                  value={form.afternoonStart}
                  onChange={(value) => setForm((v) => ({ ...v, afternoonStart: value }))}
                  minuteStep={5}
                  sx={{ flex: 1 }}
                />
                <TimePickerField
                  label="Chiều ra"
                  value={form.afternoonEnd}
                  onChange={(value) => setForm((v) => ({ ...v, afternoonEnd: value }))}
                  minuteStep={5}
                  sx={{ flex: 1 }}
                />
              </Stack>
            </Stack>
          )}

          <Box
            sx={{
              mt: 2,
              p: { xs: 1.5, sm: 1.75 },
              borderRadius: 2.5,
              bgcolor: alpha(theme.palette.info.main, 0.045),
              border: `1px solid ${alpha(theme.palette.info.main, 0.14)}`,
            }}
          >
            <Typography variant="subtitle2" fontWeight={800}>
              Cửa sổ lấy giờ chấm công của ca này
            </Typography>
            <Typography variant="caption" color="text.secondary">
              {form.kind === 'SPLIT'
                ? 'Bốn mốc: vào/ra sáng và vào/ra chiều.'
                : 'Check-in lấy giờ sớm nhất, check-out lấy giờ muộn nhất trong khoảng cho phép.'}
            </Typography>
            <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.75} sx={{ mt: 1.5 }} useFlexGap flexWrap="wrap">
              {form.kind === 'CONTINUOUS' ? (
                <>
                  {punchWindowCard({
                    title: 'Cửa sổ check-in',
                    icon: <LoginOutlinedIcon fontSize="small" />,
                    anchor: form.startTime,
                    beforeKey: 'checkInBeforeMin',
                    afterKey: 'checkInAfterMin',
                    color: theme.palette.primary.main,
                  })}
                  {punchWindowCard({
                    title: 'Cửa sổ check-out',
                    icon: <LogoutOutlinedIcon fontSize="small" />,
                    anchor: form.endTime,
                    beforeKey: 'checkOutBeforeMin',
                    afterKey: 'checkOutAfterMin',
                    color: theme.palette.secondary.main,
                  })}
                </>
              ) : (
                <>
                  {punchWindowCard({
                    title: 'Vào sáng',
                    icon: <LoginOutlinedIcon fontSize="small" />,
                    anchor: form.morningStart,
                    beforeKey: 'checkInBeforeMin',
                    afterKey: 'checkInAfterMin',
                    color: theme.palette.primary.main,
                  })}
                  {punchWindowCard({
                    title: 'Ra sáng',
                    icon: <LogoutOutlinedIcon fontSize="small" />,
                    anchor: form.morningEnd,
                    beforeKey: 'morningOutBeforeMin',
                    afterKey: 'morningOutAfterMin',
                    color: theme.palette.info.main,
                  })}
                  {punchWindowCard({
                    title: 'Vào chiều',
                    icon: <LoginOutlinedIcon fontSize="small" />,
                    anchor: form.afternoonStart,
                    beforeKey: 'afternoonInBeforeMin',
                    afterKey: 'afternoonInAfterMin',
                    color: theme.palette.warning.main,
                  })}
                  {punchWindowCard({
                    title: 'Ra chiều',
                    icon: <LogoutOutlinedIcon fontSize="small" />,
                    anchor: form.afternoonEnd,
                    beforeKey: 'checkOutBeforeMin',
                    afterKey: 'checkOutAfterMin',
                    color: theme.palette.secondary.main,
                  })}
                </>
              )}
            </Stack>
          </Box>

          <Stack direction="row" justifyContent="flex-end" spacing={1} sx={{ mt: 1.5 }}>
            {editingId != null && (
              <Button
                onClick={() => {
                  setEditingId(null);
                  setForm(blankForm);
                }}
                color="inherit"
              >
                Hủy chỉnh sửa
              </Button>
            )}
            <Button
              variant="contained"
              color="success"
              startIcon={
                saving ? <CircularProgress size={15} color="inherit" /> : editingId == null ? <AddIcon /> : <EditOutlinedIcon />
              }
              disabled={saving || !canSave}
              onClick={save}
              sx={{ borderRadius: 2, px: 2, boxShadow: 'none' }}
            >
              {editingId == null ? 'Thêm ca' : 'Lưu thay đổi'}
            </Button>
          </Stack>
        </Paper>

        <Divider sx={{ my: 2.5 }} />
        <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1.25 }}>
          <Box>
            <Typography variant="subtitle2" fontWeight={800}>
              Các ca đang áp dụng
            </Typography>
            <Typography variant="caption" color="text.secondary">
              Danh sách khung giờ trưởng khoa có thể lựa chọn khi xếp ca theo ngày.
            </Typography>
          </Box>
          <Chip size="small" label={`${types.length} ca`} sx={{ fontWeight: 700 }} />
        </Stack>
        <Stack spacing={1.1}>
          {loading ? (
            <Box sx={{ py: 3, textAlign: 'center' }}>
              <CircularProgress size={26} />
            </Box>
          ) : types.length === 0 ? (
            <Alert severity="info" sx={{ borderRadius: 2.5 }}>
              Chưa có khung ca nào.
            </Alert>
          ) : (
            types.map((type) => {
              const split = type.kind === 'SPLIT';
              return (
                <Box
                  key={type.id}
                  sx={{
                    p: 1.5,
                    border: 1,
                    borderColor: editingId === type.id ? alpha(accent, 0.5) : 'divider',
                    borderRadius: 2.5,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 1.25,
                    bgcolor: editingId === type.id ? alpha(accent, 0.045) : 'background.paper',
                    transition: 'border-color 0.15s, background-color 0.15s',
                    '&:hover': { borderColor: alpha(accent, 0.35), bgcolor: alpha(accent, 0.025) },
                  }}
                >
                  <Box
                    sx={{
                      width: 40,
                      height: 40,
                      borderRadius: 2,
                      display: 'grid',
                      placeItems: 'center',
                      color: accent,
                      bgcolor: alpha(accent, 0.1),
                      flexShrink: 0,
                    }}
                  >
                    <ScheduleOutlinedIcon fontSize="small" />
                  </Box>
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
                      <Typography fontWeight={700}>{type.name}</Typography>
                      <Chip
                        size="small"
                        label={type.kindLabel || (split ? 'Ca sáng–chiều' : 'Ca thông tầm')}
                        variant="outlined"
                        color={split ? 'primary' : 'success'}
                        sx={{ height: 22, fontWeight: 700 }}
                      />
                    </Stack>
                    <Typography variant="body2" color="text.secondary">
                      {split ? (
                        <>
                          <strong>
                            {(type.morningStart || type.startTime).slice(0, 5)}–
                            {(type.morningEnd || '').slice(0, 5)}
                          </strong>
                          {' / '}
                          <strong>
                            {(type.afternoonStart || '').slice(0, 5)}–
                            {(type.afternoonEnd || type.endTime).slice(0, 5)}
                          </strong>
                          {' · '}
                          {type.hours} giờ
                        </>
                      ) : (
                        <>
                          <strong>
                            {type.startTime.slice(0, 5)} – {type.endTime.slice(0, 5)}
                          </strong>
                          {' · '}
                          {type.hours} giờ liên tục
                        </>
                      )}
                    </Typography>
                    {!split && (
                      <Typography variant="caption" color="text.secondary">
                        Check-in{' '}
                        {windowLabel(type.startTime, String(type.checkInBeforeMin), String(type.checkInAfterMin))}
                        {' · '}
                        Check-out{' '}
                        {windowLabel(type.endTime, String(type.checkOutBeforeMin), String(type.checkOutAfterMin))}
                      </Typography>
                    )}
                  </Box>
                  <IconButton
                    size="small"
                    aria-label="Sửa ca"
                    title="Chỉnh sửa"
                    onClick={() => edit(type)}
                    disabled={saving}
                    sx={{ color: 'text.secondary' }}
                  >
                    <EditOutlinedIcon fontSize="small" />
                  </IconButton>
                  <IconButton
                    size="small"
                    color="error"
                    aria-label="Xóa ca"
                    title="Xóa"
                    onClick={() => void remove(type.id)}
                    disabled={saving}
                  >
                    <DeleteOutlineIcon fontSize="small" />
                  </IconButton>
                </Box>
              );
            })
          )}
        </Stack>
      </DialogContent>
    </Dialog>
  );
}
