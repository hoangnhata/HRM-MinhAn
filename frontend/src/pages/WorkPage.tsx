import AccessTimeIcon from '@mui/icons-material/AccessTime';
import EventAvailableIcon from '@mui/icons-material/EventAvailable';
import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import GavelIcon from '@mui/icons-material/Gavel';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import LocalHospitalOutlinedIcon from '@mui/icons-material/LocalHospitalOutlined';
import HowToRegOutlinedIcon from '@mui/icons-material/HowToRegOutlined';
import GroupAddOutlinedIcon from '@mui/icons-material/GroupAddOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined';
import RestaurantIcon from '@mui/icons-material/Restaurant';
import SwapHorizOutlinedIcon from '@mui/icons-material/SwapHorizOutlined';
import TableChartOutlinedIcon from '@mui/icons-material/TableChartOutlined';
import WarningAmberIcon from '@mui/icons-material/WarningAmber';
import {
  Alert,
  Box,
  Button,
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
import { useEffect, useMemo, useRef, useState } from 'react';
import { useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { AttendanceExplanationDialog } from '../components/AttendanceExplanationDialog';
import { AttendanceUpdateRequestDialog } from '../components/AttendanceUpdateRequestDialog';
import { CheckInOutImportDialog } from '../components/CheckInOutImportDialog';
import { CheckInOutSyncDialog } from '../components/CheckInOutSyncDialog';
import { EmployeeFilterPanel, employeeStatusQuery } from '../components/EmployeeFilterPanel';
import { PageHeader } from '../components/layout/PageHeader';
import { AttendanceDayDetailDialog } from '../components/work/AttendanceDayDetailDialog';
import { AttendanceRowActions, rowNeedsUpdate } from '../components/work/AttendanceRowActions';
import { AttendanceScheduleBanner } from '../components/work/AttendanceScheduleBanner';
import { AttendanceScheduleEditDialog } from '../components/work/AttendanceScheduleEditDialog';
import { DeploymentRequestDialog } from '../components/DeploymentRequestDialog';
import { DepartmentAttendanceMatrixDialog } from '../components/work/DepartmentAttendanceMatrixDialog';
import { DutyShiftDialog } from '../components/work/DutyShiftDialog';
import { BulkWorkSupplementDialog } from '../components/work/BulkWorkSupplementDialog';
import { BulkDeploymentDialog } from '../components/work/BulkDeploymentDialog';
import { WorkSupplementDialog } from '../components/work/WorkSupplementDialog';
import { ForgotPenaltyConfigDialog } from '../components/work/ForgotPenaltyConfigDialog';
import { HolidayWorkConfigDialog } from '../components/work/HolidayWorkConfigDialog';
import { ContinuousShiftConfigDialog } from '../components/work/ContinuousShiftConfigDialog';
import { ContinuousShiftTypeDialog } from '../components/work/ContinuousShiftTypeDialog';
import { LatePenaltyConfigDialog } from '../components/work/LatePenaltyConfigDialog';
import { WorkAdminToolbar } from '../components/work/WorkAdminToolbar';
import { YoungChildProposeDialog } from '../components/YoungChildProposeDialog';
import { ShiftConfigChangeProposeDialog } from '../components/ShiftConfigChangeProposeDialog';
import { MonthPickerField } from '../components/ui/DateTimeFields';
import { useAuth } from '../context/AuthContext';
import * as attSvc from '../services/attendanceService';
import * as youngChildReq from '../services/youngChildRequestService';
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
import { isHeadDepartmentRole, isHr2Role } from '../utils/roleAccess';
import { isNursingBlockTitle } from '../utils/nursingBlock';

const STATUS_CHIP: Record<string, { label: string; color: 'success' | 'warning' | 'default' | 'error' | 'info' }> = {
  PRESENT: { label: 'Đủ công', color: 'success' },
  PARTIAL: { label: 'Thiếu ca', color: 'warning' },
  ABSENT: { label: 'Vắng', color: 'error' },
  LEAVE: { label: 'Phép', color: 'info' },
  UNPAID_LEAVE: { label: 'Không lương', color: 'default' },
  BUSINESS_TRIP: { label: 'Công tác', color: 'warning' },
  SEMINAR: { label: 'Hội thảo', color: 'info' },
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
  const location = useLocation();
  const selfOnly = location.pathname === '/work/me' || location.pathname.endsWith('/work/me');
  const isHrOrAdmin = user?.role === 'ADMIN' || user?.role === 'HR';
  const isHr2Viewer = isHr2Role(user?.role);
  const isNursingHead = user?.role === 'HEAD_NURSING';
  const isHeadRole = isHeadDepartmentRole(user?.role);
  const isHead = user?.role === 'ADMIN' || isHeadRole || isNursingHead;
  const canPickEmployee = !selfOnly && (isHrOrAdmin || isHr2Viewer || isHead);
  const ownDepartmentId = user?.departmentId ?? null;
  const deptFilterLocked = isHeadRole && !isHrOrAdmin && !isHr2Viewer && !isNursingHead && ownDepartmentId != null;
  const ownWorkUnitDetail = user?.workUnitScoped ? (user.workUnitDetail?.trim() || undefined) : undefined;

  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [employees, setEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [selected, setSelected] = useState<number | ''>('');
  /** Trưởng phòng ĐD chỉ xem — không bổ sung công / điều động / cấu hình ca. */
  const canManageSupplement = (user?.role === 'ADMIN' || isHeadRole) && selected !== '' && !isNursingHead;
  const canManageDutyOnly = false;
  const canCreateDeployment = (isHeadRole || user?.role === 'ADMIN') && selected !== '' && !isNursingHead;
  const [qInput, setQInput] = useState('');
  const [q, setQ] = useState('');
  const [filterDept, setFilterDept] = useState<number | ''>('');
  const [filterStatus, setFilterStatus] = useState('WORKING');
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
  const [explainInitialKeys, setExplainInitialKeys] = useState<
    attSvc.ExplanationSlotKey[] | undefined
  >();
  const [dayDetailOpen, setDayDetailOpen] = useState(false);
  const [dayDetailDate, setDayDetailDate] = useState('');
  const [dayDetailRow, setDayDetailRow] = useState<Record<string, unknown> | null>(null);
  const [schedule, setSchedule] = useState<ShiftScheduleInfo>(() => scheduleForDate());
  const [scheduleEditOpen, setScheduleEditOpen] = useState(false);
  const [scheduleEditContinuous, setScheduleEditContinuous] = useState(false);
  const [forgotPenaltyConfigOpen, setForgotPenaltyConfigOpen] = useState(false);
  const [latePenaltyConfigOpen, setLatePenaltyConfigOpen] = useState(false);
  const [holidayWorkConfigOpen, setHolidayWorkConfigOpen] = useState(false);
  const [holidayDates, setHolidayDates] = useState<Set<string>>(() => new Set());
  const [continuousShift, setContinuousShift] = useState(false);
  const [continuousDates, setContinuousDates] = useState<Set<string>>(() => new Set());
  const [splitDates, setSplitDates] = useState<Set<string>>(() => new Set());
  const [continuousConfigOpen, setContinuousConfigOpen] = useState(false);
  const [continuousTypeOpen, setContinuousTypeOpen] = useState(false);
  const [continuousTypes, setContinuousTypes] = useState<attSvc.ContinuousShiftType[]>([]);
  const [youngChild, setYoungChild] = useState(false);
  const [youngChildSaving, setYoungChildSaving] = useState(false);
  const [youngChildPending, setYoungChildPending] = useState(false);
  const [youngChildProposeOpen, setYoungChildProposeOpen] = useState(false);
  const [shiftConfigProposeOpen, setShiftConfigProposeOpen] = useState(false);
  const [dutyShifts, setDutyShifts] = useState<attSvc.DutyShiftEntry[]>([]);
  const [dutyOpen, setDutyOpen] = useState(false);
  const [supplementOpen, setSupplementOpen] = useState(false);
  const [bulkSupplementOpen, setBulkSupplementOpen] = useState(false);
  const [bulkDeploymentOpen, setBulkDeploymentOpen] = useState(false);
  const [deploymentOpen, setDeploymentOpen] = useState(false);
  const [dutyDate, setDutyDate] = useState('');
  const [deploymentDate, setDeploymentDate] = useState('');
  const [supplementInitialTab, setSupplementInitialTab] = useState<0 | 1 | 2 | undefined>(undefined);
  const [matrixOpen, setMatrixOpen] = useState(false);
  const pendingSelectRef = useRef<number | null>(null);

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
    const today = new Date();
    const isCurrentMonth = today.getFullYear() === periodYear && today.getMonth() + 1 === periodMonth;
    const refDate = isCurrentMonth
      ? `${periodYear}-${String(periodMonth).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
      : `${periodYear}-${String(periodMonth).padStart(2, '0')}-15`;
    attSvc
      .fetchShiftSchedule(refDate, id)
      .then((s) => {
        setSchedule(s);
        setYoungChild(Boolean(s.youngChild));
      })
      .catch(() => setSchedule(scheduleForDate(refDate)));
    if (id != null && (isHrOrAdmin || isHeadRole)) {
      youngChildReq
        .fetchPendingYoungChildForEmployee(
          id,
          `${periodYear}-${String(periodMonth).padStart(2, '0')}-01`,
          new Date(Date.UTC(periodYear, periodMonth, 0)).toISOString().slice(0, 10),
        )
        .then((p) => setYoungChildPending(Boolean(p?.id)))
        .catch(() => setYoungChildPending(false));
    } else {
      setYoungChildPending(false);
    }
  }

  function reloadContinuousDates(employeeId?: number, periodYear = year, periodMonth = month) {
    const id =
      employeeId ??
      (selected !== '' ? Number(selected) : user?.employeeId != null ? user.employeeId : undefined);
    if (id == null) {
      setContinuousDates(new Set());
      setSplitDates(new Set());
      setContinuousShift(false);
      return;
    }
    attSvc
      .fetchEmployeeContinuousShiftDays(id, periodYear, periodMonth)
      .then((r) => {
        const continuous = new Set(
          r.continuousDates
            ?? (r.days ?? [])
              .filter((d) => d.kind !== 'SPLIT')
              .map((d) => d.date),
        );
        const split = new Set(
          r.splitDates
            ?? (r.days ?? [])
              .filter((d) => d.kind === 'SPLIT')
              .map((d) => d.date),
        );
        // Fallback cũ: API chưa trả kind → coi toàn bộ dates là thông tầm
        if (continuous.size === 0 && split.size === 0 && (r.dates?.length ?? 0) > 0) {
          r.dates.forEach((d) => continuous.add(d));
        }
        setContinuousDates(continuous);
        setSplitDates(split);
        setContinuousShift(continuous.size > 0);
      })
      .catch(() => {
        setContinuousDates(new Set());
        setSplitDates(new Set());
        setContinuousShift(false);
      });
  }

  useEffect(() => {
    reloadSchedule();
    reloadContinuousDates();
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
    attSvc.fetchContinuousShiftTypes(true)
      .then(setContinuousTypes)
      .catch(() => setContinuousTypes([]));
  }, []);

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
    if (!canPickEmployee) return;
    let cancelled = false;
    void (async () => {
      let rows: employeeService.DepartmentOption[] = [];
      try {
        rows = await employeeService.fetchDepartments();
      } catch {
        // HCNS2 / Trưởng phòng ĐD có nguồn dự phòng bên dưới.
      }

      // Không khóa HCNS2 theo phòng ban trong hồ sơ. Nếu API danh mục cũ trả rỗng,
      // dựng danh sách khoa/phòng từ chính dữ liệu công toàn viện được HR2 phép xem.
      if (rows.length === 0 && isHr2Viewer) {
        try {
          const matrix = await attSvc.fetchAttendanceMonthMatrix(year, month);
          const unique = new Map<number, employeeService.DepartmentOption>();
          matrix.rows.forEach((row) => {
            if (row.departmentId != null && row.department?.trim()) {
              unique.set(row.departmentId, {
                id: row.departmentId,
                code: `DEPT-${row.departmentId}`,
                name: row.department.trim(),
              });
            }
          });
          rows = [...unique.values()].sort((a, b) => a.name.localeCompare(b.name, 'vi'));
        } catch {
          // Lỗi tải ma trận sẽ được hiển thị trong cửa sổ bảng công khi người dùng mở.
        }
      }

      if (rows.length === 0 && isNursingHead) {
        try {
          const stats = await employeeService.fetchNursingDashboardStats();
          rows = (stats.byDepartment ?? [])
            .filter((d) => d.departmentId != null && d.departmentName?.trim())
            .map((d) => ({
              id: Number(d.departmentId),
              code: `DEPT-${d.departmentId}`,
              name: d.departmentName.trim(),
            }))
            .sort((a, b) => a.name.localeCompare(b.name, 'vi'));
        } catch {
          // Giữ danh sách rỗng; người dùng vẫn lọc được bằng tìm kiếm tên.
        }
      }

      if (!cancelled) setDepartments(rows);
    })();
    return () => {
      cancelled = true;
    };
  }, [canPickEmployee, isHr2Viewer, isNursingHead, year, month]);

  useEffect(() => {
    if (deptFilterLocked && ownDepartmentId != null) {
      setFilterDept(ownDepartmentId);
    }
  }, [deptFilterLocked, ownDepartmentId]);

  useEffect(() => {
    if (!canPickEmployee) return;
    let cancelled = false;
    (async () => {
      const p = await employeeService.fetchEmployees({
        page: 0,
        size: 1000,
        q: q.trim() || undefined,
        departmentId: filterDept === '' ? undefined : filterDept,
        workUnit: ownWorkUnitDetail,
        ...employeeStatusQuery(filterStatus),
      });
      if (cancelled) return;
      setEmployees(p.content);
      if (p.content.length === 0) {
        pendingSelectRef.current = null;
        setSelected('');
        return;
      }
      setSelected((prev) => {
        const pending = pendingSelectRef.current;
        if (pending != null && p.content.some((e) => e.id === pending)) {
          pendingSelectRef.current = null;
          return pending;
        }
        return prev !== '' && p.content.some((e) => e.id === prev) ? prev : p.content[0].id;
      });
    })();
    return () => {
      cancelled = true;
    };
  }, [canPickEmployee, q, filterDept, filterStatus, ownWorkUnitDetail]);

  useEffect(() => {
    if (canPickEmployee) return;
    if (user?.employeeId) setSelected(user.employeeId);
  }, [user, canPickEmployee]);

  // Nhân viên / Giám đốc vào /work → chuyển sang Công của tôi
  useEffect(() => {
    if (selfOnly) return;
    const role = user?.role;
    if (role === 'EMPLOYEE' || role === 'DIRECTOR') {
      navigate('/work/me', { replace: true });
    }
  }, [selfOnly, user?.role, navigate]);

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

  // Tự làm mới bảng công khi đang xem (backend đồng bộ theo chu kỳ)
  useEffect(() => {
    if (selected === '') return;
    const REFRESH_MS = 30_000;
    const tick = () => {
      if (document.visibilityState !== 'visible') return;
      reloadAll();
    };
    const id = window.setInterval(tick, REFRESH_MS);
    const onVis = () => {
      if (document.visibilityState === 'visible') reloadAll();
    };
    document.addEventListener('visibilitychange', onVis);
    return () => {
      window.clearInterval(id);
      document.removeEventListener('visibilitychange', onVis);
    };
  }, [selected, year, month, filterDept]);

  function onMonthInputChange(value: string) {
    if (!value) return;
    const [y, m] = value.split('-').map(Number);
    if (y && m) setPeriod({ year: y, month: m });
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
    if (!isHrOrAdmin && !isHeadRole) return;
    setExportingReport(true);
    setNotifyMsg(null);
    try {
      const departmentId =
        isHeadRole && !isHrOrAdmin
          ? ownDepartmentId ?? undefined
          : filterDept === ''
            ? undefined
            : Number(filterDept);
      await attSvc.downloadMonthlyReport(year, month, departmentId);
      setNotifyMsg(
        isHeadRole && !isHrOrAdmin
          ? `Đã xuất báo cáo công khoa của bạn tháng ${month}/${year}.`
          : `Đã xuất báo cáo công tháng ${month}/${year}.`,
      );
    } catch {
      setNotifyMsg('Không xuất được báo cáo công.');
    } finally {
      setExportingReport(false);
    }
  }

  async function handleScheduleSaved(scope: 'employee' | 'all') {
    const empId = selected !== '' ? Number(selected) : undefined;
    // Banner/lịch cập nhật ngay; tính lại công chạy nền (không chặn đóng dialog).
    reloadSchedule(empId, year, month);
    reloadAll();
    setNotifyMsg(`Đã lưu lịch ca tháng ${month}/${year}. Đang tính lại công…`);
    try {
      const r = scope === 'all' || empId == null
        ? await attSvc.recalculateMonth(year, month)
        : await attSvc.recalculateEmployeeMonth(empId, year, month);
      reloadAll();
      setNotifyMsg(`Đã lưu lịch ca — tính lại ${r.recalculated} ngày công tháng ${month}/${year}.`);
    } catch {
      setNotifyMsg('Đã lưu lịch ca nhưng không tính lại được bảng công. Thử nút Tính lại công.');
    }
  }

  async function handleContinuousShiftSaved(dates: string[], recalculated: number, warning?: string) {
    // Tải lại phân loại thông tầm / sáng–chiều từ API
    reloadContinuousDates();
    reloadSchedule();
    reloadAll();
    setNotifyMsg(
      warning
        ? warning
        : `Đã lưu ${dates.length} ngày xếp ca tháng ${month}/${year} — tính lại ${recalculated} ngày.`,
    );
  }

  async function handleYoungChildChange(checked: boolean) {
    if (selected === '' || user?.role !== 'ADMIN') return;
    const now = new Date();
    const effectiveDate = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    setYoungChildSaving(true);
    try {
      const result = await attSvc.setEmployeeYoungChild(Number(selected), effectiveDate, checked);
      setYoungChild(checked);
      reloadSchedule(Number(selected), year, month);
      reloadAll();
      setNotifyMsg(
        result.recalculateWarning ||
          (checked
            ? `Đã bật chế độ nuôi con nhỏ từ ${effectiveDate}; chế độ duy trì đến khi ADMIN tắt.`
            : `Đã tắt chế độ nuôi con nhỏ từ ${effectiveDate}.`),
      );
    } catch {
      setNotifyMsg('Không cập nhật được chế độ nuôi con nhỏ.');
    } finally {
      setYoungChildSaving(false);
    }
  }

  const employeeName = selectedEmployee?.fullName ?? user?.fullName ?? 'Nhân viên';

  /** Nhân viên gửi cho mình; ADMIN có thể tạo giải trình cho nhân viên đang chọn. */
  const canActOnRows = Boolean(user?.employeeId && selected !== '' && Number(selected) === user.employeeId);
  const canExplainSelected =
    selected !== '' &&
    (user?.role === 'ADMIN' || canActOnRows);

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

  function openExplain(date: string, selectedKeys?: attSvc.ExplanationSlotKey[]) {
    setDialogDate(date);
    setExplainRow(attByDate.get(date) ?? null);
    setExplainInitialKeys(selectedKeys);
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
    setExplainInitialKeys(undefined);
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

  function openEmployeeFromMatrix(employeeId: number, departmentId?: number | null) {
    pendingSelectRef.current = employeeId;
    setQInput('');
    setQ('');
    setFilterStatus('WORKING');
    if (!deptFilterLocked && departmentId != null) {
      setFilterDept(departmentId);
    }
    setSelected(employeeId);
    setMatrixOpen(false);
    setNotifyMsg('Đã chuyển sang bảng công chi tiết của nhân viên đã chọn.');
  }

  return (
    <Box>
      <PageHeader
        overline="Công"
        title={selfOnly ? 'Công của tôi' : 'Bảng công & chấm công'}
        description={
          selfOnly
            ? 'Xem bảng công cá nhân theo tháng — không cần tìm tên trong danh sách.'
            : 'Theo dõi giờ làm, phạt muộn/sớm và quên chấm. Lịch ca tự đổi theo mùa hè/đông.'
        }
        actions={
          canPickEmployee ? (
            <Button
              variant="contained"
              color="primary"
              startIcon={<TableChartOutlinedIcon />}
              onClick={() => setMatrixOpen(true)}
              sx={{
                textTransform: 'none',
                fontWeight: 700,
                borderRadius: 2,
                px: 2.25,
                py: 1,
                boxShadow: 'none',
                whiteSpace: 'nowrap',
              }}
            >
              Bảng công theo khoa
            </Button>
          ) : undefined
        }
      />

      <AttendanceScheduleBanner
        schedule={schedule}
        canEdit={isHrOrAdmin}
        onEdit={() => {
          setScheduleEditContinuous(false);
          setScheduleEditOpen(true);
        }}
        onEditContinuous={
          isHrOrAdmin
            ? () => {
                setContinuousTypeOpen(true);
              }
            : undefined
        }
        canManageContinuous={(user?.role === 'ADMIN' || isHeadRole) && selected !== ''}
        employeeName={selectedEmployee?.fullName}
        continuousShift={continuousShift}
        continuousDayCount={continuousDates.size}
        onConfigureContinuousShift={
          user?.role === 'ADMIN' || isHeadRole
            ? () => setContinuousConfigOpen(true)
            : undefined
        }
        youngChild={youngChild}
        youngChildSaving={youngChildSaving}
        youngChildPending={youngChildPending}
        onYoungChildChange={user?.role === 'ADMIN' ? handleYoungChildChange : undefined}
        canProposeYoungChild={(user?.role === 'ADMIN' || (isHeadRole && !isHrOrAdmin)) && selected !== ''}
        onProposeYoungChild={() => setYoungChildProposeOpen(true)}
        canProposeShiftConfigChange={isHeadRole && !isHrOrAdmin && selected !== ''}
        onProposeShiftConfigChange={() => setShiftConfigProposeOpen(true)}
        periodLabel={`tháng ${month}/${year}`}
        continuousTypes={continuousTypes}
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
          deptFilterLocked={deptFilterLocked}
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
                onBulkSupplement={user?.role === 'ADMIN' ? () => setBulkSupplementOpen(true) : undefined}
                onBulkDeployment={user?.role === 'ADMIN' ? () => setBulkDeploymentOpen(true) : undefined}
              />
            )}
            {isHeadRole && (
              <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                <Button
                  variant="outlined"
                  startIcon={<FileDownloadOutlinedIcon />}
                  onClick={handleExportReport}
                  disabled={exportingReport}
                  sx={{ borderRadius: 2, fontWeight: 700 }}
                >
                  {exportingReport ? 'Đang xuất…' : 'Xuất Excel khoa'}
                </Button>
                <Button
                  variant="outlined"
                  startIcon={<GroupAddOutlinedIcon />}
                  onClick={() => setBulkSupplementOpen(true)}
                  sx={{ borderRadius: 2, fontWeight: 700 }}
                >
                  Bổ sung hàng loạt
                </Button>
                <Button
                  variant="outlined"
                  startIcon={<SwapHorizOutlinedIcon />}
                  onClick={() => setBulkDeploymentOpen(true)}
                  sx={{ borderRadius: 2, fontWeight: 700 }}
                >
                  Điều động hàng loạt
                </Button>
              </Stack>
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
                      sub={`${formatWorkUnits(summary.clockedWorkUnits ?? summary.attendanceWorkUnits ?? 0)} chấm + ${formatWorkUnits(summary.leaveWorkUnits ?? 0)} phép + ${formatWorkUnits(summary.dutyWorkUnitsTotal ?? 0)} trực`}
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
                  <Grid item xs={6} md={3}>
                    <StatCard
                      icon={<PaymentsOutlinedIcon />}
                      label="Tiền hỗ trợ"
                      value={attSvc.formatMoney(summary.seminarSupportTotal ?? 0)}
                      sub={
                        Number(summary.seminarSupportCount ?? 0) > 0
                          ? `${summary.seminarSupportCount} hội thảo`
                          : undefined
                      }
                      accent="#7c3aed"
                    />
                  </Grid>
                  <Grid item xs={6} md={3}>
                    <StatCard
                      icon={<LocalHospitalOutlinedIcon />}
                      label="Phụ cấp Quang Trung"
                      value={attSvc.formatMoney(summary.quangTrungAllowance ?? 0)}
                      sub={`${summary.quangTrungAllowanceCount ?? 0} ngày × ${attSvc.formatMoney(summary.quangTrungAllowanceRate ?? 0)}`}
                      accent="#0f766e"
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
                <Table size="small" sx={{ tableLayout: 'fixed', minWidth: 920 }}>
                  <TableHead>
                    <TableRow sx={{ bgcolor: alpha(theme.palette.primary.main, 0.06) }}>
                      <TableCell sx={{ fontWeight: 700, width: 64, whiteSpace: 'nowrap', px: 1.5 }}>
                        Ngày
                      </TableCell>
                      <TableCell align="center" sx={{ fontWeight: 700, width: 96 }}>
                        Ca sáng / Vào
                      </TableCell>
                      <TableCell align="center" sx={{ fontWeight: 700, width: 96 }}>
                        Ca chiều / Ra
                      </TableCell>
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
                        <TableCell colSpan={8} align="center" sx={{ py: 5, color: 'text.secondary' }}>
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
                        const dayContinuous = continuousDates.has(workDate);
                        const daySplit = splitDates.has(workDate);
                        const dayAssigned = dayContinuous || daySplit;
                        return (
                          <TableRow
                            key={workDate}
                            hover
                            sx={{
                              ...(warnRow ? { bgcolor: alpha(theme.palette.warning.main, 0.06) } : {}),
                              ...(dayAssigned && !warnRow
                                ? {
                                    bgcolor: alpha(
                                      dayContinuous ? theme.palette.success.main : theme.palette.primary.main,
                                      0.04,
                                    ),
                                  }
                                : {}),
                              ...(noData && !warnRow ? { opacity: 0.72 } : {}),
                            }}
                          >
                            <TableCell
                              sx={{
                                fontWeight: holidayDates.has(workDate) || dayAssigned ? 800 : 500,
                                color: holidayDates.has(workDate)
                                  ? 'warning.dark'
                                  : dayContinuous
                                    ? 'success.dark'
                                    : daySplit
                                      ? 'primary.dark'
                                      : 'inherit',
                                whiteSpace: 'nowrap',
                                width: 64,
                                px: 1.5,
                                fontVariantNumeric: 'tabular-nums',
                              }}
                              title={
                                holidayDates.has(workDate)
                                  ? 'Ngày lễ — đi làm = 2 công'
                                  : dayContinuous
                                    ? 'Ca thông tầm'
                                    : daySplit
                                      ? 'Ca sáng–chiều theo ngày'
                                      : undefined
                              }
                            >
                              {(parseLocalDate(workDate) ?? new Date()).toLocaleDateString('vi-VN', {
                                day: '2-digit',
                                month: '2-digit',
                              })}
                              {dayContinuous ? (
                                <Typography
                                  component="span"
                                  variant="caption"
                                  sx={{ display: 'block', fontWeight: 700, color: 'success.main', lineHeight: 1.1 }}
                                >
                                  TT
                                </Typography>
                              ) : null}
                              {daySplit ? (
                                <Typography
                                  component="span"
                                  variant="caption"
                                  sx={{ display: 'block', fontWeight: 700, color: 'primary.main', lineHeight: 1.1 }}
                                >
                                  SC
                                </Typography>
                              ) : null}
                            </TableCell>
                            {dayContinuous ? (
                              <>
                                <TableCell align="center" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                                  {formatPunchTime(row?.morningCheckIn as string | undefined)}
                                </TableCell>
                                <TableCell align="center" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                                  {formatPunchTime(row?.afternoonCheckOut as string | undefined)}
                                </TableCell>
                              </>
                            ) : (
                              <>
                                <TableCell align="center">{shiftHoursLabel(row, schedule, 'morning')}</TableCell>
                                <TableCell align="center">{shiftHoursLabel(row, schedule, 'afternoon')}</TableCell>
                              </>
                            )}
                            <TableCell align="center">{overtimeHoursLabel(row, schedule, dayContinuous)}</TableCell>
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
                                canSubmitExplanation={canExplainSelected}
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
        employeeId={selected !== '' ? Number(selected) : user?.employeeId}
        continuousShift={dialogDate ? continuousDates.has(dialogDate) : false}
      />
      <AttendanceExplanationDialog
        open={explainOpen}
        onClose={closeExplain}
        onSubmitted={reloadAll}
        defaultDate={dialogDate}
        attendanceRow={explainRow}
        continuousShift={dialogDate ? continuousDates.has(dialogDate) : false}
        employeeId={selected !== '' ? Number(selected) : user?.employeeId}
        schedule={schedule}
        initialSelectedKeys={explainInitialKeys}
      />
      {selected !== '' && (
        <YoungChildProposeDialog
          open={youngChildProposeOpen}
          onClose={() => setYoungChildProposeOpen(false)}
          employeeId={Number(selected)}
          employeeName={selectedEmployee?.fullName || employeeName}
          departmentName={selectedEmployee?.departmentName}
          year={year}
          month={month}
          onSubmitted={() => {
            setYoungChildPending(true);
            setNotifyMsg(
              'Đã gửi đề xuất chế độ nuôi con nhỏ — chờ HCNS duyệt.',
            );
          }}
        />
      )}
      {selected !== '' && (
        <ShiftConfigChangeProposeDialog
          open={shiftConfigProposeOpen}
          onClose={() => setShiftConfigProposeOpen(false)}
          employeeId={Number(selected)}
          employeeName={selectedEmployee?.fullName || employeeName}
          departmentName={selectedEmployee?.departmentName}
          schedule={schedule}
          onSubmitted={() => {
            setNotifyMsg('Đã gửi đề xuất thay đổi ca sáng/chiều — chờ HCNS duyệt.');
          }}
        />
      )}
      {dayDetailOpen && dayDetailDate && (
        <AttendanceDayDetailDialog
          open={dayDetailOpen}
          onClose={() => setDayDetailOpen(false)}
          workDate={dayDetailDate}
          row={dayDetailRow}
          employeeName={employeeName}
          monthSummary={summary}
          schedule={schedule}
          continuousShift={continuousDates.has(dayDetailDate)}
          employeeId={selected !== '' ? Number(selected) : user?.employeeId}
          onExplain={canExplainSelected ? openExplain : undefined}
        />
      )}
      <AttendanceScheduleEditDialog
        open={scheduleEditOpen}
        onClose={() => setScheduleEditOpen(false)}
        onSaved={handleScheduleSaved}
        employeeId={Number(selected)}
        continuousShift={scheduleEditContinuous}
        employeeName={selectedEmployee?.fullName || employeeName}
      />
      {(user?.role === 'ADMIN' || isHeadRole) && selected !== '' && (
        <ContinuousShiftConfigDialog
          open={continuousConfigOpen}
          onClose={() => setContinuousConfigOpen(false)}
          employeeId={Number(selected)}
          employeeName={selectedEmployee?.fullName || employeeName || ''}
          year={year}
          month={month}
          onSaved={handleContinuousShiftSaved}
        />
      )}
      {(user?.role === 'ADMIN' || isHeadRole) && (
        <ContinuousShiftTypeDialog
          open={continuousTypeOpen}
          onClose={() => {
            setContinuousTypeOpen(false);
            attSvc.fetchContinuousShiftTypes(true)
              .then(setContinuousTypes)
              .catch(() => setContinuousTypes([]));
          }}
        />
      )}
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
      {canManageSupplement && supplementOpen && dutyDate && (
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
          showCongHo={user?.role === 'ADMIN'}
        />
      )}
      {(user?.role === 'ADMIN' || isHeadRole) && (
        <BulkWorkSupplementDialog
          open={bulkSupplementOpen}
          onClose={() => setBulkSupplementOpen(false)}
          onSaved={reloadAll}
          departmentOptions={departments}
          initialDepartmentId={filterDept}
          initialWorkDate={`${year}-${String(month).padStart(2, '0')}-01`}
        />
      )}
      {(isHrOrAdmin || isHeadRole) && (
        <BulkDeploymentDialog
          open={bulkDeploymentOpen}
          onClose={() => setBulkDeploymentOpen(false)}
          onSaved={() => {
            setNotifyMsg('Đã tạo đơn điều động hàng loạt.');
            reloadAll();
          }}
          departmentOptions={departments}
          initialDepartmentId={filterDept}
          initialWorkDate={`${year}-${String(month).padStart(2, '0')}-01`}
          periodYear={year}
          periodMonth={month}
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
      {canCreateDeployment && deploymentOpen && deploymentDate && (
        <DeploymentRequestDialog
          open={deploymentOpen}
          onClose={closeDeployment}
          onSubmitted={() => {
            setNotifyMsg(
              isNursingBlockTitle(selectedEmployee?.positionTitle)
                ? 'Đã tạo đơn điều động và chuyển Trưởng phòng Điều dưỡng duyệt.'
                : 'Đã tạo đơn điều động và chuyển HCNS duyệt.',
            );
            reloadAll();
          }}
          employeeId={Number(selected)}
          employeeName={employeeName}
          positionTitle={selectedEmployee?.positionTitle}
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
      {canPickEmployee && (
        <DepartmentAttendanceMatrixDialog
          open={matrixOpen}
          onClose={() => setMatrixOpen(false)}
          year={year}
          month={month}
          departmentId={filterDept}
          departments={departments}
          deptFilterLocked={deptFilterLocked}
          onViewEmployee={openEmployeeFromMatrix}
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
