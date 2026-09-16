import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import LocalHospitalOutlinedIcon from '@mui/icons-material/LocalHospitalOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import TrendingUpOutlinedIcon from '@mui/icons-material/TrendingUpOutlined';
import SpeedOutlinedIcon from '@mui/icons-material/SpeedOutlined';
import WarningAmberOutlinedIcon from '@mui/icons-material/WarningAmberOutlined';
import HealingOutlinedIcon from '@mui/icons-material/HealingOutlined';
import SingleBedOutlinedIcon from '@mui/icons-material/SingleBedOutlined';
import PersonSearchOutlinedIcon from '@mui/icons-material/PersonSearchOutlined';
import MedicationOutlinedIcon from '@mui/icons-material/MedicationOutlined';
import {
  Box,
  CircularProgress,
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
import type { ReactNode } from 'react';
import {
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { ActivityReport, MetricKind } from '../../../services/nursingActivityReportService';
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
import { ReportExportButtons } from './ReportExportButtons';

const ACCENT = '#0f766e';

const KPI_ICON_BY_KEY: Record<string, { icon: ReactNode; color: string }> = {
  falls: { icon: <WarningAmberOutlinedIcon fontSize="small" />, color: '#0f766e' },
  fallRateLabel: { icon: <TrendingUpOutlinedIcon fontSize="small" />, color: '#0f766e' },
  fallFrequencyLabel: { icon: <SpeedOutlinedIcon fontSize="small" />, color: '#0e7490' },
  newPressureUlcers: { icon: <HealingOutlinedIcon fontSize="small" />, color: '#0369a1' },
  pressureUlcerRateLabel: { icon: <TrendingUpOutlinedIcon fontSize="small" />, color: '#0369a1' },
  pressureUlcerFrequencyLabel: { icon: <SpeedOutlinedIcon fontSize="small" />, color: '#0284c7' },
  totalStaff: { icon: <GroupsOutlinedIcon fontSize="small" />, color: '#0e7490' },
  workingStaff: { icon: <GroupsOutlinedIcon fontSize="small" />, color: '#0e7490' },
  actualBeds: { icon: <SingleBedOutlinedIcon fontSize="small" />, color: '#0f766e' },
  nurseBedRatioLabel: { icon: <GroupsOutlinedIcon fontSize="small" />, color: '#0e7490' },
  idMixups: { icon: <PersonSearchOutlinedIcon fontSize="small" />, color: '#7c3aed' },
  idMixupFrequencyLabel: { icon: <SpeedOutlinedIcon fontSize="small" />, color: '#7c3aed' },
  medicationErrors: { icon: <MedicationOutlinedIcon fontSize="small" />, color: '#b45309' },
  medicationErrorRateLabel: { icon: <TrendingUpOutlinedIcon fontSize="small" />, color: '#b45309' },
  inpatients: { icon: <LocalHospitalOutlinedIcon fontSize="small" />, color: '#0369a1' },
  inpatientTreatmentDays: { icon: <CalendarMonthOutlinedIcon fontSize="small" />, color: '#64748b' },
};

export type MetricPanelConfig = {
  kind: MetricKind;
  title: string;
  subtitle: string;
  kpiFields: { key: string; label: string }[];
  deptHeaders: { key: keyof ActivityReport['byDepartment'][0] | string; label: string; align?: 'left' | 'right' }[];
  trendPrimaryKey: string;
  trendPrimaryName: string;
  trendSecondaryKey?: string;
  trendSecondaryName?: string;
  showSortBy?: boolean;
};

export const METRIC_CONFIGS: Record<Exclude<MetricKind, 'overview'>, MetricPanelConfig> = {
  falls: {
    kind: 'falls',
    title: 'Báo cáo tỷ lệ té ngã',
    subtitle: 'Tự động tính từ báo cáo hằng ngày · Không nhập tay tỷ lệ',
    kpiFields: [
      { key: 'falls', label: 'Tổng ca té ngã' },
      { key: 'inpatients', label: 'NB điều trị nội trú' },
      { key: 'inpatientTreatmentDays', label: 'Tổng ngày nằm viện' },
      { key: 'fallRateLabel', label: 'Tỷ lệ té ngã' },
      { key: 'fallFrequencyLabel', label: 'Tần suất/1.000 ngày' },
    ],
    deptHeaders: [
      { key: 'departmentName', label: 'Khoa' },
      { key: 'falls', label: 'Ca té ngã', align: 'right' },
      { key: 'inpatients', label: 'NB nội trú', align: 'right' },
      { key: 'inpatientTreatmentDays', label: 'Ngày nằm viện', align: 'right' },
      { key: 'fallRateLabel', label: 'Tỷ lệ', align: 'right' },
      { key: 'fallFrequencyLabel', label: 'Tần suất/1000', align: 'right' },
    ],
    trendPrimaryKey: 'fallRate',
    trendPrimaryName: 'Tỷ lệ té ngã (%)',
    trendSecondaryKey: 'fallFrequency',
    trendSecondaryName: 'Tần suất/1.000 ngày',
    showSortBy: true,
  },
  'pressure-ulcers': {
    kind: 'pressure-ulcers',
    title: 'Báo cáo tỷ lệ loét tì đè',
    subtitle: 'Ca loét mới xuất hiện · Tự động tính toán',
    kpiFields: [
      { key: 'newPressureUlcers', label: 'Tổng ca loét mới' },
      { key: 'inpatients', label: 'NB nội trú' },
      { key: 'inpatientTreatmentDays', label: 'Tổng ngày nằm viện' },
      { key: 'pressureUlcerRateLabel', label: 'Tỷ lệ loét tì đè' },
      { key: 'pressureUlcerFrequencyLabel', label: 'Tần suất/1.000 ngày' },
    ],
    deptHeaders: [
      { key: 'departmentName', label: 'Khoa' },
      { key: 'newPressureUlcers', label: 'Ca loét mới', align: 'right' },
      { key: 'inpatients', label: 'NB nội trú', align: 'right' },
      { key: 'inpatientTreatmentDays', label: 'Ngày nằm viện', align: 'right' },
      { key: 'pressureUlcerRateLabel', label: 'Tỷ lệ', align: 'right' },
      { key: 'pressureUlcerFrequencyLabel', label: 'Tần suất', align: 'right' },
    ],
    trendPrimaryKey: 'pressureUlcerRate',
    trendPrimaryName: 'Tỷ lệ loét (%)',
    trendSecondaryKey: 'pressureUlcerFrequency',
    trendSecondaryName: 'Tần suất/1.000 ngày',
    showSortBy: true,
  },
  'nurse-bed': {
    kind: 'nurse-bed',
    title: 'Báo cáo tỷ lệ điều dưỡng/người bệnh',
    subtitle: 'Điều dưỡng đi làm / Người bệnh nội trú',
    kpiFields: [
      { key: 'workingStaff', label: 'ĐD đi làm' },
      { key: 'inpatients', label: 'NB nội trú' },
      { key: 'nurseBedRatioLabel', label: 'Tỷ lệ ĐD/NB' },
    ],
    deptHeaders: [
      { key: 'departmentName', label: 'Khoa' },
      { key: 'workingStaff', label: 'ĐD đi làm', align: 'right' },
      { key: 'inpatients', label: 'NB nội trú', align: 'right' },
      { key: 'nurseBedRatioLabel', label: 'Tỷ lệ', align: 'right' },
    ],
    trendPrimaryKey: 'nurseBedRatio',
    trendPrimaryName: 'ĐD/NB',
  },
  'id-mixups': {
    kind: 'id-mixups',
    title: 'Báo cáo nhầm lẫn xác định người bệnh',
    subtitle: 'Tần suất / 1.000 ngày điều trị',
    kpiFields: [
      { key: 'idMixups', label: 'Tổng trường hợp nhầm lẫn' },
      { key: 'inpatientTreatmentDays', label: 'Tổng ngày nằm viện' },
      { key: 'idMixupFrequencyLabel', label: 'Tần suất nhầm lẫn' },
    ],
    deptHeaders: [
      { key: 'departmentName', label: 'Khoa' },
      { key: 'idMixups', label: 'Số trường hợp', align: 'right' },
      { key: 'inpatientTreatmentDays', label: 'Ngày nằm viện', align: 'right' },
      { key: 'idMixupFrequencyLabel', label: 'Tần suất/1000', align: 'right' },
    ],
    trendPrimaryKey: 'idMixupFrequency',
    trendPrimaryName: 'Tần suất/1.000 ngày',
  },
  'medication-errors': {
    kind: 'medication-errors',
    title: 'Báo cáo tỷ lệ sai sót do dùng thuốc',
    subtitle: 'NB xảy ra sai sót / NB nội trú',
    kpiFields: [
      { key: 'medicationErrors', label: 'NB xảy ra sai sót' },
      { key: 'inpatients', label: 'NB nội trú' },
      { key: 'medicationErrorRateLabel', label: 'Tỷ lệ sai sót' },
    ],
    deptHeaders: [
      { key: 'departmentName', label: 'Khoa' },
      { key: 'medicationErrors', label: 'NB sai sót', align: 'right' },
      { key: 'inpatients', label: 'NB nội trú', align: 'right' },
      { key: 'medicationErrorRateLabel', label: 'Tỷ lệ', align: 'right' },
    ],
    trendPrimaryKey: 'medicationErrorRate',
    trendPrimaryName: 'Tỷ lệ sai sót (%)',
  },
};

type Props = {
  config: MetricPanelConfig;
  report: ActivityReport | null;
  loading: boolean;
  sortBy: 'RATE' | 'FREQUENCY';
  sortDir: 'ASC' | 'DESC';
  onSortByChange: (v: 'RATE' | 'FREQUENCY') => void;
  onSortDirChange: (v: 'ASC' | 'DESC') => void;
  onExport: (kind: 'excel' | 'pdf') => void;
  exporting: 'excel' | 'pdf' | null;
  onSelectDepartment?: (id: number) => void;
};

export function ModuleAMetricPanel({
  config,
  report,
  loading,
  sortBy,
  sortDir,
  onSortByChange,
  onSortDirChange,
  onExport,
  exporting,
  onSelectDepartment,
}: Props) {
  const kpi = report?.kpi ?? {};
  const trendData = (report?.trend ?? []).filter((t) => t.hasData).map((t) => ({
    name: t.label,
    primary: Number((t as unknown as Record<string, unknown>)[config.trendPrimaryKey] ?? 0),
    secondary: config.trendSecondaryKey
      ? Number((t as unknown as Record<string, unknown>)[config.trendSecondaryKey] ?? 0)
      : undefined,
  }));

  return (
    <Box>
      <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" alignItems={{ sm: 'center' }} spacing={1} sx={{ mb: 1.5 }}>
        <Box>
          <Typography variant="subtitle2" fontWeight={800}>{config.title}</Typography>
          <Typography variant="caption" color="text.secondary">{config.subtitle}</Typography>
        </Box>
        <Stack direction="row" spacing={1}>
          <ReportExportButtons onExport={onExport} exporting={exporting} />
        </Stack>
      </Stack>

      {loading && !report ? (
        <Box sx={{ py: 6, display: 'grid', placeItems: 'center' }}><CircularProgress /></Box>
      ) : report && (
        <Stack spacing={2}>
          <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr 1fr', md: `repeat(${Math.min(config.kpiFields.length, 5)}, 1fr)` }, gap: 1.15 }}>
            {config.kpiFields.map((f) => {
              const meta = KPI_ICON_BY_KEY[f.key] ?? {
                icon: <TrendingUpOutlinedIcon fontSize="small" />,
                color: ACCENT,
              };
              return (
                <ReportKpiCard
                  key={f.key}
                  label={f.label}
                  value={String(kpi[f.key] ?? '—')}
                  hint="Tự động tính từ báo cáo hằng ngày"
                  color={meta.color}
                  icon={meta.icon}
                />
              );
            })}
          </Box>

          <ReportChartCard title="Xu hướng" subtitle={config.subtitle}>
            {trendData.length === 0 ? (
              <ReportChartEmpty message="Chưa có dữ liệu biểu đồ" />
            ) : (
              <ReportChartScrollFrame pointCount={trendData.length} height={300}>
                {(chartWidth) => (
                  <ResponsiveContainer key={chartWidth} width={chartWidth} height="100%">
                    <LineChart data={trendData} margin={{ top: 12, right: 20, left: 4, bottom: 8 }}>
                      <CartesianGrid {...reportChartGridProps} />
                      <XAxis dataKey="name" {...reportChartXAxisProps} />
                      <YAxis tick={reportChartTickStyle} axisLine={false} tickLine={false} width={40} />
                      <Tooltip
                        cursor={{ stroke: alpha(ACCENT, 0.3), strokeWidth: 1.5 }}
                        content={<ReportChartTooltip />}
                      />
                      <Legend {...reportChartLegendProps} />
                      <Line
                        type="monotone"
                        dataKey="primary"
                        name={config.trendPrimaryName}
                        stroke={REPORT_SERIES_COLORS[0]}
                        strokeWidth={2.75}
                        dot={{ r: 3.5, strokeWidth: 2, stroke: '#fff', fill: REPORT_SERIES_COLORS[0] }}
                        activeDot={{ r: 6, strokeWidth: 2, stroke: '#fff' }}
                      />
                      {config.trendSecondaryKey && (
                        <Line
                          type="monotone"
                          dataKey="secondary"
                          name={config.trendSecondaryName}
                          stroke={REPORT_SERIES_COLORS[1]}
                          strokeWidth={2.5}
                          dot={{ r: 3, strokeWidth: 2, stroke: '#fff', fill: REPORT_SERIES_COLORS[1] }}
                          activeDot={{ r: 5.5, strokeWidth: 2, stroke: '#fff' }}
                        />
                      )}
                    </LineChart>
                  </ResponsiveContainer>
                )}
              </ReportChartScrollFrame>
            )}
          </ReportChartCard>

          <Paper elevation={0} sx={{ p: 1.5, borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }} sx={{ mb: 1 }}>
              <Typography variant="subtitle2" fontWeight={800} sx={{ flex: 1 }}>Thống kê theo khoa</Typography>
              {config.showSortBy && (
                <>
                  <TextField select size="small" label="Sắp xếp" value={sortBy} sx={{ minWidth: 120 }} onChange={(e) => onSortByChange(e.target.value as 'RATE' | 'FREQUENCY')}>
                    <MenuItem value="RATE">Theo tỷ lệ</MenuItem>
                    <MenuItem value="FREQUENCY">Theo tần suất</MenuItem>
                  </TextField>
                  <TextField select size="small" label="Thứ tự" value={sortDir} sx={{ minWidth: 130 }} onChange={(e) => onSortDirChange(e.target.value as 'ASC' | 'DESC')}>
                    <MenuItem value="DESC">Cao → Thấp</MenuItem>
                    <MenuItem value="ASC">Thấp → Cao</MenuItem>
                  </TextField>
                </>
              )}
            </Stack>
            <TableContainer sx={{ borderRadius: 2, border: `1px solid ${alpha('#64748b', 0.1)}` }}>
              <Table size="small">
                <TableHead>
                  <TableRow sx={{ bgcolor: alpha(ACCENT, 0.06) }}>
                    {config.deptHeaders.map((h) => (
                      <TableCell key={h.key} align={h.align === 'right' ? 'right' : 'left'} sx={{ fontWeight: 800 }}>{h.label}</TableCell>
                    ))}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {report.byDepartment.length === 0 ? (
                    <TableRow><TableCell colSpan={config.deptHeaders.length} align="center" sx={{ py: 3, color: 'text.secondary' }}>Chưa có dữ liệu</TableCell></TableRow>
                  ) : report.byDepartment.map((row) => (
                    <TableRow
                      key={row.departmentId}
                      hover={!!onSelectDepartment}
                      sx={{ cursor: onSelectDepartment ? 'pointer' : 'default' }}
                      onClick={() => onSelectDepartment?.(row.departmentId)}
                    >
                      {config.deptHeaders.map((h) => (
                        <TableCell key={h.key} align={h.align === 'right' ? 'right' : 'left'} sx={h.key === 'departmentName' ? { fontWeight: 650 } : undefined}>
                          {String((row as Record<string, unknown>)[h.key] ?? '—')}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </Paper>
        </Stack>
      )}
    </Box>
  );
}
