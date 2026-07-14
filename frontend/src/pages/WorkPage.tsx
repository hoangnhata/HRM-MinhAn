import AccessTimeIcon from '@mui/icons-material/AccessTime';
import EventAvailableIcon from '@mui/icons-material/EventAvailable';
import GavelIcon from '@mui/icons-material/Gavel';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import HowToRegOutlinedIcon from '@mui/icons-material/HowToRegOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import RestaurantIcon from '@mui/icons-material/Restaurant';
import SwapHorizOutlinedIcon from '@mui/icons-material/SwapHorizOutlined';
import WarningAmberIcon from '@mui/icons-material/WarningAmber';
import {
  Alert,
  Box,
  Chip,
  Grid,
  LinearProgress,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { AttendanceExplanationDialog } from '../components/AttendanceExplanationDialog';
import { AttendanceUpdateRequestDialog } from '../components/AttendanceUpdateRequestDialog';
import { CheckInOutImportDialog } from '../components/CheckInOutImportDialog';
import { CheckInOutSyncDialog } from '../components/CheckInOutSyncDialog';
import { EmployeeFilterPanel } from '../components/EmployeeFilterPanel';
import { PageHeader } from '../components/layout/PageHeader';
import { AttendanceDayDetailDialog } from '../components/work/AttendanceDayDetailDialog';
import { AttendanceRowActions, rowNeedsUpdate } from '../components/work/AttendanceRowActions';
import { AttendanceScheduleBanner } from '../components/work/AttendanceScheduleBanner';
import { AttendanceScheduleEditDialog } from '../components/work/AttendanceScheduleEditDialog';
import { DeploymentRequestDialog } from '../components/DeploymentRequestDialog';
import { DutyShiftDialog } from '../components/work/DutyShiftDialog';
import { WorkSupplementDialog } from '../components/work/WorkSupplementDialog';
import { ForgotPenaltyConfigDialog } from '../components/work/ForgotPenaltyConfigDialog';
import { HolidayWorkConfigDialog } from '../components/work/HolidayWorkConfigDialog';
import { LatePenaltyConfigDialog } from '../components/work/LatePenaltyConfigDialog';
import { WorkAdminToolbar } from '../components/work/WorkAdminToolbar';
import { MonthPickerField } from '../components/ui/DateTimeFields';
import { useAuth } from '../context/AuthContext';
import * as attSvc from '../services/attendanceService';
import * as employeeService from '../services/employeeService';
import * as importService from '../services/importService';
import * as pa from '../services/payrollAttendanceService';
import {
  continuousShiftHours,
  formatPunchTime,
  formatWorkedHours,
  formatWorkUnits,
  normalizeWorkUnits,
  parseLocalDate,
  scheduleForDate,
  displayHoursFromUnits,
  type ShiftScheduleInfo,
} from '../utils/shiftSchedule';

const STATUS_CHIP: Record<string, { label: string; color: 'success' | 'warning' | 'default' | 'error' | 'info' }> = {
  PRESENT: { label: 'Đủ công', color: 'success' },
  PARTIAL: { label: 'Thiếu ca', color: 'warning' },
  ABSENT: { label: 'Vắng', color: 'error' },
  LEAVE: { label: 'Phép', color: 'info' },
  BUSINESS_TRIP: { label: 'Công tác', color: 'warning' },
  DEPLOYMENT: { label: 'Điều động', color: 'info' },
};

function monthRangeFor(year: number, month: number) {
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 0);
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  return { from: iso(start), to: iso(end) };
}

function currentYearMonth() {
  const now = new Date();
  return { year: now.getFullYear(), month: now.getMonth() + 1 };
}

function daysInMonth(year: number, month: number): string[] {
  const total = new Date(year, month, 0).getDate();
  const mm = String(month).padStart(2, '0');
  return Array.from({ length: total }, (_, i) => {
    const dd = String(i + 1).padStart(2, '0');
    return `${year}-${mm}-${dd}`;
  });
}

function shiftHoursLabel(
  row: Record<string, unknown> | null,
  sch: ShiftScheduleInfo,
  shift: 'morning' | 'afternoon',
  continuous?: boolean,
) {
  if (!row) return '—';
  if (continuous) return '—';
  const units = Number(shift === 'morning' ? row.morningWorkUnits : row.afternoonWorkUnits) || 0;
  const maxUnits = shift === 'morning' ? sch.morningUnits : sch.afternoonUnits;
  const scheduled = shift === 'morning' ? sch.morningHours : sch.afternoonHours;
  const dayHours =
    sch.effectiveDayHours ??
    ((sch.morningHours ?? 0) + (sch.afternoonHours ?? 0) || 8);
  const hasPunch =
    shift === 'morning'
      ? Boolean(row.morningCheckIn || row.morningCheckOut)
      : Boolean(row.afternoonCheckIn || row.afternoonCheckOut);
  return formatWorkedHours(
    displayHoursFromUnits(units, maxUnits, scheduled, dayHours, { hasPunch }),
  );
}

function continuousHoursLabel(row: Record<string, unknown> | null, sch: ShiftScheduleInfo) {
  if (!row) return '—';
  const morningUnits = Number(row.morningWorkUnits ?? 0) || 0;
  const afternoonUnits = Number(row.afternoonWorkUnits ?? 0) || 0;
  const totalUnits = morningUnits + afternoonUnits;
  if (totalUnits <= 0) return '—';
  const dayHours = continuousShiftHours(sch);
  const totalShiftUnits = sch.morningUnits + sch.afternoonUnits;
  const hasPunch = Boolean(row.morningCheckIn || row.afternoonCheckOut);
  return formatWorkedHours(
    displayHoursFromUnits(totalUnits, totalShiftUnits, dayHours, sch.effectiveDayHours ?? dayHours, { hasPunch }),
  );
}

