import WbSunnyIcon from '@mui/icons-material/WbSunny';
import AcUnitIcon from '@mui/icons-material/AcUnit';
import TimelineIcon from '@mui/icons-material/Timeline';
import LoginIcon from '@mui/icons-material/Login';
import LogoutIcon from '@mui/icons-material/Logout';
import {
  Alert,
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Grid,
  InputAdornment,
  Paper,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import type { Theme } from '@mui/material/styles';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import * as attSvc from '../../services/attendanceService';
import { TimePickerField, dateTimeFieldSx } from '../ui/DateTimeFields';
import type { ShiftConfigAdminView, ShiftSeasonConfig } from '../../utils/shiftSchedule';
import {
  DEFAULT_PUNCH_WINDOWS,
  formatShiftTime,
  hoursBetweenTimes,
  type PunchWindowConfig,
} from '../../utils/shiftSchedule';
import type { ShiftConfigUpdatePayload } from '../../services/attendanceService';

/** Ca thông tầm: khung giờ vào → ra tối thiểu 8 giờ = 1 công. */
const CONTINUOUS_MIN_HOURS = 8;

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved: (scope: 'employee' | 'all') => void | Promise<void>;
  employeeId: number;
  /** Khi bật ca thông tầm — form chỉ giờ vào/ra cả ngày */
  continuousShift?: boolean;
  employeeName?: string;
};

function toTimeInput(value: string) {
  return value?.slice(0, 5) ?? '';
}

type PunchForm = Record<keyof PunchWindowConfig, string>;

type SeasonForm = {
  morningStart: string;
  morningEnd: string;
  afternoonStart: string;
  afternoonEnd: string;
  morningUnits: string;
  afternoonUnits: string;
} & PunchForm;

function punchToForm(pw: PunchWindowConfig): PunchForm {
  return {
    morningInBeforeMin: String(pw.morningInBeforeMin),
    morningInAfterMin: String(pw.morningInAfterMin),
    morningOutBeforeMin: String(pw.morningOutBeforeMin),
    morningOutAfterMin: String(pw.morningOutAfterMin),
    afternoonInBeforeMin: String(pw.afternoonInBeforeMin),
    afternoonInAfterMin: String(pw.afternoonInAfterMin),
    afternoonOutBeforeMin: String(pw.afternoonOutBeforeMin),
    afternoonOutAfterMin: String(pw.afternoonOutAfterMin),
  };
}

function seasonToForm(cfg: ShiftSeasonConfig): SeasonForm {
  const pw = cfg.punchWindows ?? DEFAULT_PUNCH_WINDOWS;
  return {
    morningStart: toTimeInput(cfg.morningStart),
    morningEnd: toTimeInput(cfg.morningEnd),
    afternoonStart: toTimeInput(cfg.afternoonStart),
    afternoonEnd: toTimeInput(cfg.afternoonEnd),
    morningUnits: String(cfg.morningUnits ?? ''),
    afternoonUnits: String(cfg.afternoonUnits ?? ''),
    ...punchToForm(pw),
  };
}

function punchPayload(form: SeasonForm): Pick<
  ShiftConfigUpdatePayload,
  keyof PunchWindowConfig
> {
  return {
    morningInBeforeMin: Number(form.morningInBeforeMin),
    morningInAfterMin: Number(form.morningInAfterMin),
    morningOutBeforeMin: Number(form.morningOutBeforeMin),
    morningOutAfterMin: Number(form.morningOutAfterMin),
    afternoonInBeforeMin: Number(form.afternoonInBeforeMin),
    afternoonInAfterMin: Number(form.afternoonInAfterMin),
    afternoonOutBeforeMin: Number(form.afternoonOutBeforeMin),
    afternoonOutAfterMin: Number(form.afternoonOutAfterMin),
  };
}

