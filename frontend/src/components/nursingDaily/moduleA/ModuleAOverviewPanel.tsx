import {
  Box,
  Chip,
  MenuItem,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import WarningAmberOutlinedIcon from '@mui/icons-material/WarningAmberOutlined';
import HealingOutlinedIcon from '@mui/icons-material/HealingOutlined';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import PersonSearchOutlinedIcon from '@mui/icons-material/PersonSearchOutlined';
import MedicationOutlinedIcon from '@mui/icons-material/MedicationOutlined';
import { useMemo } from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  LabelList,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { ActivityReport, CompareMetric, DeptMetrics } from '../../../services/nursingActivityReportService';
import {
  ReportChartCard,
  ReportChartEmpty,
  ReportChartTooltip,
  ReportKpiCard,
  ReportChartScrollFrame,
  REPORT_SERIES_COLORS,
  reportChartGridProps,
  reportChartLegendProps,
  reportChartTickStyle,
  reportChartXAxisProps,
} from '../../charts/ReportChartUi';

const ACCENT = '#0f766e';
const INK = '#0f172a';

const COMPARE_OPTIONS: { value: CompareMetric; label: string }[] = [
  { value: 'FALL_RATE', label: 'Tỷ lệ té ngã (%)' },
  { value: 'FALL_FREQUENCY', label: 'Tần suất té ngã/1.000 ngày' },
  { value: 'PRESSURE_RATE', label: 'Tỷ lệ loét tì đè (%)' },
  { value: 'PRESSURE_FREQUENCY', label: 'Tần suất loét/1.000 ngày' },
  { value: 'NURSE_BED', label: 'Điều dưỡng/Giường' },
  { value: 'ID_MIXUP_FREQUENCY', label: 'Nhầm NB/1.000 ngày' },
  { value: 'MEDICATION_RATE', label: 'Sai sót thuốc (%)' },
];

function shortDeptName(name: string) {
  return name.replace(/^KHOA\s+/i, '').trim() || name;
}

function CompareTooltip({
  active,
  payload,
  metricLabel,
}: {
  active?: boolean;
  payload?: Array<{ payload: { departmentName: string; value: number; valueLabel: string; rank: number } }>;
  metricLabel: string;
}) {
  if (!active || !payload?.length) return null;
  const row = payload[0].payload;
  return (
    <Box
      sx={{
        minWidth: 220,
        px: 1.75,
        py: 1.35,
        borderRadius: 2.25,
        bgcolor: '#fff',
        border: `1px solid ${alpha(ACCENT, 0.2)}`,
        boxShadow: `0 12px 32px ${alpha(INK, 0.12)}`,
      }}
    >
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 0.75 }}>
        <Chip
          size="small"
          label={`#${row.rank}`}
          sx={{
            height: 22,
            fontWeight: 800,
            fontSize: '0.68rem',
            bgcolor: alpha(ACCENT, 0.1),
            color: ACCENT,
            border: `1px solid ${alpha(ACCENT, 0.18)}`,
          }}
        />
        <Typography variant="subtitle2" fontWeight={800} sx={{ letterSpacing: '-0.02em', lineHeight: 1.25 }}>
          {row.departmentName}
        </Typography>
      </Stack>
      <Typography variant="caption" color="text.secondary" fontWeight={650} sx={{ display: 'block', mb: 0.35 }}>
        {metricLabel}
      </Typography>
      <Typography variant="h6" fontWeight={850} sx={{ color: ACCENT, letterSpacing: '-0.03em', lineHeight: 1.2 }}>
        {row.valueLabel}
      </Typography>
    </Box>
  );
}

type Props = {
  report: ActivityReport;
  compareMetric: CompareMetric;
  onCompareMetricChange: (m: CompareMetric) => void;
  onSelectDepartment?: (id: number) => void;
  deptSearch: string;
  onDeptSearchChange: (v: string) => void;
};

