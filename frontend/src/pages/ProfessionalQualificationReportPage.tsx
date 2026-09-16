import ArrowBackOutlinedIcon from '@mui/icons-material/ArrowBackOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import CloseIcon from '@mui/icons-material/Close';
import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import LocalHospitalOutlinedIcon from '@mui/icons-material/LocalHospitalOutlined';
import MedicationOutlinedIcon from '@mui/icons-material/MedicationOutlined';
import MonitorHeartOutlinedIcon from '@mui/icons-material/MonitorHeartOutlined';
import PregnantWomanOutlinedIcon from '@mui/icons-material/PregnantWomanOutlined';
import RefreshOutlinedIcon from '@mui/icons-material/RefreshOutlined';
import SchoolOutlinedIcon from '@mui/icons-material/SchoolOutlined';
import ScienceOutlinedIcon from '@mui/icons-material/ScienceOutlined';
import SearchOutlinedIcon from '@mui/icons-material/SearchOutlined';
import VerifiedOutlinedIcon from '@mui/icons-material/VerifiedOutlined';
import WarningAmberOutlinedIcon from '@mui/icons-material/WarningAmberOutlined';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogContent,
  DialogTitle,
  FormControl,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
  LinearProgress,
  Paper,
  Select,
  Stack,
  Tab,
  Table,
  TableBody,
  Tabs,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  LabelList,
  Pie,
  PieChart,
  ResponsiveContainer,
  Sector,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { PieSectorDataItem } from 'recharts/types/polar/Pie';
import { PageHeader } from '../components/layout/PageHeader';
import { PracticeCertificateSection } from '../components/reports/PracticeCertificateSection';
import {
  REPORT_SERIES_COLORS,
  reportChartBarCursor,
  reportChartGridProps,
  reportChartTickStyle,
  ReportChartCard,
  ReportChartEmpty,
  ReportChartTooltip,
} from '../components/charts/ReportChartUi';
import * as svc from '../services/professionalQualificationReportService';
import type {
  ProfessionBlock,
  ProfessionCode,
  QualificationDetail,
} from '../services/professionalQualificationReportService';

const INK = '#0f172a';
const ACCENT = '#0f766e';

const PROFESSION_META: Record<ProfessionCode, { color: string; icon: ReactNode; short: string }> = {
  DOCTOR: {
    color: '#0f766e',
    icon: <LocalHospitalOutlinedIcon fontSize="small" />,
    short: 'BS',
  },
  NURSE: {
    color: '#0369a1',
    icon: <MonitorHeartOutlinedIcon fontSize="small" />,
    short: 'ĐD',
  },
  MIDWIFE: {
    color: '#7c3aed',
    icon: <PregnantWomanOutlinedIcon fontSize="small" />,
    short: 'HS',
  },
  TECHNICIAN: {
    color: '#0e7490',
    icon: <ScienceOutlinedIcon fontSize="small" />,
    short: 'KTV',
  },
  ASSISTANT_PHYSICIAN: {
    color: '#b45309',
    icon: <SchoolOutlinedIcon fontSize="small" />,
    short: 'YS',
  },
  PHARMACIST: {
    color: '#be123c',
    icon: <MedicationOutlinedIcon fontSize="small" />,
    short: 'DS',
  },
};

function renderActivePieSector(props: PieSectorDataItem) {
  const { outerRadius = 102, fill } = props;
  return <Sector {...props} fill={fill} stroke="none" outerRadius={outerRadius + 3} />;
}

function ChartLegendChips({
  items,
  onSelect,
}: {
  items: { key: string; label: string; color: string; value: number; percent: number }[];
  onSelect?: (key: string) => void;
}) {
  // Chú giải cùng kiểu Dashboard: chấm tròn, tên, số kèm tỉ lệ — không viền, không nền.
  return (
    <Stack direction="row" flexWrap="wrap" justifyContent="center" gap={1.25} sx={{ mt: 2, px: 1 }}>
      {items.map((item) => (
        <Stack
          key={item.key}
          direction="row"
          alignItems="center"
          spacing={0.75}
          onClick={onSelect ? () => onSelect(item.key) : undefined}
          sx={{ cursor: onSelect ? 'pointer' : 'default' }}
        >
          <Box
            sx={{ width: 10, height: 10, borderRadius: '50%', bgcolor: item.color, flexShrink: 0 }}
          />
          <Typography
            variant="caption"
            sx={{ color: 'text.primary', fontWeight: 500, lineHeight: 1.3 }}
          >
            {item.label}
            <Typography component="span" variant="caption" color="text.secondary" sx={{ ml: 0.5 }}>
              {item.value} ({Math.round(item.percent)}%)
            </Typography>
          </Typography>
        </Stack>
      ))}
    </Stack>
  );
}

function stickyTableSx(headerBg: string, accent = ACCENT) {
  return {
    borderCollapse: 'separate' as const,
    borderSpacing: 0,
    '& .MuiTableCell-root': {
      borderColor: alpha(INK, 0.075),
    },
    '& .MuiTableCell-stickyHeader': {
      position: 'sticky',
      top: 0,
      zIndex: 5,
      py: 1.05,
      bgcolor: `${headerBg} !important`,
      color: alpha(INK, 0.78),
      fontWeight: 850,
      borderBottom: `2px solid ${alpha(accent, 0.28)}`,
      boxShadow: `0 1px 0 ${alpha(INK, 0.04)}`,
    },
  };
}

function Panel({ children, sx }: { children: ReactNode; sx?: object }) {
  return (
    <Paper
      elevation={0}
      sx={{
        borderRadius: 3,
        border: `1px solid ${alpha(INK, 0.08)}`,
        bgcolor: '#fff',
        boxShadow: `0 1px 2px ${alpha(INK, 0.03)}, 0 12px 32px ${alpha(INK, 0.04)}`,
        overflow: 'hidden',
        ...sx,
      }}
    >
      {children}
    </Paper>
  );
}

function PanelTitle({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <Stack
      direction="row"
      alignItems="flex-start"
      justifyContent="space-between"
      spacing={1.5}
      sx={{ mb: 1.75 }}
    >
      <Box>
        <Typography variant="subtitle1" fontWeight={850} letterSpacing="-0.02em">
          {title}
        </Typography>
        {subtitle ? (
          <Typography variant="caption" color="text.secondary" fontWeight={600}>
            {subtitle}
          </Typography>
        ) : null}
      </Box>
      {action}
    </Stack>
  );
}