function schedulePayload(form: SeasonForm, continuous: { start: string; end: string }): ShiftConfigUpdatePayload {
  return {
    morningStart: form.morningStart,
    morningEnd: form.morningEnd,
    afternoonStart: form.afternoonStart,
    afternoonEnd: form.afternoonEnd,
    continuousStart: continuous.start,
    continuousEnd: continuous.end,
    morningUnits: Number(form.morningUnits),
    afternoonUnits: Number(form.afternoonUnits),
    ...punchPayload(form),
  };
}

type ContinuousForm = {
  dayStart: string;
  dayEnd: string;
  totalUnits: string;
};

function seasonToContinuousForm(cfg: ShiftSeasonConfig): ContinuousForm {
  const total = Math.round((cfg.morningUnits + cfg.afternoonUnits) * 1e6) / 1e6;
  const normalized = Math.abs(total - 1) < 0.02 ? 1 : total;
  return {
    dayStart: toTimeInput(cfg.continuousStart ?? cfg.morningStart),
    dayEnd: toTimeInput(cfg.continuousEnd ?? cfg.afternoonEnd),
    totalUnits: String(normalized),
  };
}

function preservedContinuous(cfg: ShiftSeasonConfig | undefined, fallback: SeasonForm): { start: string; end: string } {
  return {
    start: toTimeInput(cfg?.continuousStart ?? fallback.morningStart),
    end: toTimeInput(cfg?.continuousEnd ?? fallback.afternoonEnd),
  };
}

const minuteFieldSx = (theme: Theme) => ({
  '& .MuiOutlinedInput-root': {
    borderRadius: 2,
    bgcolor: '#fff',
  },
  '& .MuiOutlinedInput-input': {
    fontWeight: 600,
    textAlign: 'center' as const,
  },
  '& input[type=number]': {
    MozAppearance: 'textfield',
  },
  '& input[type=number]::-webkit-outer-spin-button, & input[type=number]::-webkit-inner-spin-button': {
    WebkitAppearance: 'none',
    margin: 0,
  },
  '& .MuiInputAdornment-root': {
    color: theme.palette.text.secondary,
    '& .MuiTypography-root': { fontSize: '0.8rem', fontWeight: 600 },
  },
});

function sectionPaperSx(accent: string) {
  return {
    p: 2,
    borderRadius: 2.5,
    border: `1px solid ${alpha(accent, 0.14)}`,
    bgcolor: alpha(accent, 0.03),
  };
}

function ShiftTimePair({
  startLabel,
  endLabel,
  startValue,
  endValue,
  onStartChange,
  onEndChange,
}: {
  startLabel: string;
  endLabel: string;
  startValue: string;
  endValue: string;
  onStartChange: (v: string) => void;
  onEndChange: (v: string) => void;
}) {
  return (
    <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ alignItems: 'stretch' }}>
      <Box sx={{ flex: 1, minWidth: 0 }}>
        <TimePickerField
          label={startLabel}
          value={startValue}
          onChange={onStartChange}
          sx={{ '& .MuiFormControl-root': { mb: 0 } }}
        />
      </Box>
      <Box sx={{ flex: 1, minWidth: 0 }}>
        <TimePickerField
          label={endLabel}
          value={endValue}
          onChange={onEndChange}
          sx={{ '& .MuiFormControl-root': { mb: 0 } }}
        />
      </Box>
    </Stack>
  );
}

function MinuteField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  const theme = useTheme();
  return (
    <Box>
      <Typography variant="caption" color="text.secondary" fontWeight={700} sx={{ mb: 0.75, display: 'block' }}>
        {label}
      </Typography>
      <TextField
        fullWidth
        size="small"
        type="number"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        inputProps={{ min: 0, max: 720, step: 5, inputMode: 'numeric' }}
        InputProps={{
          endAdornment: (
            <InputAdornment position="end">
              <Typography component="span" variant="caption">
                phút
              </Typography>
            </InputAdornment>
          ),
        }}
        sx={minuteFieldSx(theme)}
      />
    </Box>
  );
}

