import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import CancelOutlinedIcon from '@mui/icons-material/CancelOutlined';
import AssessmentOutlinedIcon from '@mui/icons-material/AssessmentOutlined';
import TrendingUpOutlinedIcon from '@mui/icons-material/TrendingUpOutlined';
import ExpandLessIcon from '@mui/icons-material/ExpandLess';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import {
  Box,
  Chip,
  Collapse,
  IconButton,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { Fragment, useState } from 'react';
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
import {
  ReportChartEmpty,
  ReportChartTooltip,
  ReportKpiCard,
  ReportChartScrollFrame,
  REPORT_CHART_ACCENT,
  REPORT_SERIES_COLORS,
  reportChartGridProps,
  reportChartLegendProps,
  reportChartTickStyle,
  reportChartXAxisProps,
} from '../../charts/ReportChartUi';
import type { ComplianceBucket, ComplianceKpi, ComplianceTrendPoint } from '../../../services/qtktComplianceReportService';
import { formatComplianceRate } from '../../../services/qtktComplianceReportService';

const ACCENT = REPORT_CHART_ACCENT;
const PASS = '#15803d';
const FAIL = '#b91c1c';

export function ComplianceKpiCards({
  kpi,
  labels,
}: {
  kpi: ComplianceKpi;
  labels?: {
    total?: string;
    passed?: string;
    failed?: string;
    rate?: string;
    totalHint?: string;
    passedHint?: string;
    failedHint?: string;
    rateHint?: string;
  };
}) {
  const cards = [
    { label: labels?.total ?? 'Tổng lần đánh giá', value: kpi.total, hint: labels?.totalHint ?? 'Bảng kiểm đã hoàn thành', color: ACCENT, icon: <AssessmentOutlinedIcon fontSize="small" /> },
    { label: labels?.passed ?? 'Số lần đạt', value: kpi.passed, hint: labels?.passedHint ?? 'Đạt tiêu chí tuân thủ', color: PASS, icon: <CheckCircleOutlineIcon fontSize="small" /> },
    { label: labels?.failed ?? 'Số lần không đạt', value: kpi.failed, hint: labels?.failedHint ?? 'Chưa đạt tiêu chí', color: FAIL, icon: <CancelOutlinedIcon fontSize="small" /> },
    { label: labels?.rate ?? 'Tỷ lệ tuân thủ', value: kpi.complianceRateLabel, hint: labels?.rateHint ?? 'Tự động tính từ dữ liệu', color: ACCENT, icon: <TrendingUpOutlinedIcon fontSize="small" /> },
  ];
  return (
    <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr 1fr', lg: 'repeat(4, 1fr)' }, gap: 1.25 }}>
      {cards.map((c) => (
        <ReportKpiCard
          key={c.label}
          label={c.label}
          value={c.value}
          hint={c.hint}
          color={c.color}
          icon={c.icon}
        />
      ))}
    </Box>
  );
}

export function ComplianceTrendChart({ trend }: { trend: ComplianceTrendPoint[] }) {
  const data = trend.map((t) => ({
    name: t.label,
    rate: t.complianceRate ?? 0,
    hasData: t.hasData,
  }));
  if (!data.some((d) => d.hasData)) {
    return <ReportChartEmpty message="Chưa có dữ liệu biểu đồ trong kỳ đã chọn" />;
  }
  return (
    <ReportChartScrollFrame pointCount={data.length} height={300}>
      {(chartWidth) => (
        <ResponsiveContainer key={chartWidth} width={chartWidth} height="100%">
          <LineChart data={data} margin={{ top: 12, right: 20, left: 4, bottom: 8 }}>
            <CartesianGrid {...reportChartGridProps} />
            <XAxis dataKey="name" {...reportChartXAxisProps} />
            <YAxis
              domain={[0, 100]}
              tick={reportChartTickStyle}
              tickFormatter={(v) => `${v}%`}
              axisLine={false}
              tickLine={false}
              width={44}
            />
            <Tooltip
              cursor={{ stroke: alpha(ACCENT, 0.35), strokeWidth: 1.5 }}
              content={<ReportChartTooltip valueFormatter={(v) => `${Number(v).toFixed(2)}%`} />}
            />
            <Legend {...reportChartLegendProps} />
            <Line
              type="monotone"
              dataKey="rate"
              name="Tỷ lệ tuân thủ"
              stroke={ACCENT}
              strokeWidth={2.75}
              dot={{ r: 3.5, strokeWidth: 2, stroke: '#fff', fill: ACCENT }}
              activeDot={{ r: 6, strokeWidth: 2, stroke: '#fff' }}
            />
          </LineChart>
        </ResponsiveContainer>
      )}
    </ReportChartScrollFrame>
  );
}

export function ResultChip({ passed, label }: { passed: boolean; label: string }) {
  return (
    <Chip size="small" label={label} sx={{ fontWeight: 750, bgcolor: alpha(passed ? PASS : FAIL, 0.1), color: passed ? PASS : FAIL }} />
  );
}

export function RateCell({ rate }: { rate: number | null | undefined }) {
  return (
    <Typography variant="body2" fontWeight={700} sx={{ color: rate == null ? 'text.secondary' : ACCENT }}>
      {formatComplianceRate(rate)}
    </Typography>
  );
}

type DeptTableProps = {
  rows: ComplianceBucket[];
  onSelectDepartment?: (departmentId: number) => void;
  showProcedureBreakdown?: boolean;
};

export function ComplianceDepartmentTable({ rows, onSelectDepartment, showProcedureBreakdown }: DeptTableProps) {
  const [expandedId, setExpandedId] = useState<number | null>(null);
  return (
    <TableContainer sx={{ borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
      <Table size="small">
        <TableHead>
          <TableRow sx={{ bgcolor: alpha(ACCENT, 0.06) }}>
            <TableCell sx={{ fontWeight: 800 }}>Khoa</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Tổng đánh giá</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Đạt</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Không đạt</TableCell>
            <TableCell align="right" sx={{ fontWeight: 800 }}>Tỷ lệ tuân thủ</TableCell>
            {showProcedureBreakdown && <TableCell width={48} />}
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.filter((r) => (r.total ?? 0) > 0).length === 0 ? (
            <TableRow>
              <TableCell colSpan={showProcedureBreakdown ? 6 : 5} align="center" sx={{ py: 3, color: 'text.secondary' }}>
                Chưa có dữ liệu theo khoa
              </TableCell>
            </TableRow>
          ) : rows.map((row) => {
            const deptId = row.departmentId!;
            const open = expandedId === deptId;
            return (
              <Fragment key={deptId}>
                <TableRow hover sx={{ cursor: onSelectDepartment ? 'pointer' : 'default' }} onClick={() => onSelectDepartment?.(deptId)}>
                  <TableCell sx={{ fontWeight: 650 }}>{row.departmentName}</TableCell>
                  <TableCell align="right">{row.total}</TableCell>
                  <TableCell align="right" sx={{ color: PASS, fontWeight: 700 }}>{row.passed}</TableCell>
                  <TableCell align="right" sx={{ color: FAIL, fontWeight: 700 }}>{row.failed}</TableCell>
                  <TableCell align="right"><RateCell rate={row.complianceRate} /></TableCell>
                  {showProcedureBreakdown && (
                    <TableCell align="center" onClick={(e) => e.stopPropagation()}>
                      {row.byProcedure && row.byProcedure.length > 0 && (
                        <IconButton size="small" onClick={() => setExpandedId(open ? null : deptId)}>
                          {open ? <ExpandLessIcon fontSize="small" /> : <ExpandMoreIcon fontSize="small" />}
                        </IconButton>
                      )}
                    </TableCell>
                  )}
                </TableRow>
                {showProcedureBreakdown && row.byProcedure && (
                  <TableRow>
                    <TableCell colSpan={6} sx={{ py: 0, borderBottom: open ? undefined : 'none' }}>
                      <Collapse in={open} unmountOnExit>
                        <Box sx={{ py: 1.25, px: 1 }}>
                          <Typography variant="caption" fontWeight={800} color="text.secondary" sx={{ mb: 0.75, display: 'block' }}>
                            Chi tiết quy trình — {row.departmentName}
                          </Typography>
                          <Table size="small">
                            <TableHead>
                              <TableRow>
                                <TableCell>Quy trình</TableCell>
                                <TableCell align="right">Tổng</TableCell>
                                <TableCell align="right">Đạt</TableCell>
                                <TableCell align="right">Không đạt</TableCell>
                                <TableCell align="right">Tỷ lệ</TableCell>
                              </TableRow>
                            </TableHead>
                            <TableBody>
                              {row.byProcedure.map((p: ComplianceBucket) => (
                                <TableRow key={`${deptId}-${p.procedureCode}`}>
                                  <TableCell sx={{ fontWeight: p.isTotal ? 800 : 500 }}>{p.procedureName}</TableCell>
                                  <TableCell align="right">{p.total}</TableCell>
                                  <TableCell align="right">{p.passed}</TableCell>
                                  <TableCell align="right">{p.failed}</TableCell>
                                  <TableCell align="right"><RateCell rate={p.complianceRate} /></TableCell>
                                </TableRow>
                              ))}
                            </TableBody>
                          </Table>
                        </Box>
                      </Collapse>
                    </TableCell>
                  </TableRow>
                )}
              </Fragment>
            );
          })}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

export function ComplianceBucketTable({
  title,
  rows,
  nameHeader,
  nameKey,
}: {
  title: string;
  rows: ComplianceBucket[];
  nameHeader: string;
  nameKey: 'checkContextLabel' | 'procedureName';
}) {
  return (
    <Box>
      <Typography variant="subtitle2" fontWeight={800} sx={{ mb: 1 }}>{title}</Typography>
      <TableContainer sx={{ borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
        <Table size="small">
          <TableHead>
            <TableRow sx={{ bgcolor: alpha(ACCENT, 0.06) }}>
              <TableCell sx={{ fontWeight: 800 }}>{nameHeader}</TableCell>
              <TableCell align="right" sx={{ fontWeight: 800 }}>Tổng đánh giá</TableCell>
              <TableCell align="right" sx={{ fontWeight: 800 }}>Đạt</TableCell>
              <TableCell align="right" sx={{ fontWeight: 800 }}>Không đạt</TableCell>
              <TableCell align="right" sx={{ fontWeight: 800 }}>Tuân thủ</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((row, idx) => (
              <TableRow key={`${row[nameKey]}-${idx}`} sx={{ bgcolor: row.isTotal ? alpha(ACCENT, 0.04) : undefined }}>
                <TableCell sx={{ fontWeight: row.isTotal ? 850 : 600 }}>{row[nameKey]}</TableCell>
                <TableCell align="right">{row.total}</TableCell>
                <TableCell align="right" sx={{ color: PASS, fontWeight: 700 }}>{row.passed}</TableCell>
                <TableCell align="right" sx={{ color: FAIL, fontWeight: 700 }}>{row.failed}</TableCell>
                <TableCell align="right"><RateCell rate={row.complianceRate} /></TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}

export function ComplianceMultiProcedureTrendChart({
  trendByProcedure,
}: {
  trendByProcedure: Record<string, ComplianceTrendPoint[]>;
}) {
  const codes = Object.keys(trendByProcedure);
  if (codes.length === 0) return null;
  const labels = trendByProcedure[codes[0]]?.map((t) => t.label) ?? [];
  const data = labels.map((label, idx) => {
    const point: Record<string, string | number> = { name: label };
    codes.forEach((code) => {
      point[code] = trendByProcedure[code][idx]?.complianceRate ?? 0;
    });
    return point;
  });
  const names: Record<string, string> = {
    IV_INJECTION: 'Tiêm tĩnh mạch',
    IV_INFUSION: 'Truyền tĩnh mạch',
    IV_CATHETER: 'Tiêm qua kim lưu',
  };
  if (!data.some((_, i) => codes.some((c) => trendByProcedure[c][i]?.hasData))) {
    return <ReportChartEmpty message="Chưa có dữ liệu so sánh quy trình" />;
  }
  return (
    <ReportChartScrollFrame pointCount={data.length} height={320}>
      {(chartWidth) => (
        <ResponsiveContainer key={chartWidth} width={chartWidth} height="100%">
          <LineChart data={data} margin={{ top: 12, right: 20, left: 4, bottom: 8 }}>
            <CartesianGrid {...reportChartGridProps} />
            <XAxis dataKey="name" {...reportChartXAxisProps} />
            <YAxis
              domain={[0, 100]}
              tick={reportChartTickStyle}
              tickFormatter={(v) => `${v}%`}
              axisLine={false}
              tickLine={false}
              width={44}
            />
            <Tooltip
              cursor={{ stroke: alpha(ACCENT, 0.3), strokeWidth: 1.5 }}
              content={<ReportChartTooltip valueFormatter={(v) => `${Number(v).toFixed(2)}%`} />}
            />
            <Legend {...reportChartLegendProps} />
            {codes.map((code, i) => {
              const color = REPORT_SERIES_COLORS[i % REPORT_SERIES_COLORS.length];
              return (
                <Line
                  key={code}
                  type="monotone"
                  dataKey={code}
                  name={names[code] ?? code}
                  stroke={color}
                  strokeWidth={2.5}
                  dot={{ r: 3, strokeWidth: 2, stroke: '#fff', fill: color }}
                  activeDot={{ r: 5.5, strokeWidth: 2, stroke: '#fff' }}
                />
              );
            })}
          </LineChart>
        </ResponsiveContainer>
      )}
    </ReportChartScrollFrame>
  );
}
