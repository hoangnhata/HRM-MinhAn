import { Box, Stack, Typography, useTheme } from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useMemo } from 'react';
import type { TooltipProps } from 'recharts';
import {
  Area,
  AreaChart,
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

export type StatusBreakdown = {
  working: number;
  maternityLeave: number;
  trial: number;
  terminated: number;
};

export type DeptRow = {
  departmentId: number;
  departmentName: string;
  count: number;
  officialCount: number;
  trialCount: number;
};

export type HireRow = {
  label: string;
  count: number;
  year: number;
  month: number;
  officialCount: number;
  trialCount: number;
};

type Props = {
  statusBreakdown: StatusBreakdown;
  employeesByDepartment: DeptRow[];
  hiresByMonth: HireRow[];
  onHireMonthClick?: (row: HireRow) => void;
  onDepartmentClick?: (row: DeptRow) => void;
};

const CHART_H = 300;

const STATUS_PALETTE = {
  working: '#0f766e',
  maternity: '#be185d',
  trial: '#4338ca',
  terminated: '#b45309',
} as const;

type PieItem = { key: keyof typeof STATUS_PALETTE; name: string; value: number; color: string };

function ChartTooltipCard({
  title,
  lines,
  hint,
}: {
  title?: string;
  lines: string[];
  hint?: string;
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
      {hint && (
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.5 }}>
          {hint}
        </Typography>
      )}
    </Box>
  );
}

function HireMonthTooltip({ active, payload }: TooltipProps<number, string>) {
  const row = payload?.[0]?.payload as HireRow | undefined;
  if (!active || !row) return null;

  const detail =
    row.count > 0
      ? `${row.count} (${row.officialCount} chính thức, ${row.trialCount} thử việc)`
      : '0';

  return (
    <ChartTooltipCard
      title={`Tháng ${row.month}/${row.year}`}
      lines={[`Nhận việc: ${detail}`]}
      hint={row.count > 0 ? 'Nhấn để xem danh sách' : undefined}
    />
  );
}

function DepartmentTooltip({ active, payload }: TooltipProps<number, string>) {
  const row = payload?.[0]?.payload as DeptRow | undefined;
  if (!active || !row) return null;

  const detail =
    row.count > 0
      ? `${row.count} (${row.officialCount} chính thức, ${row.trialCount} thử việc)`
      : '0';

  return (
    <ChartTooltipCard
      title={row.departmentName}
      lines={[`Nhân viên: ${detail}`]}
      hint={row.count > 0 ? 'Nhấn để xem danh sách' : undefined}
    />
  );
}

function StatusPieTooltip({
  active,
  payload,
  total,
}: TooltipProps<number, string> & { total: number }) {
  const item = payload?.[0]?.payload as PieItem | undefined;
  if (!active || !item) return null;
  const pct = total > 0 ? ((item.value / total) * 100).toFixed(1) : '0';

  return (
    <ChartTooltipCard
      title={item.name}
      lines={[`${item.value.toLocaleString('vi-VN')} người (${pct}%)`]}
    />
  );
}