type PunchRowProps = {
  title: string;
  anchorTime: string;
  pick: 'MIN' | 'MAX';
  beforeKey: keyof PunchWindowConfig;
  afterKey: keyof PunchWindowConfig;
  form: SeasonForm;
  onChange: (next: SeasonForm) => void;
  accent: string;
};

function PunchWindowCard({ title, anchorTime, pick, beforeKey, afterKey, form, onChange, accent }: PunchRowProps) {
  const theme = useTheme();
  const isIn = pick === 'MIN';
  const Icon = isIn ? LoginIcon : LogoutIcon;

  return (
    <Paper
      variant="outlined"
      sx={{
        p: 2,
        height: '100%',
        borderRadius: 2.5,
        borderColor: alpha(accent, 0.2),
        bgcolor: '#fff',
        transition: 'box-shadow 0.2s',
        '&:hover': { boxShadow: `0 4px 16px ${alpha(accent, 0.08)}` },
      }}
    >
      <Stack direction="row" spacing={1.25} alignItems="flex-start" sx={{ mb: 1.75 }}>
        <Box
          sx={{
            width: 36,
            height: 36,
            borderRadius: 2,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            bgcolor: alpha(accent, 0.1),
            color: accent,
            flexShrink: 0,
          }}
        >
          <Icon sx={{ fontSize: 18 }} />
        </Box>
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <Typography variant="subtitle2" fontWeight={700} lineHeight={1.3}>
            {title}
          </Typography>
          <Stack direction="row" spacing={0.75} flexWrap="wrap" useFlexGap sx={{ mt: 0.75 }}>
            <Chip
              size="small"
              label={isIn ? 'Lấy sớm nhất' : 'Lấy muộn nhất'}
              sx={{
                height: 22,
                fontSize: '0.7rem',
                fontWeight: 700,
                bgcolor: alpha(accent, 0.1),
                color: accent,
              }}
            />
            {anchorTime && (
              <Chip
                size="small"
                variant="outlined"
                label={`Mốc ${formatShiftTime(anchorTime)}`}
                sx={{ height: 22, fontSize: '0.7rem', fontWeight: 600 }}
              />
            )}
          </Stack>
        </Box>
      </Stack>

      <Grid container spacing={1.5}>
        <Grid item xs={6}>
          <MinuteField
            label="Lùi trước mốc"
            value={form[beforeKey]}
            onChange={(v) => onChange({ ...form, [beforeKey]: v })}
          />
        </Grid>
        <Grid item xs={6}>
          <MinuteField
            label="Tiến sau mốc"
            value={form[afterKey]}
            onChange={(v) => onChange({ ...form, [afterKey]: v })}
          />
        </Grid>
      </Grid>

      {anchorTime && (
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1.25, lineHeight: 1.45 }}>
          Khoảng{' '}
          <Box component="span" sx={{ fontWeight: 700, color: theme.palette.text.primary }}>
            {formatWindowRange(anchorTime, form[beforeKey], form[afterKey])}
          </Box>
        </Typography>
      )}
    </Paper>
  );
}

