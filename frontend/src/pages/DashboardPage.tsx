import type { ReactNode } from 'react';
import ArrowForwardIcon from '@mui/icons-material/ArrowForward';
import CalendarMonthIcon from '@mui/icons-material/CalendarMonth';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import { alpha, useTheme } from '@mui/material/styles';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  Paper,
  Stack,
  Typography,
} from '@mui/material';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import GroupsIcon from '@mui/icons-material/Groups';
import PregnantWomanIcon from '@mui/icons-material/PregnantWoman';
import DomainIcon from '@mui/icons-material/Domain';
import BadgeIcon from '@mui/icons-material/Badge';
import PictureAsPdfIcon from '@mui/icons-material/PictureAsPdf';
import EventAvailableIcon from '@mui/icons-material/EventAvailable';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { isSessionFailure } from '../utils/sessionFailure';
import { DashboardCharts } from '../components/dashboard/DashboardCharts';
import { DashboardEmployeeListDialog } from '../components/dashboard/DashboardEmployeeListDialog';
import type { DeptRow, HireRow, StatusBreakdown } from '../components/dashboard/DashboardCharts';
import * as employeeService from '../services/employeeService';

type StatTone = 'primary' | 'success' | 'warning' | 'neutral';

function safeDisplayNumber(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function StatWidget(props: {
  label: string;
  value: number | undefined | null;
  icon: ReactNode;
  tone: StatTone;
}) {
  const theme = useTheme();
  const { label, value, icon, tone } = props;
  const displayValue = safeDisplayNumber(value);

  const tones: Record<
    StatTone,
    { bg: string; color: string; border: string; gradient: string }
  > = {
    primary: {
      bg: alpha(theme.palette.primary.main, 0.1),
      color: theme.palette.primary.main,
      border: alpha(theme.palette.primary.main, 0.18),
      gradient: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.06)} 0%, ${alpha('#fff', 0.98)} 55%, ${alpha(theme.palette.secondary.main, 0.05)} 100%)`,
    },
    success: {
      bg: alpha(theme.palette.success.main, 0.12),
      color: theme.palette.success.dark,
      border: alpha(theme.palette.success.main, 0.22),
      gradient: `linear-gradient(135deg, ${alpha(theme.palette.success.main, 0.07)} 0%, #fff 100%)`,
    },
    warning: {
      bg: alpha(theme.palette.warning.main, 0.12),
      color: theme.palette.warning.dark,
      border: alpha(theme.palette.warning.main, 0.25),
      gradient: `linear-gradient(135deg, ${alpha(theme.palette.warning.main, 0.08)} 0%, #fff 100%)`,
    },
    neutral: {
      bg: alpha('#64748b', 0.09),
      color: '#475569',
      border: alpha('#64748b', 0.14),
      gradient: `linear-gradient(135deg, ${alpha('#64748b', 0.06)} 0%, #fff 100%)`,
    },
  };
  const t = tones[tone];

  return (
    <Card
      elevation={0}
      sx={{
        height: '100%',
        border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
        background: t.gradient,
        transition: 'transform 0.2s ease, box-shadow 0.2s ease',
        '&:hover': {
          transform: 'translateY(-2px)',
          boxShadow: `0 12px 28px ${alpha('#0f172a', 0.08)}`,
        },
      }}
    >
      <CardContent sx={{ p: 2.25, '&:last-child': { pb: 2.25 } }}>
        <Stack direction="row" alignItems="flex-start" justifyContent="space-between" spacing={2}>
          <Box sx={{ minWidth: 0 }}>
            <Typography
              variant="overline"
              sx={{
                color: 'text.secondary',
                display: 'block',
                mb: 0.75,
                fontWeight: 600,
                letterSpacing: '0.06em',
              }}
            >
              {label}
            </Typography>
            <Typography
              component="p"
              sx={{
                fontSize: { xs: '1.65rem', sm: '1.875rem' },
                fontWeight: 700,
                letterSpacing: '-0.03em',
                lineHeight: 1.1,
                color: 'text.primary',
                fontFeatureSettings: '"tnum"',
              }}
            >
              {displayValue.toLocaleString('vi-VN')}
            </Typography>
          </Box>
          <Box
            sx={{
              width: 48,
              height: 48,
              borderRadius: 2.5,
              flexShrink: 0,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              bgcolor: t.bg,
              color: t.color,
              border: `1px solid ${t.border}`,
              '& .MuiSvgIcon-root': { fontSize: 24 },
            }}
          >
            {icon}
          </Box>
        </Stack>
      </CardContent>
    </Card>
  );
}