export function ModuleAOverviewPanel({
  report,
  compareMetric,
  onCompareMetricChange,
  onSelectDepartment,
  deptSearch,
  onDeptSearchChange,
}: Props) {
  const ov = report.overviewKpi ?? {};
  const falls = ov.falls as Record<string, string> | undefined;
  const pu = ov.pressureUlcers as Record<string, string> | undefined;
  const nb = ov.nurseBed as Record<string, string> | undefined;
  const idm = ov.idMixups as Record<string, string> | undefined;
  const med = ov.medicationErrors as Record<string, string> | undefined;

  const filteredSummary = useMemo(() => {
    const q = deptSearch.trim().toLowerCase();
    if (!q) return report.summaryTable;
    return report.summaryTable.filter((r) => r.departmentName.toLowerCase().includes(q));
  }, [report.summaryTable, deptSearch]);

  const trendData = report.trend.filter((t) => t.hasData).map((t) => ({
    name: t.label,
    fallRate: t.fallRate ?? 0,
    pressureRate: t.pressureUlcerRate ?? 0,
    idMixup: t.idMixupFrequency ?? 0,
    medRate: t.medicationErrorRate ?? 0,
  }));

  const compareMetricLabel = COMPARE_OPTIONS.find((o) => o.value === compareMetric)?.label ?? 'Chỉ số';

  const compareData = useMemo(
    () =>
      report.compareChart.map((row, i) => ({
        ...row,
        shortName: shortDeptName(row.departmentName),
        rank: i + 1,
      })),
    [report.compareChart],
  );

  const chartHeight = Math.max(360, compareData.length * 48 + 48);

  return (
    <Stack spacing={2}>
      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr 1fr', md: 'repeat(5, 1fr)' }, gap: 1.25 }}>
        <ReportKpiCard
          label="Té ngã"
          value={(falls?.rateLabel as string) ?? '—'}
          hint={falls?.frequencyLabel as string}
          color="#0f766e"
          icon={<WarningAmberOutlinedIcon fontSize="small" />}
        />
        <ReportKpiCard
          label="Loét tì đè"
          value={(pu?.rateLabel as string) ?? '—'}
          hint={pu?.frequencyLabel as string}
          color="#0369a1"
          icon={<HealingOutlinedIcon fontSize="small" />}
        />
        <ReportKpiCard
          label="ĐD/NB"
          value={(nb?.ratioLabel as string) ?? '—'}
          hint="Điều dưỡng đi làm / người bệnh nội trú"
          color="#0e7490"
          icon={<GroupsOutlinedIcon fontSize="small" />}
        />
        <ReportKpiCard
          label="Nhầm NB"
          value={(idm?.frequencyLabel as string) ?? '—'}
          hint="Sự cố xác định người bệnh"
          color="#7c3aed"
          icon={<PersonSearchOutlinedIcon fontSize="small" />}
        />
        <ReportKpiCard
          label="Sai sót thuốc"
          value={(med?.rateLabel as string) ?? '—'}
          hint="Tỷ lệ sai sót dùng thuốc"
          color="#b45309"
          icon={<MedicationOutlinedIcon fontSize="small" />}
        />
      </Box>

      <ReportChartCard title="Xu hướng chỉ số an toàn" subtitle="Té ngã · Loét · Nhầm NB · Sai sót thuốc">
        {trendData.length === 0 ? (
          <ReportChartEmpty message="Chưa có dữ liệu biểu đồ" />
        ) : (
          <ReportChartScrollFrame pointCount={trendData.length} height={320}>
            {(chartWidth) => (
              <ResponsiveContainer key={chartWidth} width={chartWidth} height="100%">
                <LineChart data={trendData} margin={{ top: 12, right: 20, left: 4, bottom: 8 }}>
                  <CartesianGrid {...reportChartGridProps} />
                  <XAxis dataKey="name" {...reportChartXAxisProps} />
                  <YAxis
                    tick={reportChartTickStyle}
                    axisLine={false}
                    tickLine={false}
                    width={40}
                  />
                  <Tooltip
                    cursor={{ stroke: alpha(ACCENT, 0.3), strokeWidth: 1.5 }}
                    content={<ReportChartTooltip />}
                  />
                  <Legend {...reportChartLegendProps} />
                  <Line type="monotone" dataKey="fallRate" name="Té ngã %" stroke={REPORT_SERIES_COLORS[0]} strokeWidth={2.5} dot={{ r: 3, strokeWidth: 2, stroke: '#fff', fill: REPORT_SERIES_COLORS[0] }} activeDot={{ r: 5.5, strokeWidth: 2, stroke: '#fff' }} />
                  <Line type="monotone" dataKey="pressureRate" name="Loét %" stroke={REPORT_SERIES_COLORS[1]} strokeWidth={2.5} dot={{ r: 3, strokeWidth: 2, stroke: '#fff', fill: REPORT_SERIES_COLORS[1] }} activeDot={{ r: 5.5, strokeWidth: 2, stroke: '#fff' }} />
                  <Line type="monotone" dataKey="idMixup" name="Nhầm NB/1000" stroke={REPORT_SERIES_COLORS[2]} strokeWidth={2.5} dot={{ r: 3, strokeWidth: 2, stroke: '#fff', fill: REPORT_SERIES_COLORS[2] }} activeDot={{ r: 5.5, strokeWidth: 2, stroke: '#fff' }} />
                  <Line type="monotone" dataKey="medRate" name="Sai sót thuốc %" stroke={REPORT_SERIES_COLORS[3]} strokeWidth={2.5} dot={{ r: 3, strokeWidth: 2, stroke: '#fff', fill: REPORT_SERIES_COLORS[3] }} activeDot={{ r: 5.5, strokeWidth: 2, stroke: '#fff' }} />
                </LineChart>
              </ResponsiveContainer>
            )}
          </ReportChartScrollFrame>
        )}
      </ReportChartCard>

      <Paper
        elevation={0}
        sx={{
          borderRadius: 3,
          border: `1px solid ${alpha('#64748b', 0.12)}`,
          overflow: 'hidden',
          boxShadow: `0 1px 3px ${alpha(INK, 0.04)}`,
        }}
      >
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          spacing={1.25}
          alignItems={{ sm: 'center' }}
          sx={{
            px: { xs: 1.5, sm: 2 },
            py: 1.5,
            borderBottom: `1px solid ${alpha('#64748b', 0.1)}`,
            background: `linear-gradient(135deg, ${alpha(ACCENT, 0.07)} 0%, ${alpha('#fff', 0.96)} 55%, ${alpha('#f0fdfa', 0.45)} 100%)`,
          }}
        >
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography variant="subtitle1" fontWeight={850} sx={{ letterSpacing: '-0.02em', lineHeight: 1.25 }}>
              So sánh theo khoa
            </Typography>
            <Typography variant="caption" color="text.secondary" fontWeight={600}>
              Xếp hạng {compareData.length} khoa theo chỉ số đã chọn · nhấn cột để xem chi tiết
            </Typography>
          </Box>
          <TextField
            select
            size="small"
            label="Chỉ số"
            value={compareMetric}
            sx={{
              minWidth: { xs: '100%', sm: 240 },
              bgcolor: '#fff',
              borderRadius: 1.5,
              '& .MuiOutlinedInput-root': { borderRadius: 1.75 },
            }}
            onChange={(e) => onCompareMetricChange(e.target.value as CompareMetric)}
          >
            {COMPARE_OPTIONS.map((o) => (
              <MenuItem key={o.value} value={o.value}>{o.label}</MenuItem>
            ))}
          </TextField>
        </Stack>

        {compareData.length === 0 ? (
          <Box sx={{ py: 5, textAlign: 'center', color: 'text.secondary' }}>Chưa có dữ liệu so sánh</Box>
        ) : (
          <Box sx={{ px: { xs: 0.5, sm: 1.25 }, pt: 1.5, pb: 1.75, width: '100%', height: chartHeight }}>
            <ResponsiveContainer>
              <BarChart
                data={compareData}
                layout="vertical"
                margin={{ top: 4, right: 72, left: 4, bottom: 8 }}
                barCategoryGap="28%"
              >
                <defs>
                  <linearGradient id="moduleACompareBar" x1="0" y1="0" x2="1" y2="0">
                    <stop offset="0%" stopColor="#0d9488" />
                    <stop offset="100%" stopColor="#0f766e" />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="4 6" stroke={alpha('#64748b', 0.14)} horizontal={false} />
                <XAxis
                  type="number"
                  tick={{ fontSize: 12, fill: alpha(INK, 0.55), fontWeight: 600 }}
                  axisLine={{ stroke: alpha('#64748b', 0.2) }}
                  tickLine={false}
                />
                <YAxis
                  type="category"
                  dataKey="shortName"
                  width={148}
                  tick={{ fontSize: 12, fill: alpha(INK, 0.78), fontWeight: 700 }}
                  axisLine={false}
                  tickLine={false}
                  interval={0}
                />
                <Tooltip
                  cursor={{ fill: alpha(ACCENT, 0.06) }}
                  content={<CompareTooltip metricLabel={compareMetricLabel} />}
                />
                <Bar
                  dataKey="value"
                  fill="url(#moduleACompareBar)"
                  radius={[0, 8, 8, 0]}
                  maxBarSize={28}
                  style={{ cursor: onSelectDepartment ? 'pointer' : 'default' }}
                  onClick={(data) => {
                    const payload = data as { departmentId?: number };
                    if (payload?.departmentId != null) onSelectDepartment?.(payload.departmentId);
                  }}
                >
                  <LabelList
                    dataKey="valueLabel"
                    position="right"
                    style={{
                      fill: ACCENT,
                      fontSize: 12,
                      fontWeight: 750,
                    }}
                  />
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </Box>
        )}
      </Paper>

      <Paper elevation={0} sx={{ p: 1.5, borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }} sx={{ mb: 1 }}>
          <Typography variant="subtitle2" fontWeight={800} sx={{ flex: 1 }}>Bảng tổng hợp toàn viện</Typography>
          <TextField size="small" label="Tìm khoa" value={deptSearch} onChange={(e) => onDeptSearchChange(e.target.value)} sx={{ minWidth: 200 }} />
        </Stack>
        <SummaryTable rows={filteredSummary} onSelectDepartment={onSelectDepartment} />
      </Paper>
    </Stack>
  );
}