function SummaryStat({
  label,
  value,
  hint,
  color,
  icon,
}: {
  label: string;
  value: string | number;
  hint: string;
  color: string;
  icon: ReactNode;
}) {
  return (
    <Box
      sx={{
        height: '100%',
        p: 1.75,
        borderRadius: 2.75,
        border: `1px solid ${alpha(color, 0.16)}`,
        background: `linear-gradient(160deg, ${alpha(color, 0.12)} 0%, ${alpha(color, 0.02)} 42%, #fff 100%)`,
        position: 'relative',
        overflow: 'hidden',
        '&::before': {
          content: '""',
          position: 'absolute',
          left: 0,
          top: 0,
          bottom: 0,
          width: 3.5,
          bgcolor: color,
        },
      }}
    >
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
        <Box sx={{ minWidth: 0, pl: 0.5 }}>
          <Typography
            variant="caption"
            fontWeight={800}
            sx={{
              color: alpha(INK, 0.48),
              textTransform: 'uppercase',
              letterSpacing: '0.07em',
              fontSize: '0.64rem',
            }}
          >
            {label}
          </Typography>
          <Typography
            variant="h4"
            fontWeight={850}
            sx={{
              color,
              lineHeight: 1.15,
              mt: 0.6,
              letterSpacing: '-0.04em',
              fontSize: { xs: '1.55rem', md: '1.85rem' },
            }}
          >
            {value}
          </Typography>
          <Typography
            variant="caption"
            sx={{
              display: 'block',
              mt: 0.55,
              color: alpha(INK, 0.55),
              fontWeight: 600,
              lineHeight: 1.35,
            }}
          >
            {hint}
          </Typography>
        </Box>
        <Box
          sx={{
            width: 38,
            height: 38,
            borderRadius: 2,
            display: 'grid',
            placeItems: 'center',
            bgcolor: alpha(color, 0.12),
            color,
            border: `1px solid ${alpha(color, 0.14)}`,
            flexShrink: 0,
          }}
        >
          {icon}
        </Box>
      </Stack>
    </Box>
  );
}

function ProfessionCard({
  block,
  selected,
  onOpen,
}: {
  block: ProfessionBlock;
  selected: boolean;
  onOpen: () => void;
}) {
  const meta = PROFESSION_META[block.code];
  const color = meta.color;
  const coverage = block.total > 0 ? Math.round((block.withDegree * 1000) / block.total) / 10 : 0;

  return (
    <Box
      component="button"
      type="button"
      onClick={onOpen}
      sx={{
        all: 'unset',
        cursor: 'pointer',
        display: 'block',
        width: '100%',
        boxSizing: 'border-box',
        p: 1.6,
        borderRadius: 2.75,
        border: `1px solid ${selected ? alpha(color, 0.45) : alpha(color, 0.14)}`,
        background: selected
          ? `linear-gradient(155deg, ${alpha(color, 0.18)} 0%, ${alpha(color, 0.05)} 55%, #fff 100%)`
          : `linear-gradient(155deg, ${alpha(color, 0.1)} 0%, #fff 62%)`,
        boxShadow: selected
          ? `0 10px 28px ${alpha(color, 0.18)}`
          : `0 6px 18px ${alpha(INK, 0.035)}`,
        transition: 'transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease',
        '&:hover': {
          transform: 'translateY(-2px)',
          boxShadow: `0 12px 28px ${alpha(color, 0.16)}`,
          borderColor: alpha(color, 0.35),
        },
        '&:focus-visible': {
          outline: `2px solid ${alpha(color, 0.55)}`,
          outlineOffset: 2,
        },
      }}
    >
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
        <Box>
          <Typography
            variant="caption"
            fontWeight={800}
            sx={{
              color: alpha(INK, 0.48),
              letterSpacing: '0.05em',
              textTransform: 'uppercase',
              fontSize: '0.62rem',
            }}
          >
            {block.label}
          </Typography>
          <Typography
            variant="h4"
            fontWeight={850}
            sx={{ color, mt: 0.4, letterSpacing: '-0.04em', lineHeight: 1.1 }}
          >
            {block.total}
          </Typography>
        </Box>
        <Box
          sx={{
            width: 34,
            height: 34,
            borderRadius: 1.75,
            display: 'grid',
            placeItems: 'center',
            bgcolor: alpha(color, 0.12),
            color,
          }}
        >
          {meta.icon}
        </Box>
      </Stack>
      <LinearProgress
        variant="determinate"
        value={Math.min(100, coverage)}
        sx={{
          mt: 1.4,
          height: 5,
          borderRadius: 99,
          bgcolor: alpha(color, 0.1),
          '& .MuiLinearProgress-bar': { bgcolor: color, borderRadius: 99 },
        }}
      />
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mt: 0.85 }}>
        <Typography variant="caption" fontWeight={700} sx={{ color: alpha(INK, 0.55) }}>
          {block.missingDegree > 0 ? `${block.missingDegree} thiếu BC` : 'Đủ bằng cấp'}
        </Typography>
        <Typography variant="caption" fontWeight={800} sx={{ color }}>
          Xem chi tiết →
        </Typography>
      </Stack>
    </Box>
  );
}