function normalizeStatusBreakdown(s: employeeService.DashboardStats | null): StatusBreakdown {
  if (!s) {
    return { working: 0, maternityLeave: 0, trial: 0, terminated: 0 };
  }
  if (s.statusBreakdown) {
    return {
      working: safeDisplayNumber(s.statusBreakdown.working),
      maternityLeave: safeDisplayNumber(s.statusBreakdown.maternityLeave),
      trial: safeDisplayNumber(s.statusBreakdown.trial),
      terminated: safeDisplayNumber(s.statusBreakdown.terminated),
    };
  }
  const working = Math.max(0, safeDisplayNumber(s.activeEmployees) - safeDisplayNumber(s.maternityLeave));
  const maternityLeave = safeDisplayNumber(s.maternityLeave);
  const total = safeDisplayNumber(s.totalEmployees);
  const terminated = Math.max(0, total - working - maternityLeave);
  return { working, maternityLeave, trial: 0, terminated };
}

function normalizeDept(s: employeeService.DashboardStats | null): DeptRow[] {
  if (!s?.employeesByDepartment?.length) {
    return [];
  }
  return s.employeesByDepartment.map((d) => ({
    departmentId: safeDisplayNumber(d.departmentId),
    departmentName: String(d.departmentName ?? '—'),
    count: safeDisplayNumber(d.count),
    officialCount: safeDisplayNumber(d.officialCount),
    trialCount: safeDisplayNumber(d.trialCount),
  }));
}

function normalizeHires(s: employeeService.DashboardStats | null): HireRow[] {
  if (!s?.hiresByMonth?.length) {
    return [];
  }
  return s.hiresByMonth.map((h) => ({
    label: String(h.label ?? ''),
    count: safeDisplayNumber(h.count),
    year: safeDisplayNumber(h.year),
    month: safeDisplayNumber(h.month),
    officialCount: safeDisplayNumber(h.officialCount),
    trialCount: safeDisplayNumber(h.trialCount),
  }));
}

type DrillDownState =
  | { type: 'hire'; year: number; month: number; title: string; subtitle: string }
  | { type: 'department'; departmentId: number; title: string; subtitle: string };

