import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import DrawIcon from '@mui/icons-material/Draw';
import EditOutlinedIcon from '@mui/icons-material/EditOutlined';
import FilterListIcon from '@mui/icons-material/FilterList';
import HourglassEmptyIcon from '@mui/icons-material/HourglassEmpty';
import KeyIcon from '@mui/icons-material/VpnKey';
import ManageAccountsIcon from '@mui/icons-material/ManageAccounts';
import PersonAddAlt1Icon from '@mui/icons-material/PersonAddAlt1';
import PhoneAndroidIcon from '@mui/icons-material/PhoneAndroid';
import RefreshIcon from '@mui/icons-material/Refresh';
import SearchIcon from '@mui/icons-material/Search';
import VerifiedUserIcon from '@mui/icons-material/VerifiedUser';
import WarningAmberIcon from '@mui/icons-material/WarningAmber';
import {
  Alert,
  Avatar,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  IconButton,
  InputAdornment,
  MenuItem,
  Paper,
  Snackbar,
  Stack,
  Switch,
  Tab,
  Tabs,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import * as departmentService from '../services/departmentService';
import * as employeeService from '../services/employeeService';
import * as userAccountAdminService from '../services/userAccountAdminService';
import { getRoleLabel } from '../utils/roleLabels';

const ROLE_OPTIONS = [
  'ADMIN',
  'DIRECTOR',
  'HR',
  'HR2',
  'HEAD_DEPARTMENT',
  'HEAD_HR',
  'HEAD_NURSING',
  'EMPLOYEE',
] as const;

function initials(name?: string | null) {
  if (!name?.trim()) return '?';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function StatusPill({
  ok,
  okLabel,
  badLabel,
  okColor = 'success',
}: {
  ok: boolean;
  okLabel: string;
  badLabel: string;
  okColor?: 'success' | 'primary';
}) {
  return (
    <Chip
      size="small"
      label={ok ? okLabel : badLabel}
      color={ok ? okColor : 'default'}
      variant={ok ? 'filled' : 'outlined'}
      sx={{
        fontWeight: 600,
        fontSize: '0.72rem',
        height: 24,
        ...(ok
          ? {}
          : {
              borderColor: 'divider',
              color: 'text.secondary',
              bgcolor: 'transparent',
            }),
      }}
    />
  );
}

export default function AccountAdminPage() {
  const theme = useTheme();
  const [tab, setTab] = useState(0);
  const [rows, setRows] = useState<userAccountAdminService.UserAccountAdminRow[]>([]);
  const [candidates, setCandidates] = useState<userAccountAdminService.EmployeeWithoutAccount[]>([]);
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [allWorkUnits, setAllWorkUnits] = useState<departmentService.WorkUnitRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [qInput, setQInput] = useState('');
  const [q, setQ] = useState('');
  const [filterDept, setFilterDept] = useState<number | ''>('');
  const [filterWorkUnit, setFilterWorkUnit] = useState('');
  const [filterRole, setFilterRole] = useState('');
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [total, setTotal] = useState(0);
  const [totalAccounts, setTotalAccounts] = useState(0);
  const [totalInactive, setTotalInactive] = useState(0);
  const [totalMissing, setTotalMissing] = useState(0);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [grantTarget, setGrantTarget] = useState<userAccountAdminService.EmployeeWithoutAccount | null>(null);
  const [grantPhone, setGrantPhone] = useState('');
  const [grantAttendance, setGrantAttendance] = useState('');
  const [grantRole, setGrantRole] = useState('EMPLOYEE');
  const [grantPassword, setGrantPassword] = useState('123');
  const [granting, setGranting] = useState(false);
  const [editTarget, setEditTarget] = useState<userAccountAdminService.UserAccountAdminRow | null>(null);
  const [editPhone, setEditPhone] = useState('');
  const [editAttendance, setEditAttendance] = useState('');
  const [editing, setEditing] = useState(false);
  const [snack, setSnack] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
    open: false,
    message: '',
    severity: 'success',
  });

  useEffect(() => {
    const t = setTimeout(() => {
      setQ(qInput);
      setPage(0);
    }, 350);
    return () => clearTimeout(t);
  }, [qInput]);

  useEffect(() => {
    employeeService.fetchDepartments().then(setDepartments).catch(() => setDepartments([]));
    departmentService.fetchAllWorkUnits().then(setAllWorkUnits).catch(() => setAllWorkUnits([]));
  }, []);

  const workUnitOptions = useMemo(() => {
    const scoped =
      filterDept === ''
        ? allWorkUnits
        : allWorkUnits.filter((u) => u.departmentId === filterDept);
    const names = Array.from(new Set(scoped.map((u) => u.name).filter(Boolean)));
    names.sort((a, b) => a.localeCompare(b, 'vi'));
    return names;
  }, [allWorkUnits, filterDept]);

  useEffect(() => {
    if (filterWorkUnit && !workUnitOptions.includes(filterWorkUnit)) {
      setFilterWorkUnit('');
    }
  }, [workUnitOptions, filterWorkUnit]);

  const loadCounts = useCallback(async () => {
    try {
      const [acc, inactive, miss] = await Promise.all([
        userAccountAdminService.fetchUserAccounts({ page: 0, size: 1 }),
        userAccountAdminService.fetchUserAccounts({ page: 0, size: 1, inactiveOnly: true }),
        userAccountAdminService.fetchEmployeesWithoutAccount({ page: 0, size: 1 }),
      ]);
      setTotalAccounts(acc.totalElements);
      setTotalInactive(inactive.totalElements);
      setTotalMissing(miss.totalElements);
    } catch {
      /* ignore */
    }
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      if (tab === 0 || tab === 1) {
        const data = await userAccountAdminService.fetchUserAccounts({
          q: q || undefined,
          departmentId: filterDept === '' ? undefined : filterDept,
          workUnitDetail: filterWorkUnit || undefined,
          role: filterRole || undefined,
          inactiveOnly: tab === 1 ? true : undefined,
          page,
          size: rowsPerPage,
        });
        setRows(data.content);
        setTotal(data.totalElements);
        setCandidates([]);
      } else {
        const data = await userAccountAdminService.fetchEmployeesWithoutAccount({
          q: q || undefined,
          departmentId: filterDept === '' ? undefined : filterDept,
          workUnitDetail: filterWorkUnit || undefined,
          page,
          size: rowsPerPage,
        });
        setCandidates(data.content);
        setTotal(data.totalElements);
        setRows([]);
      }
      await loadCounts();
    } catch {
      setRows([]);
      setCandidates([]);
      setTotal(0);
      setSnack({ open: true, message: 'Không tải được danh sách (cần quyền ADMIN).', severity: 'error' });
    } finally {
      setLoading(false);
    }
  }, [tab, q, filterDept, filterWorkUnit, filterRole, page, rowsPerPage, loadCounts]);

  useEffect(() => {
    void load();
  }, [load]);

  async function onRoleChange(userId: number, role: string) {
    setBusyKey(`role-${userId}`);
    try {
      await userAccountAdminService.updateUserAccountRole(userId, role);
      setSnack({ open: true, message: 'Đã cập nhật vai trò.', severity: 'success' });
      await load();
    } catch {
      setSnack({ open: true, message: 'Không đổi được vai trò.', severity: 'error' });
    } finally {
      setBusyKey(null);
    }
  }

  async function onToggleEnabled(userId: number, enabled: boolean) {
    setBusyKey(`en-${userId}`);
    try {
      await userAccountAdminService.setUserAccountEnabled(userId, enabled);
      setSnack({ open: true, message: enabled ? 'Đã mở khóa tài khoản.' : 'Đã khóa tài khoản.', severity: 'success' });
      await load();
    } catch {
      setSnack({ open: true, message: 'Không cập nhật được trạng thái.', severity: 'error' });
    } finally {
      setBusyKey(null);
    }
  }

  async function onToggleDirectorApproval(userId: number, enabled: boolean) {
    setBusyKey(`approve-${userId}`);
    try {
      await userAccountAdminService.setDirectorApprovalEnabled(userId, enabled);
      setSnack({
        open: true,
        message: enabled ? 'Đã bật quyền duyệt đơn.' : 'Đã tắt quyền duyệt đơn.',
        severity: 'success',
      });
      await load();
    } catch {
      setSnack({ open: true, message: 'Không cập nhật được quyền duyệt đơn.', severity: 'error' });
    } finally {
      setBusyKey(null);
    }
  }

  async function onToggleReportView(userId: number, enabled: boolean) {
    setBusyKey(`report-${userId}`);
    try {
      await userAccountAdminService.setReportViewEnabled(userId, enabled);
      setSnack({
        open: true,
        message: enabled ? 'Đã bật quyền xem báo cáo.' : 'Đã tắt quyền xem báo cáo.',
        severity: 'success',
      });
      await load();
    } catch {
      setSnack({ open: true, message: 'Không cập nhật được quyền xem báo cáo.', severity: 'error' });
    } finally {
      setBusyKey(null);
    }
  }

  async function onToggleWorkUnitScoped(userId: number, enabled: boolean) {
    setBusyKey(`unit-${userId}`);
    try {
      await userAccountAdminService.setWorkUnitScoped(userId, enabled);
      setSnack({
        open: true,
        message: enabled
          ? 'Đã bật Trưởng bộ phận — chỉ quản lý bộ phận của mình.'
          : 'Đã tắt Trưởng bộ phận — quản lý cả khoa/phòng.',
        severity: 'success',
      });
      await load();
    } catch (e: unknown) {
      const message =
        (e as { response?: { data?: { message?: string } } })?.response?.data?.message ||
        'Không cập nhật được Trưởng bộ phận.';
      setSnack({ open: true, message, severity: 'error' });
    } finally {
      setBusyKey(null);
    }
  }

  async function onResetPassword(userId: number) {
    if (!window.confirm('Reset mật khẩu về mặc định (123) và bắt đổi mật khẩu lần đăng nhập sau?')) return;
    setBusyKey(`pw-${userId}`);
    try {
      await userAccountAdminService.resetUserAccountPassword(userId);
      setSnack({ open: true, message: 'Đã reset mật khẩu.', severity: 'success' });
      await load();
    } catch {
      setSnack({ open: true, message: 'Không reset được mật khẩu.', severity: 'error' });
    } finally {
      setBusyKey(null);
    }
  }

  function openEditIdentifiers(row: userAccountAdminService.UserAccountAdminRow) {
    setEditTarget(row);
    // Ưu tiên SĐT hồ sơ; nếu trống thì lấy TK (thường cũng là SĐT)
    setEditPhone(row.phone || row.username || '');
    setEditAttendance(row.attendanceCode || '');
  }

  async function submitIdentifiers() {
    if (!editTarget) return;
    const phone = editPhone.trim();
    if (!phone) {
      setSnack({ open: true, message: 'Số điện thoại không được để trống (dùng làm TK đăng nhập).', severity: 'error' });
      return;
    }

    setEditing(true);
    try {
      // Luôn gửi SĐT để backend đồng bộ TK đăng nhập = SĐT liên hệ
      await userAccountAdminService.updateUserAccountIdentifiers(editTarget.userId, {
        phone,
        attendanceCode: editAttendance.trim(),
      });
      setSnack({
        open: true,
        message: `Đã cập nhật SĐT/TK đăng nhập và mã chấm công của ${editTarget.fullName || editTarget.username}.`,
        severity: 'success',
      });
      setEditTarget(null);
      await load();
    } catch (e: unknown) {
      const message =
        (e as { response?: { data?: { message?: string } } })?.response?.data?.message ||
        'Không cập nhật được SĐT hoặc mã chấm công.';
      setSnack({ open: true, message, severity: 'error' });
    } finally {
      setEditing(false);
    }
  }

  function openGrant(c: userAccountAdminService.EmployeeWithoutAccount) {
    setGrantTarget(c);
    setGrantPhone(c.phone || '');
    setGrantAttendance(c.attendanceCode || '');
    setGrantRole('EMPLOYEE');
    setGrantPassword('123');
  }

  async function submitGrant() {
    if (!grantTarget) return;
    const phone = grantPhone.trim();
    if (!phone) {
      setSnack({ open: true, message: 'Nhập số điện thoại để làm tên đăng nhập.', severity: 'error' });
      return;
    }
    setGranting(true);
    try {
      await userAccountAdminService.grantLocalUserAccount({
        employeeId: grantTarget.employeeId,
        phone,
        attendanceCode: grantAttendance.trim() || undefined,
        role: grantRole,
        password: grantPassword.trim() || undefined,
      });
      setSnack({
        open: true,
        message: `Đã cấp tài khoản cho ${grantTarget.fullName}. Username = SĐT, mật khẩu mặc định ${grantPassword || '123'}.`,
        severity: 'success',
      });
      setGrantTarget(null);
      await load();
    } catch (e: unknown) {
      const msg =
        (e as { response?: { data?: { message?: string } } })?.response?.data?.message ||
        'Không cấp được tài khoản.';
      setSnack({ open: true, message: msg, severity: 'error' });
    } finally {
      setGranting(false);
    }
  }

  const cardSx = {
    borderRadius: 3,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
    bgcolor: alpha(theme.palette.background.paper, 0.96),
    boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
    overflow: 'hidden' as const,
  };

  const headCellSx = {
    fontWeight: 700,
    fontSize: '0.72rem',
    letterSpacing: '0.04em',
    textTransform: 'uppercase' as const,
    color: 'text.secondary',
    bgcolor: alpha(theme.palette.primary.main, 0.04),
    borderBottom: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
    whiteSpace: 'nowrap' as const,
    py: 1.5,
  };

  const filterFieldSx = {
    minWidth: { xs: '100%', sm: 160 },
    '& .MuiOutlinedInput-root': {
      bgcolor: alpha(theme.palette.background.default, 0.6),
    },
  };

  return (
    <Box>
      <PageHeader
        overline="Quản trị"
        title="Tài khoản đăng nhập"
        description="Quản lý tài khoản HRM độc lập: phân quyền theo vai trò & khoa, theo dõi tài khoản chưa kích hoạt (chưa đổi MK / chưa ký), bổ sung SĐT / mã chấm công, reset mật khẩu lần đầu."
      />

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr', md: '1fr 1fr 1fr' },
          gap: 2,
          mb: 2.5,
        }}
      >
        <Paper
          elevation={0}
          sx={{
            ...cardSx,
            p: 2.25,
            display: 'flex',
            alignItems: 'center',
            gap: 2,
            cursor: 'pointer',
            outline: tab === 0 ? `2px solid ${alpha(theme.palette.primary.main, 0.35)}` : 'none',
            transition: 'outline 0.15s ease',
          }}
          onClick={() => {
            setTab(0);
            setPage(0);
          }}
        >
          <Avatar
            sx={{
              width: 48,
              height: 48,
              bgcolor: alpha(theme.palette.primary.main, 0.12),
              color: 'primary.main',
            }}
          >
            <VerifiedUserIcon />
          </Avatar>
          <Box sx={{ minWidth: 0 }}>
            <Typography variant="overline" sx={{ color: 'text.secondary', letterSpacing: '0.08em' }}>
              Đã có tài khoản
            </Typography>
            <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1.1 }}>
              {totalAccounts.toLocaleString('vi-VN')}
            </Typography>
          </Box>
        </Paper>
        <Paper
          elevation={0}
          sx={{
            ...cardSx,
            p: 2.25,
            display: 'flex',
            alignItems: 'center',
            gap: 2,
            cursor: 'pointer',
            outline: tab === 1 ? `2px solid ${alpha(theme.palette.info.main, 0.45)}` : 'none',
            transition: 'outline 0.15s ease',
          }}
          onClick={() => {
            setTab(1);
            setPage(0);
          }}
        >
          <Avatar
            sx={{
              width: 48,
              height: 48,
              bgcolor: alpha(theme.palette.info.main, 0.14),
              color: 'info.dark',
            }}
          >
            <HourglassEmptyIcon />
          </Avatar>
          <Box sx={{ minWidth: 0 }}>
            <Typography variant="overline" sx={{ color: 'text.secondary', letterSpacing: '0.08em' }}>
              Chưa kích hoạt tài khoản
            </Typography>
            <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1.1 }}>
              {totalInactive.toLocaleString('vi-VN')}
            </Typography>
          </Box>
        </Paper>
        <Paper
          elevation={0}
          sx={{
            ...cardSx,
            p: 2.25,
            display: 'flex',
            alignItems: 'center',
            gap: 2,
            cursor: 'pointer',
            outline: tab === 2 ? `2px solid ${alpha(theme.palette.warning.main, 0.45)}` : 'none',
            transition: 'outline 0.15s ease',
          }}
          onClick={() => {
            setTab(2);
            setPage(0);
          }}
        >
          <Avatar
            sx={{
              width: 48,
              height: 48,
              bgcolor: alpha(theme.palette.warning.main, 0.14),
              color: 'warning.dark',
            }}
          >
            <WarningAmberIcon />
          </Avatar>
          <Box sx={{ minWidth: 0 }}>
            <Typography variant="overline" sx={{ color: 'text.secondary', letterSpacing: '0.08em' }}>
              Thiếu SĐT / mã chấm công
            </Typography>
            <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1.1 }}>
              {totalMissing.toLocaleString('vi-VN')}
            </Typography>
          </Box>
        </Paper>
      </Box>

      <Paper elevation={0} sx={{ ...cardSx, mb: 2.5 }}>
        <Tabs
          value={tab}
          onChange={(_, v) => {
            setTab(v);
            setPage(0);
          }}
          sx={{
            px: 1.5,
            minHeight: 52,
            borderBottom: `1px solid ${theme.palette.divider}`,
            '& .MuiTab-root': {
              minHeight: 52,
              textTransform: 'none',
              fontWeight: 600,
              fontSize: '0.9375rem',
            },
          }}
        >
          <Tab
            icon={<VerifiedUserIcon fontSize="small" />}
            iconPosition="start"
            label={`Đã có tài khoản (${totalAccounts})`}
          />
          <Tab
            icon={<HourglassEmptyIcon fontSize="small" />}
            iconPosition="start"
            label={`Chưa kích hoạt (${totalInactive})`}
          />
          <Tab
            icon={<WarningAmberIcon fontSize="small" />}
            iconPosition="start"
            label={`Thiếu SĐT / mã CC (${totalMissing})`}
          />
        </Tabs>

        <Stack
          direction="row"
          alignItems="center"
          spacing={1}
          sx={{
            px: 2.25,
            pt: 2,
            pb: 0.5,
          }}
        >
          <FilterListIcon fontSize="small" color="primary" />
          <Typography variant="subtitle2" fontWeight={700}>
            Bộ lọc
          </Typography>
        </Stack>

        <Stack
          direction={{ xs: 'column', md: 'row' }}
          spacing={1.5}
          useFlexGap
          flexWrap="wrap"
          sx={{ px: 2.25, pb: 2.25, pt: 1 }}
        >
          <TextField
            size="small"
            placeholder="Tìm họ tên, SĐT, mã chấm công, mã NV…"
            value={qInput}
            onChange={(e) => setQInput(e.target.value)}
            sx={{ ...filterFieldSx, flex: 1, minWidth: { xs: '100%', md: 240 } }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon fontSize="small" color="action" />
                </InputAdornment>
              ),
            }}
          />
          <TextField
            size="small"
            select
            label="Phòng ban / khoa"
            value={filterDept}
            onChange={(e) => {
              setFilterDept(e.target.value === '' ? '' : Number(e.target.value));
              setFilterWorkUnit('');
              setPage(0);
            }}
            sx={filterFieldSx}
          >
            <MenuItem value="">Tất cả khoa</MenuItem>
            {departments.map((d) => (
              <MenuItem key={d.id} value={d.id}>
                {d.name}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            size="small"
            select
            label="Bộ phận"
            value={filterWorkUnit}
            onChange={(e) => {
              setFilterWorkUnit(e.target.value);
              setPage(0);
            }}
            sx={filterFieldSx}
          >
            <MenuItem value="">Tất cả bộ phận</MenuItem>
            {workUnitOptions.map((name) => (
              <MenuItem key={name} value={name}>
                {name}
              </MenuItem>
            ))}
          </TextField>
          {(tab === 0 || tab === 1) && (
            <TextField
              size="small"
              select
              label="Vai trò"
              value={filterRole}
              onChange={(e) => {
                setFilterRole(e.target.value);
                setPage(0);
              }}
              sx={filterFieldSx}
            >
              <MenuItem value="">Tất cả vai trò</MenuItem>
              {ROLE_OPTIONS.map((role) => (
                <MenuItem key={role} value={role}>
                  {getRoleLabel(role)}
                </MenuItem>
              ))}
            </TextField>
          )}
          <Button
            variant="outlined"
            startIcon={<RefreshIcon />}
            onClick={() => void load()}
            sx={{ height: 40, px: 2, whiteSpace: 'nowrap' }}
          >
            Tải lại
          </Button>
        </Stack>
      </Paper>

      <Paper elevation={0} sx={cardSx}>
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
            <CircularProgress size={36} />
          </Box>
        ) : tab === 0 || tab === 1 ? (
          <TableContainer>
            <Table size="small" sx={{ tableLayout: 'auto' }}>
              <TableHead>
                <TableRow>
                  <TableCell sx={{ ...headCellSx, minWidth: 210 }}>Nhân viên / tài khoản</TableCell>
                  <TableCell sx={{ ...headCellSx, minWidth: 190 }}>Đơn vị công tác</TableCell>
                  <TableCell sx={headCellSx}>Chức vụ</TableCell>
                  <TableCell sx={{ ...headCellSx, minWidth: 145 }}>Liên hệ / chấm công</TableCell>
                  <TableCell sx={{ ...headCellSx, minWidth: 150 }}>Vai trò</TableCell>
                  <TableCell align="center" sx={headCellSx}>
                    Trạng thái
                  </TableCell>
                  <TableCell align="center" sx={headCellSx}>
                    Hiệu lực
                  </TableCell>
                  <TableCell align="center" sx={{ ...headCellSx, minWidth: 120 }}>
                    Phân quyền
                  </TableCell>
                  <TableCell align="right" sx={headCellSx}>
                    Thao tác
                  </TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {rows.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={9}>
                      <Stack alignItems="center" spacing={1} sx={{ py: 6 }}>
                        {tab === 1 ? (
                          <HourglassEmptyIcon sx={{ fontSize: 40, color: 'text.disabled' }} />
                        ) : (
                          <ManageAccountsIcon sx={{ fontSize: 40, color: 'text.disabled' }} />
                        )}
                        <Typography color="text.secondary">
                          {tab === 1
                            ? 'Không còn tài khoản chưa đổi mật khẩu hoặc chưa ký khớp bộ lọc.'
                            : 'Không có tài khoản khớp bộ lọc.'}
                        </Typography>
                      </Stack>
                    </TableCell>
                  </TableRow>
                ) : (
                  rows.map((r) => (
                    <TableRow
                      key={r.userId}
                      hover
                      sx={{
                        '&:last-child td': { borderBottom: 0 },
                        '& td': { py: 1.35, verticalAlign: 'middle' },
                      }}
                    >
                      <TableCell>
                        <Stack direction="row" spacing={1.25} alignItems="center">
                          <Avatar
                            sx={{
                              width: 36,
                              height: 36,
                              fontSize: '0.8rem',
                              fontWeight: 700,
                              bgcolor: alpha(theme.palette.primary.main, 0.12),
                              color: 'primary.dark',
                            }}
                          >
                            {initials(r.fullName || r.username)}
                          </Avatar>
                          <Box sx={{ minWidth: 0 }}>
                            <Typography fontWeight={700} sx={{ lineHeight: 1.35 }}>
                              {r.fullName || r.displayName || '—'}
                            </Typography>
                            <Typography variant="caption" color="text.secondary" display="block">
                              TK · {r.username}
                            </Typography>
                            <Typography variant="caption" color="text.secondary" display="block">
                              Mã NV · {r.employeeCode || '—'}
                            </Typography>
                          </Box>
                        </Stack>
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2" fontWeight={600}>
                          {r.departmentName || '—'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          {r.workUnitDetail || 'Chưa có bộ phận'}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2">{r.positionTitle || '—'}</Typography>
                      </TableCell>
                      <TableCell>
                        <Stack spacing={0.6}>
                          <Stack direction="row" spacing={0.75} alignItems="center">
                            <PhoneAndroidIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                            <Typography variant="body2" fontWeight={600}>
                              {r.phone || 'Chưa có SĐT'}
                            </Typography>
                          </Stack>
                          <Stack direction="row" spacing={0.75} alignItems="center">
                            <BadgeOutlinedIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                            <Typography
                              variant="caption"
                              color={r.attendanceCode ? 'text.primary' : 'text.secondary'}
                              fontWeight={r.attendanceCode ? 700 : 500}
                            >
                              {r.attendanceCode ? `Mã CC · ${r.attendanceCode}` : 'Chưa có mã CC'}
                            </Typography>
                          </Stack>
                        </Stack>
                      </TableCell>
                      <TableCell>
                        <TextField
                          size="small"
                          select
                          value={r.role}
                          disabled={busyKey === `role-${r.userId}`}
                          onChange={(e) => void onRoleChange(r.userId, e.target.value)}
                          sx={{
                            minWidth: 148,
                            '& .MuiOutlinedInput-root': {
                              bgcolor: alpha(theme.palette.primary.main, 0.03),
                            },
                          }}
                        >
                          {ROLE_OPTIONS.map((role) => (
                            <MenuItem key={role} value={role}>
                              {getRoleLabel(role, r.positionTitle)}
                            </MenuItem>
                          ))}
                        </TextField>
                      </TableCell>
                      <TableCell align="center">
                        <Stack direction="row" spacing={0.75} justifyContent="center" flexWrap="wrap" useFlexGap>
                          <Tooltip title="Bắt buộc đổi mật khẩu lần đầu">
                            <span>
                              <StatusPill
                                ok={!r.mustChangePassword}
                                okLabel="MK OK"
                                badLabel="Đổi MK"
                              />
                            </span>
                          </Tooltip>
                          <Tooltip title="Chữ ký số">
                            <span>
                              <StatusPill
                                ok={r.hasSignature}
                                okLabel="Đã ký"
                                badLabel="Chưa ký"
                                okColor="primary"
                              />
                            </span>
                          </Tooltip>
                        </Stack>
                      </TableCell>
                      <TableCell align="center">
                        <Switch
                          checked={r.enabled}
                          disabled={busyKey === `en-${r.userId}`}
                          onChange={(e) => void onToggleEnabled(r.userId, e.target.checked)}
                          color="primary"
                        />
                      </TableCell>
                      <TableCell align="center">
                        <Stack
                          direction="row"
                          spacing={1.5}
                          justifyContent="center"
                          alignItems="center"
                          flexWrap="wrap"
                          useFlexGap
                        >
                          <Tooltip title="Xem menu Báo cáo (nhân lực toàn viện / đi làm hằng ngày)">
                            <Stack alignItems="center" spacing={0.25}>
                              <Typography variant="caption" color="text.secondary" fontWeight={600}>
                                Báo cáo
                              </Typography>
                              <Switch
                                checked={r.reportViewEnabled}
                                disabled={busyKey === `report-${r.userId}` || !r.enabled}
                                onChange={(e) =>
                                  void onToggleReportView(r.userId, e.target.checked)
                                }
                                color="secondary"
                              />
                            </Stack>
                          </Tooltip>
                          {r.role === 'DIRECTOR' ? (
                            <Tooltip title="Nhận hàng đợi và thông báo duyệt cấp Giám đốc">
                              <Stack alignItems="center" spacing={0.25}>
                                <Typography variant="caption" color="text.secondary" fontWeight={600}>
                                  Duyệt đơn
                                </Typography>
                                <Switch
                                  checked={r.directorApprovalEnabled}
                                  disabled={busyKey === `approve-${r.userId}` || !r.enabled}
                                  onChange={(e) =>
                                    void onToggleDirectorApproval(r.userId, e.target.checked)
                                  }
                                  color="secondary"
                                />
                              </Stack>
                            </Tooltip>
                          ) : null}
                          {r.role === 'HEAD_DEPARTMENT' || r.role === 'HEAD_HR' ? (
                            <Tooltip
                              title={
                                r.workUnitDetail
                                  ? `Chỉ quản lý bộ phận: ${r.workUnitDetail}`
                                  : 'Cần có bộ phận trên hồ sơ trước khi bật'
                              }
                            >
                              <span>
                                <Stack alignItems="center" spacing={0.25}>
                                  <Typography variant="caption" color="text.secondary" fontWeight={600}>
                                    Trưởng BP
                                  </Typography>
                                  <Switch
                                    checked={r.workUnitScoped}
                                    disabled={
                                      busyKey === `unit-${r.userId}` ||
                                      !r.enabled ||
                                      (!r.workUnitDetail && !r.workUnitScoped)
                                    }
                                    onChange={(e) =>
                                      void onToggleWorkUnitScoped(r.userId, e.target.checked)
                                    }
                                    color="secondary"
                                  />
                                </Stack>
                              </span>
                            </Tooltip>
                          ) : null}
                        </Stack>
                      </TableCell>
                      <TableCell align="right">
                        <Stack direction="row" spacing={0.5} justifyContent="flex-end">
                          <Tooltip title="Sửa SĐT / mã chấm công">
                            <span>
                              <IconButton
                                size="small"
                                color="primary"
                                disabled={!r.employeeId}
                                onClick={() => openEditIdentifiers(r)}
                              >
                                <EditOutlinedIcon fontSize="small" />
                              </IconButton>
                            </span>
                          </Tooltip>
                          <Tooltip title="Reset mật khẩu">
                            <span>
                              <IconButton
                                size="small"
                                color="primary"
                                disabled={busyKey === `pw-${r.userId}`}
                                onClick={() => void onResetPassword(r.userId)}
                              >
                                <KeyIcon fontSize="small" />
                              </IconButton>
                            </span>
                          </Tooltip>
                        </Stack>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </TableContainer>
        ) : (
          <TableContainer>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell sx={headCellSx}>Nhân sự</TableCell>
                  <TableCell sx={headCellSx}>Mã NV</TableCell>
                  <TableCell sx={headCellSx}>Khoa / bộ phận</TableCell>
                  <TableCell sx={headCellSx}>Chức vụ</TableCell>
                  <TableCell sx={headCellSx}>SĐT</TableCell>
                  <TableCell sx={headCellSx}>Mã chấm công</TableCell>
                  <TableCell align="right" sx={headCellSx}>
                    Thao tác
                  </TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {candidates.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7}>
                      <Stack alignItems="center" spacing={1} sx={{ py: 6 }}>
                        <BadgeOutlinedIcon sx={{ fontSize: 40, color: 'text.disabled' }} />
                        <Typography color="text.secondary">
                          Không còn nhân sự thiếu SĐT hoặc mã chấm công khớp bộ lọc.
                        </Typography>
                      </Stack>
                    </TableCell>
                  </TableRow>
                ) : (
                  candidates.map((c) => (
                    <TableRow
                      key={c.employeeId}
                      hover
                      sx={{
                        '&:last-child td': { borderBottom: 0 },
                        '& td': { py: 1.4, verticalAlign: 'middle' },
                      }}
                    >
                      <TableCell>
                        <Stack direction="row" spacing={1.25} alignItems="center">
                          <Avatar
                            sx={{
                              width: 36,
                              height: 36,
                              fontSize: '0.8rem',
                              fontWeight: 700,
                              bgcolor: alpha(theme.palette.warning.main, 0.16),
                              color: 'warning.dark',
                            }}
                          >
                            {initials(c.fullName)}
                          </Avatar>
                          <Typography fontWeight={700}>{c.fullName}</Typography>
                        </Stack>
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2" color="text.secondary">
                          {c.employeeCode || '—'}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2" fontWeight={600}>
                          {c.departmentName || '—'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          {c.workUnitDetail || 'Chưa có bộ phận'}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2">{c.positionTitle || '—'}</Typography>
                      </TableCell>
                      <TableCell>
                        {c.missingPhone ? (
                          <Chip
                            size="small"
                            icon={<PhoneAndroidIcon />}
                            color="warning"
                            label="Chưa có SĐT"
                            sx={{ fontWeight: 700 }}
                          />
                        ) : (
                          <Typography variant="body2" fontWeight={600}>
                            {c.phone}
                          </Typography>
                        )}
                      </TableCell>
                      <TableCell>
                        {c.missingAttendanceCode ? (
                          <Chip
                            size="small"
                            variant="outlined"
                            icon={<BadgeOutlinedIcon />}
                            label="Chưa có mã"
                            sx={{ fontWeight: 600 }}
                          />
                        ) : (
                          <Typography variant="body2" fontWeight={600}>
                            {c.attendanceCode}
                          </Typography>
                        )}
                      </TableCell>
                      <TableCell align="right">
                        <Button
                          size="small"
                          variant="contained"
                          startIcon={<PersonAddAlt1Icon />}
                          onClick={() => openGrant(c)}
                          sx={{ fontWeight: 700, px: 1.75 }}
                        >
                          Cấp tài khoản
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </TableContainer>
        )}
        <Divider />
        <TablePagination
          component="div"
          count={total}
          page={page}
          onPageChange={(_, p) => setPage(p)}
          rowsPerPage={rowsPerPage}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(Number(e.target.value));
            setPage(0);
          }}
          rowsPerPageOptions={[10, 25, 50, 100]}
          labelRowsPerPage="Số dòng"
          sx={{
            '.MuiTablePagination-toolbar': { px: 2 },
            '.MuiTablePagination-selectLabel, .MuiTablePagination-displayedRows': {
              fontWeight: 500,
            },
          }}
        />
      </Paper>

      <Dialog
        open={!!grantTarget}
        onClose={() => !granting && setGrantTarget(null)}
        fullWidth
        maxWidth="sm"
        PaperProps={{
          sx: {
            borderRadius: 3,
            border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
          },
        }}
      >
        <DialogTitle sx={{ pb: 1.5 }}>
          <Stack direction="row" spacing={1.5} alignItems="center">
            <Avatar sx={{ bgcolor: alpha(theme.palette.primary.main, 0.12), color: 'primary.main' }}>
              <PersonAddAlt1Icon />
            </Avatar>
            <Box>
              <Typography variant="h6" fontWeight={700}>
                Cấp tài khoản đăng nhập
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Gán SĐT làm username và mã chấm công
              </Typography>
            </Box>
          </Stack>
        </DialogTitle>
        <DialogContent dividers>
          {grantTarget && (
            <Stack spacing={2.25}>
              <Paper
                elevation={0}
                sx={{
                  p: 1.75,
                  borderRadius: 2,
                  bgcolor: alpha(theme.palette.primary.main, 0.04),
                  border: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
                }}
              >
                <Typography fontWeight={700}>{grantTarget.fullName}</Typography>
                <Typography variant="body2" color="text.secondary">
                  {[grantTarget.employeeCode, grantTarget.departmentName, grantTarget.positionTitle]
                    .filter(Boolean)
                    .join(' · ')}
                </Typography>
              </Paper>
              <Alert severity="info" icon={<DrawIcon fontSize="inherit" />}>
                Sau khi cấp, lần đăng nhập đầu sẽ yêu cầu đổi mật khẩu và tạo chữ ký số.
              </Alert>
              <TextField
                label="Số điện thoại"
                value={grantPhone}
                onChange={(e) => setGrantPhone(e.target.value)}
                fullWidth
                required
                helperText="Bắt buộc — dùng làm username đăng nhập"
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <PhoneAndroidIcon fontSize="small" color="action" />
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                label="Mã chấm công"
                value={grantAttendance}
                onChange={(e) => setGrantAttendance(e.target.value)}
                fullWidth
                helperText="Mã máy chấm công (UserEnrollNumber)"
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <BadgeOutlinedIcon fontSize="small" color="action" />
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                select
                label="Vai trò"
                value={grantRole}
                onChange={(e) => setGrantRole(e.target.value)}
                fullWidth
              >
                {ROLE_OPTIONS.map((role) => (
                  <MenuItem key={role} value={role}>
                    {getRoleLabel(role, grantTarget?.positionTitle)}
                  </MenuItem>
                ))}
              </TextField>
              <TextField
                label="Mật khẩu tạm"
                value={grantPassword}
                onChange={(e) => setGrantPassword(e.target.value)}
                fullWidth
                helperText="Mặc định 123 — bắt buộc đổi ở lần đầu"
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <KeyIcon fontSize="small" color="action" />
                    </InputAdornment>
                  ),
                }}
              />
            </Stack>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, py: 2 }}>
          <Button onClick={() => setGrantTarget(null)} disabled={granting}>
            Hủy
          </Button>
          <Button
            variant="contained"
            startIcon={<PersonAddAlt1Icon />}
            onClick={() => void submitGrant()}
            disabled={granting}
            sx={{ fontWeight: 700 }}
          >
            {granting ? 'Đang cấp…' : 'Cấp tài khoản'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={!!editTarget}
        onClose={() => !editing && setEditTarget(null)}
        fullWidth
        maxWidth="sm"
        PaperProps={{
          sx: {
            borderRadius: 3,
            border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
          },
        }}
      >
        <DialogTitle sx={{ pb: 1.5 }}>
          <Stack direction="row" spacing={1.5} alignItems="center">
            <Avatar sx={{ bgcolor: alpha(theme.palette.primary.main, 0.12), color: 'primary.main' }}>
              <EditOutlinedIcon />
            </Avatar>
            <Box>
              <Typography variant="h6" fontWeight={700}>
                Sửa thông tin tài khoản
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {editTarget?.fullName || editTarget?.displayName || editTarget?.username}
              </Typography>
            </Box>
          </Stack>
        </DialogTitle>
        <DialogContent dividers>
          <Stack spacing={2.25}>
            <Alert severity="info">
              SĐT liên hệ và TK đăng nhập luôn cùng một số. Đổi SĐT tại đây thì tên đăng nhập cũng đổi theo.
              {editTarget?.username &&
                editTarget?.phone &&
                editTarget.username.replace(/\D/g, '') !== editTarget.phone.replace(/\D/g, '') && (
                  <>
                    {' '}
                    Hiện đang lệch: TK <strong>{editTarget.username}</strong> ≠ SĐT{' '}
                    <strong>{editTarget.phone}</strong> — bấm Lưu để đồng bộ.
                  </>
                )}
            </Alert>
            <TextField
              label="Số điện thoại / TK đăng nhập"
              value={editPhone}
              onChange={(e) => setEditPhone(e.target.value)}
              fullWidth
              autoFocus
              helperText="Dùng chung cho liên hệ và đăng nhập hệ thống"
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <PhoneAndroidIcon fontSize="small" color="action" />
                  </InputAdornment>
                ),
              }}
            />
            <TextField
              label="Mã chấm công"
              value={editAttendance}
              onChange={(e) => setEditAttendance(e.target.value)}
              fullWidth
              helperText="Để trống nếu nhân viên chưa được cấp mã chấm công"
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <BadgeOutlinedIcon fontSize="small" color="action" />
                  </InputAdornment>
                ),
              }}
            />
          </Stack>
        </DialogContent>
        <DialogActions sx={{ px: 3, py: 2 }}>
          <Button onClick={() => setEditTarget(null)} disabled={editing}>
            Hủy
          </Button>
          <Button
            variant="contained"
            startIcon={<EditOutlinedIcon />}
            onClick={() => void submitIdentifiers()}
            disabled={editing}
            sx={{ fontWeight: 700 }}
          >
            {editing ? 'Đang lưu…' : 'Lưu thay đổi'}
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snack.open}
        autoHideDuration={4500}
        onClose={() => setSnack((s) => ({ ...s, open: false }))}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          severity={snack.severity}
          onClose={() => setSnack((s) => ({ ...s, open: false }))}
          variant="filled"
          sx={{ borderRadius: 2 }}
        >
          {snack.message}
        </Alert>
      </Snackbar>
    </Box>
  );
}
