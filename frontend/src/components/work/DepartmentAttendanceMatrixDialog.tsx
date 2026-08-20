import CloseIcon from '@mui/icons-material/Close';
import ClearRoundedIcon from '@mui/icons-material/ClearRounded';
import ChildCareOutlinedIcon from '@mui/icons-material/ChildCareOutlined';
import KeyboardArrowLeftRoundedIcon from '@mui/icons-material/KeyboardArrowLeftRounded';
import KeyboardArrowRightRoundedIcon from '@mui/icons-material/KeyboardArrowRightRounded';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import NightsStayOutlinedIcon from '@mui/icons-material/NightsStayOutlined';
import OpenInNewOutlinedIcon from '@mui/icons-material/OpenInNewOutlined';
import RefreshIcon from '@mui/icons-material/Refresh';
import SearchIcon from '@mui/icons-material/Search';
import TableChartOutlinedIcon from '@mui/icons-material/TableChartOutlined';
import {
  Alert,
  Avatar,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogContent,
  FormControl,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { memo, useCallback, useEffect, useMemo, useRef, useState, type ReactNode, type UIEvent } from 'react';
import * as attSvc from '../../services/attendanceService';
import type { DepartmentOption } from '../../services/employeeService';
import { formatAttendanceNotesPlain } from '../../utils/attendanceNotes';
import { formatWorkUnits } from '../../utils/shiftSchedule';

type Props = {
  open: boolean;
  onClose: () => void;
  year: number;
  month: number;
  departmentId?: number | '';
  departments: DepartmentOption[];
  deptFilterLocked?: boolean;
  onViewEmployee: (employeeId: number, departmentId?: number | null) => void;
};

const EMP_W = 272;
const SUM_W = 440;
const DAY_W = 132;
const ROW_H = 184;
const HEADER_H = 52;

function rowShell(bg: string) {
  return {
    height: ROW_H,
    minHeight: ROW_H,
    maxHeight: ROW_H,
    boxSizing: 'border-box' as const,
    borderBottom: 1,
    borderColor: '#e5eeec',
    bgcolor: bg,
    overflow: 'hidden',
  };
}
const WEEKDAYS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'] as const;

type DayCol = { day: number; workDate: string; wd: string; sun: boolean; weekend: boolean; today: boolean };

function shortTime(raw?: string | null): string | null {
  if (!raw || !String(raw).trim()) return null;
  return String(raw).slice(0, 5);
}

function punchRange(a?: string | null, b?: string | null): string | null {
  const x = shortTime(a);
  const y = shortTime(b);
  if (!x && !y) return null;
  if (x && y) return `${x}–${y}`;
  return x || y;
}

function isLeave(status?: string) {
  return status === 'LEAVE' || status === 'UNPAID_LEAVE' || status === 'ABSENT';
}

function dutyDisplayName(duty?: attSvc.AttendanceMatrixDutyDay): { short: string; full: string } {
  const rawCode = String(duty?.shiftTypeCode || duty?.shiftType || duty?.shiftTypeLabel || '').trim();
  const code = rawCode.toLowerCase().replace(/[\s_-]+/g, '');
  const configuredLabel = String(duty?.shiftTypeLabel || '').trim();
  const known =
    code === 'tructoichinh'
      ? { short: 'Trực chính', full: 'Trực chính' }
      : code === 'tc1'
        ? { short: 'Trực cọc 1', full: 'Trực cọc 1 cấp cứu' }
        : code === 'tcc'
          ? { short: 'Trực đa khoa', full: 'Trực đa khoa / cấp cứu / cọc 1 nội nhi' }
          : code === 'tk'
            ? { short: 'Trực kèm', full: 'Trực kèm' }
            : null;
  if (known) {
    const normalizedConfigured = configuredLabel.toLowerCase().replace(/[\s_-]+/g, '');
    return { short: known.short, full: configuredLabel && normalizedConfigured !== code ? configuredLabel : known.full };
  }
  const fallback = configuredLabel || rawCode || 'Ca trực';
  return { short: fallback, full: fallback };
}

function buildDays(year: number, month: number, n: number): DayCol[] {
  const mm = String(month).padStart(2, '0');
  const now = new Date();
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  return Array.from({ length: n }, (_, i) => {
    const day = i + 1;
    const workDate = `${year}-${mm}-${String(day).padStart(2, '0')}`;
    const dow = new Date(year, month - 1, day).getDay();
    return {
      day,
      workDate,
      wd: WEEKDAYS[dow],
      sun: dow === 0,
      weekend: dow === 0 || dow === 6,
      today: workDate === todayStr,
    };
  });
}

function computeStats(row: attSvc.AttendanceMatrixRow, daysInMonth: number) {
  const attendanceUnits = Number(row.attendanceWorkUnits ?? 0);
  const dutyUnits = Number(row.dutyWorkUnitsTotal ?? 0);
  const totalUnits = Number(row.totalWorkUnits ?? attendanceUnits + dutyUnits);
  let leaveDays = 0;
  let lateCount = 0;
  let quangTrungDays = 0;
  let quangTrungUnits = 0;
  for (const d of row.days ?? []) {
    if (isLeave(d.status)) leaveDays += 1;
    if ((Number(d.lateMinutes) || 0) > 0 && !d.lateMinutesExempt) lateCount += 1;
    if (d.quangTrung) {
      quangTrungDays += 1;
      quangTrungUnits += Number(d.totalWorkUnits ?? 0);
    }
  }
  const thieu = Math.max(0, Math.round((daysInMonth - leaveDays - attendanceUnits) * 100) / 100);
  return {
    attendanceUnits,
    dutyUnits,
    totalUnits,
    leaveDays,
    thieu,
    lateCount,
    lateMinutes: Number(row.lateMinutesTotal ?? 0),
    dutyCount: Number(row.dutyShiftCount ?? 0),
    dutyBonus: Number(row.dutyBonusTotal ?? 0),
    dutyPostPay: Number(row.dutyPostPayTotal ?? 0),
    quangTrungDays,
    quangTrungUnits,
    quangTrungAllowance: Number(row.quangTrungAllowance ?? 0),
    quangTrungAllowanceRate: Number(row.quangTrungAllowanceRate ?? 0),
  };
}

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function normalizeSearch(s: string) {
  return s
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

function TimeBadge({ text, tone }: { text: string; tone: 'am' | 'pm' }) {
  const theme = useTheme();
  const color = tone === 'am' ? theme.palette.warning.dark : theme.palette.success.dark;
  const base = tone === 'am' ? theme.palette.warning.main : theme.palette.success.main;
  return (
    <Box
      sx={{
        display: 'inline-flex',
        alignItems: 'center',
        px: 0.9,
        py: 0.4,
        borderRadius: 999,
        bgcolor: alpha(base, 0.09),
        border: `1px solid ${alpha(base, 0.12)}`,
        maxWidth: '100%',
      }}
    >
      <Typography
        component="span"
        sx={{
          fontSize: 12,
          fontWeight: 700,
          color,
          fontVariantNumeric: 'tabular-nums',
          letterSpacing: '-0.02em',
          whiteSpace: 'nowrap',
        }}
      >
        {text}
      </Typography>
    </Box>
  );
}

function DaySupplement({
  icon,
  title,
  value,
  color,
}: {
  icon: ReactNode;
  title: string;
  value: string;
  color: string;
}) {
  return (
    <Box
      sx={{
        width: '100%',
        display: 'flex',
        alignItems: 'center',
        gap: 0.65,
        px: 0.7,
        py: 0.5,
        borderRadius: 1.75,
        bgcolor: alpha(color, 0.055),
        border: `1px solid ${alpha(color, 0.14)}`,
        textAlign: 'left',
      }}
    >
      <Box
        sx={{
          width: 24,
          height: 24,
          flexShrink: 0,
          display: 'grid',
          placeItems: 'center',
          borderRadius: 1.2,
          bgcolor: alpha(color, 0.11),
          color,
          '& svg': { fontSize: 15 },
        }}
      >
        {icon}
      </Box>
      <Box sx={{ minWidth: 0 }}>
        <Typography variant="caption" noWrap title={title} sx={{ display: 'block', color, fontSize: 10.5, fontWeight: 800, lineHeight: 1.15 }}>
          {title}
        </Typography>
        <Typography variant="caption" noWrap sx={{ display: 'block', color: 'text.secondary', fontSize: 10, fontWeight: 650, lineHeight: 1.25 }}>
          {value}
        </Typography>
      </Box>
    </Box>
  );
}

const DayCell = memo(function DayCell({
  day,
  weekend,
  duty,
}: {
  day: attSvc.AttendanceMatrixDay | undefined;
  weekend: boolean;
  duty?: attSvc.AttendanceMatrixDutyDay;
}) {
  const theme = useTheme();

  if (!day && !duty) {
    return (
      <Typography variant="caption" sx={{ color: weekend ? 'warning.light' : 'divider', fontWeight: 500 }}>
        —
      </Typography>
    );
  }

  const leave = isLeave(day?.status);
  const am = punchRange(day?.morningCheckIn, day?.morningCheckOut);
  const pm = punchRange(day?.afternoonCheckIn, day?.afternoonCheckOut);
  const attendanceUnits = Number(day?.totalWorkUnits) || 0;
  const dutyUnits = Number(duty?.workUnits) || 0;
  const dutyName = dutyDisplayName(duty);
  const quangTrung = day?.quangTrung === true;
  const late = (Number(day?.lateMinutes) || 0) > 0 && !day?.lateMinutesExempt;

  if (!leave && !am && !pm && !duty && !quangTrung && attendanceUnits <= 0) {
    return (
      <Typography variant="caption" sx={{ color: 'text.disabled', fontWeight: 500 }}>
        —
      </Typography>
    );
  }

  const tip = [
    am ? `Sáng ${am}` : null,
    pm ? `Chiều ${pm}` : null,
    leave ? `Trạng thái: Nghỉ` : null,
    attendanceUnits > 0 ? `Công chấm: ${formatWorkUnits(attendanceUnits)}` : null,
    quangTrung ? `Công Quang Trung: ${formatWorkUnits(attendanceUnits)}` : null,
    quangTrung && day?.note ? `Ghi chú QT:\n${formatAttendanceNotesPlain(day.note)}` : null,
    duty ? `Ca trực: ${dutyName.full}` : null,
    duty?.roleTierLabel ? `Nhóm trực: ${duty.roleTierLabel}` : null,
    duty ? `Công trực: ${formatWorkUnits(dutyUnits)}` : null,
    duty && Number(duty.bonusAmount ?? 0) > 0 ? `Thưởng trực: ${attSvc.formatMoney(duty.bonusAmount)}` : null,
    duty && Number(duty.postDutyPay ?? 0) > 0 ? `Sau trực: ${attSvc.formatMoney(duty.postDutyPay)}` : null,
    duty?.note ? `Ghi chú trực: ${duty.note}` : null,
    day?.youngChild ? 'Chế độ nuôi con nhỏ (giảm 1 giờ)' : null,
    late ? `Muộn ${day?.lateMinutes} phút` : null,
    `Tổng ngày gồm trực: ${formatWorkUnits(attendanceUnits + dutyUnits)} công`,
  ]
    .filter(Boolean)
    .join(' · ');

  return (
    <Tooltip title={tip} arrow placement="top" enterDelay={400}>
      <Stack spacing={0.5} alignItems="center" sx={{ width: '100%', py: 0.5 }}>
        {leave && (
          <Chip
            label="Nghỉ"
            size="small"
            sx={{ height: 23, fontSize: 11, fontWeight: 700, bgcolor: alpha(theme.palette.warning.main, 0.12), color: 'warning.dark' }}
          />
        )}
        {!leave && am && <TimeBadge text={am} tone="am" />}
        {!leave && pm && <TimeBadge text={pm} tone="pm" />}
        {quangTrung && (
          <DaySupplement
            icon={<LocationOnOutlinedIcon />}
            title="Quang Trung"
            value={`${formatWorkUnits(attendanceUnits)} công`}
            color={theme.palette.info.dark}
          />
        )}
        {duty && (
          <DaySupplement
            icon={<NightsStayOutlinedIcon />}
            title={dutyName.short}
            value={`${formatWorkUnits(dutyUnits)} công trực`}
            color="#9a6700"
          />
        )}
        {day?.youngChild && (
          <Stack direction="row" spacing={0.35} alignItems="center" sx={{ color: 'secondary.dark' }}>
            <ChildCareOutlinedIcon sx={{ fontSize: 12 }} />
            <Typography variant="caption" sx={{ fontSize: 9.5, fontWeight: 800, lineHeight: 1 }}>
              Con nhỏ −1h
            </Typography>
          </Stack>
        )}
        {!leave && !am && !pm && !quangTrung && attendanceUnits > 0 && (
          <Typography variant="caption" sx={{ fontSize: 12.5, fontWeight: 700, color: 'primary.main', fontVariantNumeric: 'tabular-nums' }}>
            {formatWorkUnits(attendanceUnits)} công
          </Typography>
        )}
        {late && (
          <Typography variant="caption" sx={{ fontSize: 11, fontWeight: 700, color: 'error.main', lineHeight: 1 }}>
            +{day?.lateMinutes}′
          </Typography>
        )}
      </Stack>
    </Tooltip>
  );
});

function rowBg(zebra: boolean) {
  return zebra ? '#f9fbfb' : '#ffffff';
}

const EmpCell = memo(function EmpCell({ row, zebra }: { row: attSvc.AttendanceMatrixRow; zebra: boolean }) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;
  const bg = rowBg(zebra);
  return (
    <Box
      sx={{
        ...rowShell(bg),
        width: EMP_W,
        px: 1.5,
        display: 'flex',
        alignItems: 'center',
        gap: 1.25,
        '&:hover': { bgcolor: alpha(primary, 0.05) },
      }}
    >
      <Avatar sx={{ width: 40, height: 40, fontSize: 13, fontWeight: 700, flexShrink: 0, bgcolor: alpha(primary, 0.12), color: 'primary.dark' }}>
        {initials(row.fullName)}
      </Avatar>
      <Box sx={{ minWidth: 0, flex: 1 }}>
        <Typography variant="body2" fontWeight={600} noWrap title={row.fullName} sx={{ fontSize: 14, letterSpacing: '-0.02em', lineHeight: 1.35 }}>
          {row.fullName}
        </Typography>
        <Typography variant="caption" color="text.secondary" noWrap title={[row.position, row.employeeCode].filter(Boolean).join(' · ')} sx={{ display: 'block', fontSize: 12, lineHeight: 1.35, mt: 0.25 }}>
          {[row.position, row.employeeCode].filter(Boolean).join(' · ') || '—'}
        </Typography>
      </Box>
    </Box>
  );
});

const DaysRow = memo(function DaysRow({
  row,
  dayCols,
  zebra,
}: {
  row: attSvc.AttendanceMatrixRow;
  dayCols: DayCol[];
  zebra: boolean;
}) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;
  const bg = rowBg(zebra);
  const byDate = useMemo(() => {
    const m = new Map<string, attSvc.AttendanceMatrixDay>();
    for (const d of row.days ?? []) m.set(d.workDate, d);
    return m;
  }, [row.days]);
  const dutyByDate = useMemo(() => {
    const m = new Map<string, attSvc.AttendanceMatrixDutyDay>();
    for (const d of row.dutyDays ?? []) {
      m.set(d.workDate, d);
    }
    return m;
  }, [row.dutyDays]);

  return (
    <Box sx={{ ...rowShell(bg), display: 'flex', width: dayCols.length * DAY_W, '&:hover': { bgcolor: alpha(primary, 0.05) } }}>
      {dayCols.map((d) => (
        <Box
          key={d.workDate}
          sx={{
            width: DAY_W,
            flexShrink: 0,
            px: 0.75,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRight: 1,
            borderColor: alpha(theme.palette.divider, 0.3),
            bgcolor: d.today ? alpha(primary, 0.055) : d.weekend ? alpha(theme.palette.warning.main, 0.032) : 'transparent',
          }}
        >
          <DayCell day={byDate.get(d.workDate)} weekend={d.weekend} duty={dutyByDate.get(d.workDate)} />
        </Box>
      ))}
    </Box>
  );
});