function formatWindowRange(anchor: string, beforeMin: string, afterMin: string) {
  const [h, m] = anchor.split(':').map(Number);
  if (Number.isNaN(h)) return '—';
  const base = h * 60 + (m || 0);
  const b = Number(beforeMin) || 0;
  const a = Number(afterMin) || 0;
  const fmt = (mins: number) => {
    const wrapped = ((mins % (24 * 60)) + 24 * 60) % (24 * 60);
    const hh = Math.floor(wrapped / 60);
    const mm = wrapped % 60;
    return `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
  };
  return `${fmt(base - b)} → ${fmt(base + a)}`;
}

function splitTotalUnits(total: number) {
  const morningUnits = Math.round((total * 2) / 3 * 1e8) / 1e8;
  const afternoonUnits = Math.round((total - morningUnits) * 1e8) / 1e8;
  return { morningUnits, afternoonUnits };
}

function PunchWindowsSection({
  form,
  onChange,
  continuousShift,
  scheduleForm,
  accent,
}: {
  form: SeasonForm;
  onChange: (next: SeasonForm) => void;
  continuousShift?: boolean;
  scheduleForm: { morningStart: string; afternoonEnd: string; morningEnd: string; afternoonStart: string };
  accent: string;
}) {
  const rows = continuousShift
    ? [
        {
          title: 'Giờ vào đầu ngày',
          anchorTime: scheduleForm.morningStart,
          pick: 'MIN' as const,
          beforeKey: 'morningInBeforeMin' as const,
          afterKey: 'morningInAfterMin' as const,
        },
        {
          title: 'Giờ ra cuối ngày',
          anchorTime: scheduleForm.afternoonEnd,
          pick: 'MAX' as const,
          beforeKey: 'afternoonOutBeforeMin' as const,
          afterKey: 'afternoonOutAfterMin' as const,
        },
      ]
    : [
        {
          title: 'Vào ca sáng',
          anchorTime: scheduleForm.morningStart,
          pick: 'MIN' as const,
          beforeKey: 'morningInBeforeMin' as const,
          afterKey: 'morningInAfterMin' as const,
        },
        {
          title: 'Ra ca sáng',
          anchorTime: scheduleForm.morningEnd,
          pick: 'MAX' as const,
          beforeKey: 'morningOutBeforeMin' as const,
          afterKey: 'morningOutAfterMin' as const,
        },
        {
          title: 'Vào ca chiều',
          anchorTime: scheduleForm.afternoonStart,
          pick: 'MIN' as const,
          beforeKey: 'afternoonInBeforeMin' as const,
          afterKey: 'afternoonInAfterMin' as const,
        },
        {
          title: 'Ra ca chiều',
          anchorTime: scheduleForm.afternoonEnd,
          pick: 'MAX' as const,
          beforeKey: 'afternoonOutBeforeMin' as const,
          afterKey: 'afternoonOutAfterMin' as const,
        },
      ];

  return (
    <Box sx={sectionPaperSx(accent)}>
      <Typography variant="overline" color="text.secondary" fontWeight={800} letterSpacing="0.08em">
        Cửa sổ lấy giờ chấm công
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5, mb: 2, lineHeight: 1.55 }}>
        Chỉ log máy chấm nằm trong khoảng thời gian quy định mới được dùng để tính giờ vào/ra.
      </Typography>
      <Grid container spacing={2}>
        {rows.map((row) => (
          <Grid item xs={12} sm={6} key={row.title}>
            <PunchWindowCard
              {...row}
              form={form}
              onChange={onChange}
              accent={accent}
            />
          </Grid>
        ))}
      </Grid>
    </Box>
  );
}

export function AttendanceScheduleEditDialog({
  open,
  onClose,
  onSaved,
  employeeId,
  continuousShift,
  employeeName,
}: Props) {
  const theme = useTheme();
  const [tab, setTab] = useState(0);
  const [config, setConfig] = useState<ShiftConfigAdminView | null>(null);
  const [summer, setSummer] = useState<SeasonForm>(seasonToForm({} as ShiftSeasonConfig));
  const [winter, setWinter] = useState<SeasonForm>(seasonToForm({} as ShiftSeasonConfig));
  const [summerCont, setSummerCont] = useState<ContinuousForm>(seasonToContinuousForm({} as ShiftSeasonConfig));
  const [winterCont, setWinterCont] = useState<ContinuousForm>(seasonToContinuousForm({} as ShiftSeasonConfig));
  const [err, setErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [applyingAll, setApplyingAll] = useState(false);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    attSvc
      .fetchEmployeeShiftConfigAdmin(employeeId)
      .then((c) => {
        setConfig(c);
        setSummer(seasonToForm(c.summer));
        setWinter(seasonToForm(c.winter));
        setSummerCont(seasonToContinuousForm(c.summer));
        setWinterCont(seasonToContinuousForm(c.winter));
      })
      .catch(() => setErr('Không tải được cấu hình lịch ca.'));
  }, [open, employeeId]);

  const active = tab === 0 ? summer : winter;
  const setActive = tab === 0 ? setSummer : setWinter;
  const activeCont = tab === 0 ? summerCont : winterCont;
  const setActiveCont = tab === 0 ? setSummerCont : setWinterCont;
  const punchForm = tab === 0 ? summer : winter;
  const baseSeason = tab === 0 ? config?.summer : config?.winter;
  const isSummer = tab === 0;
  const SeasonIcon = isSummer ? WbSunnyIcon : AcUnitIcon;
  const seasonColor = isSummer ? theme.palette.warning.main : theme.palette.info.main;
  const accent = continuousShift ? theme.palette.success.main : seasonColor;
  const HeaderIcon = continuousShift ? TimelineIcon : SeasonIcon;

  function numberField(key: 'morningUnits' | 'afternoonUnits', label: string) {
    return (
      <TextField
        fullWidth
        size="small"
        label={label}
        type="number"
        InputLabelProps={{ shrink: true }}
        inputProps={{ step: 0.01, min: 0.01 }}
        value={active[key]}
        onChange={(e) => setActive((prev) => ({ ...prev, [key]: e.target.value }))}
        sx={dateTimeFieldSx}
      />
    );
  }

  function ScheduleBlock({
    title,
    children,
    fill,
  }: {
    title: string;
    children: React.ReactNode;
    fill?: boolean;
  }) {
    return (
      <Box sx={{ ...sectionPaperSx(accent), ...(fill ? { height: '100%', display: 'flex', flexDirection: 'column' } : {}) }}>
        <Typography variant="overline" color="text.secondary" fontWeight={800} letterSpacing="0.08em">
          {title}
        </Typography>
        <Box sx={{ mt: 1.5, ...(fill ? { flex: 1 } : {}) }}>{children}</Box>
      </Box>
    );
  }

  function ShiftHoursSection({
    morningStart,
    morningEnd,
    afternoonStart,
    afternoonEnd,
    onMorningStart,
    onMorningEnd,
    onAfternoonStart,
    onAfternoonEnd,
  }: {
    morningStart: string;
    morningEnd: string;
    afternoonStart: string;
    afternoonEnd: string;
    onMorningStart: (v: string) => void;
    onMorningEnd: (v: string) => void;
    onAfternoonStart: (v: string) => void;
    onAfternoonEnd: (v: string) => void;
  }) {
    return (
      <Box sx={sectionPaperSx(accent)}>
        <Typography variant="overline" color="text.secondary" fontWeight={800} letterSpacing="0.08em">
          Khung giờ ca
        </Typography>
        <Grid container spacing={2} sx={{ mt: 1.5 }} alignItems="stretch">
          <Grid item xs={12} md={6}>
            <Box
              sx={{
                height: '100%',
                p: 1.5,
                borderRadius: 2,
                bgcolor: '#fff',
                border: `1px solid ${alpha(accent, 0.12)}`,
              }}
            >
              <Typography variant="subtitle2" fontWeight={700} sx={{ mb: 1.25 }}>
                Ca sáng
              </Typography>
              <ShiftTimePair
                startLabel="Bắt đầu"
                endLabel="Kết thúc"
                startValue={morningStart}
                endValue={morningEnd}
                onStartChange={onMorningStart}
                onEndChange={onMorningEnd}
              />
            </Box>
          </Grid>
          <Grid item xs={12} md={6}>
            <Box
              sx={{
                height: '100%',
                p: 1.5,
                borderRadius: 2,
                bgcolor: '#fff',
                border: `1px solid ${alpha(accent, 0.12)}`,
              }}
            >
              <Typography variant="subtitle2" fontWeight={700} sx={{ mb: 1.25 }}>
                Ca chiều
              </Typography>
              <ShiftTimePair
                startLabel="Bắt đầu"
                endLabel="Kết thúc"
                startValue={afternoonStart}
                endValue={afternoonEnd}
                onStartChange={onAfternoonStart}
                onEndChange={onAfternoonEnd}
              />
            </Box>
          </Grid>
        </Grid>
      </Box>
    );
  }

  async function save() {
    setSaving(true);
    setErr(null);
    const season = tab === 0 ? 'SUMMER' : 'WINTER';
    const punchForm = tab === 0 ? summer : winter;
    try {
      if (continuousShift) {
        const form = tab === 0 ? summerCont : winterCont;
        const dayHours = hoursBetweenTimes(form.dayStart, form.dayEnd);
        if (dayHours < CONTINUOUS_MIN_HOURS) {
          setErr(
            `Ca thông tầm phải tối thiểu ${CONTINUOUS_MIN_HOURS} giờ (hiện ${dayHours.toFixed(2).replace('.', ',')} giờ).`,
          );
          return;
        }
        const total = Number(form.totalUnits);
        const { morningUnits, afternoonUnits } = splitTotalUnits(total);
        // Chỉ cập nhật giờ thông tầm — giữ nguyên khung sáng/chiều
        await attSvc.updateEmployeeShiftConfig(employeeId, season, {
          ...punchPayload(punchForm),
          morningStart: toTimeInput(baseSeason?.morningStart ?? punchForm.morningStart),
          morningEnd: toTimeInput(baseSeason?.morningEnd ?? punchForm.morningEnd),
          afternoonStart: toTimeInput(baseSeason?.afternoonStart ?? punchForm.afternoonStart),
          afternoonEnd: toTimeInput(baseSeason?.afternoonEnd ?? punchForm.afternoonEnd),
          continuousStart: form.dayStart,
          continuousEnd: form.dayEnd,
          morningUnits,
          afternoonUnits,
        });
      } else {
        const form = tab === 0 ? summer : winter;
        // Chỉ cập nhật sáng/chiều — giữ nguyên giờ thông tầm
        await attSvc.updateEmployeeShiftConfig(
          employeeId,
          season,
          schedulePayload(form, preservedContinuous(baseSeason, form)),
        );
      }
      // Đóng dialog ngay; onSaved tự reload UI rồi tính lại công nền.
      onClose();
      void Promise.resolve(onSaved('employee'));
    } catch {
      setErr('Không lưu được. Kiểm tra giờ ca và đơn vị công.');
    } finally {
      setSaving(false);
    }
  }

  async function applyToAllEmployees() {
    const season = tab === 0 ? 'SUMMER' : 'WINTER';
    const punchForm = tab === 0 ? summer : winter;
    let payload: ShiftConfigUpdatePayload;

    if (continuousShift) {
      const form = tab === 0 ? summerCont : winterCont;
      const dayHours = hoursBetweenTimes(form.dayStart, form.dayEnd);
      if (dayHours < CONTINUOUS_MIN_HOURS) {
        setErr(`Ca thông tầm phải tối thiểu ${CONTINUOUS_MIN_HOURS} giờ.`);
        return;
      }
      const { morningUnits, afternoonUnits } = splitTotalUnits(Number(form.totalUnits));
      payload = {
        ...punchPayload(punchForm),
        morningStart: toTimeInput(baseSeason?.morningStart ?? punchForm.morningStart),
        morningEnd: toTimeInput(baseSeason?.morningEnd ?? punchForm.morningEnd),
        afternoonStart: toTimeInput(baseSeason?.afternoonStart ?? punchForm.afternoonStart),
        afternoonEnd: toTimeInput(baseSeason?.afternoonEnd ?? punchForm.afternoonEnd),
        continuousStart: form.dayStart,
        continuousEnd: form.dayEnd,
        morningUnits,
        afternoonUnits,
      };
    } else {
      const form = tab === 0 ? summer : winter;
      payload = schedulePayload(form, preservedContinuous(baseSeason, form));
    }

    const seasonLabel = season === 'SUMMER' ? 'mùa hè' : 'mùa đông';
    if (!window.confirm(`Áp dụng cấu hình ${seasonLabel} hiện tại cho tất cả nhân viên đang làm việc?`)) {
      return;
    }

    setApplyingAll(true);
    setErr(null);
    try {
      const result = await attSvc.applyShiftConfigToAll(season, payload);
      window.alert(`Đã áp dụng cho ${result.updatedEmployees} nhân viên.`);
      onClose();
      void Promise.resolve(onSaved('all'));
    } catch {
      setErr('Không áp dụng được cấu hình cho tất cả nhân viên.');
    } finally {
      setApplyingAll(false);
    }
  }

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth scroll="paper">
      <DialogTitle sx={{ pb: 1, pt: 2.5, px: 3 }}>
        <Typography variant="h6" fontWeight={800}>
          Chỉnh sửa lịch làm việc
        </Typography>
        <Typography variant="body2" color="text.secondary">
          {continuousShift
            ? `Ca thông tầm${employeeName ? ` · ${employeeName}` : ''} — chỉnh giờ vào/ra cả ngày, không nghỉ trưa.`
            : `Cập nhật ca sáng / chiều riêng cho ${employeeName || 'nhân viên đang chọn'}.`}
        </Typography>
      </DialogTitle>
      <DialogContent sx={{ px: 3, pt: 1 }}>
        {err && (
          <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }}>
            {err}
          </Alert>
        )}
        <Alert severity="info" sx={{ mb: 2, borderRadius: 2 }}>
          Thay đổi này chỉ áp dụng cho <strong>{employeeName || 'nhân viên đang chọn'}</strong>.
          Chỉ dùng nút “Áp dụng cho tất cả” khi muốn cập nhật toàn bộ nhân viên.
        </Alert>
        <Tabs
          value={tab}
          onChange={(_, v) => setTab(v)}
          sx={{
            mb: 2,
            minHeight: 42,
            '& .MuiTab-root': { minHeight: 42, fontWeight: 700 },
          }}
        >
          <Tab label={`Mùa hè (${config?.periodLabels.summer ?? '15/4 – 15/10'})`} />
          <Tab label={`Mùa đông (${config?.periodLabels.winter ?? '16/10 – 14/4'})`} />
        </Tabs>

        <Box
          sx={{
            mb: 2,
            p: 1.5,
            borderRadius: 2.5,
            display: 'flex',
            alignItems: 'center',
            gap: 1.25,
            bgcolor: alpha(accent, 0.08),
            border: `1px solid ${alpha(accent, 0.2)}`,
          }}
        >
          <HeaderIcon sx={{ color: accent }} />
          <Typography variant="body2" fontWeight={600}>
            {continuousShift
              ? `${isSummer ? 'Ca hè' : 'Ca đông'} · thông tầm (vào đầu ngày → ra cuối ngày)`
              : `${isSummer ? 'Ca hè' : 'Ca đông'} · chỉnh giờ ca sáng / chiều`}
          </Typography>
        </Box>

        {continuousShift ? (
          <Stack spacing={2.5}>
            <ScheduleBlock title="Khung giờ ca thông tầm">
              <ShiftTimePair
                startLabel="Giờ vào"
                endLabel="Giờ ra"
                startValue={activeCont.dayStart}
                endValue={activeCont.dayEnd}
                onStartChange={(v) => setActiveCont((p) => ({ ...p, dayStart: v }))}
                onEndChange={(v) => setActiveCont((p) => ({ ...p, dayEnd: v }))}
              />
              {(() => {
                const dayHours = hoursBetweenTimes(activeCont.dayStart, activeCont.dayEnd);
                const ok = dayHours >= CONTINUOUS_MIN_HOURS;
                return (
                  <Typography
                    variant="caption"
                    color={ok ? 'text.secondary' : 'error'}
                    sx={{ display: 'block', mt: 1.25, fontWeight: 600 }}
                  >
                    Tổng {Number.isFinite(dayHours) ? dayHours.toFixed(2).replace('.', ',') : '—'} giờ
                    {' · '}
                    tối thiểu {CONTINUOUS_MIN_HOURS} giờ = 1 công
                    {!ok ? ' — chưa đủ' : ''}
                  </Typography>
                );
              })()}
            </ScheduleBlock>
            <ScheduleBlock title="Đơn vị công">
              <TextField
                fullWidth
                size="small"
                label="Công cả ngày"
                type="number"
                InputLabelProps={{ shrink: true }}
                inputProps={{ step: 0.01, min: 0.01 }}
                value={activeCont.totalUnits}
                onChange={(e) => setActiveCont((p) => ({ ...p, totalUnits: e.target.value }))}
                helperText="Đủ công khi có giờ vào và giờ ra (không cần chấm giữa trưa)"
                sx={dateTimeFieldSx}
              />
            </ScheduleBlock>
            <PunchWindowsSection
              form={punchForm}
              onChange={tab === 0 ? setSummer : setWinter}
              continuousShift
              accent={accent}
              scheduleForm={{
                morningStart: activeCont.dayStart,
                afternoonEnd: activeCont.dayEnd,
                morningEnd: punchForm.morningEnd,
                afternoonStart: punchForm.afternoonStart,
              }}
            />
          </Stack>
        ) : (
          <Stack spacing={2.5}>
            <ShiftHoursSection
              morningStart={active.morningStart}
              morningEnd={active.morningEnd}
              afternoonStart={active.afternoonStart}
              afternoonEnd={active.afternoonEnd}
              onMorningStart={(v) => setActive((p) => ({ ...p, morningStart: v }))}
              onMorningEnd={(v) => setActive((p) => ({ ...p, morningEnd: v }))}
              onAfternoonStart={(v) => setActive((p) => ({ ...p, afternoonStart: v }))}
              onAfternoonEnd={(v) => setActive((p) => ({ ...p, afternoonEnd: v }))}
            />
            <ScheduleBlock title="Đơn vị công">
              <Grid container spacing={1.5}>
                <Grid item xs={12} sm={6}>{numberField('morningUnits', 'Công ca sáng')}</Grid>
                <Grid item xs={12} sm={6}>{numberField('afternoonUnits', 'Công ca chiều')}</Grid>
              </Grid>
            </ScheduleBlock>
            <PunchWindowsSection
              form={active}
              onChange={setActive}
              accent={theme.palette.primary.main}
              scheduleForm={{
                morningStart: active.morningStart,
                morningEnd: active.morningEnd,
                afternoonStart: active.afternoonStart,
                afternoonEnd: active.afternoonEnd,
              }}
            />
          </Stack>
        )}
      </DialogContent>
      <DialogActions sx={{ px: 3, py: 2, borderTop: 1, borderColor: 'divider', bgcolor: alpha(theme.palette.primary.main, 0.02) }}>
        <Button onClick={onClose} color="inherit">
          Hủy
        </Button>
        <Button
          variant="outlined"
          color="warning"
          onClick={applyToAllEmployees}
          disabled={saving || applyingAll}
        >
          {applyingAll ? 'Đang áp dụng…' : 'Áp dụng cho tất cả'}
        </Button>
        <Button variant="contained" onClick={save} disabled={saving || applyingAll}>
          Lưu thay đổi
        </Button>
      </DialogActions>
    </Dialog>
  );
}
