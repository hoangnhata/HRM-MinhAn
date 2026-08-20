import AddIcon from '@mui/icons-material/Add';
import AssignmentOutlinedIcon from '@mui/icons-material/AssignmentOutlined';
import BeachAccessOutlinedIcon from '@mui/icons-material/BeachAccessOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import EditCalendarOutlinedIcon from '@mui/icons-material/EditCalendarOutlined';
import EventAvailableOutlinedIcon from '@mui/icons-material/EventAvailableOutlined';
import HourglassEmptyOutlinedIcon from '@mui/icons-material/HourglassEmptyOutlined';
import InboxOutlinedIcon from '@mui/icons-material/InboxOutlined';
import MoneyOffOutlinedIcon from '@mui/icons-material/MoneyOffOutlined';
import SwapHorizIcon from '@mui/icons-material/SwapHoriz';
import HowToRegIcon from '@mui/icons-material/HowToReg';
import ChildCareIcon from '@mui/icons-material/ChildCare';
import WbSunnyOutlinedIcon from '@mui/icons-material/WbSunnyOutlined';
import SchoolOutlinedIcon from '@mui/icons-material/SchoolOutlined';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import WarningAmberOutlinedIcon from '@mui/icons-material/WarningAmberOutlined';
import {
  Alert,
  Box,
  Button,
  Chip,
  Grid,
  Menu,
  MenuItem,
  ListItemIcon,
  ListItemText,
  Paper,
  Stack,
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { AttendancePendingPanel } from '../components/AttendancePendingPanel';
import { DepartmentTransferPendingPanel } from '../components/DepartmentTransferPendingPanel';
import { LeaveRequestDialog } from '../components/LeaveRequestDialog';
import { ProbationConversionPendingPanel } from '../components/ProbationConversionPendingPanel';
import { SeminarProposalPendingPanel } from '../components/SeminarProposalPendingPanel';
import { MainDutyAuthorizationPendingPanel } from '../components/MainDutyAuthorizationPendingPanel';
import { EmployeeRelatedRequestsPanel } from '../components/EmployeeRelatedRequestsPanel';
import { EMPLOYEE_RELATED_TABS, employeeTabIndexForKey } from '../components/employeeRelatedRequestsMeta';
import { TrainingProposalPendingPanel } from '../components/TrainingProposalPendingPanel';
import { YoungChildRequestPendingPanel } from '../components/YoungChildRequestPendingPanel';
import { ShiftConfigChangePendingPanel } from '../components/ShiftConfigChangePendingPanel';
import { SeminarProposalDialog } from '../components/SeminarProposalDialog';
import { UnpaidLeaveRequestDialog } from '../components/UnpaidLeaveRequestDialog';
import { PageHeader } from '../components/layout/PageHeader';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from '../components/requests/RequestListFilters';
import { RequestListTable, formatRequestSubject, type RequestListRow } from '../components/requests/RequestListTable';
import { WorkRequestDetailDialog } from '../components/work/WorkRequestDetailDialog';
import { useAuth } from '../context/AuthContext';
import { isHeadDepartmentRole, isHr2Role } from '../utils/roleAccess';
import * as att from '../services/attendanceService';

function workRequestSummary(r: att.WorkRequest): string {
  const isRanged =
    r.requestType === 'LEAVE' ||
    r.requestType === 'UNPAID_LEAVE' ||
    r.requestType === 'BUSINESS_TRIP';
  if (r.requestType === 'UPDATE') return att.formatRequestedTimes(r);
  if (r.requestType === 'DEPLOYMENT' && r.requestedStart && r.requestedEnd) {
    return `${r.requestedStart.slice(0, 5)}–${r.requestedEnd.slice(0, 5)}${
      r.location ? ` · ${r.location}` : ''
    }`;
  }
  if (isRanged) {
    const days = r.requestType === 'BUSINESS_TRIP' ? r.tripDays : r.leaveDays;
    return `${att.formatLeaveRange(r)}${days != null ? ` · ${days} ngày` : ''}`;
  }
  return att.formatExplanationTimes(r);
}

type FilterKey = 'all' | 'leave' | 'unpaid' | 'work' | 'pending' | 'done';

const WORK_REQUEST_TYPES = new Set<att.WorkRequest['requestType']>([
  'UPDATE',
  'EXPLANATION',
]);

function BalanceStat({
  label,
  value,
  hint,
  accent,
  icon,
}: {
  label: string;
  value: string | number;
  hint?: string;
  accent: string;
  icon: React.ReactNode;
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
        transition: 'transform 0.18s, box-shadow 0.18s',
        '&:hover': {
          transform: 'translateY(-1px)',
          boxShadow: `0 8px 22px ${alpha(accent, 0.1)}`,
        },
      }}
    >
      <Stack direction="row" spacing={1.5} alignItems="flex-start">
        <Box
          sx={{
            width: 40,
            height: 40,
            borderRadius: 2,
            display: 'grid',
            placeItems: 'center',
            bgcolor: alpha(accent, 0.12),
            color: accent,
            flexShrink: 0,
          }}
        >
          {icon}
        </Box>
        <Box sx={{ minWidth: 0 }}>
          <Typography variant="caption" color="text.secondary" fontWeight={600} display="block">
            {label}
          </Typography>
          <Typography variant="h5" fontWeight={800} sx={{ lineHeight: 1.2, letterSpacing: '-0.02em' }}>
            {value}
          </Typography>
          {hint && (
            <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.35 }}>
              {hint}
            </Typography>
          )}
        </Box>
      </Stack>
    </Paper>
  );
}

