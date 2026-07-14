import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CalendarTodayOutlinedIcon from '@mui/icons-material/CalendarTodayOutlined';
import ChevronLeftIcon from '@mui/icons-material/ChevronLeft';
import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import {
  Box,
  Button,
  Divider,
  IconButton,
  InputAdornment,
  Popover,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import type { TextFieldProps } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import type { Theme } from '@mui/material/styles';
import { useMemo, useState } from 'react';
import { ClockTimePickerPanel } from './ClockTimePickerPanel';

const MONTHS_VI = [
  'Tháng 1',
  'Tháng 2',
  'Tháng 3',
  'Tháng 4',
  'Tháng 5',
  'Tháng 6',
  'Tháng 7',
  'Tháng 8',
  'Tháng 9',
  'Tháng 10',
  'Tháng 11',
  'Tháng 12',
];

const MONTHS_SHORT = ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9', 'T10', 'T11', 'T12'];

const WEEKDAYS_VI = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

export const dateTimeFieldSx = {
  '& .MuiOutlinedInput-root': {
    borderRadius: 2.5,
    bgcolor: '#fff',
    transition: 'border-color 0.2s, box-shadow 0.2s',
    '&:hover .MuiOutlinedInput-notchedOutline': {
      borderColor: alpha('#006865', 0.35),
    },
    '&.Mui-focused': {
      boxShadow: `0 0 0 3px ${alpha('#006865', 0.12)}`,
    },
  },
  '& .MuiInputLabel-root.Mui-focused': {
    color: '#006865',
  },
};

function popoverPaperSx(theme: Theme) {
  return {
    mt: 0.75,
    borderRadius: 3,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.14)}`,
    boxShadow: `0 20px 48px ${alpha('#0f172a', 0.14)}`,
    overflow: 'hidden',
    minWidth: 300,
  };
}

function toIsoDate(y: number, m: number, d: number): string {
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

function parseIsoDate(iso: string): { year: number; month: number; day: number } | null {
  if (!iso) return null;
  const [y, m, d] = iso.split('-').map(Number);
  if (!y || !m || !d) return null;
  return { year: y, month: m, day: d };
}

/** Lưới lịch tháng — tuần bắt đầu Thứ 2 */
function buildMonthGrid(year: number, month: number): { date: Date; inMonth: boolean }[] {
  const first = new Date(year, month - 1, 1);
  const startOffset = (first.getDay() + 6) % 7; // Mon=0 … Sun=6
  const start = new Date(year, month - 1, 1 - startOffset);
  return Array.from({ length: 42 }, (_, i) => {
    const date = new Date(start);
    date.setDate(start.getDate() + i);
    return {
      date,
      inMonth: date.getMonth() === month - 1,
    };
  });
}

function timePopoverPaperSx(theme: Theme) {
  return {
    mt: 0.75,
    borderRadius: 3,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
    boxShadow: `0 16px 40px ${alpha('#0f172a', 0.14)}`,
    overflow: 'hidden',
    width: 280,
    maxWidth: '92vw',
  };
}

function formatDateVi(iso: string): string {
  if (!iso) return 'Chọn ngày';
  const [y, m, d] = iso.split('-').map(Number);
  if (!y || !m || !d) return iso;
  return `${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}/${y}`;
}

function formatTimeDisplay(value: string): string {
  if (!value) return 'Chọn giờ';
  const [h, m] = value.split(':');
  if (h == null) return value;
  const mm = (m ?? '00').padStart(2, '0');
  return `${Number(h)}h${mm}`;
}

function parseYearMonth(value: string): { year: number; month: number } {
  const [y, m] = value.split('-').map(Number);
  const now = new Date();
  return {
    year: y || now.getFullYear(),
    month: m || now.getMonth() + 1,
  };
}

type PickerShellProps = {
  label?: string;
  display: string;
  icon: React.ReactNode;
  open: boolean;
  anchorEl: HTMLElement | null;
  onOpen: (el: HTMLElement) => void;
  onClose: () => void;
  children: React.ReactNode;
  required?: boolean;
  disabled?: boolean;
  fullWidth?: boolean;
  size?: 'small' | 'medium';
  helperText?: string;
  error?: boolean;
  sx?: TextFieldProps['sx'];
};

function PickerShell({
  label,
  display,
  icon,
  open,
  anchorEl,
  onOpen,
  onClose,
  children,
  required,
  disabled,
  fullWidth = true,
  size = 'small',
  helperText,
  error,
  sx,
}: PickerShellProps) {
  const theme = useTheme();
  return (
    <>
      <TextField
        fullWidth={fullWidth}
        size={size}
        label={label}
        required={required}
        disabled={disabled}
        error={error}
        helperText={helperText}
        value={display}
        onClick={(e) => {
          if (!disabled) onOpen(e.currentTarget);
        }}
        InputProps={{
          readOnly: true,
          startAdornment: <InputAdornment position="start">{icon}</InputAdornment>,
        }}
        sx={{
          ...dateTimeFieldSx,
          ...sx,
          cursor: disabled ? 'default' : 'pointer',
          '& .MuiOutlinedInput-input': { cursor: disabled ? 'default' : 'pointer' },
        }}
      />
      <Popover
        open={open}
        anchorEl={anchorEl}
        onClose={onClose}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
        transformOrigin={{ vertical: 'top', horizontal: 'left' }}
        slotProps={{ paper: { sx: popoverPaperSx(theme) } }}
      >
        {children}
      </Popover>
    </>
  );
}

type MonthPickerFieldProps = Omit<TextFieldProps, 'value' | 'onChange' | 'type' | 'label' | 'helperText'> & {
  value: string;
  onChange: (value: string) => void;
  label?: string;
  helperText?: string;
};

/** Chọn tháng/năm — YYYY-MM */
export function MonthPickerField({
  value,
  onChange,
  label = 'Tháng xem',
  sx,
  helperText,
  required,
  disabled,
  fullWidth,
  size,
  error,
}: MonthPickerFieldProps) {
  const theme = useTheme();
  const parsed = parseYearMonth(value);
  const [viewYear, setViewYear] = useState(parsed.year);
  const [anchorEl, setAnchorEl] = useState<HTMLElement | null>(null);
  const open = Boolean(anchorEl);

  const display = useMemo(() => {
    const { year, month } = parseYearMonth(value);
    return `${MONTHS_VI[month - 1]} ${year}`;
  }, [value]);

  function pickMonth(m: number) {
    onChange(`${viewYear}-${String(m).padStart(2, '0')}`);
    setAnchorEl(null);
  }

  function openPicker(el: HTMLElement) {
    setViewYear(parseYearMonth(value).year);
    setAnchorEl(el);
  }

  const now = new Date();
  const thisMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

  return (
    <PickerShell
      label={label}
      display={display}
      icon={<CalendarMonthOutlinedIcon fontSize="small" color="primary" />}
      open={open}
      anchorEl={anchorEl}
      onOpen={openPicker}
      onClose={() => setAnchorEl(null)}
      sx={sx}
      helperText={helperText}
      required={required}
      disabled={disabled}
      fullWidth={fullWidth}
      size={size}
      error={error}
    >
      <Box
        sx={{
          px: 1.75,
          pt: 1.5,
          pb: 1.25,
          background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.12)} 0%, ${alpha(theme.palette.primary.main, 0.03)} 100%)`,
          borderBottom: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
        }}
      >
        <Stack direction="row" alignItems="center" justifyContent="space-between">
          <IconButton
            size="small"
            onClick={() => setViewYear((y) => y - 1)}
            sx={{ bgcolor: alpha('#fff', 0.7), '&:hover': { bgcolor: '#fff' } }}
          >
            <ChevronLeftIcon fontSize="small" />
          </IconButton>
          <Typography variant="subtitle2" fontWeight={800}>
            {viewYear}
          </Typography>
          <IconButton
            size="small"
            onClick={() => setViewYear((y) => y + 1)}
            sx={{ bgcolor: alpha('#fff', 0.7), '&:hover': { bgcolor: '#fff' } }}
          >
            <ChevronRightIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Box>
      <Box sx={{ p: 1.5, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 1 }}>
        {MONTHS_SHORT.map((short, idx) => {
          const m = idx + 1;
          const selected = parsed.year === viewYear && parsed.month === m;
          return (
            <Button
              key={short}
              size="small"
              variant={selected ? 'contained' : 'outlined'}
              disableElevation
              onClick={() => pickMonth(m)}
              sx={{
                minWidth: 0,
                py: 1.1,
                fontWeight: 700,
                borderRadius: 2,
                ...(selected
                  ? {}
                  : {
                      borderColor: alpha(theme.palette.primary.main, 0.15),
                      color: 'text.primary',
                      '&:hover': {
                        borderColor: alpha(theme.palette.primary.main, 0.35),
                        bgcolor: alpha(theme.palette.primary.main, 0.06),
                      },
                    }),
              }}
            >
              {short}
            </Button>
          );
        })}
      </Box>
      <Divider />
      <Stack direction="row" justifyContent="space-between" sx={{ px: 1.5, py: 1 }}>
        <Button
          size="small"
          color="inherit"
          onClick={() => {
            onChange('');
            setAnchorEl(null);
          }}
          sx={{ fontWeight: 600, borderRadius: 2 }}
        >
          Xóa
        </Button>
        <Button
          size="small"
          variant="contained"
          disableElevation
          onClick={() => {
            onChange(thisMonth);
            setAnchorEl(null);
          }}
          sx={{ fontWeight: 700, borderRadius: 2, px: 1.75 }}
        >
          Tháng này
        </Button>
      </Stack>
    </PickerShell>
  );
}

