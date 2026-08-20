import type { ReactNode } from 'react';
import AssignmentOutlinedIcon from '@mui/icons-material/AssignmentOutlined';
import ArrowForwardIcon from '@mui/icons-material/ArrowForward';
import CalendarMonthIcon from '@mui/icons-material/CalendarMonth';
import DomainIcon from '@mui/icons-material/Domain';
import GroupsIcon from '@mui/icons-material/Groups';
import HowToRegIcon from '@mui/icons-material/HowToReg';
import LocalHospitalIcon from '@mui/icons-material/LocalHospital';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import PendingActionsIcon from '@mui/icons-material/PendingActions';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import WorkOutlineIcon from '@mui/icons-material/WorkOutline';
import {
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
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { Link as RouterLink, useNavigate } from 'react-router-dom';
import type { TooltipProps } from 'recharts';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Sector,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { PieSectorDataItem } from 'recharts/types/polar/Pie';
import type { NursingDashboardStats } from '../../services/employeeService';
import * as employeeService from '../../services/employeeService';
import { DashboardEmployeeListDialog } from './DashboardEmployeeListDialog';

type StatTone = 'primary' | 'success' | 'warning' | 'neutral';

const CHART_H = 300;

const SUBGROUP_PALETTE = {
  nurse: '#0f766e',
  tech: '#0369a1',
  midwife: '#7c3aed',
  secretary: '#be185d',
  other: '#b45309',
} as const;

type Props = {
  stats: NursingDashboardStats;
  userName?: string | null;
  profile?: {
    id: number;
    fullName: string;
    departmentName?: string | null;
    positionTitle?: string | null;
    employeeCode?: string | null;
  } | null;
};

function safeNum(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function StatWidget({
  label,
  value,
  icon,
  tone,
}: {
  label: string;
  value: number | undefined | null;
  icon: ReactNode;
  tone: StatTone;
}) {
  const theme = useTheme();
  const displayValue = safeNum(value);
  const tones: Record<StatTone, { bg: string; color: string; border: string; gradient: string }> = {
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

function ChartTooltipCard({
  title,
  lines,
}: {
  title?: string;
  lines: string[];
}) {
  const theme = useTheme();
  return (
    <Box
      sx={{
        px: 1.5,
        py: 1.25,
        borderRadius: 2.5,
        bgcolor: 'background.paper',
        border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
        boxShadow: '0 8px 24px rgba(15,23,42,0.1)',
        maxWidth: 280,
      }}
    >
      {title && (
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5, lineHeight: 1.4 }}>
          {title}
        </Typography>
      )}
      {lines.map((line) => (
        <Typography key={line} variant="body2" sx={{ fontWeight: 600, color: 'text.primary', lineHeight: 1.45 }}>
          {line}
        </Typography>
      ))}
    </Box>
  );
}

type PieItem = { key: string; name: string; value: number; color: string };
type DeptBar = {
  departmentId: number | null;
  departmentName: string;
  count: number;
  officialCount: number;
  trialCount: number;
};
type PendingBar = { key: string; label: string; count: number; color: string };

function colorForSubGroup(label: string, index: number): string {
  const folded = label
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/đ/gi, 'd')
    .toLowerCase();
  if (folded.includes('dieu duong')) return SUBGROUP_PALETTE.nurse;
  if (folded.includes('ktv') || folded.includes('ky thuat')) return SUBGROUP_PALETTE.tech;
  if (folded.includes('ho sinh')) return SUBGROUP_PALETTE.midwife;
  if (folded.includes('thu ky')) return SUBGROUP_PALETTE.secretary;
  const fallback = Object.values(SUBGROUP_PALETTE);
  return fallback[index % fallback.length];
}

function renderActivePieSector(props: PieSectorDataItem) {
  const { outerRadius = 102, fill } = props;
  return <Sector {...props} fill={fill} stroke="none" outerRadius={outerRadius + 3} />;
}

function StatusPieTooltip({
  active,
  payload,
  total,
}: TooltipProps<number, string> & { total: number }) {
  const item = payload?.[0]?.payload as PieItem | undefined;
  if (!active || !item) return null;
  const pct = total > 0 ? ((item.value / total) * 100).toFixed(1) : '0';
  return <ChartTooltipCard title={item.name} lines={[`${item.value.toLocaleString('vi-VN')} người (${pct}%)`]} />;
}

function DepartmentTooltip({ active, payload }: TooltipProps<number, string>) {
  const row = payload?.[0]?.payload as DeptBar | undefined;
  if (!active || !row) return null;
  return (
    <ChartTooltipCard
      title={row.departmentName}
      lines={[
        `Tổng: ${row.count.toLocaleString('vi-VN')}`,
        `Chính thức: ${row.officialCount} · Thử việc: ${row.trialCount}`,
        row.departmentId != null && row.count > 0 ? 'Nhấn để xem danh sách' : '',
      ].filter(Boolean)}
    />
  );
}

function PendingTooltip({ active, payload }: TooltipProps<number, string>) {
  const row = payload?.[0]?.payload as PendingBar | undefined;
  if (!active || !row) return null;
  return <ChartTooltipCard title={row.label} lines={[`${row.count} đơn chờ duyệt`]} />;
}

export function NursingDashboard({ stats, userName, profile }: Props) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;
  const navigate = useNavigate();
  const [deptDrill, setDeptDrill] = useState<{
    departmentId: number;
    title: string;
    subtitle: string;
  } | null>(null);
  const [deptEmployees, setDeptEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [deptLoading, setDeptLoading] = useState(false);

  const todayLabel = new Date().toLocaleDateString('vi-VN', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });

  const pieData = useMemo<PieItem[]>(
    () =>
      (stats.bySubGroup || [])
        .filter((r) => r.count > 0)
        .map((r, i) => ({
          key: r.label,
          name: r.label,
          value: r.count,
          color: colorForSubGroup(r.label, i),
        })),
    [stats.bySubGroup],
  );
  const pieTotal = useMemo(() => pieData.reduce((s, d) => s + d.value, 0), [pieData]);

  const deptData = useMemo<DeptBar[]>(
    () =>
      [...(stats.byDepartment || [])]
        .sort((a, b) => b.count - a.count)
        .map((d) => ({
          departmentId: d.departmentId ?? null,
          departmentName: d.departmentName,
          count: d.count,
          officialCount: d.officialCount,
          trialCount: d.trialCount,
        })),
    [stats.byDepartment],
  );

  const deptYAxisWidth = useMemo(() => {
    const maxChars = deptData.reduce((m, d) => Math.max(m, d.departmentName.length), 0);
    return Math.min(280, Math.max(140, Math.ceil(maxChars * 7.2) + 24));
  }, [deptData]);

  useEffect(() => {
    if (!deptDrill) {
      setDeptEmployees([]);
      return;
    }
    let cancelled = false;
    setDeptLoading(true);
    (async () => {
      try {
        const rows = await employeeService.fetchNursingDepartmentEmployees(deptDrill.departmentId);
        if (!cancelled) setDeptEmployees(rows);
      } catch {
        if (!cancelled) setDeptEmployees([]);
      } finally {
        if (!cancelled) setDeptLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [deptDrill]);

  function handleDeptBarClick(barData: { payload?: DeptBar } & Partial<DeptBar>) {
    const data = (barData.payload ?? barData) as DeptBar;
    if (data?.departmentId != null && data.count > 0) {
      setDeptDrill({
        departmentId: data.departmentId,
        title: data.departmentName,
        subtitle: `${data.count} nhân viên khối (${data.officialCount} chính thức, ${data.trialCount} thử việc)`,
      });
    }
  }

  const pendingData = useMemo<PendingBar[]>(
    () => [
      {
        key: 'deployments',
        label: 'Điều động',
        count: safeNum(stats.pendingDeployments),
        color: '#0369a1',
      },
      {
        key: 'probation',
        label: 'Lên chính thức',
        count: safeNum(stats.pendingProbation),
        color: '#0f766e',
      },
      {
        key: 'mainDuty',
        label: 'Trực chính',
        count: safeNum(stats.pendingMainDuty),
        color: '#7c3aed',
      },
    ],
    [stats.pendingDeployments, stats.pendingProbation, stats.pendingMainDuty],
  );

  const pendingLinks: Record<string, string> = {
    deployments: '/requests?tab=deployments',
    probation: '/requests?tab=probation-conversions',
    mainDuty: '/requests?tab=main-duty',
  };
  const firstPendingLink =
    pendingLinks[pendingData.find((item) => item.count > 0)?.key ?? ''] ?? pendingLinks.deployments;

  const statCards = [
    {
      label: 'Nhân sự khối',
      value: stats.totalInBlock,
      icon: <GroupsIcon />,
      tone: 'primary' as const,
    },
    {
      label: 'Chính thức',
      value: stats.officialCount,
      icon: <HowToRegIcon />,
      tone: 'success' as const,
    },
    {
      label: 'Thử việc / thực tập',
      value: stats.trialCount,
      icon: <AssignmentOutlinedIcon />,
      tone: 'warning' as const,
    },
    {
      label: 'Được trực chính',
      value: stats.mainDutyAuthorized,
      icon: <NightsStayIcon />,
      tone: 'primary' as const,
    },
    {
      label: 'Đơn chờ tôi duyệt',
      value: stats.pendingTotal,
      icon: <PendingActionsIcon />,
      tone: 'warning' as const,
    },
    {
      label: 'Khoa / phòng có NV khối',
      value: stats.departmentsCovered,
      icon: <DomainIcon />,
      tone: 'neutral' as const,
    },
  ];

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
              Bảng điều khiển · Trưởng phòng Điều dưỡng
            </Typography>
            <Typography variant="h4" component="h1" sx={{ fontWeight: 700, letterSpacing: '-0.03em', mb: 1 }}>
              Tổng quan khối ĐD – KTV – Hộ sinh – Thư ký y khoa
            </Typography>
            <List dense disablePadding sx={{ maxWidth: 580 }}>
              <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.35 }}>
                <ListItemIcon sx={{ minWidth: 38, color: 'primary.main', mt: 0.2 }}>
                  <LocalHospitalIcon fontSize="small" />
                </ListItemIcon>
                <ListItemText
                  primary={
                    userName
                      ? `${userName} — theo dõi biên chế và đơn duyệt trong phạm vi khối mình quản lý.`
                      : 'Theo dõi biên chế và đơn duyệt trong phạm vi khối mình quản lý.'
                  }
                  primaryTypographyProps={{ variant: 'body2', color: 'text.secondary', lineHeight: 1.65 }}
                />
              </ListItem>
              <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.35 }}>
                <ListItemIcon sx={{ minWidth: 38, color: 'primary.main', mt: 0.2 }}>
                  <TrendingUpIcon fontSize="small" />
                </ListItemIcon>
                <ListItemText
                  primary="Chỉ xem nhân sự & bảng công khối; duyệt điều động, lên chính thức và trực chính trước khi chuyển bước tiếp."
                  primaryTypographyProps={{ variant: 'body2', color: 'text.secondary', lineHeight: 1.65 }}
                />
              </ListItem>
              <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.35 }}>
                <ListItemIcon sx={{ minWidth: 38, color: 'primary.main', mt: 0.2 }}>
                  <GroupsIcon fontSize="small" />
                </ListItemIcon>
                <ListItemText
                  primary="Bệnh viện Minh An — tổng quan khối Điều dưỡng trên một màn hình."
                  primaryTypographyProps={{ variant: 'body2', color: 'text.secondary', lineHeight: 1.65 }}
                />
              </ListItem>
            </List>
          </Box>
          <Stack alignItems={{ xs: 'flex-start', sm: 'flex-end' }} spacing={1.25}>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ color: 'text.secondary' }}>
              <CalendarMonthIcon sx={{ fontSize: 22, opacity: 0.85 }} />
              <Typography variant="body2" sx={{ fontWeight: 500, textAlign: { xs: 'left', sm: 'right' } }}>
                {todayLabel}
              </Typography>
            </Stack>
            <Button
              component={RouterLink}
              to={firstPendingLink}
              variant="contained"
              endIcon={<ArrowForwardIcon />}
              sx={{ borderRadius: 2, fontWeight: 700, textTransform: 'none', px: 2 }}
            >
              {stats.pendingTotal > 0 ? `Duyệt đơn (${stats.pendingTotal})` : 'Vào danh sách đơn'}
            </Button>
          </Stack>
        </Stack>
      </Paper>

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: {
            xs: '1fr',
            sm: 'repeat(2, 1fr)',
            md: 'repeat(3, 1fr)',
            lg: 'repeat(3, 1fr)',
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

      <Box sx={{ mb: 1 }}>
        <Typography variant="h6" sx={{ fontWeight: 700, mb: 0.5, letterSpacing: '-0.02em' }}>
          Phân tích trực quan
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Biểu đồ chỉ gồm nhân sự khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa.
        </Typography>

        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', lg: '1fr 1fr' },
            gap: 2.5,
            mb: 2.5,
          }}
        >
          <Box
            sx={{
              p: 2.5,
              borderRadius: 3,
              border: `1px solid ${alpha(theme.palette.divider, 1)}`,
              bgcolor: 'background.paper',
              boxShadow: '0 2px 12px rgba(15, 23, 42, 0.04)',
            }}
          >
            <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 0.5 }}>
              Phân bố theo chức danh
            </Typography>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
              Tỷ lệ ĐD / KTV / Hộ sinh / Thư ký y khoa trong khối
            </Typography>
            {pieData.length === 0 ? (
              <Typography variant="body2" color="text.secondary">
                Chưa có dữ liệu.
              </Typography>
            ) : (
              <>
                <ResponsiveContainer width="100%" height={CHART_H}>
                  <PieChart>
                    <Pie
                      data={pieData}
                      cx="50%"
                      cy="50%"
                      innerRadius={72}
                      outerRadius={102}
                      paddingAngle={0}
                      minAngle={2}
                      dataKey="value"
                      nameKey="name"
                      stroke="none"
                      isAnimationActive={false}
                      activeShape={renderActivePieSector}
                    >
                      {pieData.map((entry) => (
                        <Cell key={entry.key} fill={entry.color} stroke={entry.color} strokeWidth={0} />
                      ))}
                    </Pie>
                    <Tooltip content={<StatusPieTooltip total={pieTotal} />} />
                    <text x="50%" y="50%" textAnchor="middle" dominantBaseline="middle" style={{ pointerEvents: 'none' }}>
                      <tspan
                        x="50%"
                        dy="-4"
                        style={{ fontSize: 22, fontWeight: 700, fill: theme.palette.text.primary }}
                      >
                        {pieTotal}
                      </tspan>
                      <tspan x="50%" dy="22" style={{ fontSize: 11, fill: theme.palette.text.secondary }}>
                        nhân viên
                      </tspan>
                    </text>
                  </PieChart>
                </ResponsiveContainer>
                <Stack direction="row" flexWrap="wrap" justifyContent="center" gap={1.25} sx={{ mt: 2, px: 1 }}>
                  {pieData.map((item) => {
                    const pct = pieTotal > 0 ? Math.round((item.value / pieTotal) * 100) : 0;
                    return (
                      <Stack key={item.key} direction="row" alignItems="center" spacing={0.75}>
                        <Box
                          sx={{
                            width: 10,
                            height: 10,
                            borderRadius: '50%',
                            bgcolor: item.color,
                            flexShrink: 0,
                          }}
                        />
                        <Typography variant="caption" sx={{ color: 'text.primary', fontWeight: 500, lineHeight: 1.3 }}>
                          {item.name}
                          <Typography component="span" variant="caption" color="text.secondary" sx={{ ml: 0.5 }}>
                            {item.value} ({pct}%)
                          </Typography>
                        </Typography>
                      </Stack>
                    );
                  })}
                </Stack>
              </>
            )}
          </Box>

          <Box
            sx={{
              p: 2.5,
              borderRadius: 3,
              border: `1px solid ${alpha(theme.palette.divider, 1)}`,
              bgcolor: 'background.paper',
              boxShadow: '0 2px 12px rgba(15, 23, 42, 0.04)',
            }}
          >
            <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 0.5 }}>
              Đơn chờ duyệt
            </Typography>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
              Nhấn vào cột để mở danh sách đơn tương ứng
            </Typography>
            <ResponsiveContainer width="100%" height={CHART_H}>
              <BarChart
                data={pendingData}
                margin={{ top: 8, right: 12, left: -8, bottom: 0 }}
                style={{ cursor: 'pointer' }}
                onClick={(state) => {
                  const row = state?.activePayload?.[0]?.payload as PendingBar | undefined;
                  if (row?.key && pendingLinks[row.key]) {
                    navigate(pendingLinks[row.key]);
                  }
                }}
              >
                <CartesianGrid strokeDasharray="3 3" stroke={alpha(theme.palette.divider, 0.9)} vertical={false} />
                <XAxis dataKey="label" tick={{ fontSize: 12, fill: theme.palette.text.secondary }} axisLine={false} />
                <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: theme.palette.text.secondary }} axisLine={false} />
                <Tooltip content={<PendingTooltip />} />
                <Bar dataKey="count" radius={[8, 8, 0, 0]} maxBarSize={48}>
                  {pendingData.map((d) => (
                    <Cell key={d.key} fill={d.color} cursor="pointer" />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </Box>

          <Box
            sx={{
              gridColumn: { xs: '1', lg: '1 / -1' },
              p: 2.5,
              borderRadius: 3,
              border: `1px solid ${alpha(theme.palette.divider, 1)}`,
              bgcolor: 'background.paper',
              boxShadow: '0 2px 12px rgba(15, 23, 42, 0.04)',
            }}
          >
            <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 0.5 }}>
              Nhân sự khối theo phòng ban
            </Typography>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
              Số lượng nhân viên khối ĐD–KTV–HS–Thư ký theo từng khoa/phòng — nhấn vào thanh để xem danh sách
            </Typography>
            {deptData.length === 0 ? (
              <Typography variant="body2" color="text.secondary">
                Chưa có dữ liệu phòng ban.
              </Typography>
            ) : (
              <ResponsiveContainer width="100%" height={Math.max(280, 48 + deptData.length * 36)}>
                <BarChart layout="vertical" data={deptData} margin={{ top: 4, right: 24, left: 4, bottom: 4 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={alpha(theme.palette.divider, 0.9)} horizontal={false} />
                  <XAxis type="number" allowDecimals={false} tick={{ fontSize: 11 }} />
                  <YAxis
                    type="category"
                    dataKey="departmentName"
                    width={deptYAxisWidth}
                    interval={0}
                    tick={{ fontSize: 11, fill: theme.palette.text.primary }}
                  />
                  <Tooltip content={<DepartmentTooltip />} />
                  <Bar
                    dataKey="count"
                    radius={[0, 8, 8, 0]}
                    maxBarSize={22}
                    cursor="pointer"
                    onClick={(data) => handleDeptBarClick(data as DeptBar)}
                  >
                    {deptData.map((_, i) => (
                      <Cell key={i} fill={i % 2 === 0 ? primary : alpha(primary, 0.75)} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </Box>
        </Box>
      </Box>

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' },
          gap: 2,
          mb: 3,
        }}
      >
        {[
          {
            title: 'Nhân sự khối',
            hint: 'Chỉ xem — ĐD / KTV / Hộ sinh / Thư ký y khoa',
            to: '/employees/official',
            icon: <GroupsIcon />,
          },
          {
            title: 'Bảng công khối',
            hint: 'Xem công nhân viên trong phạm vi quản lý',
            to: '/work',
            icon: <WorkOutlineIcon />,
          },
          {
            title: 'Đơn chờ duyệt',
            hint:
              stats.pendingTotal > 0
                ? `${stats.pendingTotal} đơn cần xử lý`
                : 'Không có đơn chờ',
            to: firstPendingLink,
            icon: <PendingActionsIcon />,
          },
        ].map((item) => (
          <Card
            key={item.to}
            elevation={0}
            sx={{
              borderRadius: 3,
              border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
              background: `linear-gradient(180deg, ${alpha(theme.palette.primary.main, 0.04)} 0%, #fff 40%)`,
              transition: 'transform 0.2s ease, box-shadow 0.2s ease',
              '&:hover': {
                transform: 'translateY(-2px)',
                boxShadow: `0 12px 28px ${alpha('#0f172a', 0.07)}`,
              },
            }}
          >
            <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
              <Stack spacing={1.75}>
                <Box
                  sx={{
                    width: 44,
                    height: 44,
                    borderRadius: 2.5,
                    display: 'grid',
                    placeItems: 'center',
                    bgcolor: alpha(theme.palette.primary.main, 0.1),
                    color: 'primary.main',
                    border: `1px solid ${alpha(theme.palette.primary.main, 0.16)}`,
                  }}
                >
                  {item.icon}
                </Box>
                <Box>
                  <Typography fontWeight={700}>{item.title}</Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ mt: 0.35, lineHeight: 1.55 }}>
                    {item.hint}
                  </Typography>
                </Box>
                <Button
                  component={RouterLink}
                  to={item.to}
                  size="small"
                  endIcon={<ArrowForwardIcon />}
                  sx={{ alignSelf: 'flex-start', textTransform: 'none', fontWeight: 700 }}
                >
                  Mở
                </Button>
              </Stack>
            </CardContent>
          </Card>
        ))}
      </Box>

      {profile && (
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
                  {profile.fullName}
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.65 }}>
                  {profile.departmentName} · {profile.positionTitle}
                  {profile.employeeCode ? ` · Mã ${profile.employeeCode}` : ''}
                </Typography>
              </Box>
              <Button
                component={RouterLink}
                to={`/employees/${profile.id}`}
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

      <DashboardEmployeeListDialog
        open={deptDrill != null}
        title={deptDrill?.title ?? ''}
        subtitle={deptDrill?.subtitle}
        employees={deptEmployees}
        loading={deptLoading}
        onClose={() => setDeptDrill(null)}
      />
    </Box>
  );
}