export default function RequestsPage() {
  const theme = useTheme();
  const { user, refreshUser } = useAuth();
  const isDeptHead = user?.role === 'ADMIN' || isHeadDepartmentRole(user?.role);
  const isNursingHead = user?.role === 'ADMIN' || user?.role === 'HEAD_NURSING';
  const isHead = isDeptHead; // for leave/work approve — nursing head excluded
  const isHrOrAdmin = user?.role === 'ADMIN' || isHr2Role(user?.role);
  const isDirector =
    user?.role === 'ADMIN'
    || user?.role === 'DIRECTOR'
    || user?.directorApprovalEnabled === true;
  const canApprove = isHead || isHrOrAdmin;
  const canApproveLeave = canApprove || isDirector;
  const canApproveWorkRequests = canApprove || isDirector;
  const canViewDeployments = isDeptHead || isNursingHead || isHrOrAdmin || isDirector;
  const canViewTransfers = isDirector || user?.role === 'HR';
  const canViewConversions =
    isDirector
    || isHr2Role(user?.role)
    || isHeadDepartmentRole(user?.role)
    || user?.role === 'HEAD_NURSING';
  const canViewYoungChild =
    user?.role === 'ADMIN' || isHr2Role(user?.role) || isHeadDepartmentRole(user?.role);
  const canViewShiftConfigChange =
    user?.role === 'ADMIN' || isHr2Role(user?.role) || isHeadDepartmentRole(user?.role);
  const canViewTrainingProposals =
    isDirector || isHr2Role(user?.role) || isHeadDepartmentRole(user?.role) || isNursingHead;
  const canViewSeminarProposals = canViewTrainingProposals;
  const canViewMainDuty =
    isDirector
    || isHr2Role(user?.role)
    || isHeadDepartmentRole(user?.role)
    || user?.role === 'HEAD_NURSING';

  // Giám đốc khi tắt quyền duyệt dùng giao diện Nhân viên. Khi bật quyền,
  // chỉ hiển thị các hàng chờ thuộc bước Giám đốc, tránh panel/tab rỗng.
  const isEmployee =
    user?.role === 'EMPLOYEE'
    || (user?.role === 'DIRECTOR' && user?.directorApprovalEnabled !== true);
  // Trưởng khoa / Trưởng phòng ĐD vẫn xem đơn liên quan bản thân — nhưng không tách tab
  // trùng với tab duyệt cùng loại (Điều động / Chuyển chính thức / Trực chính / …).
  const showEmployeeRelatedTabs =
    isEmployee
    || ((user?.role === 'HEAD_NURSING' || isHeadDepartmentRole(user?.role))
      && Boolean(user?.employeeId));
  const showMyDeploymentTab = showEmployeeRelatedTabs && !canViewDeployments;
  const showMySeminarTab = showEmployeeRelatedTabs && !canViewSeminarProposals;
  const showMyTrainingTab = showEmployeeRelatedTabs && !canViewTrainingProposals;
  const showMyMainDutyTab = showEmployeeRelatedTabs && !canViewMainDuty;
  const showMyConversionTab = showEmployeeRelatedTabs && !canViewConversions;
  const showMyTransferTab = showEmployeeRelatedTabs && !canViewTransfers;
  const showMyYoungChildTab = showEmployeeRelatedTabs && !canViewYoungChild;
  const showMyShiftConfigTab = showEmployeeRelatedTabs && !canViewShiftConfigChange;

  let nextTab = 1;
  const employeeDeploymentTab = showMyDeploymentTab ? nextTab++ : -1;
  const employeeSeminarTab = showMySeminarTab ? nextTab++ : -1;
  const employeeTrainingTab = showMyTrainingTab ? nextTab++ : -1;
  const employeeMainDutyTab = showMyMainDutyTab ? nextTab++ : -1;
  const employeeConversionTab = showMyConversionTab ? nextTab++ : -1;
  const employeeTransferTab = showMyTransferTab ? nextTab++ : -1;
  const employeeYoungChildTab = showMyYoungChildTab ? nextTab++ : -1;
  const employeeShiftConfigTab = showMyShiftConfigTab ? nextTab++ : -1;
  const employeeTabIndices =
    showMySeminarTab
    || showMyTrainingTab
    || showMyMainDutyTab
    || showMyConversionTab
    || showMyTransferTab
    || showMyYoungChildTab
    || showMyShiftConfigTab
      ? {
          seminar: employeeSeminarTab,
          training: employeeTrainingTab,
          'main-duty': employeeMainDutyTab,
          probation: employeeConversionTab,
          transfer: employeeTransferTab,
          'young-child': employeeYoungChildTab,
          'shift-config': employeeShiftConfigTab,
        }
      : null;

  const leaveTabIndex = canApproveLeave ? nextTab++ : -1;
  const workTabIndex = canApproveWorkRequests ? nextTab++ : -1;
  const deploymentTabIndex = canViewDeployments ? nextTab++ : -1;
  const transfersTabIndex = canViewTransfers ? nextTab++ : -1;
  const conversionsTabIndex = canViewConversions ? nextTab++ : -1;
  const youngChildTabIndex = canViewYoungChild ? nextTab++ : -1;
  const shiftConfigTabIndex = canViewShiftConfigChange ? nextTab++ : -1;
  const trainingTabIndex = canViewTrainingProposals ? nextTab++ : -1;
  const seminarTabIndex = canViewSeminarProposals ? nextTab++ : -1;
  const mainDutyTabIndex = !isEmployee && canViewMainDuty ? nextTab++ : -1;

  const [searchParams, setSearchParams] = useSearchParams();
  const [tab, setTab] = useState(0);
  const [myRequests, setMyRequests] = useState<att.WorkRequest[]>([]);
  const [filter, setFilter] = useState<FilterKey>('all');
  const [listFilters, setListFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [detail, setDetail] = useState<att.WorkRequest | null>(null);
  const [leaveOpen, setLeaveOpen] = useState(false);
  const [unpaidLeaveOpen, setUnpaidLeaveOpen] = useState(false);
  const [createMenuEl, setCreateMenuEl] = useState<null | HTMLElement>(null);
  const [seminarOpen, setSeminarOpen] = useState(false);
  const [balance, setBalance] = useState<att.LeaveBalance | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [msgSeverity, setMsgSeverity] = useState<'success' | 'error'>('success');

  const paperSx = {
    borderRadius: 3,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
    bgcolor: alpha(theme.palette.background.paper, 0.96),
    boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
    overflow: 'hidden' as const,
  };

  const reload = useCallback(() => {
    const loadBalance = () =>
      att
        .fetchMyLeaveBalance()
        .then(setBalance)
        .catch(async () => {
          if (user?.employeeId) {
            try {
              const bal = await att.fetchEmployeeLeaveBalance(user.employeeId);
              setBalance(bal);
              return;
            } catch {
              /* ignore */
            }
          }
          setBalance(null);
        });

    const loadMine = () => {
      att.fetchMyWorkRequests().then(setMyRequests).catch(() => setMyRequests([]));
    };

    // Mọi role (có hồ sơ NV liên kết) đều xem hạn mức phép trên trang Đơn
    loadBalance();

    if (user?.employeeId) {
      loadMine();
      return;
    }

    // Session chưa có employeeId — gắn lại từ /account/me rồi tải đơn của tôi
    void refreshUser()
      .then(() => {
        loadMine();
        loadBalance();
      })
      .catch(() => {
        setMyRequests([]);
      });
  }, [user?.employeeId, user?.role, refreshUser]);

  useEffect(() => {
    reload();
  }, [reload]);

  useEffect(() => {
    const raw = searchParams.get('tab');
    const kind = searchParams.get('kind');
    const id = searchParams.get('id');

    const pickEmployeeTab = (tabKey: string) => {
      if (!employeeTabIndices) return false;
      const idx = employeeTabIndexForKey(tabKey, employeeTabIndices);
      if (idx >= 0) {
        setTab(idx);
        return true;
      }
      return false;
    };

    if (isEmployee) {
      if (kind && pickEmployeeTab(kind)) return;
      if (raw && pickEmployeeTab(raw)) return;
      if (raw === 'deployments') {
        setTab(employeeDeploymentTab);
        return;
      }
      if (raw === 'mine' || raw === '0' || (raw === 'seminar-proposals' && id)) {
        if (raw === 'seminar-proposals' || kind === 'seminar') pickEmployeeTab('seminar');
        else if (kind) pickEmployeeTab(kind);
        else setTab(0);
        return;
      }
    } else if (showEmployeeRelatedTabs) {
      if (kind && pickEmployeeTab(kind)) return;
      if (raw && pickEmployeeTab(raw)) return;
    }

    if (raw === 'young-child' && canViewYoungChild) {
      setTab(youngChildTabIndex);
    } else if ((raw === 'shift-config' || raw === 'shift-config-change') && canViewShiftConfigChange) {
      setTab(shiftConfigTabIndex);
    } else if (raw === 'training-proposals' && canViewTrainingProposals) {
      setTab(trainingTabIndex);
    } else if (raw === 'training-proposals' && showEmployeeRelatedTabs) {
      pickEmployeeTab('training');
    } else if (raw === 'training' && showEmployeeRelatedTabs) {
      pickEmployeeTab('training');
    } else if (raw === 'seminar-proposals' && canViewSeminarProposals) {
      setTab(seminarTabIndex);
    } else if (raw === 'seminar-proposals' && showEmployeeRelatedTabs) {
      pickEmployeeTab('seminar');
    } else if (raw === 'seminar' && showEmployeeRelatedTabs) {
      pickEmployeeTab('seminar');
    } else if (raw === 'main-duty' && showEmployeeRelatedTabs && !canViewMainDuty) {
      pickEmployeeTab('main-duty');
    } else if (raw === 'main-duty' && canViewMainDuty) {
      setTab(mainDutyTabIndex);
    } else if (raw === 'probation-conversions' && canViewConversions) {
      setTab(conversionsTabIndex);
    } else if (raw === 'probation-conversions' && showEmployeeRelatedTabs) {
      pickEmployeeTab('probation');
    } else if (raw === 'probation' && showEmployeeRelatedTabs && !canViewConversions) {
      pickEmployeeTab('probation');
    } else if (raw === 'transfers' && canViewTransfers) {
      setTab(transfersTabIndex);
    } else if (raw === 'transfers' && showEmployeeRelatedTabs) {
      pickEmployeeTab('transfer');
    } else if (raw === 'transfer' && showEmployeeRelatedTabs) {
      pickEmployeeTab('transfer');
    } else if (raw === 'leave' && canApprove) {
      setTab(leaveTabIndex);
    } else if (raw === 'deployments' && canViewDeployments) {
      setTab(deploymentTabIndex);
    } else if ((raw === 'work' || raw === 'approve' || raw === 'pending') && canApproveWorkRequests) {
      setTab(workTabIndex);
    } else if (raw === 'mine' || raw === '0') {
      setTab(0);
    } else if (!raw && user?.role === 'DIRECTOR' && canApproveWorkRequests) {
      setTab(workTabIndex);
    } else if (!raw && user?.role === 'DIRECTOR' && canViewTransfers) {
      setTab(transfersTabIndex);
    }
  }, [
    searchParams,
    isEmployee,
    showEmployeeRelatedTabs,
    employeeTabIndices,
    employeeDeploymentTab,
    canApprove,
    canApproveWorkRequests,
    canViewDeployments,
    canViewTransfers,
    canViewConversions,
    canViewYoungChild,
    canViewShiftConfigChange,
    canViewTrainingProposals,
    canViewSeminarProposals,
    canViewMainDuty,
    leaveTabIndex,
    workTabIndex,
    deploymentTabIndex,
    transfersTabIndex,
    conversionsTabIndex,
    youngChildTabIndex,
    shiftConfigTabIndex,
    trainingTabIndex,
    seminarTabIndex,
    mainDutyTabIndex,
    user?.role,
  ]);

  useEffect(() => {
    if (!showMyDeploymentTab || tab !== employeeDeploymentTab) return;
    const requestedId = Number(searchParams.get('id'));
    if (!Number.isFinite(requestedId) || requestedId <= 0) return;
    const requested = myRequests.find(
      (request) => request.id === requestedId && request.requestType === 'DEPLOYMENT',
    );
    if (requested) setDetail(requested);
  }, [showMyDeploymentTab, tab, employeeDeploymentTab, searchParams, myRequests]);

  const counts = useMemo(() => {
    const requestsInMine = myRequests.filter((r) => r.requestType !== 'DEPLOYMENT');
    const leave = requestsInMine.filter((r) => r.requestType === 'LEAVE').length;
    const unpaid = requestsInMine.filter((r) => r.requestType === 'UNPAID_LEAVE').length;
    const work = requestsInMine.filter((r) => WORK_REQUEST_TYPES.has(r.requestType)).length;
    const pending = requestsInMine.filter((r) => att.isRequestPending(r.status)).length;
    const done = requestsInMine.filter((r) => !att.isRequestPending(r.status)).length;
    return { all: requestsInMine.length, leave, unpaid, work, pending, done };
  }, [myRequests]);

  const filteredByType = useMemo(() => {
    const requestsInMine = myRequests.filter((r) => r.requestType !== 'DEPLOYMENT');
    if (filter === 'leave') return requestsInMine.filter((r) => r.requestType === 'LEAVE');
    if (filter === 'unpaid') return requestsInMine.filter((r) => r.requestType === 'UNPAID_LEAVE');
    if (filter === 'work') return requestsInMine.filter((r) => WORK_REQUEST_TYPES.has(r.requestType));
    if (filter === 'pending') return requestsInMine.filter((r) => att.isRequestPending(r.status));
    if (filter === 'done') return requestsInMine.filter((r) => !att.isRequestPending(r.status));
    return requestsInMine;
  }, [myRequests, filter]);

  useEffect(() => {
    setListFilters(EMPTY_REQUEST_FILTERS);
  }, [filter]);

  const filtered = useMemo(
    () =>
      applyRequestListFilters(filteredByType, listFilters, {
        searchText: (r) =>
          [r.employeeName, r.department, r.reason, att.requestTypeLabel(r.requestType), r.status].join(
            ' ',
          ),
        dateValue: (r) => r.createdAt,
        statusValue: (r) => r.status,
        departmentValue: (r) => r.department,
      }),
    [filteredByType, listFilters],
  );

  const myStatusOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const r of filteredByType) {
      if (!map.has(r.status)) {
        map.set(r.status, att.requestStatusLabel(r.status, r.requestType));
      }
    }
    return [...map.entries()].map(([value, label]) => ({ value, label }));
  }, [filteredByType]);

  const myRows: RequestListRow[] = filtered.map((r) => ({
    id: r.id,
    typeLabel: att.requestTypeLabel(r.requestType),
    subject: formatRequestSubject(r.employeeName || 'Tôi', r.positionTitle),
    department: r.department,
    summary: workRequestSummary(r),
    meta: r.reason?.trim() || undefined,
    statusLabel: att.requestStatusLabel(r.status, r.requestType),
    statusColor: att.requestStatusColor(r.status),
    dateLabel: att.formatWorkDate(r.workDate),
    submittedAtLabel: r.createdAt ? att.formatWorkDate(String(r.createdAt).slice(0, 10)) : undefined,
    pending: att.isRequestPending(r.status),
  }));

  const myById = useMemo(() => new Map(filtered.map((r) => [r.id, r])), [filtered]);

  function changeTab(next: number) {
    setTab(next);
    const params = new URLSearchParams(searchParams);
    params.delete('kind');
    params.delete('id');
    let tabKey = 'mine';
    if (next === employeeDeploymentTab) tabKey = 'deployments';
    else if (next === employeeSeminarTab) tabKey = 'seminar';
    else if (next === employeeTrainingTab) tabKey = 'training';
    else if (next === employeeMainDutyTab) tabKey = 'main-duty';
    else if (next === employeeConversionTab) tabKey = 'probation';
    else if (next === employeeTransferTab) tabKey = 'transfer';
    else if (next === employeeYoungChildTab) tabKey = 'young-child';
    else if (next === employeeShiftConfigTab) tabKey = 'shift-config';
    else if (next === leaveTabIndex) tabKey = 'leave';
    else if (next === workTabIndex) tabKey = 'work';
    else if (next === deploymentTabIndex) tabKey = 'deployments';
    else if (next === transfersTabIndex) tabKey = 'transfers';
    else if (next === conversionsTabIndex) tabKey = 'probation-conversions';
    else if (next === youngChildTabIndex) tabKey = 'young-child';
    else if (next === shiftConfigTabIndex) tabKey = 'shift-config';
    else if (next === trainingTabIndex) tabKey = 'training-proposals';
    else if (next === seminarTabIndex) tabKey = 'seminar-proposals';
    else if (next === mainDutyTabIndex) tabKey = 'main-duty';
    params.set('tab', tabKey);
    setSearchParams(params, { replace: true });
  }

  function employeeRelatedTabIcon(tabKey: string) {
    switch (tabKey) {
      case 'seminar':
        return <GroupsOutlinedIcon />;
      case 'training':
        return <SchoolOutlinedIcon />;
      case 'main-duty':
        return <NightsStayIcon />;
      case 'probation':
        return <HowToRegIcon />;
      case 'transfer':
        return <SwapHorizIcon />;
      case 'young-child':
        return <ChildCareIcon />;
      case 'shift-config':
        return <WbSunnyOutlinedIcon />;
      default:
        return <InboxOutlinedIcon />;
    }
  }

  const filters: { key: FilterKey; label: string; count: number }[] = [
    { key: 'all', label: 'Tất cả', count: counts.all },
    { key: 'leave', label: 'Nghỉ phép', count: counts.leave },
    { key: 'unpaid', label: 'Không lương', count: counts.unpaid },
    { key: 'work', label: 'Đơn công', count: counts.work },
    { key: 'pending', label: 'Chờ duyệt', count: counts.pending },
    { key: 'done', label: 'Đã xử lý', count: counts.done },
  ];

  const remainingAccent =
    balance && balance.remainingDays <= 2 ? theme.palette.warning.main : theme.palette.success.main;

  return (
    <Box>
      <PageHeader
        overline="Đơn từ"
        title="Đơn nghỉ phép"
        description="Gửi đơn nghỉ phép hoặc nghỉ không lương; theo dõi trạng thái duyệt và hạn mức phép năm. Nhu cầu đi công tác sử dụng đơn Hội thảo."
        actions={
          <>
            <Button
              variant="contained"
              size="large"
              startIcon={<AddIcon />}
              onClick={(e) => setCreateMenuEl(e.currentTarget)}
              sx={{
                borderRadius: 2.5,
                px: 2.5,
                py: 1.1,
                fontWeight: 700,
                boxShadow: `0 8px 20px ${alpha(theme.palette.primary.main, 0.28)}`,
              }}
            >
              Tạo đơn
            </Button>
            <Menu
              anchorEl={createMenuEl}
              open={Boolean(createMenuEl)}
              onClose={() => setCreateMenuEl(null)}
              anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
              transformOrigin={{ vertical: 'top', horizontal: 'right' }}
              PaperProps={{
                sx: {
                  mt: 1,
                  minWidth: 240,
                  borderRadius: 2.5,
                  border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                  boxShadow: `0 12px 32px ${alpha('#0f172a', 0.12)}`,
                },
              }}
            >
              <MenuItem
                onClick={() => {
                  setCreateMenuEl(null);
                  setLeaveOpen(true);
                }}
                sx={{ py: 1.25, borderRadius: 1.5, mx: 0.5 }}
              >
                <ListItemIcon>
                  <BeachAccessOutlinedIcon fontSize="small" color="secondary" />
                </ListItemIcon>
                <ListItemText
                  primary="Xin nghỉ phép"
                  secondary="Có tính công · trừ hạn mức năm"
                  primaryTypographyProps={{ fontWeight: 700, fontSize: '0.9rem' }}
                  secondaryTypographyProps={{ fontSize: '0.72rem' }}
                />
              </MenuItem>
              <MenuItem
                onClick={() => {
                  setCreateMenuEl(null);
                  setUnpaidLeaveOpen(true);
                }}
                sx={{ py: 1.25, borderRadius: 1.5, mx: 0.5 }}
              >
                <ListItemIcon>
                  <MoneyOffOutlinedIcon fontSize="small" color="error" />
                </ListItemIcon>
                <ListItemText
                  primary="Xin nghỉ không lương"
                  secondary="0 công · không trừ phép năm"
                  primaryTypographyProps={{ fontWeight: 700, fontSize: '0.9rem' }}
                  secondaryTypographyProps={{ fontSize: '0.72rem' }}
                />
              </MenuItem>
              {isNursingHead && user?.employeeId && (
                <MenuItem
                  onClick={() => {
                    setCreateMenuEl(null);
                    setSeminarOpen(true);
                  }}
                  sx={{ py: 1.25, borderRadius: 1.5, mx: 0.5 }}
                >
                  <ListItemIcon>
                    <GroupsOutlinedIcon fontSize="small" color="primary" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Đề xuất hội thảo / công tác"
                    secondary="Gửi Giám đốc duyệt"
                    primaryTypographyProps={{ fontWeight: 700, fontSize: '0.9rem' }}
                    secondaryTypographyProps={{ fontSize: '0.72rem' }}
                  />
                </MenuItem>
              )}
            </Menu>
          </>
        }
      />

      {msg && (
        <Alert severity={msgSeverity} sx={{ mb: 2.5, borderRadius: 2 }} onClose={() => setMsg(null)}>
          {msg}
        </Alert>
      )}

      {balance && (
        <Box sx={{ mb: 2.5 }}>
          <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1.5 }}>
            <Typography variant="subtitle2" fontWeight={800} color="text.secondary">
              Hạn mức phép năm {balance.year}
            </Typography>
            {balance.yearsOfService > 0 && (
              <Chip
                size="small"
                label={`Thâm niên ${balance.yearsOfService} năm`}
                variant="outlined"
                sx={{ height: 24, fontWeight: 600 }}
              />
            )}
          </Stack>
          <Grid container spacing={1.75}>
            <Grid item xs={6} md={3}>
              <BalanceStat
                icon={<EventAvailableOutlinedIcon fontSize="small" />}
                label="Hạn mức năm"
                value={balance.entitlementDays}
                hint={
                  balance.yearsOfService > 0
                    ? '12 ngày + 1 mỗi 5 năm'
                    : '12 ngày (mặc định khi chưa có thâm niên)'
                }
                accent={theme.palette.primary.main}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <BalanceStat
                icon={<CheckCircleOutlineIcon fontSize="small" />}
                label="Đã dùng"
                value={balance.usedDays}
                hint="Đơn nghỉ phép đã duyệt"
                accent={theme.palette.info.main}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <BalanceStat
                icon={<HourglassEmptyOutlinedIcon fontSize="small" />}
                label="Chờ duyệt"
                value={balance.pendingDays}
                hint="Đang chờ Lãnh đạo / HCNS / Giám đốc"
                accent={theme.palette.warning.main}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <BalanceStat
                icon={
                  balance.remainingDays <= 2 ? (
                    <WarningAmberOutlinedIcon fontSize="small" />
                  ) : (
                    <BeachAccessOutlinedIcon fontSize="small" />
                  )
                }
                label="Còn lại"
                value={balance.remainingDays}
                hint={`Tối đa ${balance.entitlementDays} ngày/năm`}
                accent={remainingAccent}
              />
            </Grid>
          </Grid>
          {balance.warning && (
            <Alert severity="warning" variant="outlined" sx={{ mt: 1.75, borderRadius: 2 }}>
              {balance.warning}
            </Alert>
          )}
        </Box>
      )}

      <Paper elevation={0} sx={paperSx}>
        <Box
          sx={{
            px: 2,
            pt: 1,
            borderBottom: 1,
            borderColor: 'divider',
            bgcolor: alpha(theme.palette.primary.main, 0.03),
          }}
        >
          <Tabs
            value={tab}
            onChange={(_, v) => changeTab(v)}
            variant="scrollable"
            scrollButtons="auto"
            allowScrollButtonsMobile
            sx={{
              minHeight: 52,
              '& .MuiTabs-scrollButtons': {
                '&.Mui-disabled': { opacity: 0.25 },
              },
              '& .MuiTab-root': {
                fontWeight: 600,
                minHeight: 52,
                textTransform: 'none',
                flexShrink: 0,
              },
            }}
          >
            <Tab icon={<AssignmentOutlinedIcon />} iconPosition="start" label="Đơn của tôi" />
            {showMyDeploymentTab && (
              <Tab icon={<SwapHorizIcon />} iconPosition="start" label="Điều động" />
            )}
            {EMPLOYEE_RELATED_TABS.filter((t) => {
              if (t.tabKey === 'seminar') return showMySeminarTab;
              if (t.tabKey === 'training') return showMyTrainingTab;
              if (t.tabKey === 'main-duty') return showMyMainDutyTab;
              if (t.tabKey === 'probation') return showMyConversionTab;
              if (t.tabKey === 'transfer') return showMyTransferTab;
              if (t.tabKey === 'young-child') return showMyYoungChildTab;
              if (t.tabKey === 'shift-config') return showMyShiftConfigTab;
              return false;
            }).map((t) => (
              <Tab
                key={t.tabKey}
                icon={employeeRelatedTabIcon(t.tabKey)}
                iconPosition="start"
                label={t.label}
              />
            ))}
            {canApproveLeave && (
              <Tab icon={<BeachAccessOutlinedIcon />} iconPosition="start" label="Nghỉ phép" />
            )}
            {canApproveWorkRequests && (
              <Tab icon={<EditCalendarOutlinedIcon />} iconPosition="start" label="Đơn công" />
            )}
            {canViewDeployments && (
              <Tab icon={<SwapHorizIcon />} iconPosition="start" label="Điều động" />
            )}
            {canViewTransfers && (
              <Tab icon={<SwapHorizIcon />} iconPosition="start" label="Luân chuyển" />
            )}
            {canViewConversions && (
              <Tab icon={<HowToRegIcon />} iconPosition="start" label="Chuyển chính thức" />
            )}
            {canViewYoungChild && (
              <Tab icon={<ChildCareIcon />} iconPosition="start" label="Nuôi con nhỏ" />
            )}
            {canViewShiftConfigChange && (
              <Tab icon={<WbSunnyOutlinedIcon />} iconPosition="start" label="Chỉnh ca sáng/chiều" />
            )}
            {canViewTrainingProposals && (
              <Tab icon={<SchoolOutlinedIcon />} iconPosition="start" label="Đào tạo" />
            )}
            {canViewSeminarProposals && (
              <Tab icon={<GroupsOutlinedIcon />} iconPosition="start" label="Hội thảo" />
            )}
            {canViewMainDuty && !isEmployee && (
              <Tab icon={<NightsStayIcon />} iconPosition="start" label="Trực chính" />
            )}
          </Tabs>
        </Box>

        <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
          {tab === 0 && (
            <Stack spacing={2.25}>
              <Stack
                direction={{ xs: 'column', sm: 'row' }}
                spacing={1.5}
                alignItems={{ sm: 'center' }}
                justifyContent="space-between"
              >
                <Box
                  sx={{
                    display: 'inline-flex',
                    p: 0.5,
                    borderRadius: 2.5,
                    bgcolor: alpha(theme.palette.grey[500], 0.06),
                    border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                    flexWrap: 'wrap',
                    gap: 0.5,
                  }}
                >
                  {filters.map((f) => {
                    const selected = filter === f.key;
                    return (
                      <Button
                        key={f.key}
                        size="small"
                        onClick={() => setFilter(f.key)}
                        sx={{
                          borderRadius: 2,
                          px: 1.5,
                          py: 0.75,
                          minWidth: 0,
                          textTransform: 'none',
                          fontWeight: selected ? 700 : 500,
                          color: selected ? theme.palette.primary.contrastText : 'text.secondary',
                          bgcolor: selected ? theme.palette.primary.main : 'transparent',
                          boxShadow: selected
                            ? `0 4px 12px ${alpha(theme.palette.primary.main, 0.25)}`
                            : 'none',
                          '&:hover': {
                            bgcolor: selected
                              ? theme.palette.primary.main
                              : alpha(theme.palette.primary.main, 0.06),
                          },
                        }}
                      >
                        {f.label}
                        <Box
                          component="span"
                          sx={{
                            ml: 0.75,
                            px: 0.75,
                            py: 0.1,
                            borderRadius: 1,
                            fontSize: '0.7rem',
                            fontWeight: 700,
                            bgcolor: selected
                              ? alpha('#fff', 0.22)
                              : alpha(theme.palette.text.primary, 0.06),
                          }}
                        >
                          {f.count}
                        </Box>
                      </Button>
                    );
                  })}
                </Box>
              </Stack>

              <RequestListTable
                rows={myRows}
                emptyTitle={
                  filter === 'all' ? 'Chưa có đơn nào' : 'Không có đơn phù hợp bộ lọc'
                }
                emptyHint={
                  filter === 'all'
                    ? 'Bắt đầu bằng đơn nghỉ phép hoặc nghỉ không lương — chọn khoảng ngày và lý do, rồi gửi lãnh đạo duyệt.'
                    : filter === 'unpaid'
                      ? 'Chưa có đơn nghỉ không lương. Ngày được duyệt ghi 0 công, không trừ phép năm.'
                      : filter === 'work'
                        ? 'Chưa có đơn cập nhật công hoặc giải trình. Tạo từ trang Công.'
                        : 'Thử đổi bộ lọc hoặc tạo đơn mới.'
                }
                toolbar={
                  <RequestListFilters
                    value={listFilters}
                    onChange={setListFilters}
                    statusOptions={myStatusOptions}
                    resultCount={filtered.length}
                  />
                }
                onView={(row) => {
                  const r = myById.get(Number(row.id));
                  if (r) setDetail(r);
                }}
              />

            </Stack>
          )}

          {showMySeminarTab && user?.employeeId && tab === employeeSeminarTab && (
            <EmployeeRelatedRequestsPanel kind="seminar" employeeId={user.employeeId} />
          )}
          {showMyDeploymentTab && tab === employeeDeploymentTab && (
            <Stack spacing={2}>
              <Typography variant="body2" color="text.secondary">
                Các đơn điều động được Trưởng khoa/Điều dưỡng trưởng lập cho bạn và trạng thái duyệt hiện tại.
              </Typography>
              <RequestListTable
                rows={myRequests
                  .filter((request) => request.requestType === 'DEPLOYMENT')
                  .sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')))
                  .map((r) => ({
                    id: r.id,
                    typeLabel: att.requestTypeLabel(r.requestType),
                    subject: formatRequestSubject(r.employeeName || 'Tôi', r.positionTitle),
                    department: r.department,
                    summary: workRequestSummary(r),
                    meta: r.reason?.trim() || undefined,
                    statusLabel: att.requestStatusLabel(r.status, r.requestType),
                    statusColor: att.requestStatusColor(r.status),
                    dateLabel: att.formatWorkDate(r.workDate),
                    submittedAtLabel: r.createdAt
                      ? att.formatWorkDate(String(r.createdAt).slice(0, 10))
                      : undefined,
                    pending: att.isRequestPending(r.status),
                  }))}
                emptyTitle="Bạn chưa có đơn điều động nào"
                emptyHint="Khi có đơn điều động liên quan đến bạn, chúng sẽ hiện tại đây."
                onView={(row) => {
                  const r = myRequests.find((x) => x.id === Number(row.id));
                  if (r) setDetail(r);
                }}
              />
            </Stack>
          )}
          {showMyTrainingTab && user?.employeeId && tab === employeeTrainingTab && (
            <EmployeeRelatedRequestsPanel kind="training" employeeId={user.employeeId} />
          )}
          {showMyMainDutyTab && user?.employeeId && tab === employeeMainDutyTab && (
            <EmployeeRelatedRequestsPanel kind="main-duty" employeeId={user.employeeId} />
          )}
          {showMyConversionTab && user?.employeeId && tab === employeeConversionTab && (
            <EmployeeRelatedRequestsPanel kind="probation" employeeId={user.employeeId} />
          )}
          {showMyTransferTab && user?.employeeId && tab === employeeTransferTab && (
            <EmployeeRelatedRequestsPanel kind="transfer" employeeId={user.employeeId} />
          )}
          {showMyYoungChildTab && user?.employeeId && tab === employeeYoungChildTab && (
            <EmployeeRelatedRequestsPanel kind="young-child" employeeId={user.employeeId} />
          )}
          {showMyShiftConfigTab && user?.employeeId && tab === employeeShiftConfigTab && (
            <EmployeeRelatedRequestsPanel kind="shift-config" employeeId={user.employeeId} />
          )}

          {tab === leaveTabIndex && canApproveLeave && (
            <AttendancePendingPanel
              onChanged={reload}
              types={['LEAVE', 'UNPAID_LEAVE']}
              description="Nghỉ phép và nghỉ không lương: Lãnh đạo → HCNS → Giám đốc. Dùng bảng danh sách để xem, lọc và duyệt."
            />
          )}
          {tab === workTabIndex && canApproveWorkRequests && (
            <AttendancePendingPanel
              onChanged={reload}
              types={['UPDATE', 'EXPLANATION']}
              description="Cập nhật công / giải trình: Lãnh đạo → HCNS → Giám đốc. Duyệt trên bảng hoặc mở chi tiết."
            />
          )}
          {tab === deploymentTabIndex && canViewDeployments && (
            <AttendancePendingPanel
              onChanged={reload}
              types={['DEPLOYMENT']}
              description="Điều động: Trưởng khoa/Điều dưỡng trưởng lập → Trưởng phòng Điều dưỡng (khối ĐD) → HCNS → Giám đốc. Lọc theo ngày/tên để tìm đơn nhanh."
            />
          )}
          {tab === transfersTabIndex && canViewTransfers && (
            <DepartmentTransferPendingPanel
              onChanged={() => {
                setMsg('Đã cập nhật đề nghị luân chuyển.');
                setMsgSeverity('success');
              }}
            />
          )}
          {tab === conversionsTabIndex && canViewConversions && (
            <ProbationConversionPendingPanel
              onChanged={() => {
                setMsg('Đã cập nhật đơn chuyển chính thức.');
                setMsgSeverity('success');
              }}
            />
          )}
          {tab === youngChildTabIndex && canViewYoungChild && (
            <YoungChildRequestPendingPanel
              onChanged={() => {
                setMsg('Đã cập nhật đề xuất nuôi con nhỏ.');
                setMsgSeverity('success');
              }}
            />
          )}
          {tab === shiftConfigTabIndex && canViewShiftConfigChange && (
            <ShiftConfigChangePendingPanel
              onChanged={() => {
                setMsg('Đã cập nhật đề xuất chỉnh ca sáng/chiều.');
                setMsgSeverity('success');
              }}
            />
          )}
          {tab === trainingTabIndex && canViewTrainingProposals && (
            <TrainingProposalPendingPanel
              onChanged={() => {
                setMsg('Đã cập nhật phiếu đề xuất đào tạo.');
                setMsgSeverity('success');
              }}
            />
          )}
          {tab === seminarTabIndex && canViewSeminarProposals && (
            <SeminarProposalPendingPanel
              onChanged={() => {
                setMsg('Đã cập nhật phiếu đề xuất hội thảo.');
                setMsgSeverity('success');
              }}
            />
          )}
          {tab === mainDutyTabIndex && canViewMainDuty && (
            <MainDutyAuthorizationPendingPanel
              onChanged={() => {
                setMsg('Đã cập nhật đơn trực chính.');
                setMsgSeverity('success');
              }}
            />
          )}
        </Box>
      </Paper>

      <LeaveRequestDialog
        open={leaveOpen}
        onClose={() => setLeaveOpen(false)}
        onSubmitted={() => {
          setMsg('Đã gửi đơn nghỉ phép thành công.');
          setMsgSeverity('success');
          reload();
        }}
      />

      <UnpaidLeaveRequestDialog
        open={unpaidLeaveOpen}
        onClose={() => setUnpaidLeaveOpen(false)}
        onSubmitted={() => {
          setMsg('Đã gửi đơn nghỉ không lương thành công.');
          setMsgSeverity('success');
          reload();
        }}
      />

      {isNursingHead && user?.employeeId && (
        <SeminarProposalDialog
          open={seminarOpen}
          onClose={() => setSeminarOpen(false)}
          employee={{
            id: user.employeeId,
            fullName: user.fullName ?? '',
            departmentName: user.departmentName ?? undefined,
            positionTitle: user.positionTitle ?? undefined,
          }}
          onSubmitted={() => {
            setMsg('Đã gửi phiếu đề xuất hội thảo — chờ Giám đốc duyệt.');
            setMsgSeverity('success');
          }}
        />
      )}

      <WorkRequestDetailDialog
        open={Boolean(detail)}
        onClose={() => setDetail(null)}
        request={detail}
        mode="mine"
        onChanged={reload}
      />
    </Box>
  );
}