export function SummaryTable({
  rows,
  onSelectDepartment,
}: {
  rows: DeptMetrics[];
  onSelectDepartment?: (id: number) => void;
}) {
  return (
    <TableContainer sx={{ borderRadius: 2, border: `1px solid ${alpha('#64748b', 0.1)}` }}>
      <Table size="small">
        <TableHead>
          <TableRow sx={{ bgcolor: alpha(ACCENT, 0.06) }}>
            <TableCell sx={{ fontWeight: 800 }}>Khoa</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Té ngã %</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Té ngã/1000</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Loét %</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Loét/1000</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>ĐD/NB</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Nhầm NB/1000</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Sai sót %</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.length === 0 ? (
            <TableRow><TableCell colSpan={8} align="center" sx={{ py: 3, color: 'text.secondary' }}>Chưa có dữ liệu</TableCell></TableRow>
          ) : rows.map((r) => (
            <TableRow
              key={r.departmentId}
              hover={!!onSelectDepartment}
              sx={{ cursor: onSelectDepartment ? 'pointer' : 'default' }}
              onClick={() => onSelectDepartment?.(r.departmentId)}
            >
              <TableCell sx={{ fontWeight: 650 }}>{r.departmentName}</TableCell>
              <TableCell align="right">{r.fallRateLabel}</TableCell>
              <TableCell align="right">{r.fallFrequencyLabel}</TableCell>
              <TableCell align="right">{r.pressureUlcerRateLabel}</TableCell>
              <TableCell align="right">{r.pressureUlcerFrequencyLabel}</TableCell>
              <TableCell align="right">{r.nurseBedRatioLabel}</TableCell>
              <TableCell align="right">{r.idMixupFrequencyLabel}</TableCell>
              <TableCell align="right">{r.medicationErrorRateLabel}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
