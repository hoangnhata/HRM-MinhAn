import { Box, Typography, useTheme } from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useMemo } from 'react';
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';

export type StatusBreakdown = {
  active: number;
  onLeave: number;
  terminated: number;
};

export type DeptRow = { departmentName: string; count: number };
export type HireRow = { label: string; count: number; year: number; month: number };

type Props = {
  statusBreakdown: StatusBreakdown;
  employeesByDepartment: DeptRow[];
  hiresByMonth: HireRow[];
};

const CHART_H = 300;

export function DashboardCharts({ statusBreakdown, employeesByDepartment, hiresByMonth }: Props) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;
  const success = theme.palette.success.main;
  const warning = theme.palette.warning.main;
  const secondary = theme.palette.secondary.main;

  const pieData = [
    { name: 'Đang làm việc', value: statusBreakdown.active, color: success },
    { name: 'Nghỉ phép', value: statusBreakdown.onLeave, color: warning },
    { name: 'Chấm dứt / nghỉ việc', value: statusBreakdown.terminated, color: alpha(theme.palette.text.secondary, 0.55) },
  ].filter((d) => d.value > 0);

  const deptData = [...employeesByDepartment].slice(0, 12);

  /** Space for full department names on the category axis (~px per char at tick fontSize 11). */
  const deptYAxisWidth = useMemo(() => {
    const maxChars = deptData.reduce((m, d) => Math.max(m, d.departmentName.length), 0);
    return Math.min(440, Math.max(168, Math.ceil(maxChars * 7.2) + 28));
  }, [deptData]);

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
          <ResponsiveContainer width="100%" height={CHART_H}>
            <PieChart>
              <Pie
                data={pieData}
                cx="50%"
                cy="50%"
                innerRadius={68}
                outerRadius={100}
                paddingAngle={2}
                dataKey="value"
                nameKey="name"
                label={false}
              >
                {pieData.map((entry, i) => (
                  <Cell key={i} fill={entry.color} stroke={alpha('#fff', 0.9)} strokeWidth={2} />
                ))}
              </Pie>
              <Tooltip
                formatter={(value: number) => [value.toLocaleString('vi-VN'), 'Số người']}
                contentStyle={{
                  borderRadius: 10,
                  border: `1px solid ${alpha(primary, 0.15)}`,
                  boxShadow: '0 4px 20px rgba(15,23,42,0.08)',
                }}
              />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
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
          Số nhân viên theo tháng nhận việc (12 tháng gần nhất)
        </Typography>
        <ResponsiveContainer width="100%" height={CHART_H}>
          <AreaChart data={hiresByMonth} margin={{ top: 8, right: 8, left: -8, bottom: 0 }}>
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
              formatter={(value: number) => [value.toLocaleString('vi-VN'), 'Nhận việc']}
              labelFormatter={(_, p) => {
                const pl = p?.[0]?.payload as HireRow | undefined;
                return pl ? `Tháng ${pl.month}/${pl.year}` : '';
              }}
              contentStyle={{
                borderRadius: 10,
                border: `1px solid ${alpha(primary, 0.15)}`,
                boxShadow: '0 4px 20px rgba(15,23,42,0.08)',
              }}
            />
            <Area
              type="monotone"
              dataKey="count"
              stroke={primary}
              strokeWidth={2}
              fill="url(#hireGrad)"
              dot={{ fill: secondary, strokeWidth: 0, r: 3 }}
              activeDot={{ r: 5 }}
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
          Số lượng nhân viên (top 12 đơn vị)
        </Typography>
        {deptData.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            Chưa có dữ liệu phòng ban.
          </Typography>
        ) : (
          <ResponsiveContainer width="100%" height={Math.min(420, 48 + deptData.length * 36)}>
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
              <Tooltip
                formatter={(value: number) => [value.toLocaleString('vi-VN'), 'Nhân viên']}
                contentStyle={{
                  borderRadius: 10,
                  border: `1px solid ${alpha(primary, 0.15)}`,
                  boxShadow: '0 4px 20px rgba(15,23,42,0.08)',
                }}
              />
              <Bar dataKey="count" radius={[0, 8, 8, 0]} maxBarSize={22}>
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