export default function DashboardPage() {
  const theme = useTheme();
  const { user } = useAuth();
  const [stats, setStats] = useState<employeeService.DashboardStats | null>(null);
  const [me, setMe] = useState<employeeService.EmployeeDetail | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [drillDown, setDrillDown] = useState<DrillDownState | null>(null);
  const [drillEmployees, setDrillEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [drillLoading, setDrillLoading] = useState(false);

  const isAdmin = user?.role === 'ADMIN';

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        if (isAdmin) {
          const data = await employeeService.fetchDashboardStats();
          if (!cancelled) setStats(data);
        }
        if (user?.employeeId) {
          const m = await employeeService.fetchMe();
          if (!cancelled) setMe(m);
        }
      } catch (e) {
        if (!cancelled && !isSessionFailure(e)) {
          setErr('Không tải được dữ liệu dashboard.');
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [user, isAdmin]);

  const chartStatus = useMemo(() => normalizeStatusBreakdown(stats), [stats]);
  const chartDept = useMemo(() => normalizeDept(stats), [stats]);
  const chartHires = useMemo(() => normalizeHires(stats), [stats]);

  useEffect(() => {
    if (!drillDown) {
      setDrillEmployees([]);
      return;
    }
    let cancelled = false;
    setDrillLoading(true);
    (async () => {
      try {
        const rows =
          drillDown.type === 'hire'
            ? await employeeService.fetchDashboardHiresInMonth(drillDown.year, drillDown.month)
            : await employeeService.fetchDashboardDepartmentEmployees(drillDown.departmentId);
        if (!cancelled) setDrillEmployees(rows);
      } catch {
        if (!cancelled) setDrillEmployees([]);
      } finally {
        if (!cancelled) setDrillLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [drillDown]);

  function openHireDrillDown(row: HireRow) {
    setDrillDown({
      type: 'hire',
      year: row.year,
      month: row.month,
      title: `Nhân viên nhận việc tháng ${row.month}/${row.year}`,
      subtitle: `${row.count} người (${row.officialCount} chính thức, ${row.trialCount} thử việc)`,
    });
  }

  function openDepartmentDrillDown(row: DeptRow) {
    setDrillDown({
      type: 'department',
      departmentId: row.departmentId,
      title: row.departmentName,
      subtitle: `${row.count} nhân viên (${row.officialCount} chính thức, ${row.trialCount} thử việc)`,
    });
  }

  const statCards =
    stats &&
    ([
      {
        label: 'Tổng nhân viên (hồ sơ)',
        value: stats.totalEmployees,
        icon: <GroupsIcon />,
        tone: 'primary' as const,
      },
      {
        label: 'Tài khoản vai trò NV',
        value: stats.employeeRoleAccounts,
        icon: <BadgeIcon />,
        tone: 'primary' as const,
      },
      {
        label: 'Hồ sơ PDF đính kèm',
        value: stats.totalPdfDocuments,
        icon: <PictureAsPdfIcon />,
        tone: 'neutral' as const,
      },
      {
        label: 'Xét lương (14 ngày tới)',
        value: stats.salaryReviewsDueSoon,
        icon: <EventAvailableIcon />,
        tone: 'warning' as const,
      },
      {
        label: 'Đang làm việc',
        value: stats.activeEmployees,
        icon: <TrendingUpIcon />,
        tone: 'success' as const,
      },
      {
        label: 'Nghỉ thai sản',
        value: stats.maternityLeave,
        icon: <PregnantWomanIcon />,
        tone: 'warning' as const,
      },
      {
        label: 'Đơn vị / phòng ban',
        value: stats.departments,
        icon: <DomainIcon />,
        tone: 'neutral' as const,
      },
    ] as const);

  const todayLabel = new Date().toLocaleDateString('vi-VN', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });

  return (
    <Box sx={{ width: '100%' }}>
      <Paper
        elevation={0}
        sx={{
          p: { xs: 2.5, sm: 3 },
          mb: 3,
          borderRadius: 3,
          border: `1px solid ${alpha(theme.palette.primary.main, 0.14)}`,
          background: `linear-gradient(118deg, ${alpha(theme.palette.primary.main, 0.09)} 0%, ${alpha('#fff', 0.97)} 42%, ${alpha(theme.palette.secondary.main, 0.07)} 100%)`,
          boxShadow: `0 8px 32px ${alpha('#0f172a', 0.06)}`,
        }}
      >
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          alignItems={{ xs: 'flex-start', sm: 'center' }}
          justifyContent="space-between"
          spacing={2}
        >
          <Box>
            <Typography
              variant="overline"
              sx={{ color: 'primary.dark', fontWeight: 700, letterSpacing: '0.12em', mb: 0.5 }}
            >
              Bảng điều khiển
            </Typography>
            <Typography variant="h4" component="h1" sx={{ fontWeight: 700, letterSpacing: '-0.03em', mb: 1 }}>
              {isAdmin ? 'Tổng quan nhân sự' : 'Trang chủ'}
            </Typography>
            {isAdmin ? (
              <List dense disablePadding sx={{ maxWidth: 560 }}>
                <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.35 }}>
                  <ListItemIcon sx={{ minWidth: 38, color: 'primary.main', mt: 0.2 }}>
                    <GroupsIcon fontSize="small" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Theo dõi biên chế, phòng ban và hồ sơ nhân viên trên toàn bệnh viện."
                    primaryTypographyProps={{ variant: 'body2', color: 'text.secondary', lineHeight: 1.65 }}
                  />
                </ListItem>
                <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.35 }}>
                  <ListItemIcon sx={{ minWidth: 38, color: 'primary.main', mt: 0.2 }}>
                    <BadgeIcon fontSize="small" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Đồng bộ tài khoản vai trò, PDF đính kèm và nhắc lịch xét lương."
                    primaryTypographyProps={{ variant: 'body2', color: 'text.secondary', lineHeight: 1.65 }}
                  />
                </ListItem>
                <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.35 }}>
                  <ListItemIcon sx={{ minWidth: 38, color: 'primary.main', mt: 0.2 }}>
                    <TrendingUpIcon fontSize="small" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Bệnh viện Minh An — tổng quan trên một màn hình."
                    primaryTypographyProps={{ variant: 'body2', color: 'text.secondary', lineHeight: 1.65 }}
                  />
                </ListItem>
              </List>
            ) : (
              <List dense disablePadding sx={{ maxWidth: 520 }}>
                <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.35 }}>
                  <ListItemIcon sx={{ minWidth: 38, color: 'primary.main', mt: 0.2 }}>
                    <PersonOutlineIcon fontSize="small" />
                  </ListItemIcon>
                  <ListItemText
                    primary="Thông tin cá nhân, lịch làm việc và thông báo nội viện."
                    primaryTypographyProps={{ variant: 'body2', color: 'text.secondary', lineHeight: 1.65 }}
                  />
                </ListItem>
              </List>
            )}
          </Box>
          <Stack direction="row" alignItems="center" spacing={1} sx={{ color: 'text.secondary' }}>
            <CalendarMonthIcon sx={{ fontSize: 22, opacity: 0.85 }} />
            <Typography variant="body2" sx={{ fontWeight: 500, textAlign: { xs: 'left', sm: 'right' } }}>
              {todayLabel}
            </Typography>
          </Stack>
        </Stack>
      </Paper>

      {err && (
        <Alert severity="error" sx={{ mb: 2 }} variant="outlined">
          {err}
        </Alert>
      )}

      {stats && stats.accountsMatchEmployees === false && (
        <Alert severity="warning" sx={{ mb: 2.5 }} variant="outlined">
          Số hồ sơ nhân viên và số tài khoản vai trò <strong>EMPLOYEE</strong> chưa khớp. Kiểm tra import Excel hoặc
          tài khoản thừa — mục tiêu: <strong>một nhân viên một tài khoản</strong>.
        </Alert>
      )}

      {statCards && (
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: {
              xs: '1fr',
              sm: 'repeat(2, 1fr)',
              md: 'repeat(3, 1fr)',
              lg: 'repeat(4, 1fr)',
            },
            gap: 2.25,
            mb: 3,
          }}
        >
          {statCards.map((c) => (
            <Box key={c.label}>
              <StatWidget label={c.label} value={c.value} icon={c.icon} tone={c.tone} />
            </Box>
          ))}
        </Box>
      )}

      {isAdmin && stats && (
        <Box sx={{ mb: 1 }}>
          <Typography variant="h6" sx={{ fontWeight: 700, mb: 0.5, letterSpacing: '-0.02em' }}>
            Phân tích trực quan
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Biểu đồ cập nhật theo dữ liệu hệ thống (trạng thái, phòng ban, tuyển dụng theo tháng).
          </Typography>
          <DashboardCharts
            statusBreakdown={chartStatus}
            employeesByDepartment={chartDept}
            hiresByMonth={chartHires}
            onHireMonthClick={openHireDrillDown}
            onDepartmentClick={openDepartmentDrillDown}
          />
          <DashboardEmployeeListDialog
            open={drillDown != null}
            title={drillDown?.title ?? ''}
            subtitle={drillDown?.subtitle}
            employees={drillEmployees}
            loading={drillLoading}
            showHireDate={drillDown?.type === 'hire'}
            onClose={() => setDrillDown(null)}
          />
        </Box>
      )}

      {isAdmin && !user?.employeeId && (
        <Card
          sx={{
            mb: 3,
            borderRadius: 3,
            borderLeft: `4px solid ${theme.palette.primary.main}`,
            bgcolor: alpha(theme.palette.primary.main, 0.03),
          }}
        >
          <CardContent sx={{ py: 2.5, px: 3, '&:last-child': { pb: 2.5 } }}>
            <Typography variant="subtitle1" sx={{ mb: 0.75, fontWeight: 700 }}>
              Tài khoản quản trị
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.65 }}>
              Tài khoản ADMIN không gắn hồ sơ nhân viên. Dùng menu <strong>Nhân viên</strong> để quản lý toàn bệnh
              viện.
            </Typography>
          </CardContent>
        </Card>
      )}

      {me && (
        <Card
          sx={{
            borderRadius: 3,
            overflow: 'hidden',
            border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
            background: `linear-gradient(180deg, ${alpha(theme.palette.primary.main, 0.05)} 0%, #fff 28%)`,
          }}
        >
          <CardContent sx={{ py: 2.75, px: 3, '&:last-child': { pb: 2.75 } }}>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2.5} alignItems={{ sm: 'center' }}>
              <Box
                sx={{
                  width: 56,
                  height: 56,
                  borderRadius: '50%',
                  bgcolor: alpha(theme.palette.primary.main, 0.12),
                  color: 'primary.main',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                <PersonOutlineIcon sx={{ fontSize: 32 }} />
              </Box>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="overline" color="primary" sx={{ fontWeight: 700 }}>
                  Hồ sơ của tôi
                </Typography>
                <Typography variant="h6" sx={{ fontWeight: 700, mt: 0.25, mb: 0.5 }}>
                  {me.fullName}
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.65 }}>
                  {me.departmentName} · {me.positionTitle}
                  {me.employeeCode ? ` · Mã ${me.employeeCode}` : ''}
                </Typography>
              </Box>
              <Button
                component={Link}
                to={`/employees/${me.id}`}
                variant="contained"
                color="primary"
                endIcon={<ArrowForwardIcon />}
                sx={{ alignSelf: { xs: 'stretch', sm: 'center' } }}
              >
                Xem chi tiết
              </Button>
            </Stack>
          </CardContent>
        </Card>
      )}
    </Box>
  );
}