/** Cột ngoài giờ — công điều động ngoài ca × giờ ngày. */
function overtimeHoursLabel(
  row: Record<string, unknown> | null,
  sch: ShiftScheduleInfo,
  continuous?: boolean,
) {
  if (!row) return '—';
  const units = Number(row.overtimeWorkUnits ?? 0) || 0;
  if (units <= 0) return '—';
  const dayHours = continuous
    ? (sch.effectiveDayHours ?? continuousShiftHours(sch))
    : (sch.effectiveDayHours ?? ((sch.morningHours ?? 0) + (sch.afternoonHours ?? 0) || 8));
  return formatWorkedHours(units * dayHours);
}

const statusChipSx = {
  height: 22,
  maxWidth: 'none',
  fontSize: 11,
  fontWeight: 600,
  borderRadius: 1.25,
  '& .MuiChip-label': { px: 0.85, whiteSpace: 'nowrap' as const },
  '& .MuiChip-icon': { ml: 0.6, mr: -0.15, fontSize: '13px !important' },
};

export default function WorkPage() {
  const theme = useTheme();
  const { user } = useAuth();
  const isHrOrAdmin = user?.role === 'ADMIN' || user?.role === 'HR';
  const isHead =
    user?.role === 'ADMIN' || user?.role === 'HEAD_DEPARTMENT' || user?.role === 'HEAD_NURSING';
  const isHeadRole = user?.role === 'HEAD_DEPARTMENT' || user?.role === 'HEAD_NURSING';
  const canPickEmployee = isHrOrAdmin || isHead;

  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [employees, setEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [selected, setSelected] = useState<number | ''>('');
  const canManageSupplement = isHrOrAdmin && selected !== '';
  const canManageDutyOnly = isHeadRole && !isHrOrAdmin && selected !== '';
  const canCreateDeployment = (isHeadRole || isHrOrAdmin) && selected !== '';
  const [qInput, setQInput] = useState('');
  const [q, setQ] = useState('');
  const [filterDept, setFilterDept] = useState<number | ''>('');
  const [filterStatus, setFilterStatus] = useState('ACTIVE');
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [{ year, month }, setPeriod] = useState(currentYearMonth);
  const [att, setAtt] = useState<Record<string, unknown>[]>([]);
  const [summary, setSummary] = useState<attSvc.MonthSummary | null>(null);
  const [myRequests, setMyRequests] = useState<attSvc.WorkRequest[]>([]);
  const [notifyMsg, setNotifyMsg] = useState<string | null>(null);
  const [exportingReport, setExportingReport] = useState(false);
  const [recalculating, setRecalculating] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [syncOpen, setSyncOpen] = useState(false);
  const [chamcongSyncEnabled, setChamcongSyncEnabled] = useState(false);
  const [updateOpen, setUpdateOpen] = useState(false);
  const [explainOpen, setExplainOpen] = useState(false);
  const [dialogDate, setDialogDate] = useState<string | undefined>();
  const [updateRow, setUpdateRow] = useState<Record<string, unknown> | null>(null);
  const [explainRow, setExplainRow] = useState<Record<string, unknown> | null>(null);
  const [dayDetailOpen, setDayDetailOpen] = useState(false);
  const [dayDetailDate, setDayDetailDate] = useState('');
  const [dayDetailRow, setDayDetailRow] = useState<Record<string, unknown> | null>(null);
  const [schedule, setSchedule] = useState<ShiftScheduleInfo>(() => scheduleForDate());
  const [scheduleEditOpen, setScheduleEditOpen] = useState(false);
  const [forgotPenaltyConfigOpen, setForgotPenaltyConfigOpen] = useState(false);
  const [latePenaltyConfigOpen, setLatePenaltyConfigOpen] = useState(false);
  const [holidayWorkConfigOpen, setHolidayWorkConfigOpen] = useState(false);
  const [holidayDates, setHolidayDates] = useState<Set<string>>(() => new Set());
  const [continuousShift, setContinuousShift] = useState(false);
  const [continuousSaving, setContinuousSaving] = useState(false);
  const [youngChild, setYoungChild] = useState(false);
  const [youngChildSaving, setYoungChildSaving] = useState(false);
  const [dutyShifts, setDutyShifts] = useState<attSvc.DutyShiftEntry[]>([]);
  const [dutyOpen, setDutyOpen] = useState(false);
  const [supplementOpen, setSupplementOpen] = useState(false);
  const [deploymentOpen, setDeploymentOpen] = useState(false);
  const [dutyDate, setDutyDate] = useState('');
  const [deploymentDate, setDeploymentDate] = useState('');
  const [supplementInitialTab, setSupplementInitialTab] = useState<0 | 1 | 2 | undefined>(undefined);

  const selectedEmployee = useMemo(
    () => employees.find((e) => e.id === selected),
    [employees, selected],
  );

  const attByDate = useMemo(() => {
    const m = new Map<string, Record<string, unknown>>();
    att.forEach((r) => m.set(String(r.workDate), r));
    return m;
  }, [att]);

  const dutyByDate = useMemo(() => {
    const m = new Map<string, attSvc.DutyShiftEntry>();
    dutyShifts.forEach((d) => m.set(d.workDate, d));
    return m;
  }, [dutyShifts]);

  const monthDays = useMemo(
    () =>
      daysInMonth(year, month).map((workDate) => ({
        workDate,
        row: attByDate.get(workDate) ?? null,
      })),
    [year, month, attByDate],
  );

  const paperSx = {
    borderRadius: 3,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
    bgcolor: alpha(theme.palette.background.paper, 0.96),
    boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
    overflow: 'hidden' as const,
  };

  useEffect(() => {
    const t = setTimeout(() => setQ(qInput), 400);
    return () => clearTimeout(t);
  }, [qInput]);

  function reloadSchedule(employeeId?: number, periodYear = year, periodMonth = month) {
    const id =
      employeeId ??
      (selected !== '' ? Number(selected) : user?.employeeId != null ? user.employeeId : undefined);
    const refDate = `${periodYear}-${String(periodMonth).padStart(2, '0')}-15`;
    attSvc
      .fetchShiftSchedule(refDate, id)
      .then((s) => {
        setSchedule(s);
        setContinuousShift(Boolean(s.continuousShift));
        setYoungChild(Boolean(s.youngChild));
      })
      .catch(() => setSchedule(scheduleForDate(refDate)));
  }

  useEffect(() => {
    reloadSchedule();
  }, [selected, user?.employeeId, year, month]);

  useEffect(() => {
    if (!isHrOrAdmin) {
      setHolidayDates(new Set());
      return;
    }
    let cancelled = false;
    attSvc
      .fetchHolidayWorkDays(year, month)
      .then((r) => {
        if (!cancelled) setHolidayDates(new Set(r.dates ?? []));
      })
      .catch(() => {
        if (!cancelled) setHolidayDates(new Set());
      });
    return () => {
      cancelled = true;
    };
  }, [isHrOrAdmin, year, month]);

  useEffect(() => {
    const raw = searchParams.get('tab');
    if (!raw) return;
    // Tab đơn đã chuyển sang trang /requests
    if (raw === 'requests' || raw === 'my-requests') {
      navigate('/requests?tab=mine', { replace: true });
      return;
    }
    if (raw === 'approve' || raw === 'pending') {
      navigate('/requests?tab=approve', { replace: true });
    }
  }, [searchParams, navigate]);

  useEffect(() => {
    if (canPickEmployee) {
      employeeService.fetchDepartments().then(setDepartments).catch(() => {});
    }
  }, [canPickEmployee]);

  useEffect(() => {
    if (!canPickEmployee) return;
    let cancelled = false;
    (async () => {
      const p = await employeeService.fetchEmployees({
        page: 0,
        size: 1000,
        q: q.trim() || undefined,
        departmentId: filterDept === '' ? undefined : filterDept,
        status: filterStatus || undefined,
      });
      if (cancelled) return;
      setEmployees(p.content);
      if (p.content.length === 0) {
        setSelected('');
        return;
      }
      setSelected((prev) => (prev !== '' && p.content.some((e) => e.id === prev) ? prev : p.content[0].id));
    })();
    return () => {
      cancelled = true;
    };
  }, [canPickEmployee, q, filterDept, filterStatus]);

  useEffect(() => {
    if (canPickEmployee) return;
    if (user?.employeeId) setSelected(user.employeeId);
  }, [user, canPickEmployee]);

  useEffect(() => {
    if (!isHrOrAdmin) return;
    let cancelled = false;
    importService.fetchCheckInOutSyncStatus().then((s) => {
      if (!cancelled) setChamcongSyncEnabled(s.enabled);
    }).catch(() => {
      if (!cancelled) setChamcongSyncEnabled(false);
    });
    return () => {
      cancelled = true;
    };
  }, [isHrOrAdmin]);

  function reloadAll() {
    if (selected === '') return;
    const id = Number(selected);
    const { from, to } = monthRangeFor(year, month);
    pa.fetchAttendance(id, from, to).then(setAtt);
    attSvc.fetchMonthSummary(id, year, month).then(setSummary).catch(() => setSummary(null));
    attSvc.fetchDutyShifts(id, from, to).then(setDutyShifts).catch(() => setDutyShifts([]));
    if (user?.employeeId) {
      attSvc.fetchMyWorkRequests().then(setMyRequests).catch(() => setMyRequests([]));
    } else {
      setMyRequests([]);
    }
  }

  useEffect(() => {
    reloadAll();
  }, [selected, year, month, filterDept]);

  function onMonthInputChange(value: string) {
    if (!value) return;
    const [y, m] = value.split('-').map(Number);
    if (y && m) setPeriod({ year: y, month: m });
  }

  async function sendAttendanceNotify() {
    setNotifyMsg(null);
    if (selected === '' || !isHrOrAdmin) return;
    try {
      await pa.notifyAttendanceMonth(Number(selected), year, month);
      setNotifyMsg(`Đã gửi thông báo bảng công tháng ${month}/${year}.`);
    } catch {
      setNotifyMsg('Không gửi được thông báo.');
    }
  }

  async function handleHolidayWorkSaved(savedYear: number, savedMonth: number, dates: string[]) {
    if (savedYear === year && savedMonth === month) {
      setHolidayDates(new Set(dates));
    }
    // Chỉ tính lại NV đang xem (nhanh). Toàn viện: bấm «Tính lại».
    if (selected === '') {
      setNotifyMsg(
        `Đã lưu ${dates.length} ngày lễ tháng ${savedMonth}/${savedYear}. Chọn nhân viên hoặc bấm «Tính lại» để áp dụng 2 công.`,
      );
      return;
    }
    setNotifyMsg(`Đã lưu ngày lễ. Đang tính lại công nhân viên đang xem…`);
    try {
      const r = await attSvc.recalculateEmployeeMonth(Number(selected), savedYear, savedMonth);
      if (savedYear === year && savedMonth === month) {
        reloadAll();
      }
      setNotifyMsg(
        `Đã lưu công lễ (${dates.length} ngày) — tính lại ${r.recalculated} ngày cho NV đang xem. Bấm «Tính lại» để áp dụng toàn viện.`,
      );
    } catch {
      setNotifyMsg('Đã lưu ngày lễ (đã bôi đậm). Bấm «Tính lại» để áp dụng 2 công.');
    }
  }

  async function handleRecalculate() {
    if (recalculating) return;
    setRecalculating(true);
    setNotifyMsg(null);
    try {
      const r = await attSvc.recalculateMonth(year, month);
      reloadAll();
      setNotifyMsg(`Đã tính lại ${r.recalculated} ngày công tháng ${month}/${year}.`);
    } catch {
      setNotifyMsg('Không tính lại được.');
    } finally {
      setRecalculating(false);
    }
  }

  async function handleExportReport() {
    if (!isHrOrAdmin) return;
    setExportingReport(true);
    setNotifyMsg(null);
    try {
      await attSvc.downloadMonthlyReport(year, month, filterDept === '' ? undefined : Number(filterDept));
      setNotifyMsg(`Đã xuất báo cáo công tháng ${month}/${year}.`);
    } catch {
      setNotifyMsg('Không xuất được báo cáo công.');
    } finally {
      setExportingReport(false);
    }
  }

  async function handleScheduleSaved() {
    const empId = selected !== '' ? Number(selected) : undefined;
    // Banner/lịch cập nhật ngay; tính lại công chạy nền (không chặn đóng dialog).
    reloadSchedule(empId, year, month);
    reloadAll();
    setNotifyMsg(`Đã lưu lịch ca tháng ${month}/${year}. Đang tính lại công…`);
    try {
      const r = await attSvc.recalculateMonth(year, month);
      reloadAll();
      setNotifyMsg(`Đã lưu lịch ca — tính lại ${r.recalculated} ngày công tháng ${month}/${year}.`);
    } catch {
      setNotifyMsg('Đã lưu lịch ca nhưng không tính lại được bảng công. Thử nút Tính lại công.');
    }
  }

  async function handleContinuousShiftChange(checked: boolean) {
    if (selected === '' || !isHrOrAdmin) return;
    setContinuousSaving(true);
    try {
      const result = await attSvc.setEmployeeContinuousShift(Number(selected), year, month, checked);
      setContinuousShift(checked);
      reloadSchedule(Number(selected), year, month);
      reloadAll();
      setNotifyMsg(
        result.recalculateWarning
          ? result.recalculateWarning
          : checked
            ? `Đã bật ca thông tầm tháng ${month}/${year} — tính lại ${result.recalculated} ngày.`
            : `Đã tắt ca thông tầm tháng ${month}/${year} — tính lại ${result.recalculated} ngày.`,
      );
    } catch {
      setNotifyMsg('Không cập nhật được ca thông tầm.');
    } finally {
      setContinuousSaving(false);
    }
  }

  async function handleYoungChildChange(checked: boolean) {
    if (selected === '' || !isHrOrAdmin) return;
    setYoungChildSaving(true);
    try {
      const result = await attSvc.setEmployeeYoungChild(Number(selected), year, month, checked);
      setYoungChild(checked);
      reloadSchedule(Number(selected), year, month);
      reloadAll();
      setNotifyMsg(
        result.recalculateWarning
          ? result.recalculateWarning
          : checked
            ? `Đã bật nuôi con nhỏ tháng ${month}/${year} (−1 giờ, tối thiểu 7h = 1 công) — tính lại ${result.recalculated} ngày.`
            : `Đã tắt nuôi con nhỏ tháng ${month}/${year} — tính lại ${result.recalculated} ngày.`,
      );
    } catch {
      setNotifyMsg('Không cập nhật được chế độ nuôi con nhỏ.');
    } finally {
      setYoungChildSaving(false);
    }
  }

  const employeeName = selectedEmployee?.fullName ?? user?.fullName ?? 'Nhân viên';

  /** Nhân viên chỉ gửi đơn trên hồ sơ của chính mình (backend gắn theo tài khoản đăng nhập). */
  const canActOnRows = Boolean(user?.employeeId && selected !== '' && Number(selected) === user.employeeId);

  function openDutyShift(date: string) {
    setDutyDate(date);
    setDutyOpen(true);
  }

  function openSupplement(date: string, tab?: 0 | 1 | 2) {
    setDutyDate(date);
    setSupplementInitialTab(tab);
    setSupplementOpen(true);
  }

  function openDeployment(date: string) {
    setDeploymentDate(date);
    setDeploymentOpen(true);
  }

  function closeDutyShift() {
    setDutyOpen(false);
    setDutyDate('');
  }

  function closeSupplement() {
    setSupplementOpen(false);
    setDutyDate('');
    setSupplementInitialTab(undefined);
  }

  function closeDeployment() {
    setDeploymentOpen(false);
    setDeploymentDate('');
  }

  function openExplain(date: string) {
    setDialogDate(date);
    setExplainRow(attByDate.get(date) ?? null);
    setExplainOpen(true);
  }

  function openUpdate(date: string) {
    setDialogDate(date);
    setUpdateRow(attByDate.get(date) ?? null);
    setUpdateOpen(true);
  }

  function closeExplain() {
    setExplainOpen(false);
    setDialogDate(undefined);
    setExplainRow(null);
  }

  function closeUpdate() {
    setUpdateOpen(false);
    setDialogDate(undefined);
    setUpdateRow(null);
  }

  function openDayDetail(workDate: string) {
    setDayDetailDate(workDate);
    setDayDetailRow(attByDate.get(workDate) ?? null);
    setDayDetailOpen(true);
  }

  return (
    <Box>
      <PageHeader
        overline="Công"
        title="Bảng công & chấm công"
        description="Theo dõi giờ làm, phạt muộn/sớm và quên chấm. Lịch ca tự đổi theo mùa hè/đông."
      />

      <AttendanceScheduleBanner
        schedule={schedule}
        canEdit={isHrOrAdmin}
        onEdit={() => setScheduleEditOpen(true)}
        canManageContinuous={isHrOrAdmin && selected !== ''}
        employeeName={selectedEmployee?.fullName}
        continuousShift={continuousShift}
        continuousSaving={continuousSaving}
        onContinuousShiftChange={handleContinuousShiftChange}
        youngChild={youngChild}
        youngChildSaving={youngChildSaving}
        onYoungChildChange={handleYoungChildChange}
        periodLabel={`tháng ${month}/${year}`}
      />

      {canPickEmployee && (
        <EmployeeFilterPanel
          qInput={qInput}
          onQInputChange={setQInput}
          filterDept={filterDept}
          onFilterDeptChange={setFilterDept}
          filterStatus={filterStatus}
          onFilterStatusChange={setFilterStatus}
          departments={departments}
          employees={employees}
          selected={selected}
          onSelectedChange={setSelected}
        />
      )}

      <Paper elevation={0} sx={paperSx}>
        <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
          <Stack spacing={2} sx={{ mb: 2.5 }}>
            <Stack direction="row" spacing={1.5} alignItems="center" flexWrap="wrap" useFlexGap>
              <MonthPickerField
                label="Tháng xem"
                value={`${year}-${String(month).padStart(2, '0')}`}
                onChange={onMonthInputChange}
                sx={{ minWidth: 220 }}
              />
            </Stack>

            {isHrOrAdmin && (
              <WorkAdminToolbar
                onImportSql={() => setImportOpen(true)}
                onSyncChamcong={() => setSyncOpen(true)}
                chamcongSyncEnabled={chamcongSyncEnabled}
                onExportReport={handleExportReport}
                exporting={exportingReport}
                onRecalculate={handleRecalculate}
                recalculating={recalculating}
                onForgotPenaltyConfig={() => setForgotPenaltyConfigOpen(true)}
                onLatePenaltyConfig={() => setLatePenaltyConfigOpen(true)}
                onHolidayWorkConfig={() => setHolidayWorkConfigOpen(true)}
                onNotify={sendAttendanceNotify}
                notifyDisabled={selected === ''}
              />
            )}
          </Stack>

          {recalculating && (
            <Paper
              variant="outlined"
              sx={{
                mb: 2,
                p: 1.75,
                borderRadius: 2,
                borderColor: (t) => alpha(t.palette.primary.main, 0.35),
                bgcolor: (t) => alpha(t.palette.primary.main, 0.04),
              }}
            >
              <Stack spacing={1}>
                <Typography variant="body2" fontWeight={600} color="primary.main">
                  Đang tính lại bảng công tháng {month}/{year}…
                </Typography>
                <LinearProgress sx={{ borderRadius: 1, height: 6 }} />
                <Typography variant="caption" color="text.secondary">
                  Vui lòng đợi — thanh sẽ tắt khi hoàn tất.
                </Typography>
              </Stack>
            </Paper>
          )}

          {notifyMsg && !recalculating && (
            <Alert severity="info" sx={{ mb: 2 }} onClose={() => setNotifyMsg(null)}>
              {notifyMsg}
            </Alert>
          )}

          {summary && (
                <Grid container spacing={2} sx={{ mb: 2.5 }}>
                  <Grid item xs={6} md={3}>
                    <StatCard
                      icon={<EventAvailableIcon />}
                      label="Tổng công tháng"
                      value={formatWorkUnits(summary.totalWorkUnits)}
                      sub={
                        Number(summary.dutyWorkUnitsTotal ?? 0) > 0
                          ? `${formatWorkUnits(summary.attendanceWorkUnits ?? 0)} chấm + ${formatWorkUnits(summary.dutyWorkUnitsTotal)} trực`
                          : undefined
                      }
                      accent={theme.palette.primary.main}
                    />
                  </Grid>
                  <Grid item xs={6} md={3}>
                    <StatCard
                      icon={<AccessTimeIcon />}
                      label="Phút muộn / về sớm"
                      value={String(summary.lateMinutesTotal)}
                      accent={theme.palette.warning.main}
                    />
                  </Grid>
                  <Grid item xs={6} md={3}>
                    <StatCard
                      icon={<GavelIcon />}
                      label="Trừ đi muộn"
                      value={attSvc.formatMoney(summary.latePenalty)}
                      sub={summary.latePenaltyTier}
                      accent={theme.palette.error.main}
                    />
                  </Grid>
                  <Grid item xs={6} md={3}>
                    <StatCard
                      icon={<WarningAmberIcon />}
                      label="Trừ quên chấm"
                      value={attSvc.formatMoney(summary.forgotPenalty)}
                      sub={`${summary.forgotFineCount} lần`}
                      accent={theme.palette.secondary.main}
                    />
                  </Grid>
                  <Grid item xs={6} md={3}>
                    <StatCard
                      icon={<NightsStayIcon />}
                      label="Tổng tiền trực"
                      value={attSvc.formatMoney(summary.dutyBonusTotal ?? 0)}
                      sub={`${summary.dutyShiftCount ?? 0} ca trực`}
                      accent={theme.palette.info.main}
                    />
                  </Grid>
                  <Grid item xs={6} md={3}>
                    <StatCard
                      icon={<EventAvailableIcon />}
                      label="Công sau trực"
                      value={
                        Number(summary.dutyWorkUnitsTotal ?? 0) > 0
                          ? `+${formatWorkUnits(summary.dutyWorkUnitsTotal)}`
                          : '0,00'
                      }
                      sub={`${summary.dutyShiftCount ?? 0} ca trực`}
                      accent={theme.palette.success.main}
                    />
                  </Grid>
                  <Grid item xs={6} md={3}>
                    <StatCard
                      icon={<RestaurantIcon />}
                      label="Phụ cấp phần ăn"
                      value={attSvc.formatMoney(summary.mealAllowance ?? 0)}
                      sub={mealAllowanceSub(summary)}
                      accent="#e65100"
                    />
                  </Grid>
                </Grid>
              )}

              {summary?.requiresDiscipline && (
                <Alert severity="warning" icon={<WarningAmberIcon />} sx={{ mb: 2 }}>
                  Tổng muộn/sớm &gt; 200 phút trong tháng — cần tự kiểm điểm theo quy định.
                </Alert>
              )}

              {canPickEmployee && selected !== '' && !canActOnRows && (
                <Alert severity="info" sx={{ mb: 2 }}>
                  Đang xem bảng công nhân viên khác — cột Thao tác hiện <strong>Cập nhật</strong> /{' '}
                  <strong>Giải trình</strong> (mờ) để tham khảo. Nhân viên cần đăng nhập tài khoản của mình để gửi
                  đơn.
                </Alert>
              )}

              <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 1.5 }}>
                Chi tiết từng ngày — {month}/{year}
              </Typography>
              <TableContainer
                sx={{
                  borderRadius: 2.5,
                  border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                }}
              >
                <Table size="small" sx={{ tableLayout: 'fixed', minWidth: continuousShift ? 940 : 880 }}>
                  <TableHead>
                    <TableRow sx={{ bgcolor: alpha(theme.palette.primary.main, 0.06) }}>
                      <TableCell sx={{ fontWeight: 700, width: 64, whiteSpace: 'nowrap', px: 1.5 }}>
                        Ngày
                      </TableCell>
                      {continuousShift ? (
                        <>
                          <TableCell align="center" sx={{ fontWeight: 700, width: 72 }}>
                            Vào
                          </TableCell>
                          <TableCell align="center" sx={{ fontWeight: 700, width: 72 }}>
                            Ra
                          </TableCell>
                          <TableCell align="center" sx={{ fontWeight: 700, width: 72 }}>
                            Giờ làm
                          </TableCell>
                        </>
                      ) : (
                        <>
                          <TableCell align="center" sx={{ fontWeight: 700, width: 88 }}>
                            Ca sáng
                          </TableCell>
                          <TableCell align="center" sx={{ fontWeight: 700, width: 88 }}>
                            Ca chiều
                          </TableCell>
                        </>
                      )}
                      <TableCell align="center" sx={{ fontWeight: 700, width: 88 }}>
                        Ngoài giờ
                      </TableCell>
                      <TableCell align="right" sx={{ fontWeight: 700, width: 64 }}>
                        Công
                      </TableCell>
                      <TableCell align="right" sx={{ fontWeight: 700, width: 88 }}>
                        Muộn/sớm
                      </TableCell>
                      <TableCell sx={{ fontWeight: 700, width: 168, minWidth: 168 }}>Trạng thái</TableCell>
                      <TableCell align="right" sx={{ fontWeight: 700, width: 168, whiteSpace: 'nowrap', px: 1.25 }}>
                        Thao tác
                      </TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {selected === '' && (
                      <TableRow>
                        <TableCell colSpan={continuousShift ? 9 : 8} align="center" sx={{ py: 5, color: 'text.secondary' }}>
                          Chọn nhân viên để xem bảng công tháng.
                        </TableCell>
                      </TableRow>
                    )}
                    {selected !== '' &&
                      monthDays.map(({ workDate, row }) => {
                        const st = row ? String(row.status ?? '') : '';
                        const chip = st ? STATUS_CHIP[st] : null;
                        const partialLabels = st === 'PARTIAL' && row ? attSvc.partialStatusLabels(row) : [];
                        const duty = dutyByDate.get(workDate);
                        const warnRow = canActOnRows && rowNeedsUpdate(row, workDate);
                        const noData = !row;
                        const isDeployment = attSvc.isDeploymentRow(row);
                        return (
                          <TableRow
                            key={workDate}
                            hover
                            sx={{
                              ...(warnRow ? { bgcolor: alpha(theme.palette.warning.main, 0.06) } : {}),
                              ...(noData && !warnRow ? { opacity: 0.72 } : {}),
                            }}
                          >
                            <TableCell
                              sx={{
                                fontWeight: holidayDates.has(workDate) ? 800 : 500,
                                color: holidayDates.has(workDate) ? 'warning.dark' : 'inherit',
                                whiteSpace: 'nowrap',
                                width: 64,
                                px: 1.5,
                                fontVariantNumeric: 'tabular-nums',
                              }}
                              title={holidayDates.has(workDate) ? 'Ngày lễ — đi làm = 2 công' : undefined}
                            >
                              {(parseLocalDate(workDate) ?? new Date()).toLocaleDateString('vi-VN', {
                                day: '2-digit',
                                month: '2-digit',
                              })}
                            </TableCell>
                            {continuousShift ? (
                              <>
                                <TableCell align="center" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                                  {formatPunchTime(row?.morningCheckIn as string | undefined)}
                                </TableCell>
                                <TableCell align="center" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                                  {formatPunchTime(row?.afternoonCheckOut as string | undefined)}
                                </TableCell>
                                <TableCell align="center">{continuousHoursLabel(row, schedule)}</TableCell>
                              </>
                            ) : (
                              <>
                                <TableCell align="center">{shiftHoursLabel(row, schedule, 'morning')}</TableCell>
                                <TableCell align="center">{shiftHoursLabel(row, schedule, 'afternoon')}</TableCell>
                              </>
                            )}
                            <TableCell align="center">{overtimeHoursLabel(row, schedule, continuousShift)}</TableCell>
                            <TableCell align="right" sx={{ fontWeight: 600 }}>
                              {(() => {
                                const attUnits = row ? normalizeWorkUnits(Number(row.totalWorkUnits ?? 0)) : 0;
                                const dutyUnits = duty ? normalizeWorkUnits(Number(duty.workUnits ?? 0)) : 0;
                                const total = normalizeWorkUnits(attUnits + dutyUnits);
                                if (!row && !duty) return '—';
                                if (dutyUnits > 0 && attUnits > 0) {
                                  return (
                                    <Tooltip
                                      title={`${formatWorkUnits(attUnits)} chấm công + ${formatWorkUnits(dutyUnits)} ca trực`}
                                    >
                                      <Typography component="span" variant="body2" fontWeight={600}>
                                        {formatWorkUnits(total)}
                                      </Typography>
                                    </Tooltip>
                                  );
                                }
                                return formatWorkUnits(total);
                              })()}
                            </TableCell>
                            <TableCell align="right">
                              {!row ? (
                                '—'
                              ) : row.lateMinutesExempt ? (
                                <Chip size="small" label="Miễn" color="success" variant="outlined" />
                              ) : (
                                `${String(row.lateMinutes ?? 0)} phút`
                              )}
                            </TableCell>
                            <TableCell sx={{ py: 0.75, width: 168, minWidth: 168, verticalAlign: 'middle' }}>
                              <Stack
                                direction="row"
                                spacing={0.5}
                                useFlexGap
                                alignItems="center"
                                flexWrap="nowrap"
                                sx={{ overflow: 'visible' }}
                              >
                                {!row ? (
                                  <Chip size="small" label="Chưa có" variant="outlined" sx={statusChipSx} />
                                ) : st === 'PARTIAL' ? (
                                  partialLabels.length > 0 ? (
                                    <Tooltip title={partialLabels.join(' · ')}>
                                      <Chip
                                        size="small"
                                        label={partialLabels.join(' · ')}
                                        color={
                                          partialLabels.length === 1 && partialLabels[0] === 'Ngoài giờ'
                                            ? 'info'
                                            : 'warning'
                                        }
                                        variant="outlined"
                                        sx={statusChipSx}
                                      />
                                    </Tooltip>
                                  ) : (
                                    <Chip
                                      size="small"
                                      label="Thiếu ca"
                                      color="warning"
                                      variant="outlined"
                                      sx={statusChipSx}
                                    />
                                  )
                                ) : chip ? (
                                  <Chip
                                    size="small"
                                    label={chip.label}
                                    color={chip.color}
                                    variant="outlined"
                                    sx={statusChipSx}
                                  />
                                ) : (
                                  <Typography variant="body2">{st}</Typography>
                                )}
                                {isDeployment && (
                                  <Tooltip title="Có đơn điều động trong ngày">
                                    <Chip
                                      size="small"
                                      icon={<SwapHorizOutlinedIcon />}
                                      label="Đ.động"
                                      color="info"
                                      variant="outlined"
                                      sx={{
                                        ...statusChipSx,
                                        bgcolor: alpha(theme.palette.info.main, 0.08),
                                        borderColor: alpha(theme.palette.info.main, 0.45),
                                        color: 'info.dark',
                                      }}
                                    />
                                  </Tooltip>
                                )}
                                {duty && (
                                  <Tooltip title={duty.shiftTypeLabel}>
                                    <Chip
                                      size="small"
                                      icon={<NightsStayIcon />}
                                      label="Trực"
                                      color="secondary"
                                      variant="outlined"
                                      sx={statusChipSx}
                                    />
                                  </Tooltip>
                                )}
                                {attSvc.isQuangTrungRow(row) && (
                                  <Tooltip title="Công Quang Trung — mở để sửa hoặc xóa">
                                    <Chip
                                      size="small"
                                      icon={<LocationOnOutlinedIcon />}
                                      label="QT"
                                      color="success"
                                      variant="outlined"
                                      onClick={
                                        canManageSupplement ? () => openSupplement(workDate, 1) : undefined
                                      }
                                      sx={{
                                        ...statusChipSx,
                                        ...(canManageSupplement ? { cursor: 'pointer' } : {}),
                                      }}
                                    />
                                  </Tooltip>
                                )}
                                {attSvc.isCongHoRow(row) && (
                                  <Tooltip title="Công hộ — mở để sửa hoặc xóa">
                                    <Chip
                                      size="small"
                                      icon={<HowToRegOutlinedIcon />}
                                      label="Hộ"
                                      color="info"
                                      variant="outlined"
                                      onClick={
                                        canManageSupplement ? () => openSupplement(workDate, 2) : undefined
                                      }
                                      sx={{
                                        ...statusChipSx,
                                        ...(canManageSupplement ? { cursor: 'pointer' } : {}),
                                      }}
                                    />
                                  </Tooltip>
                                )}
                              </Stack>
                            </TableCell>
                            <TableCell align="right" sx={{ py: 0.5, px: 1.25, whiteSpace: 'nowrap', width: 168 }}>
                              <AttendanceRowActions
                                row={row}
                                workDate={workDate}
                                requests={myRequests}
                                canSubmit={canActOnRows}
                                canManageSupplement={canManageSupplement}
                                canManageDuty={canManageDutyOnly}
                                canCreateDeployment={canCreateDeployment}
                                hasDutyShift={Boolean(duty)}
                                onDetail={openDayDetail}
                                onExplain={openExplain}
                                onUpdate={openUpdate}
                                onSupplement={openSupplement}
                                onDutyShift={openDutyShift}
                                onDeployment={openDeployment}
                              />
                            </TableCell>
                          </TableRow>
                        );
                      })}
                  </TableBody>
                </Table>
              </TableContainer>
        </Box>
      </Paper>

      <CheckInOutImportDialog open={importOpen} onClose={() => setImportOpen(false)} onImported={reloadAll} />
      <CheckInOutSyncDialog
        open={syncOpen}
        onClose={() => setSyncOpen(false)}
        defaultFromDate={`${year}-${String(month).padStart(2, '0')}-01`}
        onSynced={(msg) => {
          setNotifyMsg(msg);
          reloadAll();
        }}
      />
      <AttendanceUpdateRequestDialog
        open={updateOpen}
        onClose={closeUpdate}
        onSubmitted={reloadAll}
        defaultDate={dialogDate}
        attendanceRow={updateRow}
      />
      <AttendanceExplanationDialog
        open={explainOpen}
        onClose={closeExplain}
        onSubmitted={reloadAll}
        defaultDate={dialogDate}
        attendanceRow={explainRow}
        continuousShift={continuousShift}
      />
      {dayDetailOpen && dayDetailDate && (
        <AttendanceDayDetailDialog
          open={dayDetailOpen}
          onClose={() => setDayDetailOpen(false)}
          workDate={dayDetailDate}
          row={dayDetailRow}
          employeeName={employeeName}
          monthSummary={summary}
          schedule={schedule}
          continuousShift={continuousShift}
        />
      )}
      <AttendanceScheduleEditDialog
        open={scheduleEditOpen}
        onClose={() => setScheduleEditOpen(false)}
        onSaved={handleScheduleSaved}
        continuousShift={continuousShift}
        employeeName={continuousShift ? employeeName : undefined}
      />
      <ForgotPenaltyConfigDialog
        open={forgotPenaltyConfigOpen}
        onClose={() => setForgotPenaltyConfigOpen(false)}
        onSaved={reloadAll}
      />
      <LatePenaltyConfigDialog
        open={latePenaltyConfigOpen}
        onClose={() => setLatePenaltyConfigOpen(false)}
        onSaved={reloadAll}
      />
      <HolidayWorkConfigDialog
        open={holidayWorkConfigOpen}
        onClose={() => setHolidayWorkConfigOpen(false)}
        initialYear={year}
        initialMonth={month}
        onSaved={handleHolidayWorkSaved}
      />
      {canManageSupplement && supplementOpen && dutyDate && selected !== '' && (
        <WorkSupplementDialog
          open={supplementOpen}
          onClose={closeSupplement}
          onSaved={reloadAll}
          employeeId={Number(selected)}
          employeeName={employeeName}
          workDate={dutyDate}
          existingDuty={dutyByDate.get(dutyDate) ?? null}
          attendanceRow={attByDate.get(dutyDate) ?? null}
          initialTab={supplementInitialTab}
        />
      )}
      {canManageDutyOnly && dutyOpen && dutyDate && selected !== '' && (
        <DutyShiftDialog
          open={dutyOpen}
          onClose={closeDutyShift}
          onSaved={reloadAll}
          employeeId={Number(selected)}
          employeeName={employeeName}
          workDate={dutyDate}
          existing={dutyByDate.get(dutyDate) ?? null}
        />
      )}
      {canCreateDeployment && deploymentOpen && deploymentDate && selected !== '' && (
        <DeploymentRequestDialog
          open={deploymentOpen}
          onClose={closeDeployment}
          onSubmitted={() => {
            setNotifyMsg('Đã tạo đơn điều động và gửi thông báo cho nhân viên.');
            reloadAll();
          }}
          employeeId={Number(selected)}
          employeeName={employeeName}
          workDate={deploymentDate}
          periodYear={year}
          periodMonth={month}
          schedule={schedule}
          getDayStatus={(d) => {
            const row = attByDate.get(d);
            return row ? String(row.status ?? '') : null;
          }}
        />
      )}
    </Box>
  );
}