function ProfessionDetailDialog({
  open,
  block,
  employees,
  onClose,
}: {
  open: boolean;
  block: ProfessionBlock | null;
  employees: QualificationDetail[];
  onClose: () => void;
}) {
  const theme = useTheme();
  const [q, setQ] = useState('');
  const [deptFilter, setDeptFilter] = useState('ALL');

  useEffect(() => {
    if (open) {
      setQ('');
      setDeptFilter('ALL');
    }
  }, [open, block?.code]);

  const deptOptions = useMemo(
    () => ['ALL', ...(block?.byDepartment.map((d) => d.departmentName) ?? [])],
    [block],
  );

  const filtered = useMemo(() => {
    const needle = q.trim().toLocaleLowerCase('vi');
    return employees.filter((e) => {
      if (deptFilter !== 'ALL' && e.departmentName !== deptFilter) return false;
      if (!needle) return true;
      return `${e.employeeCode || ''} ${e.fullName} ${e.departmentName} ${e.positionTitle} ${e.degreeRaw || ''} ${e.degreeLevelLabel}`
        .toLocaleLowerCase('vi')
        .includes(needle);
    });
  }, [employees, q, deptFilter]);

  if (!block) return null;
  const color = PROFESSION_META[block.code].color;
  const chartData = block.byDegreeLevel.filter((d) => d.count > 0);
  const deptChart = block.byDepartment.slice(0, 8).map((d) => ({
    name: d.departmentName.length > 18 ? `${d.departmentName.slice(0, 16)}…` : d.departmentName,
    fullName: d.departmentName,
    count: d.count,
  }));

  return (
    <Dialog
      open={open}
      onClose={onClose}
      fullWidth
      maxWidth="lg"
      PaperProps={{
        sx: {
          borderRadius: 3,
          overflow: 'hidden',
          bgcolor: alpha('#f8fafc', 1),
        },
      }}
    >
      <DialogTitle
        sx={{
          py: 1.75,
          px: 2.5,
          background: `linear-gradient(120deg, ${alpha(color, 0.16)} 0%, ${alpha(color, 0.04)} 55%, #fff 100%)`,
          borderBottom: `1px solid ${alpha(color, 0.12)}`,
        }}
      >
        <Stack direction="row" alignItems="center" spacing={1.5}>
          <Box
            sx={{
              width: 42,
              height: 42,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(color, 0.14),
              color,
              border: `1px solid ${alpha(color, 0.18)}`,
            }}
          >
            {PROFESSION_META[block.code].icon}
          </Box>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography variant="h6" fontWeight={850} letterSpacing="-0.02em">
              {block.label}
            </Typography>
            <Typography variant="body2" color="text.secondary" fontWeight={600}>
              {block.total} nhân sự · Có bằng cấp {block.withDegree}/{block.total}
              {block.missingDegree > 0 ? ` · ${block.missingDegree} chưa cập nhật` : ''}
            </Typography>
          </Box>
          <Chip
            size="small"
            color={block.missingDegree > 0 ? 'warning' : 'success'}
            variant="outlined"
            label={block.missingDegree > 0 ? 'Thiếu bằng cấp' : 'Đủ bằng cấp'}
            sx={{ fontWeight: 750 }}
          />
          <IconButton onClick={onClose} aria-label="Đóng">
            <CloseIcon />
          </IconButton>
        </Stack>
      </DialogTitle>

      <DialogContent sx={{ px: { xs: 1.5, sm: 2.5 }, py: 2.25 }}>
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', md: '1fr 1fr' },
            gap: 1.5,
            mb: 2,
          }}
        >
          <ReportChartCard
            title="Phân bố trình độ chuẩn hoá"
            subtitle="Theo nhóm trình độ đã chuẩn hoá từ hồ sơ"
            height={268}
          >
            {chartData.length === 0 ? (
              <ReportChartEmpty message="Chưa có dữ liệu trình độ" />
            ) : (
              <ResponsiveContainer width="100%" height={248}>
                <BarChart
                  data={chartData}
                  layout="vertical"
                  margin={{ left: 4, right: 44, top: 4, bottom: 4 }}
                  barCategoryGap="22%"
                >
                  <CartesianGrid {...reportChartGridProps} horizontal={false} />
                  <XAxis
                    type="number"
                    allowDecimals={false}
                    tick={reportChartTickStyle}
                    axisLine={false}
                    tickLine={false}
                  />
                  <YAxis
                    type="category"
                    dataKey="label"
                    width={118}
                    tick={{
                      ...reportChartTickStyle,
                      fontSize: 11,
                      fill: alpha(INK, 0.72),
                      fontWeight: 700,
                    }}
                    axisLine={false}
                    tickLine={false}
                    interval={0}
                  />
                  <Tooltip cursor={reportChartBarCursor} content={<ReportChartTooltip />} />
                  <Bar dataKey="count" name="Số người" radius={[0, 9, 9, 0]} maxBarSize={26}>
                    {chartData.map((_, i) => (
                      <Cell key={i} fill={REPORT_SERIES_COLORS[i % REPORT_SERIES_COLORS.length]} />
                    ))}
                    <LabelList
                      dataKey="count"
                      position="right"
                      style={{ fill: color, fontSize: 12, fontWeight: 800 }}
                    />
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </ReportChartCard>

          <ReportChartCard
            title="Theo khoa / phòng"
            subtitle="Top khoa có nhiều nhân sự nhất"
            height={268}
          >
            {deptChart.length === 0 ? (
              <ReportChartEmpty message="Chưa có dữ liệu khoa" />
            ) : (
              <ResponsiveContainer width="100%" height={248}>
                <BarChart
                  data={deptChart}
                  layout="vertical"
                  margin={{ left: 4, right: 40, top: 4, bottom: 4 }}
                  barCategoryGap="20%"
                >
                  <CartesianGrid {...reportChartGridProps} horizontal={false} />
                  <XAxis
                    type="number"
                    allowDecimals={false}
                    tick={reportChartTickStyle}
                    axisLine={false}
                    tickLine={false}
                  />
                  <YAxis
                    type="category"
                    dataKey="name"
                    width={132}
                    tick={{
                      ...reportChartTickStyle,
                      fontSize: 10.5,
                      fill: alpha(INK, 0.72),
                      fontWeight: 700,
                    }}
                    axisLine={false}
                    tickLine={false}
                    interval={0}
                  />
                  <Tooltip
                    cursor={reportChartBarCursor}
                    content={<ReportChartTooltip />}
                    labelFormatter={(_, payload) => {
                      const row = payload?.[0]?.payload as { fullName?: string } | undefined;
                      return row?.fullName || '';
                    }}
                  />
                  <Bar
                    dataKey="count"
                    name="Số người"
                    fill={color}
                    radius={[0, 9, 9, 0]}
                    maxBarSize={24}
                    style={{ cursor: 'pointer' }}
                    onClick={(row) => {
                      const payload = row as { fullName?: string };
                      if (payload?.fullName) setDeptFilter(payload.fullName);
                    }}
                  >
                    <LabelList
                      dataKey="count"
                      position="right"
                      style={{ fill: color, fontSize: 12, fontWeight: 800 }}
                    />
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </ReportChartCard>
        </Box>

        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', lg: '0.9fr 1.1fr' },
            gap: 1.5,
            mb: 2,
          }}
        >
          <Panel sx={{ p: 1.75 }}>
            <PanelTitle title="Bằng cấp nguyên văn" subtitle="Top giá trị ghi trên hồ sơ" />
            <Stack spacing={1.05}>
              {block.rawDegreeBreakdown.slice(0, 8).map((d) => (
                <Box key={d.degree}>
                  <Stack direction="row" justifyContent="space-between" spacing={1}>
                    <Typography
                      variant="body2"
                      fontWeight={700}
                      noWrap
                      title={d.degree}
                      sx={{ maxWidth: '72%' }}
                    >
                      {d.degree}
                    </Typography>
                    <Typography variant="caption" fontWeight={800} color="text.secondary">
                      {d.count} · {d.percent}%
                    </Typography>
                  </Stack>
                  <LinearProgress
                    variant="determinate"
                    value={Math.min(100, d.percent)}
                    sx={{
                      mt: 0.45,
                      height: 6,
                      borderRadius: 99,
                      bgcolor: alpha(color, 0.08),
                      '& .MuiLinearProgress-bar': {
                        bgcolor: color,
                        borderRadius: 99,
                      },
                    }}
                  />
                </Box>
              ))}
            </Stack>
          </Panel>

          <Panel sx={{ p: 0 }}>
            <Box sx={{ px: 1.75, pt: 1.75, pb: 1 }}>
              <PanelTitle
                title="Bảng theo khoa"
                subtitle={`${block.byDepartment.length} khoa/phòng`}
              />
            </Box>
            <TableContainer sx={{ maxHeight: 280 }}>
              <Table size="small" stickyHeader sx={stickyTableSx('#eef7f6', color)}>
                <TableHead>
                  <TableRow>
                    <TableCell>Khoa / phòng</TableCell>
                    <TableCell align="right">SL</TableCell>
                    <TableCell>Trình độ nổi bật</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {block.byDepartment.map((d) => {
                    const top = [...d.byDegreeLevel]
                      .filter((x) => x.count > 0)
                      .sort((a, b) => b.count - a.count)[0];
                    return (
                      <TableRow
                        key={d.departmentName}
                        hover
                        sx={{ cursor: 'pointer' }}
                        onClick={() => setDeptFilter(d.departmentName)}
                      >
                        <TableCell
                          sx={{
                            fontWeight: deptFilter === d.departmentName ? 800 : 500,
                          }}
                        >
                          {d.departmentName}
                        </TableCell>
                        <TableCell align="right" sx={{ fontWeight: 800, color }}>
                          {d.count}
                        </TableCell>
                        <TableCell>{top ? `${top.label} (${top.count})` : '—'}</TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </TableContainer>
          </Panel>
        </Box>

        <Panel sx={{ p: 1.75 }}>
          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            spacing={1.25}
            alignItems={{ sm: 'center' }}
            justifyContent="space-between"
            sx={{ mb: 1.5 }}
          >
            <Box>
              <Typography variant="subtitle1" fontWeight={850}>
                Danh sách nhân viên
              </Typography>
              <Typography variant="caption" color="text.secondary" fontWeight={650}>
                {filtered.length} / {employees.length} người
                {deptFilter !== 'ALL' ? ` · ${deptFilter}` : ''}
              </Typography>
            </Box>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <TextField
                size="small"
                placeholder="Tìm tên, mã, bằng cấp…"
                value={q}
                onChange={(e) => setQ(e.target.value)}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <SearchOutlinedIcon fontSize="small" />
                    </InputAdornment>
                  ),
                }}
                sx={{ minWidth: { xs: '100%', sm: 240 }, bgcolor: '#fff' }}
              />
              <TextField
                select
                size="small"
                label="Khoa"
                value={deptFilter}
                onChange={(e) => setDeptFilter(e.target.value)}
                SelectProps={{ native: true }}
                sx={{ minWidth: 180, bgcolor: '#fff' }}
              >
                {deptOptions.map((d) => (
                  <option key={d} value={d}>
                    {d === 'ALL' ? 'Tất cả khoa' : d}
                  </option>
                ))}
              </TextField>
              {deptFilter !== 'ALL' && (
                <Button
                  size="small"
                  startIcon={<ArrowBackOutlinedIcon />}
                  onClick={() => setDeptFilter('ALL')}
                >
                  Bỏ lọc khoa
                </Button>
              )}
            </Stack>
          </Stack>

          <TableContainer
            sx={{
              borderRadius: 2,
              border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
              maxHeight: 420,
              bgcolor: '#fff',
              overflow: 'auto',
            }}
          >
            <Table size="small" stickyHeader sx={stickyTableSx('#eaf4f3', color)}>
              <TableHead>
                <TableRow>
                  {['Họ tên', 'Khoa', 'Chức danh', 'Bằng cấp', 'Chuẩn hoá', 'TT'].map((h) => (
                    <TableCell key={h}>{h}</TableCell>
                  ))}
                </TableRow>
              </TableHead>
              <TableBody>
                {filtered.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} align="center" sx={{ py: 4, color: 'text.secondary' }}>
                      Không có nhân viên khớp bộ lọc
                    </TableCell>
                  </TableRow>
                ) : (
                  filtered.map((d) => (
                    <TableRow key={d.employeeId} hover>
                      <TableCell>
                        <Typography variant="body2" fontWeight={750}>
                          {d.fullName}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          {d.employeeCode || '—'}
                        </Typography>
                      </TableCell>
                      <TableCell>{d.departmentName || '—'}</TableCell>
                      <TableCell>{d.positionTitle || '—'}</TableCell>
                      <TableCell>{d.degreeRaw || '—'}</TableCell>
                      <TableCell>
                        <Chip
                          size="small"
                          variant="outlined"
                          color={d.degreeLevelCode === 'MISSING' ? 'warning' : 'default'}
                          label={d.degreeLevelLabel}
                          sx={{ fontWeight: 700 }}
                        />
                      </TableCell>
                      <TableCell>{d.statusLabel}</TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </Panel>
      </DialogContent>
    </Dialog>
  );
}

export default function ProfessionalQualificationReportPage() {
  const theme = useTheme();
  const [report, setReport] = useState<svc.QualificationReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [listProfession, setListProfession] = useState<string>('ALL');
  const [listDepartment, setListDepartment] = useState<string>('ALL');
  const [listLevel, setListLevel] = useState<string>('ALL');
  const [listStatus, setListStatus] = useState<string>('ALL');
  const [selectedCode, setSelectedCode] = useState<ProfessionCode | null>(null);
  const [tab, setTab] = useState<'degree' | 'certificate'>('degree');
  const professionColors = useMemo(
    () =>
      Object.fromEntries(
        (Object.keys(PROFESSION_META) as ProfessionCode[]).map((k) => [
          k,
          PROFESSION_META[k].color,
        ]),
      ) as Record<ProfessionCode, string>,
    [],
  );

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setReport(await svc.fetchProfessionalQualificationReport());
    } catch {
      setError('Không tải được báo cáo trình độ chuyên môn.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const selectedBlock = useMemo(
    () => report?.byProfession.find((b) => b.code === selectedCode) ?? null,
    [report, selectedCode],
  );

  const selectedEmployees = useMemo(() => {
    if (!report || !selectedCode) return [];
    return report.details.filter((d) => d.professionCode === selectedCode);
  }, [report, selectedCode]);

  const overviewPie = useMemo(() => {
    if (!report) return [];
    return report.kpiCards
      .filter((c) => c.total > 0)
      .map((c) => ({ name: c.label, value: c.total, code: c.code }));
  }, [report]);

  const pieTotal = useMemo(() => overviewPie.reduce((sum, d) => sum + d.value, 0), [overviewPie]);

  const stackedChart = useMemo(() => {
    if (!report) return [];
    return report.degreeMatrix.rows
      .filter((r) => r.total > 0)
      .map((r) => {
        const point: Record<string, string | number> = { level: r.levelLabel };
        report.degreeMatrix.columns.forEach((c) => {
          point[c.label] = r.counts[c.code] ?? 0;
        });
        return point;
      });
  }, [report]);

  const listDepartmentOptions = useMemo(() => {
    if (!report) return [];
    const names = new Set<string>();
    report.details.forEach((d) => names.add(d.departmentName || '(Chưa có khoa)'));
    return [...names].sort((a, b) => a.localeCompare(b, 'vi'));
  }, [report]);

  const listLevelOptions = useMemo(() => {
    if (!report) return [];
    const present = new Set(report.details.map((d) => d.degreeLevelCode));
    return report.degreeLevelOrder
      .filter((code) => present.has(code))
      .map((code) => ({ code, label: report.degreeLevelLabels[code] || code }));
  }, [report]);

  const listStatusOptions = useMemo(() => {
    if (!report) return [];
    const map = new Map<string, string>();
    report.details.forEach((d) => map.set(d.status, d.statusLabel));
    return [...map.entries()].map(([code, label]) => ({ code, label }));
  }, [report]);

  const listFilterActive =
    listProfession !== 'ALL' ||
    listDepartment !== 'ALL' ||
    listLevel !== 'ALL' ||
    listStatus !== 'ALL' ||
    search.trim() !== '';

  const filteredDetails = useMemo(() => {
    if (!report) return [];
    const q = search.trim().toLocaleLowerCase('vi');
    return report.details.filter((d) => {
      if (listProfession !== 'ALL' && d.professionCode !== listProfession) return false;
      if (listDepartment !== 'ALL' && (d.departmentName || '(Chưa có khoa)') !== listDepartment) {
        return false;
      }
      if (listLevel !== 'ALL' && d.degreeLevelCode !== listLevel) return false;
      if (listStatus !== 'ALL' && d.status !== listStatus) return false;
      if (!q) return true;
      return `${d.employeeCode || ''} ${d.fullName} ${d.departmentName} ${d.positionTitle} ${d.degreeRaw || ''} ${d.degreeLevelLabel} ${d.professionLabel}`
        .toLocaleLowerCase('vi')
        .includes(q);
    });
  }, [listDepartment, listLevel, listProfession, listStatus, report, search]);

  async function handleExport() {
    setExporting(true);
    try {
      await svc.downloadProfessionalQualificationExcel();
    } catch {
      setError('Không xuất được file Excel.');
    } finally {
      setExporting(false);
    }
  }

  return (
    <Box>
      <PageHeader
        overline="Báo cáo"
        title="Trình độ chuyên môn"
        description="Trình độ / bằng cấp và chứng chỉ hành nghề của 6 đối tượng nghề nghiệp trên hồ sơ nhân lực."
        actions={
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Button
              variant="outlined"
              startIcon={<RefreshOutlinedIcon />}
              onClick={() => void load()}
              disabled={loading}
              sx={{ borderRadius: 2.25, fontWeight: 750 }}
            >
              Làm mới
            </Button>
            <Button
              variant="contained"
              startIcon={
                exporting ? (
                  <CircularProgress size={16} color="inherit" />
                ) : (
                  <FileDownloadOutlinedIcon />
                )
              }
              onClick={() => void handleExport()}
              disabled={exporting || !report}
              sx={{ borderRadius: 2.25, fontWeight: 750 }}
            >
              {exporting ? 'Đang xuất…' : 'Xuất Excel'}
            </Button>
          </Stack>
        }
      />

      {error && (
        <Alert severity="error" sx={{ mb: 2, borderRadius: 2.5 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {loading && !report ? (
        <Box sx={{ py: 10, textAlign: 'center' }}>
          <CircularProgress />
          <Typography color="text.secondary" sx={{ mt: 2, fontWeight: 600 }}>
            Đang tổng hợp trình độ chuyên môn…
          </Typography>
        </Box>
      ) : report ? (
        <Stack spacing={2.25}>
          <Paper
            elevation={0}
            sx={{
              borderRadius: 3,
              border: `1px solid ${alpha(INK, 0.08)}`,
              bgcolor: '#fff',
              px: 1,
            }}
          >
            <Tabs
              value={tab}
              onChange={(_, v) => setTab(v)}
              sx={{
                minHeight: 52,
                '& .MuiTab-root': {
                  minHeight: 52,
                  fontWeight: 800,
                  textTransform: 'none',
                  fontSize: 14.5,
                  px: 2.25,
                },
                '& .MuiTabs-indicator': { height: 3, borderRadius: 3 },
              }}
            >
              <Tab
                value="degree"
                icon={<SchoolOutlinedIcon fontSize="small" />}
                iconPosition="start"
                label="Trình độ / bằng cấp"
              />
              <Tab
                value="certificate"
                icon={<VerifiedOutlinedIcon fontSize="small" />}
                iconPosition="start"
                label={
                  <Stack direction="row" alignItems="center" spacing={0.75}>
                    <span>Chứng chỉ hành nghề</span>
                    {report.practiceCertificate.kpi.needsAttention > 0 && (
                      <Chip
                        size="small"
                        label={report.practiceCertificate.kpi.needsAttention}
                        sx={{
                          height: 20,
                          fontWeight: 800,
                          bgcolor: alpha('#dc2626', 0.1),
                          color: '#dc2626',
                        }}
                      />
                    )}
                  </Stack>
                }
              />
            </Tabs>
          </Paper>

          {tab === 'certificate' ? (
            <PracticeCertificateSection
              data={report.practiceCertificate}
              professionColors={professionColors}
              generatedAtLabel={report.generatedAtLabel}
            />
          ) : (
            <Stack spacing={2.25}>
              <Typography variant="caption" color="text.secondary" fontWeight={650}>
                Số liệu tại {report.generatedAtLabel} · Chỉ nhân sự chưa nghỉ việc · Nguồn: «Trình
                độ / bằng cấp»
              </Typography>

              <Box
                sx={{
                  display: 'grid',
                  gridTemplateColumns: { xs: '1fr 1fr', lg: 'repeat(4, 1fr)' },
                  gap: 1.35,
                }}
              >
                <SummaryStat
                  label="Trong 6 đối tượng"
                  value={report.totalInScope}
                  hint={`Trên ${report.totalHospitalStaff} NV toàn viện`}
                  color={ACCENT}
                  icon={<GroupsOutlinedIcon fontSize="small" />}
                />
                <SummaryStat
                  label="Có bằng cấp"
                  value={report.withDegreeCount}
                  hint={`${report.totalInScope ? Math.round((report.withDegreeCount * 1000) / report.totalInScope) / 10 : 0}% đã cập nhật`}
                  color="#0369a1"
                  icon={<CheckCircleOutlineIcon fontSize="small" />}
                />
                <SummaryStat
                  label="Chưa cập nhật"
                  value={report.missingDegreeCount}
                  hint="Cần bổ sung trên hồ sơ NV"
                  color="#b45309"
                  icon={<WarningAmberOutlinedIcon fontSize="small" />}
                />
                <SummaryStat
                  label="Nhóm nghề có dữ liệu"
                  value={report.kpiCards.filter((c) => c.total > 0).length}
                  hint="Bấm thẻ bên dưới để xem chi tiết"
                  color="#7c3aed"
                  icon={<SchoolOutlinedIcon fontSize="small" />}
                />
              </Box>

              <Box>
                <Typography
                  variant="subtitle2"
                  fontWeight={850}
                  sx={{ mb: 1.1, letterSpacing: '-0.01em' }}
                >
                  Chọn đối tượng để xem chi tiết
                </Typography>
                <Box
                  sx={{
                    display: 'grid',
                    gridTemplateColumns: {
                      xs: '1fr 1fr',
                      md: 'repeat(3, 1fr)',
                      lg: 'repeat(6, 1fr)',
                    },
                    gap: 1.25,
                  }}
                >
                  {report.byProfession.map((block) => (
                    <ProfessionCard
                      key={block.code}
                      block={block}
                      selected={selectedCode === block.code}
                      onOpen={() => setSelectedCode(block.code)}
                    />
                  ))}
                </Box>
              </Box>

              <Box
                sx={{
                  display: 'grid',
                  gridTemplateColumns: { xs: '1fr', lg: '0.92fr 1.28fr' },
                  gap: 1.5,
                }}
              >
                <ReportChartCard
                  title="Cơ cấu theo đối tượng"
                  subtitle="Tỷ lệ nhân sự trong 6 nhóm nghề — bấm để xem chi tiết"
                  height={360}
                >
                  {overviewPie.length === 0 ? (
                    <ReportChartEmpty message="Chưa có dữ liệu đối tượng" />
                  ) : (
                    <Box
                      sx={{
                        height: '100%',
                        display: 'flex',
                        flexDirection: 'column',
                      }}
                    >
                      <Box sx={{ flex: 1, minHeight: 240, position: 'relative' }}>
                        <ResponsiveContainer width="100%" height="100%">
                          <PieChart>
                            <Pie
                              data={overviewPie}
                              dataKey="value"
                              nameKey="name"
                              cx="50%"
                              cy="50%"
                              innerRadius={72}
                              outerRadius={102}
                              paddingAngle={0}
                              minAngle={2}
                              stroke="none"
                              isAnimationActive={false}
                              activeShape={renderActivePieSector}
                              style={{ cursor: 'pointer', outline: 'none' }}
                              onClick={(_, index) => {
                                const row = overviewPie[index];
                                if (row?.code) setSelectedCode(row.code as ProfessionCode);
                              }}
                            >
                              {overviewPie.map((d) => (
                                <Cell
                                  key={d.code}
                                  fill={PROFESSION_META[d.code as ProfessionCode].color}
                                  stroke={PROFESSION_META[d.code as ProfessionCode].color}
                                  strokeWidth={0}
                                />
                              ))}
                            </Pie>
                            <Tooltip
                              content={
                                <ReportChartTooltip
                                  valueFormatter={(v) => {
                                    const pct =
                                      pieTotal > 0
                                        ? Math.round((Number(v) * 1000) / pieTotal) / 10
                                        : 0;
                                    return `${v} người · ${pct}%`;
                                  }}
                                />
                              }
                            />
                            <text
                              x="50%"
                              y="50%"
                              textAnchor="middle"
                              dominantBaseline="middle"
                              style={{ pointerEvents: 'none' }}
                            >
                              <tspan
                                x="50%"
                                dy="-4"
                                style={{ fontSize: 22, fontWeight: 700, fill: INK }}
                              >
                                {pieTotal}
                              </tspan>
                              <tspan
                                x="50%"
                                dy="22"
                                style={{ fontSize: 11, fill: alpha(INK, 0.55) }}
                              >
                                nhân sự
                              </tspan>
                            </text>
                          </PieChart>
                        </ResponsiveContainer>
                      </Box>
                      <ChartLegendChips
                        items={overviewPie.map((d) => ({
                          key: d.code,
                          label: d.name,
                          color: PROFESSION_META[d.code as ProfessionCode].color,
                          value: d.value,
                          percent: pieTotal > 0 ? Math.round((d.value * 1000) / pieTotal) / 10 : 0,
                        }))}
                        onSelect={(key) => setSelectedCode(key as ProfessionCode)}
                      />
                    </Box>
                  )}
                </ReportChartCard>

                <ReportChartCard
                  title="Trình độ × đối tượng"
                  subtitle="Cột chồng theo nhóm nghề trong từng mức trình độ"
                  height={360}
                >
                  {stackedChart.length === 0 ? (
                    <ReportChartEmpty message="Chưa có dữ liệu trình độ" />
                  ) : (
                    <Box
                      sx={{
                        height: '100%',
                        display: 'flex',
                        flexDirection: 'column',
                      }}
                    >
                      <Box sx={{ flex: 1, minHeight: 250 }}>
                        <ResponsiveContainer width="100%" height="100%">
                          <BarChart
                            data={stackedChart}
                            margin={{ top: 12, right: 10, left: 0, bottom: 4 }}
                            barCategoryGap="28%"
                          >
                            <CartesianGrid {...reportChartGridProps} />
                            <XAxis
                              dataKey="level"
                              tick={{
                                ...reportChartTickStyle,
                                fontSize: 10.5,
                                fontWeight: 700,
                              }}
                              interval={0}
                              angle={-14}
                              textAnchor="end"
                              height={52}
                              axisLine={false}
                              tickLine={false}
                            />
                            <YAxis
                              allowDecimals={false}
                              tick={reportChartTickStyle}
                              axisLine={false}
                              tickLine={false}
                              width={36}
                            />
                            <Tooltip
                              cursor={reportChartBarCursor}
                              content={<ReportChartTooltip valueFormatter={(v) => `${v} người`} />}
                            />
                            {report.degreeMatrix.columns.map((c, idx, arr) => (
                              <Bar
                                key={c.code}
                                dataKey={c.label}
                                stackId="a"
                                fill={PROFESSION_META[c.code].color}
                                maxBarSize={42}
                                radius={idx === arr.length - 1 ? [7, 7, 0, 0] : [0, 0, 0, 0]}
                                style={{ cursor: 'pointer' }}
                                onClick={() => setSelectedCode(c.code)}
                              />
                            ))}
                          </BarChart>
                        </ResponsiveContainer>
                      </Box>
                      <ChartLegendChips
                        items={report.degreeMatrix.columns.map((c) => {
                          const value = report.degreeMatrix.columnTotals[c.code] || 0;
                          const grand = report.degreeMatrix.grandTotal || 1;
                          return {
                            key: c.code,
                            label: c.label,
                            color: PROFESSION_META[c.code].color,
                            value,
                            percent: Math.round((value * 1000) / grand) / 10,
                          };
                        })}
                        onSelect={(key) => setSelectedCode(key as ProfessionCode)}
                      />
                    </Box>
                  )}
                </ReportChartCard>
              </Box>

              <Panel sx={{ p: 2 }}>
                <PanelTitle
                  title="Ma trận trình độ chuyên môn"
                  subtitle="Số lượng nhân sự theo trình độ chuẩn hoá và đối tượng"
                />
                <TableContainer
                  sx={{
                    borderRadius: 2.25,
                    border: `1px solid ${alpha(INK, 0.08)}`,
                  }}
                >
                  <Table size="small">
                    <TableHead>
                      <TableRow sx={{ bgcolor: alpha(ACCENT, 0.06) }}>
                        <TableCell sx={{ fontWeight: 850 }}>Trình độ</TableCell>
                        {report.degreeMatrix.columns.map((c) => (
                          <TableCell
                            key={c.code}
                            align="right"
                            sx={{
                              fontWeight: 850,
                              color: PROFESSION_META[c.code].color,
                              cursor: 'pointer',
                              '&:hover': {
                                bgcolor: alpha(PROFESSION_META[c.code].color, 0.08),
                              },
                            }}
                            onClick={() => setSelectedCode(c.code)}
                          >
                            {c.label}
                          </TableCell>
                        ))}
                        <TableCell align="right" sx={{ fontWeight: 850 }}>
                          Tổng
                        </TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {report.degreeMatrix.rows.map((row) => (
                        <TableRow key={row.levelCode} hover>
                          <TableCell sx={{ fontWeight: 750 }}>{row.levelLabel}</TableCell>
                          {report.degreeMatrix.columns.map((c) => (
                            <TableCell key={c.code} align="right">
                              {row.counts[c.code] || 0}
                            </TableCell>
                          ))}
                          <TableCell align="right" sx={{ fontWeight: 850 }}>
                            {row.total}
                          </TableCell>
                        </TableRow>
                      ))}
                      <TableRow sx={{ bgcolor: alpha(ACCENT, 0.045) }}>
                        <TableCell sx={{ fontWeight: 850 }}>Tổng</TableCell>
                        {report.degreeMatrix.columns.map((c) => (
                          <TableCell key={c.code} align="right" sx={{ fontWeight: 850 }}>
                            {report.degreeMatrix.columnTotals[c.code] || 0}
                          </TableCell>
                        ))}
                        <TableCell align="right" sx={{ fontWeight: 850 }}>
                          {report.degreeMatrix.grandTotal}
                        </TableCell>
                      </TableRow>
                    </TableBody>
                  </Table>
                </TableContainer>
              </Panel>

              <Panel sx={{ p: 2 }}>
                <Stack
                  direction={{ xs: 'column', sm: 'row' }}
                  spacing={1.25}
                  alignItems={{ sm: 'center' }}
                  justifyContent="space-between"
                  sx={{ mb: 1.5 }}
                >
                  <Box>
                    <Typography variant="subtitle1" fontWeight={850}>
                      Danh sách nhân sự toàn phạm vi
                    </Typography>
                    <Typography variant="caption" color="text.secondary" fontWeight={650}>
                      {filteredDetails.length} / {report.details.length} người · Bấm một dòng để mở
                      chi tiết nhóm
                    </Typography>
                  </Box>
                  {listFilterActive && (
                    <Chip
                      size="small"
                      label="Xoá bộ lọc"
                      onClick={() => {
                        setListProfession('ALL');
                        setListDepartment('ALL');
                        setListLevel('ALL');
                        setListStatus('ALL');
                        setSearch('');
                      }}
                      sx={{ fontWeight: 750 }}
                    />
                  )}
                </Stack>
                <Box
                  sx={{
                    display: 'grid',
                    gridTemplateColumns: {
                      xs: '1fr',
                      sm: '1fr 1fr',
                      lg: '1fr 1.2fr 1fr 1fr 1.6fr',
                    },
                    gap: 1,
                    mb: 1.5,
                  }}
                >
                  <FormControl size="small">
                    <InputLabel>Đối tượng</InputLabel>
                    <Select
                      label="Đối tượng"
                      value={listProfession}
                      onChange={(e) => setListProfession(e.target.value)}
                    >
                      <MenuItem value="ALL">Tất cả đối tượng</MenuItem>
                      {report.kpiCards
                        .filter((c) => c.total > 0)
                        .map((c) => (
                          <MenuItem key={c.code} value={c.code}>
                            <Box
                              sx={{
                                width: 9,
                                height: 9,
                                borderRadius: '50%',
                                bgcolor: PROFESSION_META[c.code].color,
                                mr: 1,
                                flexShrink: 0,
                              }}
                            />
                            <Box sx={{ flex: 1 }}>{c.label}</Box>
                            <Typography variant="caption" color="text.secondary" fontWeight={800}>
                              {c.total}
                            </Typography>
                          </MenuItem>
                        ))}
                    </Select>
                  </FormControl>
                  <FormControl size="small">
                    <InputLabel>Khoa/phòng</InputLabel>
                    <Select
                      label="Khoa/phòng"
                      value={listDepartment}
                      onChange={(e) => setListDepartment(e.target.value)}
                    >
                      <MenuItem value="ALL">Tất cả khoa/phòng</MenuItem>
                      {listDepartmentOptions.map((name) => (
                        <MenuItem key={name} value={name}>
                          {name}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                  <FormControl size="small">
                    <InputLabel>Trình độ chuẩn hoá</InputLabel>
                    <Select
                      label="Trình độ chuẩn hoá"
                      value={listLevel}
                      onChange={(e) => setListLevel(e.target.value)}
                    >
                      <MenuItem value="ALL">Tất cả trình độ</MenuItem>
                      {listLevelOptions.map((l) => (
                        <MenuItem key={l.code} value={l.code}>
                          {l.label}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                  <FormControl size="small">
                    <InputLabel>Trạng thái</InputLabel>
                    <Select
                      label="Trạng thái"
                      value={listStatus}
                      onChange={(e) => setListStatus(e.target.value)}
                    >
                      <MenuItem value="ALL">Tất cả trạng thái</MenuItem>
                      {listStatusOptions.map((st) => (
                        <MenuItem key={st.code} value={st.code}>
                          {st.label}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                  <TextField
                    size="small"
                    placeholder="Tìm tên, mã NV, chức danh, bằng cấp…"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    InputProps={{
                      startAdornment: (
                        <InputAdornment position="start">
                          <SearchOutlinedIcon fontSize="small" />
                        </InputAdornment>
                      ),
                    }}
                  />
                </Box>
                <TableContainer
                  sx={{
                    borderRadius: 2.25,
                    border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                    maxHeight: 440,
                    bgcolor: '#fff',
                    overflow: 'auto',
                  }}
                >
                  <Table size="small" stickyHeader sx={stickyTableSx('#eaf4f3', ACCENT)}>
                    <TableHead>
                      <TableRow>
                        {[
                          'Họ tên',
                          'Khoa',
                          'Chức danh',
                          'Đối tượng',
                          'Bằng cấp',
                          'Chuẩn hoá',
                          'TT',
                        ].map((h) => (
                          <TableCell key={h}>{h}</TableCell>
                        ))}
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {filteredDetails.length === 0 ? (
                        <TableRow>
                          <TableCell
                            colSpan={7}
                            align="center"
                            sx={{ py: 4, color: 'text.secondary' }}
                          >
                            Không có nhân sự khớp bộ lọc
                          </TableCell>
                        </TableRow>
                      ) : (
                        filteredDetails.map((d) => (
                          <TableRow
                            key={d.employeeId}
                            hover
                            sx={{ cursor: 'pointer' }}
                            onClick={() => setSelectedCode(d.professionCode)}
                          >
                            <TableCell>
                              <Typography variant="body2" fontWeight={750}>
                                {d.fullName}
                              </Typography>
                              <Typography variant="caption" color="text.secondary">
                                {d.employeeCode || '—'}
                              </Typography>
                            </TableCell>
                            <TableCell>{d.departmentName || '—'}</TableCell>
                            <TableCell>{d.positionTitle || '—'}</TableCell>
                            <TableCell>
                              <Chip
                                size="small"
                                label={d.professionLabel}
                                sx={{
                                  fontWeight: 750,
                                  bgcolor: alpha(PROFESSION_META[d.professionCode].color, 0.1),
                                  color: PROFESSION_META[d.professionCode].color,
                                }}
                              />
                            </TableCell>
                            <TableCell>{d.degreeRaw || '—'}</TableCell>
                            <TableCell>
                              <Chip
                                size="small"
                                variant="outlined"
                                color={d.degreeLevelCode === 'MISSING' ? 'warning' : 'default'}
                                label={d.degreeLevelLabel}
                                sx={{ fontWeight: 700 }}
                              />
                            </TableCell>
                            <TableCell>{d.statusLabel}</TableCell>
                          </TableRow>
                        ))
                      )}
                    </TableBody>
                  </Table>
                </TableContainer>
              </Panel>
            </Stack>
          )}
        </Stack>
      ) : null}

      <ProfessionDetailDialog
        open={selectedBlock != null}
        block={selectedBlock}
        employees={selectedEmployees}
        onClose={() => setSelectedCode(null)}
      />
    </Box>
  );
}