function StatusLegend({ items, total }: { items: PieItem[]; total: number }) {
  return (
    <Stack direction="row" flexWrap="wrap" justifyContent="center" gap={1.25} sx={{ mt: 2, px: 1 }}>
      {items.map((item) => {
        const pct = total > 0 ? Math.round((item.value / total) * 100) : 0;
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
  );
}

function renderActivePieSector(props: PieSectorDataItem) {
  const { outerRadius = 102, fill } = props;
  return <Sector {...props} fill={fill} stroke="none" outerRadius={outerRadius + 3} />;
}

export function DashboardCharts({
  statusBreakdown,
  employeesByDepartment,
  hiresByMonth,
  onHireMonthClick,
  onDepartmentClick,
}: Props) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;
  const secondary = theme.palette.secondary.main;

  const pieData = useMemo<PieItem[]>(
    () =>
      [
        { key: 'working' as const, name: 'Đang làm việc', value: statusBreakdown.working, color: STATUS_PALETTE.working },
        {
          key: 'maternity' as const,
          name: 'Đang nghỉ thai sản',
          value: statusBreakdown.maternityLeave,
          color: STATUS_PALETTE.maternity,
        },
        { key: 'trial' as const, name: 'Đang thực tập', value: statusBreakdown.trial, color: STATUS_PALETTE.trial },
        { key: 'terminated' as const, name: 'Nghỉ việc', value: statusBreakdown.terminated, color: STATUS_PALETTE.terminated },
      ].filter((d) => d.value > 0),
    [statusBreakdown],
  );

  const pieTotal = useMemo(() => pieData.reduce((sum, d) => sum + d.value, 0), [pieData]);

  const deptData = [...employeesByDepartment];

  const deptYAxisWidth = useMemo(() => {
    const maxChars = deptData.reduce((m, d) => Math.max(m, d.departmentName.length), 0);
    return Math.min(440, Math.max(168, Math.ceil(maxChars * 7.2) + 28));
  }, [deptData]);

  function handleHireChartClick(state: { activePayload?: Array<{ payload?: HireRow }> }) {
    const row = state?.activePayload?.[0]?.payload;
    if (row && row.count > 0) {
      onHireMonthClick?.(row);
    }
  }

  function handleDeptBarClick(barData: { payload?: DeptRow } & Partial<DeptRow>) {
    const data = (barData.payload ?? barData) as DeptRow;
    if (data?.departmentId && data.count > 0) {
      onDepartmentClick?.(data);
    }
  }

  return (
    <Box
      sx={{
        display: 'grid',
        gridTemplateColumns: { xs: '1fr', lg: '1fr 1fr' },
        gap: 2.5,
        mb: 3,
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
          Trạng thái nhân sự
        </Typography>
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
          Tỷ lệ theo trạng thái hồ sơ
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
                <text
                  x="50%"
                  y="50%"
                  textAnchor="middle"
                  dominantBaseline="middle"
                  style={{ pointerEvents: 'none' }}
                >
                  <tspan x="50%" dy="-4" style={{ fontSize: 22, fontWeight: 700, fill: theme.palette.text.primary }}>
                    {pieTotal}
                  </tspan>
                  <tspan x="50%" dy="22" style={{ fontSize: 11, fill: theme.palette.text.secondary }}>
                    nhân viên
                  </tspan>
                </text>
              </PieChart>
            </ResponsiveContainer>
            <StatusLegend items={pieData} total={pieTotal} />
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
          Tuyển dụng theo tháng
        </Typography>
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
          Số nhân viên theo tháng nhận việc (12 tháng gần nhất) — nhấn vào điểm trên biểu đồ để xem chi tiết
        </Typography>
        <ResponsiveContainer width="100%" height={CHART_H}>
          <AreaChart
            data={hiresByMonth}
            margin={{ top: 8, right: 8, left: -8, bottom: 0 }}
            onClick={handleHireChartClick}
            style={{ cursor: 'pointer' }}
          >
            <defs>
              <linearGradient id="hireGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={primary} stopOpacity={0.35} />
                <stop offset="100%" stopColor={primary} stopOpacity={0.02} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke={alpha(theme.palette.divider, 0.9)} vertical={false} />
            <XAxis dataKey="label" tick={{ fontSize: 11, fill: theme.palette.text.secondary }} axisLine={false} />
            <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: theme.palette.text.secondary }} axisLine={false} />
            <Tooltip
              content={<HireMonthTooltip />}
              labelFormatter={(_, p) => {
                const pl = p?.[0]?.payload as HireRow | undefined;
                return pl ? `Tháng ${pl.month}/${pl.year}` : '';
              }}
            />
            <Area
              type="monotone"
              dataKey="count"
              stroke={primary}
              strokeWidth={2}
              fill="url(#hireGrad)"
              dot={{ fill: secondary, strokeWidth: 0, r: 3 }}
              activeDot={{ r: 6 }}
            />
          </AreaChart>
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
          Nhân sự theo phòng ban
        </Typography>
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
          Số lượng nhân viên theo phòng ban — nhấn vào thanh để xem danh sách
        </Typography>
        {deptData.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            Chưa có dữ liệu phòng ban.
          </Typography>
        ) : (
          <ResponsiveContainer width="100%" height={Math.max(280, 48 + deptData.length * 36)}>
            <BarChart
              layout="vertical"
              data={deptData}
              margin={{ top: 4, right: 24, left: 4, bottom: 4 }}
            >
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
                onClick={(data) => handleDeptBarClick(data as DeptRow)}
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
  );
}