const SumCell = memo(function SumCell({
  row,
  daysInMonth,
  zebra,
  onDetail,
}: {
  row: attSvc.AttendanceMatrixRow;
  daysInMonth: number;
  zebra: boolean;
  onDetail: (employeeId: number, departmentId?: number | null) => void;
}) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;
  const bg = rowBg(zebra);
  const stats = useMemo(() => computeStats(row, daysInMonth), [row, daysInMonth]);
  const statusMetrics = [
    stats.leaveDays > 0
      ? { label: 'Nghỉ', value: `${stats.leaveDays} ngày`, color: theme.palette.warning.dark }
      : null,
    stats.thieu > 0
      ? { label: 'Thiếu', value: `${formatWorkUnits(stats.thieu)} công`, color: theme.palette.error.main }
      : null,
    stats.lateMinutes > 0
      ? { label: 'Đi muộn', value: `${stats.lateCount} lần · ${stats.lateMinutes} phút`, color: theme.palette.error.main }
      : { label: 'Giờ công', value: 'Không phát sinh đi muộn', color: theme.palette.success.dark },
  ].filter((item): item is { label: string; value: string; color: string } => item != null);
  const moneyMetrics = [
    stats.dutyBonus > 0 ? { label: 'Thưởng trực', value: attSvc.formatMoney(stats.dutyBonus) } : null,
    stats.dutyPostPay > 0 ? { label: 'Tiền sau trực', value: attSvc.formatMoney(stats.dutyPostPay) } : null,
    stats.quangTrungAllowance > 0
      ? {
          label: 'Phụ cấp Quang Trung',
          value: `${attSvc.formatMoney(stats.quangTrungAllowance)} (${stats.quangTrungDays} ngày × ${attSvc.formatMoney(stats.quangTrungAllowanceRate)})`,
        }
      : null,
  ].filter((item): item is { label: string; value: string } => item != null);
  const unitMetrics = [
    {
      label: 'Chấm công',
      value: `${formatWorkUnits(stats.attendanceUnits)} công`,
      hint: 'Chưa gồm công trực',
      tone: primary,
    },
    {
      label: 'Công trực',
      value: `${formatWorkUnits(stats.dutyUnits)} công`,
      hint: `${stats.dutyCount} ca trực`,
      tone: theme.palette.secondary.dark,
    },
    {
      label: 'Quang Trung',
      value: `${formatWorkUnits(stats.quangTrungUnits)} công`,
      hint: `${stats.quangTrungDays} ngày · đã nằm trong chấm`,
      tone: theme.palette.info.dark,
    },
  ];

  return (
    <Box
      sx={{
        ...rowShell(bg),
        width: SUM_W,
        px: 1.75,
        py: 1,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        gap: 0.75,
        '&:hover': { bgcolor: alpha(primary, 0.05) },
      }}
    >
      <Stack direction="row" alignItems="center" justifyContent="space-between" spacing={1}>
        <Stack direction="row" alignItems="baseline" spacing={0.6}>
          <Typography variant="h6" fontWeight={850} color="primary.main" sx={{ fontVariantNumeric: 'tabular-nums', lineHeight: 1.1, fontSize: '1.35rem' }}>
            {formatWorkUnits(stats.totalUnits)}
          </Typography>
          <Typography variant="body2" color="text.secondary" fontWeight={700}>
            tổng công
          </Typography>
        </Stack>
        <Button
          size="small"
          variant="outlined"
          color="primary"
          onClick={() => onDetail(row.employeeId, row.departmentId)}
          endIcon={<OpenInNewOutlinedIcon sx={{ fontSize: 14 }} />}
          sx={{ minWidth: 0, px: 1, py: 0.35, borderRadius: 999, fontSize: 11.5, fontWeight: 750, textTransform: 'none', flexShrink: 0, borderColor: alpha(primary, 0.22), bgcolor: alpha(primary, 0.025) }}
        >
          Xem chi tiết
        </Button>
      </Stack>
      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: 'repeat(3, minmax(0, 1fr))',
          borderRadius: 2,
          bgcolor: alpha(primary, 0.025),
          border: `1px solid ${alpha(primary, 0.1)}`,
          overflow: 'hidden',
        }}
      >
        {unitMetrics.map((metric, index) => (
          <Box
            key={metric.label}
            sx={{
              minWidth: 0,
              px: 1,
              py: 0.75,
              borderLeft: index === 0 ? 'none' : `1px solid ${alpha(primary, 0.1)}`,
            }}
          >
            <Typography variant="caption" sx={{ display: 'block', color: 'text.secondary', fontSize: 10.25, fontWeight: 650, lineHeight: 1.15 }}>
              {metric.label}
            </Typography>
            <Typography variant="body2" sx={{ display: 'block', color: metric.tone, fontWeight: 850, fontSize: 13, lineHeight: 1.4, fontVariantNumeric: 'tabular-nums' }}>
              {metric.value}
            </Typography>
            <Typography variant="caption" sx={{ display: 'block', color: 'text.secondary', fontSize: 9.5, lineHeight: 1.2 }}>
              {metric.hint}
            </Typography>
          </Box>
        ))}
      </Box>
      {moneyMetrics.length > 0 && (
        <Stack
          direction="row"
          spacing={1.25}
          flexWrap="wrap"
          useFlexGap
          sx={{ px: 0.9, py: 0.6, borderRadius: 1.5, bgcolor: alpha(theme.palette.grey[500], 0.045) }}
        >
          {moneyMetrics.map((metric) => (
            <Typography key={metric.label} variant="caption" color="text.secondary" sx={{ fontSize: 10.25, lineHeight: 1.25 }}>
              {metric.label}: <Box component="span" sx={{ color: 'text.primary', fontWeight: 750 }}>{metric.value}</Box>
            </Typography>
          ))}
        </Stack>
      )}
      <Stack direction="row" spacing={1.25} flexWrap="wrap" useFlexGap>
        {statusMetrics.map((metric) => (
          <Stack key={metric.label} direction="row" spacing={0.45} alignItems="center">
            <Box sx={{ width: 5, height: 5, borderRadius: '50%', bgcolor: metric.color, flexShrink: 0 }} />
            <Typography variant="caption" sx={{ color: 'text.secondary', fontSize: 10.5, lineHeight: 1.2 }}>
              {metric.label} <Box component="span" sx={{ color: metric.color, fontWeight: 750 }}>{metric.value}</Box>
            </Typography>
          </Stack>
        ))}
      </Stack>
    </Box>
  );
});