type DatePickerFieldProps = Omit<TextFieldProps, 'value' | 'onChange' | 'type' | 'label' | 'helperText'> & {
  value: string;
  onChange: (value: string) => void;
  label?: string;
  helperText?: string;
};

/** Chọn ngày — YYYY-MM-DD */
export function DatePickerField({
  value,
  onChange,
  label = 'Chọn ngày',
  sx,
  helperText,
  required,
  disabled,
  fullWidth,
  size,
  error,
}: DatePickerFieldProps) {
  const theme = useTheme();
  const [anchorEl, setAnchorEl] = useState<HTMLElement | null>(null);
  const open = Boolean(anchorEl);
  const selected = parseIsoDate(value);
  const today = new Date();
  const todayIso = toIsoDate(today.getFullYear(), today.getMonth() + 1, today.getDate());

  const [viewYear, setViewYear] = useState(selected?.year ?? today.getFullYear());
  const [viewMonth, setViewMonth] = useState(selected?.month ?? today.getMonth() + 1);

  const cells = useMemo(() => buildMonthGrid(viewYear, viewMonth), [viewYear, viewMonth]);

  function openPicker(el: HTMLElement) {
    const cur = parseIsoDate(value);
    setViewYear(cur?.year ?? today.getFullYear());
    setViewMonth(cur?.month ?? today.getMonth() + 1);
    setAnchorEl(el);
  }

  function shiftMonth(delta: number) {
    const d = new Date(viewYear, viewMonth - 1 + delta, 1);
    setViewYear(d.getFullYear());
    setViewMonth(d.getMonth() + 1);
  }

  function pickDay(iso: string) {
    onChange(iso);
    setAnchorEl(null);
  }

  return (
    <PickerShell
      label={label}
      display={formatDateVi(value)}
      icon={<CalendarTodayOutlinedIcon fontSize="small" color="primary" />}
      open={open}
      anchorEl={anchorEl}
      onOpen={openPicker}
      onClose={() => setAnchorEl(null)}
      sx={sx}
      helperText={helperText}
      required={required}
      disabled={disabled}
      fullWidth={fullWidth}
      size={size}
      error={error}
    >
      <Box
        sx={{
          px: 1.75,
          pt: 1.5,
          pb: 1.25,
          background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.12)} 0%, ${alpha(theme.palette.primary.main, 0.03)} 100%)`,
          borderBottom: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
        }}
      >
        <Stack direction="row" alignItems="center" justifyContent="space-between">
          <IconButton
            size="small"
            onClick={() => shiftMonth(-1)}
            aria-label="Tháng trước"
            sx={{
              bgcolor: alpha('#fff', 0.7),
              '&:hover': { bgcolor: '#fff' },
            }}
          >
            <ChevronLeftIcon fontSize="small" />
          </IconButton>
          <Typography variant="subtitle2" fontWeight={800} sx={{ letterSpacing: '-0.01em' }}>
            {MONTHS_VI[viewMonth - 1]} {viewYear}
          </Typography>
          <IconButton
            size="small"
            onClick={() => shiftMonth(1)}
            aria-label="Tháng sau"
            sx={{
              bgcolor: alpha('#fff', 0.7),
              '&:hover': { bgcolor: '#fff' },
            }}
          >
            <ChevronRightIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Box>

      <Box sx={{ px: 1.5, pt: 1.25, pb: 0.5 }}>
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: 'repeat(7, 1fr)',
            gap: 0.25,
            mb: 0.5,
          }}
        >
          {WEEKDAYS_VI.map((d) => (
            <Typography
              key={d}
              variant="caption"
              align="center"
              fontWeight={700}
              color="text.secondary"
              sx={{ py: 0.5, fontSize: '0.68rem', letterSpacing: '0.02em' }}
            >
              {d}
            </Typography>
          ))}
        </Box>

        <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 0.35 }}>
          {cells.map(({ date, inMonth }) => {
            const iso = toIsoDate(date.getFullYear(), date.getMonth() + 1, date.getDate());
            const isSelected = value === iso;
            const isToday = inMonth && iso === todayIso;
            const isWeekend = date.getDay() === 0 || date.getDay() === 6;

            return (
              <Box
                key={iso}
                component="button"
                type="button"
                onClick={() => pickDay(iso)}
                sx={{
                  appearance: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  width: '100%',
                  aspectRatio: '1',
                  borderRadius: 2,
                  display: 'grid',
                  placeItems: 'center',
                  position: 'relative',
                  font: 'inherit',
                  fontSize: '0.8125rem',
                  fontWeight: isSelected ? 700 : 500,
                  color: !inMonth
                    ? alpha(theme.palette.text.primary, 0.28)
                    : isSelected
                      ? theme.palette.primary.contrastText
                      : isWeekend
                        ? theme.palette.error.main
                        : theme.palette.text.primary,
                  bgcolor: isSelected ? theme.palette.primary.main : 'transparent',
                  transition: 'background-color 0.15s, transform 0.12s',
                  '&:hover': {
                    bgcolor: isSelected
                      ? theme.palette.primary.dark
                      : alpha(theme.palette.primary.main, 0.1),
                    transform: 'scale(1.04)',
                  },
                  ...(isToday && !isSelected
                    ? {
                        '&::after': {
                          content: '""',
                          position: 'absolute',
                          bottom: 5,
                          left: '50%',
                          transform: 'translateX(-50%)',
                          width: 5,
                          height: 5,
                          borderRadius: '50%',
                          bgcolor: theme.palette.primary.main,
                        },
                      }
                    : {}),
                }}
              >
                {date.getDate()}
              </Box>
            );
          })}
        </Box>
      </Box>

      <Divider />
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ px: 1.5, py: 1 }}>
        <Button
          size="small"
          color="inherit"
          onClick={() => {
            onChange('');
            setAnchorEl(null);
          }}
          sx={{ fontWeight: 600, borderRadius: 2 }}
        >
          Xóa
        </Button>
        <Button
          size="small"
          variant="contained"
          disableElevation
          onClick={() => pickDay(todayIso)}
          sx={{ fontWeight: 700, borderRadius: 2, px: 1.75 }}
        >
          Hôm nay
        </Button>
      </Stack>
    </PickerShell>
  );
}

type TimePickerFieldProps = Omit<TextFieldProps, 'value' | 'onChange' | 'type' | 'label' | 'helperText'> & {
  value: string;
  onChange: (value: string) => void;
  minuteStep?: number;
  label?: string;
  helperText?: string;
};

/** Chọn giờ — HH:mm (mặt đồng hồ, nhập trực tiếp trong popover) */
export function TimePickerField({
  value,
  onChange,
  label = 'Chọn giờ',
  minuteStep = 5,
  sx,
  helperText,
  required,
  disabled,
  fullWidth,
  size,
  error,
}: TimePickerFieldProps) {
  const theme = useTheme();
  const [anchorEl, setAnchorEl] = useState<HTMLElement | null>(null);
  const open = Boolean(anchorEl);

  return (
    <>
      <TextField
        fullWidth={fullWidth ?? true}
        size={size ?? 'small'}
        label={label}
        required={required}
        disabled={disabled}
        error={error}
        helperText={helperText}
        value={formatTimeDisplay(value)}
        onClick={(e) => {
          if (!disabled) setAnchorEl(e.currentTarget);
        }}
        InputProps={{
          readOnly: true,
          startAdornment: (
            <InputAdornment position="start">
              <ScheduleOutlinedIcon fontSize="small" color="primary" />
            </InputAdornment>
          ),
        }}
        sx={{
          ...dateTimeFieldSx,
          ...sx,
          cursor: disabled ? 'default' : 'pointer',
          '& .MuiOutlinedInput-input': { cursor: disabled ? 'default' : 'pointer' },
        }}
      />
      <Popover
        open={open}
        anchorEl={anchorEl}
        onClose={() => setAnchorEl(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
        transformOrigin={{ vertical: 'top', horizontal: 'left' }}
        slotProps={{ paper: { sx: timePopoverPaperSx(theme) } }}
      >
        <ClockTimePickerPanel
          value={value}
          minuteStep={minuteStep}
          onApply={(next) => {
            onChange(next);
            setAnchorEl(null);
          }}
          onCancel={() => setAnchorEl(null)}
        />
      </Popover>
    </>
  );
}