function mealAllowanceSub(summary: attSvc.MonthSummary): string {
  const present = summary.mealAllowancePresentDays ?? 0;
  const morning = summary.mealAllowanceMorningDays ?? 0;
  const duty = summary.mealAllowanceDutyUnits ?? 0;
  const parts: string[] = [];
  if (present > 0) parts.push(`${present} đủ công`);
  if (morning > 0) parts.push(`${morning} sáng`);
  if (duty > 0) parts.push(`${duty / 2} trực ×2`);
  return parts.length > 0 ? parts.join(' + ') : '0 suất × 20k';
}

function StatCard({
  icon,
  label,
  value,
  sub,
  accent,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  sub?: string;
  accent: string;
}) {
  return (
    <Paper
      elevation={0}
      sx={{
        p: 2,
        height: '100%',
        borderRadius: 2.5,
        border: `1px solid ${alpha(accent, 0.18)}`,
        bgcolor: alpha(accent, 0.04),
        transition: 'transform 0.2s, box-shadow 0.2s',
        '&:hover': {
          transform: 'translateY(-2px)',
          boxShadow: `0 8px 24px ${alpha(accent, 0.12)}`,
        },
      }}
    >
      <Stack direction="row" spacing={1.5} alignItems="flex-start">
        <Box sx={{ color: accent, mt: 0.25 }}>{icon}</Box>
        <Box sx={{ minWidth: 0 }}>
          <Typography variant="caption" color="text.secondary" display="block">
            {label}
          </Typography>
          <Typography variant="h6" fontWeight={700} sx={{ lineHeight: 1.2 }}>
            {value}
          </Typography>
          {sub && (
            <Typography variant="caption" color="text.secondary">
              {sub}
            </Typography>
          )}
        </Box>
      </Stack>
    </Paper>
  );
}