type MatrixGridProps = {
  rows: attSvc.AttendanceMatrixRow[];
  dayCols: DayCol[];
  daysInMonth: number;
  onDetail: (employeeId: number, departmentId?: number | null) => void;
};

const hideScrollbar = {
  scrollbarWidth: 'none' as const,
  msOverflowStyle: 'none' as const,
  '&::-webkit-scrollbar': { display: 'none' },
};

const H_SCROLL_H = 44;

/**
 * 3 cột tách biệt — Nhân viên / Tổng hợp không đè lên ngày.
 * Thanh điều hướng ngang riêng, luôn hiển thị dưới cột ngày.
 * Thanh dọc chỉ ở cột Tổng hợp (đồng bộ 3 cột).
 */
function MatrixGrid({ rows, dayCols, daysInMonth, onDetail }: MatrixGridProps) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;
  const headerBg = '#f0f6f5';
  const daysWidth = dayCols.length * DAY_W;

  const leftRef = useRef<HTMLDivElement>(null);
  const midRef = useRef<HTMLDivElement>(null);
  const midHeadRef = useRef<HTMLDivElement>(null);
  const rightRef = useRef<HTMLDivElement>(null);
  const scrollTrackRef = useRef<HTMLDivElement>(null);
  const syncing = useRef(false);
  const syncingX = useRef(false);
  const dragRef = useRef<{ pointerId: number; startX: number; startScrollLeft: number } | null>(null);
  const [scrollLeft, setScrollLeft] = useState(0);
  const [viewportWidth, setViewportWidth] = useState(0);
  const [trackWidth, setTrackWidth] = useState(0);

  const syncY = useCallback((source: 'left' | 'mid' | 'right', top: number) => {
    if (syncing.current) return;
    syncing.current = true;
    if (source !== 'left' && leftRef.current) leftRef.current.scrollTop = top;
    if (source !== 'mid' && midRef.current) midRef.current.scrollTop = top;
    if (source !== 'right' && rightRef.current) rightRef.current.scrollTop = top;
    syncing.current = false;
  }, []);

  const applyScrollX = useCallback((left: number) => {
    const viewport = midRef.current?.clientWidth ?? 0;
    const next = Math.max(0, Math.min(left, Math.max(0, daysWidth - viewport)));
    if (midHeadRef.current) midHeadRef.current.scrollLeft = next;
    if (midRef.current) midRef.current.scrollLeft = next;
    setScrollLeft(next);
  }, [daysWidth]);

  const onMidScroll = useCallback(
    (e: UIEvent<HTMLDivElement>) => {
      syncY('mid', e.currentTarget.scrollTop);
      if (!syncingX.current) {
        syncingX.current = true;
        const x = e.currentTarget.scrollLeft;
        if (midHeadRef.current) midHeadRef.current.scrollLeft = x;
        setScrollLeft(x);
        syncingX.current = false;
      }
    },
    [syncY],
  );

  /** Trackpad / Shift+wheel lướt ngang trên vùng ngày */
  useEffect(() => {
    const el = midRef.current;
    if (!el) return;
    const onWheel = (e: WheelEvent) => {
      const horizontal = Math.abs(e.deltaX) > Math.abs(e.deltaY) || e.shiftKey;
      if (!horizontal) return;
      e.preventDefault();
      const dx = e.shiftKey && Math.abs(e.deltaX) < Math.abs(e.deltaY) ? e.deltaY : e.deltaX || e.deltaY;
      const next = (midRef.current?.scrollLeft ?? 0) + dx;
      applyScrollX(next);
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, [applyScrollX, rows.length, daysWidth]);

  useEffect(() => {
    const updateSizes = () => {
      const viewport = midRef.current?.clientWidth ?? 0;
      setViewportWidth(viewport);
      setTrackWidth(scrollTrackRef.current?.clientWidth ?? 0);
      setScrollLeft((current) => Math.min(current, Math.max(0, daysWidth - viewport)));
    };

    updateSizes();
    const observer = new ResizeObserver(updateSizes);
    if (midRef.current) observer.observe(midRef.current);
    if (scrollTrackRef.current) observer.observe(scrollTrackRef.current);
    return () => observer.disconnect();
  }, [daysWidth]);

  const maxScroll = Math.max(0, daysWidth - viewportWidth);
  const canScroll = maxScroll > 1;
  const thumbWidth = canScroll ? Math.min(trackWidth, Math.max(72, trackWidth * (viewportWidth / daysWidth))) : trackWidth;
  const thumbTravel = Math.max(0, trackWidth - thumbWidth);
  const thumbLeft = maxScroll > 0 ? (scrollLeft / maxScroll) * thumbTravel : 0;
  const firstVisibleDay = Math.min(dayCols.length, Math.max(1, Math.floor(scrollLeft / DAY_W) + 1));
  const lastVisibleDay = Math.max(firstVisibleDay, Math.min(dayCols.length, Math.ceil((scrollLeft + viewportWidth) / DAY_W)));

  const handleTrackPointerDown = useCallback(
    (event: React.PointerEvent<HTMLDivElement>) => {
      if (!canScroll || event.target !== event.currentTarget) return;
      const rect = event.currentTarget.getBoundingClientRect();
      const targetOffset = Math.max(0, Math.min(event.clientX - rect.left - thumbWidth / 2, thumbTravel));
      applyScrollX(thumbTravel > 0 ? (targetOffset / thumbTravel) * maxScroll : 0);
    },
    [applyScrollX, canScroll, maxScroll, thumbTravel, thumbWidth],
  );

  const handleThumbPointerDown = useCallback(
    (event: React.PointerEvent<HTMLDivElement>) => {
      if (!canScroll) return;
      event.preventDefault();
      event.currentTarget.setPointerCapture(event.pointerId);
      dragRef.current = { pointerId: event.pointerId, startX: event.clientX, startScrollLeft: scrollLeft };
    },
    [canScroll, scrollLeft],
  );

  const handleThumbPointerMove = useCallback(
    (event: React.PointerEvent<HTMLDivElement>) => {
      const drag = dragRef.current;
      if (!drag || drag.pointerId !== event.pointerId || thumbTravel <= 0) return;
      applyScrollX(drag.startScrollLeft + ((event.clientX - drag.startX) / thumbTravel) * maxScroll);
    },
    [applyScrollX, maxScroll, thumbTravel],
  );

  const stopThumbDrag = useCallback((event: React.PointerEvent<HTMLDivElement>) => {
    if (dragRef.current?.pointerId !== event.pointerId) return;
    dragRef.current = null;
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
  }, []);

  const headerLabelSx = {
    height: HEADER_H,
    minHeight: HEADER_H,
    flexShrink: 0,
    display: 'flex',
    alignItems: 'center',
    bgcolor: headerBg,
    borderBottom: `1px solid ${alpha(primary, 0.18)}`,
    fontWeight: 700,
    fontSize: 12,
    color: 'text.secondary',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.06em',
    boxSizing: 'border-box' as const,
  };

  return (
    <Box
      sx={{
        flex: 1,
        minHeight: 0,
        display: 'flex',
        flexDirection: 'column',
        borderRadius: 2,
        border: 1,
        borderColor: alpha(primary, 0.14),
        overflow: 'hidden',
        bgcolor: '#fff',
        boxShadow: `0 8px 28px ${alpha(theme.palette.common.black, 0.06)}`,
      }}
    >
      <Box sx={{ flex: 1, minHeight: 0, display: 'flex' }}>
        {/* Cột Nhân viên */}
        <Box
          sx={{
            width: EMP_W,
            flexShrink: 0,
            display: 'flex',
            flexDirection: 'column',
            minHeight: 0,
            bgcolor: '#fff',
            borderRight: `1px solid ${alpha(primary, 0.18)}`,
            zIndex: 2,
            boxShadow: `6px 0 20px ${alpha(theme.palette.common.black, 0.035)}`,
          }}
        >
          <Box sx={{ ...headerLabelSx, px: 1.5 }}>Nhân viên</Box>
          <Box
            ref={leftRef}
            onScroll={(e) => syncY('left', e.currentTarget.scrollTop)}
            sx={{ flex: 1, minHeight: 0, overflowY: 'auto', overflowX: 'hidden', ...hideScrollbar }}
          >
            {rows.map((row, i) => (
              <EmpCell key={row.employeeId} row={row} zebra={i % 2 === 1} />
            ))}
          </Box>
        </Box>

        {/* Cột ngày */}
        <Box sx={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
          <Box ref={midHeadRef} sx={{ overflow: 'hidden', flexShrink: 0 }}>
            <Box sx={{ width: daysWidth, ...headerLabelSx, bgcolor: headerBg }}>
              {dayCols.map((d) => (
                <Box
                  key={d.day}
                  sx={{
                    width: DAY_W,
                    flexShrink: 0,
                    height: '100%',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    borderRight: 1,
                    borderColor: alpha(theme.palette.divider, 0.3),
                    bgcolor: d.today ? alpha(primary, 0.095) : d.sun ? alpha(theme.palette.warning.main, 0.075) : 'transparent',
                  }}
                >
                  <Typography variant="caption" fontWeight={700} sx={{ fontSize: 11, letterSpacing: '0.06em', color: d.sun ? 'warning.dark' : 'text.secondary', lineHeight: 1.15 }}>
                    {d.wd}
                  </Typography>
                  <Typography variant="body2" fontWeight={800} sx={{ fontVariantNumeric: 'tabular-nums', color: d.today ? 'primary.dark' : 'text.primary', fontSize: 14, lineHeight: 1.25, mt: 0.2 }}>
                    {String(d.day).padStart(2, '0')}
                  </Typography>
                </Box>
              ))}
            </Box>
          </Box>
          <Box
            ref={midRef}
            onScroll={onMidScroll}
            sx={{
              flex: 1,
              minHeight: 0,
              overflow: 'auto',
              ...hideScrollbar,
            }}
          >
            <Box sx={{ width: daysWidth }}>
              {rows.map((row, i) => (
                <DaysRow key={row.employeeId} row={row} dayCols={dayCols} zebra={i % 2 === 1} />
              ))}
            </Box>
          </Box>
        </Box>

        {/* Cột Tổng hợp + thanh dọc */}
        <Box
          sx={{
            width: SUM_W,
            flexShrink: 0,
            display: 'flex',
            flexDirection: 'column',
            minHeight: 0,
            bgcolor: '#fff',
            borderLeft: `1px solid ${alpha(primary, 0.18)}`,
            zIndex: 2,
            boxShadow: `-6px 0 20px ${alpha(theme.palette.common.black, 0.035)}`,
          }}
        >
          <Box sx={{ ...headerLabelSx, justifyContent: 'center' }}>Tổng hợp</Box>
          <Box
            ref={rightRef}
            onScroll={(e) => syncY('right', e.currentTarget.scrollTop)}
            sx={{
              flex: 1,
              minHeight: 0,
              overflowY: 'auto',
              overflowX: 'hidden',
              scrollbarWidth: 'thin',
              scrollbarColor: `${alpha(primary, 0.4)} transparent`,
              '&::-webkit-scrollbar': { width: 10 },
              '&::-webkit-scrollbar-thumb': { bgcolor: alpha(primary, 0.35), borderRadius: 5 },
              '&::-webkit-scrollbar-track': { bgcolor: 'transparent' },
            }}
          >
            {rows.map((row, i) => (
              <SumCell key={row.employeeId} row={row} daysInMonth={daysInMonth} zebra={i % 2 === 1} onDetail={onDetail} />
            ))}
          </Box>
        </Box>
      </Box>

      {/* Thanh cuộn ngang tùy biến — luôn hiển thị, không phụ thuộc cài đặt scrollbar của hệ điều hành */}
      <Box
        sx={{
          display: 'flex',
          flexShrink: 0,
          height: H_SCROLL_H,
          bgcolor: '#f8fbfa',
          borderTop: `1px solid ${alpha(primary, 0.12)}`,
        }}
      >
        <Box
          sx={{
            width: EMP_W,
            flexShrink: 0,
            px: 1.5,
            display: 'flex',
            alignItems: 'center',
            color: 'text.secondary',
            borderRight: `1px solid ${alpha(primary, 0.12)}`,
          }}
        >
          <Typography variant="caption" fontWeight={600} noWrap>
            Kéo thanh để xem đủ {dayCols.length} ngày
          </Typography>
        </Box>

        <Stack direction="row" alignItems="center" spacing={1} sx={{ flex: 1, minWidth: 0, px: 1 }}>
          <IconButton
            size="small"
            disabled={!canScroll || scrollLeft <= 0}
            onClick={() => applyScrollX(scrollLeft - DAY_W * 3)}
            aria-label="Xem các ngày trước"
            sx={{ width: 28, height: 28, flexShrink: 0, color: 'primary.main' }}
          >
            <KeyboardArrowLeftRoundedIcon fontSize="small" />
          </IconButton>
          <Box
            ref={scrollTrackRef}
            role="scrollbar"
            aria-label="Cuộn ngang bảng công theo ngày"
            aria-valuemin={0}
            aria-valuemax={Math.round(maxScroll)}
            aria-valuenow={Math.round(scrollLeft)}
            tabIndex={canScroll ? 0 : -1}
            onPointerDown={handleTrackPointerDown}
            onKeyDown={(event) => {
              if (event.key === 'ArrowLeft') applyScrollX(scrollLeft - DAY_W);
              if (event.key === 'ArrowRight') applyScrollX(scrollLeft + DAY_W);
              if (event.key === 'Home') applyScrollX(0);
              if (event.key === 'End') applyScrollX(maxScroll);
            }}
            sx={{
              position: 'relative',
              flex: 1,
              minWidth: 40,
              height: 12,
              borderRadius: 999,
              bgcolor: alpha(primary, 0.11),
              boxShadow: `inset 0 1px 2px ${alpha(theme.palette.common.black, 0.08)}`,
              cursor: canScroll ? 'pointer' : 'default',
              outline: 'none',
              '&:focus-visible': { boxShadow: `0 0 0 3px ${alpha(primary, 0.2)}` },
            }}
          >
            <Box
              onPointerDown={handleThumbPointerDown}
              onPointerMove={handleThumbPointerMove}
              onPointerUp={stopThumbDrag}
              onPointerCancel={stopThumbDrag}
              sx={{
                position: 'absolute',
                insetBlock: 0,
                left: thumbLeft,
                width: thumbWidth,
                minWidth: canScroll ? 72 : 0,
                borderRadius: 999,
                bgcolor: canScroll ? 'primary.main' : alpha(primary, 0.22),
                border: '2px solid #f8fbfa',
                boxShadow: canScroll ? `0 2px 7px ${alpha(primary, 0.32)}` : 'none',
                cursor: canScroll ? 'grab' : 'default',
                touchAction: 'none',
                transition: dragRef.current ? 'none' : 'background-color 160ms ease',
                '&:hover': { bgcolor: canScroll ? 'primary.dark' : alpha(primary, 0.22) },
                '&:active': { cursor: canScroll ? 'grabbing' : 'default' },
              }}
            />
          </Box>
          <IconButton
            size="small"
            disabled={!canScroll || scrollLeft >= maxScroll - 1}
            onClick={() => applyScrollX(scrollLeft + DAY_W * 3)}
            aria-label="Xem các ngày tiếp theo"
            sx={{ width: 28, height: 28, flexShrink: 0, color: 'primary.main' }}
          >
            <KeyboardArrowRightRoundedIcon fontSize="small" />
          </IconButton>
        </Stack>

        <Box
          sx={{
            width: SUM_W,
            flexShrink: 0,
            px: 1.5,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderLeft: `1px solid ${alpha(primary, 0.12)}`,
          }}
        >
          <Typography variant="caption" color="text.secondary" fontWeight={600} noWrap sx={{ fontVariantNumeric: 'tabular-nums' }}>
            Đang xem {String(firstVisibleDay).padStart(2, '0')}–{String(lastVisibleDay).padStart(2, '0')} / {dayCols.length}
          </Typography>
        </Box>
      </Box>
    </Box>
  );
}

export function DepartmentAttendanceMatrixDialog({
  open,
  onClose,
  year,
  month,
  departmentId = '',
  departments,
  deptFilterLocked,
  onViewEmployee,
}: Props) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;

  const initialScope = useMemo(() => {
    if (departmentId !== '' && departmentId != null) return departmentId;
    if (deptFilterLocked) return departmentId === '' ? '' : departmentId;
    return '';
  }, [departmentId, deptFilterLocked, departments]);

  const [scopeDept, setScopeDept] = useState<number | ''>(initialScope);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [matrix, setMatrix] = useState<attSvc.AttendanceMonthMatrix | null>(null);

  useEffect(() => {
    if (!open) return;
    setScopeDept(initialScope);
    setSearch('');
  }, [open, initialScope]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await attSvc.fetchAttendanceMonthMatrix(
        year,
        month,
        scopeDept === '' || scopeDept == null ? undefined : Number(scopeDept),
      );
      setMatrix(data);
    } catch (e: unknown) {
      setMatrix(null);
      const ax = e as { response?: { data?: { message?: string } }; message?: string };
      setError(ax.response?.data?.message || ax.message || 'Không tải được bảng công theo khoa');
    } finally {
      setLoading(false);
    }
  }, [year, month, scopeDept]);

  useEffect(() => {
    if (!open) return;
    void load();
  }, [open, load]);

  const daysInMonth = matrix?.daysInMonth ?? new Date(year, month, 0).getDate();
  const dayCols = useMemo(() => buildDays(year, month, daysInMonth), [year, month, daysInMonth]);

  const allRows = matrix?.rows ?? [];
  const availableDepartments = useMemo(() => {
    const unique = new Map<number, DepartmentOption>();
    departments.forEach((department) => unique.set(department.id, department));
    allRows.forEach((row) => {
      if (row.departmentId != null && row.department?.trim()) {
        unique.set(row.departmentId, {
          id: row.departmentId,
          code: `DEPT-${row.departmentId}`,
          name: row.department.trim(),
        });
      }
    });
    return [...unique.values()].sort((a, b) => a.name.localeCompare(b.name, 'vi'));
  }, [departments, allRows]);
  const filteredRows = useMemo(() => {
    const q = normalizeSearch(search);
    if (!q) return allRows;
    return allRows.filter((row) => {
      const hay = normalizeSearch([row.fullName, row.employeeCode, row.position].filter(Boolean).join(' '));
      return hay.includes(q);
    });
  }, [allRows, search]);

  const scopeLabel =
    matrix?.departmentName ||
    departments.find((d) => d.id === scopeDept)?.name ||
    'Chọn khoa/phòng';

  const needsDept = !matrix && !loading;

  return (
    <Dialog
      open={open}
      onClose={onClose}
      fullScreen
      transitionDuration={220}
      PaperProps={{
        sx: {
          bgcolor: 'background.default',
          borderRadius: 0,
          display: 'flex',
          flexDirection: 'column',
          height: '100%',
          overflow: 'hidden',
        },
      }}
    >
      <DialogContent
        sx={{
          p: { xs: 1.5, md: 2 },
          display: 'flex',
          flexDirection: 'column',
          gap: 1.5,
          overflow: 'hidden',
          flex: 1,
          minHeight: 0,
        }}
      >
        <Paper elevation={0} sx={{ px: 2, py: 1.25, borderRadius: 2.5, border: 1, borderColor: 'divider', bgcolor: 'background.paper', flexShrink: 0 }}>
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5} alignItems={{ md: 'center' }} justifyContent="space-between" useFlexGap>
            <Stack direction="row" spacing={2} alignItems="center" flexWrap="wrap" useFlexGap>
              <Typography variant="body2" color="text.secondary" fontWeight={500}>
                {needsDept ? (
                  'Chọn khoa/phòng để xem bảng công'
                ) : (
                  <>
                    <Box component="span" sx={{ color: 'text.primary', fontWeight: 700 }}>
                      {filteredRows.length}
                    </Box>
                    {search.trim() ? ` / ${allRows.length}` : ''} nhân viên
                  </>
                )}
              </Typography>
              {!needsDept && (
                <Stack direction="row" spacing={1.5} alignItems="center" flexWrap="wrap" useFlexGap>
                  <LegendDot color={theme.palette.warning.dark} label="Sáng" />
                  <LegendDot color={theme.palette.success.dark} label="Chiều" />
                  <LegendDot color={theme.palette.warning.main} label="Nghỉ" />
                  <LegendDot color={theme.palette.secondary.dark} label="Công trực" />
                  <LegendDot color={theme.palette.info.dark} label="Quang Trung" />
                  <LegendDot color={primary} label="Hôm nay" outline />
                </Stack>
              )}
            </Stack>

            <Stack
              direction={{ xs: 'column', sm: 'row' }}
              spacing={1}
              alignItems={{ sm: 'center' }}
              sx={{ width: { xs: '100%', md: 'auto' } }}
            >
              {!deptFilterLocked && (
                <FormControl size="small" sx={{ minWidth: { xs: '100%', sm: 230 } }}>
                  <InputLabel id="matrix-dept">Khoa / phòng</InputLabel>
                  <Select
                    labelId="matrix-dept"
                    label="Khoa / phòng"
                    value={scopeDept === '' ? '' : String(scopeDept)}
                    onChange={(e) => {
                      const v = e.target.value;
                      setScopeDept(v === '' ? '' : Number(v));
                    }}
                    sx={{ bgcolor: 'background.paper', fontWeight: 600 }}
                  >
                    <MenuItem value="">
                      Toàn bệnh viện
                    </MenuItem>
                    {availableDepartments.map((d) => (
                      <MenuItem key={d.id} value={String(d.id)}>
                        {d.name}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              )}

              {!needsDept && (
                <TextField
                  size="small"
                  placeholder="Tìm theo tên hoặc mã nhân viên…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  inputProps={{ 'aria-label': 'Tìm kiếm nhân viên theo tên hoặc mã nhân viên' }}
                  sx={{ minWidth: { xs: '100%', sm: 280 }, maxWidth: 380 }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <SearchIcon fontSize="small" sx={{ color: search ? 'primary.main' : 'text.disabled' }} />
                      </InputAdornment>
                    ),
                    endAdornment: search ? (
                      <InputAdornment position="end">
                        <Tooltip title="Xóa nội dung tìm kiếm">
                          <IconButton
                            size="small"
                            onClick={() => setSearch('')}
                            aria-label="Xóa nội dung tìm kiếm"
                            edge="end"
                            sx={{ mr: -0.5 }}
                          >
                            <ClearRoundedIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      </InputAdornment>
                    ) : undefined,
                  }}
                />
              )}

              {!needsDept && (
                <Tooltip title="Tải lại dữ liệu">
                  <span>
                    <IconButton
                      onClick={() => void load()}
                      disabled={loading}
                      aria-label="Tải lại"
                      sx={{ border: 1, borderColor: 'divider', bgcolor: 'background.paper', color: 'primary.main' }}
                    >
                      {loading ? <CircularProgress size={20} color="inherit" /> : <RefreshIcon />}
                    </IconButton>
                  </span>
                </Tooltip>
              )}

              <Tooltip title="Đóng bảng công">
                <IconButton
                  onClick={onClose}
                  aria-label="Đóng"
                  sx={{ border: 1, borderColor: 'divider', bgcolor: 'background.paper', color: 'text.secondary' }}
                >
                  <CloseIcon />
                </IconButton>
              </Tooltip>
            </Stack>
          </Stack>
        </Paper>

        {error && (
          <Alert severity="error" onClose={() => setError(null)} sx={{ borderRadius: 2, flexShrink: 0 }}>
            {error}
          </Alert>
        )}

        {needsDept ? (
          <EmptyState text="Chọn khoa/phòng ở thanh trên để tải bảng công" dashed />
        ) : loading ? (
          <EmptyState text={`Đang tải dữ liệu ${scopeLabel}…`} loading />
        ) : filteredRows.length === 0 ? (
          <EmptyState text={search.trim() ? 'Không tìm thấy nhân viên phù hợp' : 'Không có nhân viên trong khoa này'} />
        ) : (
          <MatrixGrid rows={filteredRows} dayCols={dayCols} daysInMonth={daysInMonth} onDetail={onViewEmployee} />
        )}
      </DialogContent>
    </Dialog>
  );
}

function LegendDot({ color, label, outline }: { color: string; label: string; outline?: boolean }) {
  return (
    <Box component="span" sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.6, fontSize: 12, fontWeight: 500, color: 'text.secondary' }}>
      <Box
        component="span"
        sx={{
          width: outline ? 10 : 8,
          height: outline ? 10 : 8,
          borderRadius: outline ? 1 : '50%',
          bgcolor: outline ? alpha(color, 0.15) : color,
          border: outline ? `2px solid ${alpha(color, 0.45)}` : 'none',
          flexShrink: 0,
        }}
      />
      {label}
    </Box>
  );
}

function EmptyState({ text, dashed, loading }: { text: string; dashed?: boolean; loading?: boolean }) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;

  return (
    <Paper
      elevation={0}
      sx={{
        flex: 1,
        display: 'grid',
        placeItems: 'center',
        borderRadius: 2.5,
        border: dashed ? `2px dashed ${alpha(primary, 0.25)}` : 1,
        borderColor: dashed ? undefined : 'divider',
        minHeight: 280,
        bgcolor: 'background.paper',
      }}
    >
      <Stack spacing={2} alignItems="center" sx={{ px: 3, textAlign: 'center' }}>
        {loading ? (
          <CircularProgress size={36} thickness={3.5} />
        ) : (
          <Box sx={{ width: 56, height: 56, borderRadius: 3, display: 'grid', placeItems: 'center', bgcolor: alpha(primary, 0.08), color: 'primary.main' }}>
            <TableChartOutlinedIcon sx={{ fontSize: 28 }} />
          </Box>
        )}
        <Typography color="text.secondary" fontWeight={500}>
          {text}
        </Typography>
      </Stack>
    </Paper>
  );
}
