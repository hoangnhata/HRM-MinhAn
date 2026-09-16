import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import EventBusyOutlinedIcon from '@mui/icons-material/EventBusyOutlined';
import EventRepeatOutlinedIcon from '@mui/icons-material/EventRepeatOutlined';
import ReportProblemOutlinedIcon from '@mui/icons-material/ReportProblemOutlined';
import SearchOutlinedIcon from '@mui/icons-material/SearchOutlined';
import VerifiedOutlinedIcon from '@mui/icons-material/VerifiedOutlined';
import {
  Box,
  Chip,
  FormControl,
  InputAdornment,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Tooltip as MuiTooltip,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useMemo, useState, type ReactNode } from 'react';
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
import {
  reportChartBarCursor,
  reportChartGridProps,
  reportChartTickStyle,
  ReportChartCard,
  ReportChartEmpty,
  ReportChartTooltip,
} from '../charts/ReportChartUi';
import type {
  CertStatusCode,
  PracticeCertificateDetail,
  PracticeCertificateReport,
  ProfessionCode,
} from '../../services/professionalQualificationReportService';

const INK = '#0f172a';
const ACCENT = '#0f766e';

/** Màu theo trạng thái — đỏ cho hết hạn, cam cho sắp hết hạn và chưa có, xanh cho còn hiệu lực. */
const STATUS_META: Record<CertStatusCode, { color: string; short: string }> = {
  EXPIRED: { color: '#dc2626', short: 'Hết hạn' },
  EXPIRING_SOON: { color: '#d97706', short: 'Sắp hết hạn' },
  MISSING: { color: '#b45309', short: 'Chưa có' },
  NO_DATE: { color: '#64748b', short: 'Thiếu ngày cấp' },
  VALID: { color: '#0f766e', short: 'Còn hạn' },
  UNLIMITED: { color: '#0369a1', short: 'Trước 2024' },
};

type Filter = 'ALL' | 'ATTENTION' | CertStatusCode;

const FILTER_CHIPS: { key: Filter; label: string }[] = [
  { key: 'ALL', label: 'Tất cả' },
  { key: 'ATTENTION', label: 'Cần xử lý' },
  { key: 'EXPIRED', label: 'Đã hết hạn' },
  { key: 'EXPIRING_SOON', label: 'Sắp hết hạn' },
  { key: 'MISSING', label: 'Chưa có CCHN' },
  { key: 'NO_DATE', label: 'Thiếu ngày cấp' },
  { key: 'VALID', label: 'Còn hạn' },
  { key: 'UNLIMITED', label: 'Cấp trước 2024' },
];

/** Cùng kiểu bảng dán tiêu đề với tab Trình độ / bằng cấp — không đè dòng đầu. */
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

function renderActivePieSector(props: PieSectorDataItem) {
  const { outerRadius = 102, fill } = props;
  return <Sector {...props} fill={fill} stroke="none" outerRadius={outerRadius + 3} />;
}

function pct(n: number, d: number) {
  return d > 0 ? Math.round((n * 1000) / d) / 10 : 0;
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

function StatCard({
  label,
  value,
  hint,
  color,
  icon,
  onClick,
  active,
}: {
  label: string;
  value: string | number;
  hint: string;
  color: string;
  icon: ReactNode;
  onClick?: () => void;
  active?: boolean;
}) {
  return (
    <Box
      component={onClick ? 'button' : 'div'}
      type={onClick ? 'button' : undefined}
      onClick={onClick}
      sx={{
        all: 'unset',
        boxSizing: 'border-box',
        display: 'block',
        width: '100%',
        height: '100%',
        p: 1.75,
        borderRadius: 2.75,
        cursor: onClick ? 'pointer' : 'default',
        border: `1px solid ${alpha(color, active ? 0.55 : 0.16)}`,
        background: `linear-gradient(160deg, ${alpha(color, 0.12)} 0%, ${alpha(color, 0.02)} 42%, #fff 100%)`,
        position: 'relative',
        overflow: 'hidden',
        transition: 'transform .15s ease, box-shadow .15s ease, border-color .15s ease',
        '&:hover': onClick
          ? {
              transform: 'translateY(-1px)',
              boxShadow: `0 10px 26px ${alpha(color, 0.14)}`,
            }
          : undefined,
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

function StatusChip({ code, label }: { code: CertStatusCode; label: string }) {
  const meta = STATUS_META[code];
  return (
    <Chip
      size="small"
      label={label}
      sx={{
        fontWeight: 750,
        bgcolor: alpha(meta.color, 0.1),
        color: meta.color,
        border: `1px solid ${alpha(meta.color, 0.22)}`,
      }}
    />
  );
}

function CoverageBar({ percent, color }: { percent: number; color: string }) {
  return (
    <Stack direction="row" alignItems="center" spacing={1}>
      <Box
        sx={{
          flex: 1,
          height: 7,
          borderRadius: 999,
          bgcolor: alpha(INK, 0.07),
          overflow: 'hidden',
        }}
      >
        <Box
          sx={{
            width: `${Math.min(100, percent)}%`,
            height: '100%',
            bgcolor: color,
            borderRadius: 999,
          }}
        />
      </Box>
      <Typography
        variant="caption"
        fontWeight={800}
        sx={{ minWidth: 42, textAlign: 'right', color }}
      >
        {percent}%
      </Typography>
    </Stack>
  );
}

function coverageColor(percent: number) {
  if (percent >= 95) return '#0f766e';
  if (percent >= 80) return '#0369a1';
  if (percent >= 60) return '#d97706';
  return '#dc2626';
}

export function PracticeCertificateSection({
  data,
  professionColors,
  generatedAtLabel,
}: {
  data: PracticeCertificateReport;
  professionColors: Record<ProfessionCode, string>;
  generatedAtLabel: string;
}) {
  const [filter, setFilter] = useState<Filter>('ALL');
  const [certNumberFilter, setCertNumberFilter] = useState<'ALL' | 'HAS' | 'NONE'>('ALL');
  const [professionFilter, setProfessionFilter] = useState<string>('ALL');
  const [deptFilter, setDeptFilter] = useState<string>('ALL');
  const [search, setSearch] = useState('');
  const { kpi } = data;

  const statusPie = useMemo(
    () =>
      data.byStatus
        .filter((s) => s.count > 0)
        .map((s) => ({ name: s.label, value: s.count, code: s.code })),
    [data.byStatus],
  );

  const professionBars = useMemo(
    () =>
      data.byProfession
        .filter((p) => p.total > 0)
        .map((p) => ({
          name: p.label,
          code: p.code,
          coverage: p.coveragePercent,
          withCert: p.withCert,
          missing: p.missing,
          total: p.total,
        })),
    [data.byProfession],
  );

  const yearBars = useMemo(
    () => data.byIssueYear.map((y) => ({ year: String(y.year), count: y.count })),
    [data.byIssueYear],
  );

  const professionOptions = useMemo(
    () =>
      data.byProfession.filter((p) => p.total > 0).map((p) => ({ code: p.code, label: p.label })),
    [data.byProfession],
  );
  const departmentOptions = useMemo(
    () => data.byDepartment.map((d) => d.departmentName),
    [data.byDepartment],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLocaleLowerCase('vi');
    return data.details.filter((d) => {
      if (filter === 'ATTENTION' && !d.needsAttention) return false;
      if (filter !== 'ALL' && filter !== 'ATTENTION' && d.certStatusCode !== filter) return false;
      if (certNumberFilter === 'HAS' && !d.certNumber) return false;
      if (certNumberFilter === 'NONE' && d.certNumber) return false;
      if (professionFilter !== 'ALL' && d.professionCode !== professionFilter) return false;
      if (deptFilter !== 'ALL' && (d.departmentName || '(Chưa có khoa)') !== deptFilter)
        return false;
      if (!q) return true;
      return `${d.employeeCode || ''} ${d.fullName} ${d.departmentName} ${d.positionTitle} ${d.professionLabel} ${d.certNumber || ''} ${d.scope || ''} ${d.certStatusLabel}`
        .toLocaleLowerCase('vi')
        .includes(q);
    });
  }, [certNumberFilter, data.details, deptFilter, filter, professionFilter, search]);

  const filterCounts = useMemo(() => {
    const counts: Record<string, number> = {
      ALL: data.details.length,
      ATTENTION: kpi.needsAttention,
    };
    data.byStatus.forEach((s) => {
      counts[s.code] = s.count;
    });
    return counts;
  }, [data.byStatus, data.details.length, kpi.needsAttention]);

  const alertCount = kpi.expired + kpi.expiringSoon;

  return (
    <Stack spacing={2.25}>
      <Typography variant="caption" color="text.secondary" fontWeight={650}>
        Số liệu tại {generatedAtLabel} · Nguồn: «Số CCHN», «Ngày cấp», «Phạm vi hành nghề» trên hồ
        sơ nhân lực · Giấy phép cấp từ 01/01/2024 tính hạn 5 năm; chứng chỉ cấp trước đó ghi nhận
        không thời hạn.
      </Typography>

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr 1fr', lg: 'repeat(4, 1fr)' },
          gap: 1.35,
        }}
      >
        <StatCard
          label="Có chứng chỉ"
          value={kpi.withCert}
          hint={`${kpi.coveragePercent}% trong ${kpi.total} nhân sự thuộc 6 đối tượng`}
          color={ACCENT}
          icon={<VerifiedOutlinedIcon fontSize="small" />}
          onClick={() => setFilter('ALL')}
          active={filter === 'ALL'}
        />
        <StatCard
          label="Chưa có chứng chỉ"
          value={kpi.missing}
          hint="Chưa cập nhật số CCHN trên hồ sơ"
          color={STATUS_META.MISSING.color}
          icon={<BadgeOutlinedIcon fontSize="small" />}
          onClick={() => setFilter('MISSING')}
          active={filter === 'MISSING'}
        />
        <StatCard
          label="Hết hạn / sắp hết hạn"
          value={alertCount}
          hint={`${kpi.expired} đã hết hạn · ${kpi.expiringSoon} hết hạn trong 6 tháng`}
          color={alertCount > 0 ? STATUS_META.EXPIRED.color : '#64748b'}
          icon={<EventBusyOutlinedIcon fontSize="small" />}
          onClick={() => setFilter(kpi.expired > 0 ? 'EXPIRED' : 'EXPIRING_SOON')}
          active={filter === 'EXPIRED' || filter === 'EXPIRING_SOON'}
        />
        <StatCard
          label="Cần rà soát hồ sơ"
          value={kpi.noDate}
          hint={`Có số CCHN nhưng thiếu hoặc sai ngày cấp · ${kpi.unlimited} cấp trước 2024`}
          color="#7c3aed"
          icon={<EventRepeatOutlinedIcon fontSize="small" />}
          onClick={() => setFilter('NO_DATE')}
          active={filter === 'NO_DATE'}
        />
      </Box>

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', lg: '0.92fr 1.28fr' },
          gap: 1.5,
        }}
      >
        <ReportChartCard
          title="Trạng thái chứng chỉ"
          subtitle="Phân bố nhân sự theo hiệu lực chứng chỉ hành nghề"
          height={340}
        >
          {statusPie.length === 0 ? (
            <ReportChartEmpty message="Chưa có dữ liệu chứng chỉ" />
          ) : (
            <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
              <Box sx={{ flex: 1, minHeight: 220, position: 'relative' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={statusPie}
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
                        const row = statusPie[index];
                        if (row?.code) setFilter(row.code);
                      }}
                    >
                      {statusPie.map((d) => (
                        <Cell
                          key={d.code}
                          fill={STATUS_META[d.code].color}
                          stroke={STATUS_META[d.code].color}
                          strokeWidth={0}
                        />
                      ))}
                    </Pie>
                    <Tooltip
                      content={
                        <ReportChartTooltip
                          valueFormatter={(v) => `${v} người · ${pct(Number(v), kpi.total)}%`}
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
                      <tspan x="50%" dy="-4" style={{ fontSize: 22, fontWeight: 700, fill: INK }}>
                        {kpi.coveragePercent}%
                      </tspan>
                      <tspan x="50%" dy="22" style={{ fontSize: 11, fill: alpha(INK, 0.55) }}>
                        có chứng chỉ
                      </tspan>
                    </text>
                  </PieChart>
                </ResponsiveContainer>
              </Box>
              {/* Chú giải kiểu dashboard: chấm tròn + tên + số (tỉ lệ), bấm để lọc danh sách. */}
              <Stack
                direction="row"
                flexWrap="wrap"
                justifyContent="center"
                gap={1.25}
                sx={{ mt: 1.5, px: 1 }}
              >
                {statusPie.map((d) => (
                  <Stack
                    key={d.code}
                    direction="row"
                    alignItems="center"
                    spacing={0.75}
                    onClick={() => setFilter(d.code)}
                    sx={{
                      cursor: 'pointer',
                      opacity: filter === 'ALL' || filter === d.code ? 1 : 0.55,
                    }}
                  >
                    <Box
                      sx={{
                        width: 10,
                        height: 10,
                        borderRadius: '50%',
                        bgcolor: STATUS_META[d.code].color,
                        flexShrink: 0,
                      }}
                    />
                    <Typography
                      variant="caption"
                      sx={{ color: 'text.primary', fontWeight: 500, lineHeight: 1.3 }}
                    >
                      {d.name}
                      <Typography
                        component="span"
                        variant="caption"
                        color="text.secondary"
                        sx={{ ml: 0.5 }}
                      >
                        {d.value} ({Math.round((d.value / Math.max(1, kpi.total)) * 100)}%)
                      </Typography>
                    </Typography>
                  </Stack>
                ))}
              </Stack>
            </Box>
          )}
        </ReportChartCard>

        <ReportChartCard
          title="Tỷ lệ có chứng chỉ theo đối tượng"
          subtitle="Phần trăm nhân sự đã cập nhật số CCHN trong từng nhóm nghề"
          height={340}
        >
          {professionBars.length === 0 ? (
            <ReportChartEmpty message="Chưa có dữ liệu đối tượng" />
          ) : (
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={professionBars}
                layout="vertical"
                margin={{ top: 8, right: 44, left: 8, bottom: 4 }}
                barCategoryGap="30%"
              >
                <CartesianGrid {...reportChartGridProps} horizontal={false} />
                <XAxis
                  type="number"
                  domain={[0, 100]}
                  tick={reportChartTickStyle}
                  tickFormatter={(v) => `${v}%`}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  type="category"
                  dataKey="name"
                  width={96}
                  tick={{ ...reportChartTickStyle, fontWeight: 700 }}
                  axisLine={false}
                  tickLine={false}
                />
                <Tooltip
                  cursor={reportChartBarCursor}
                  content={
                    <ReportChartTooltip
                      valueFormatter={(v, name) => {
                        const row = professionBars.find((p) => p.name === name);
                        return row
                          ? `${v}% · ${row.withCert}/${row.total} có CCHN · ${row.missing} chưa có`
                          : `${v}%`;
                      }}
                    />
                  }
                />
                <Bar dataKey="coverage" name="Tỷ lệ có CCHN" radius={[0, 8, 8, 0]} maxBarSize={26}>
                  {professionBars.map((d) => (
                    <Cell key={d.code} fill={professionColors[d.code]} />
                  ))}
                  <LabelList
                    dataKey="coverage"
                    position="right"
                    formatter={(v: number) => `${v}%`}
                    style={{ fontSize: 11, fontWeight: 800, fill: INK }}
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
          gridTemplateColumns: { xs: '1fr', lg: '1.28fr 0.92fr' },
          gap: 1.5,
        }}
      >
        <ReportChartCard
          title="Năm cấp chứng chỉ"
          subtitle="Số chứng chỉ theo năm cấp — cột từ 2024 là giấy phép có thời hạn 5 năm"
          height={300}
        >
          {yearBars.length === 0 ? (
            <ReportChartEmpty message="Chưa có ngày cấp nào đọc được" />
          ) : (
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={yearBars}
                margin={{ top: 18, right: 12, left: 0, bottom: 4 }}
                barCategoryGap="32%"
              >
                <CartesianGrid {...reportChartGridProps} />
                <XAxis
                  dataKey="year"
                  tick={{ ...reportChartTickStyle, fontWeight: 700 }}
                  axisLine={false}
                  tickLine={false}
                  interval={0}
                />
                <YAxis
                  allowDecimals={false}
                  tick={reportChartTickStyle}
                  axisLine={false}
                  tickLine={false}
                  width={32}
                />
                <Tooltip
                  cursor={reportChartBarCursor}
                  content={<ReportChartTooltip valueFormatter={(v) => `${v} chứng chỉ`} />}
                />
                <Bar dataKey="count" name="Số chứng chỉ" radius={[8, 8, 0, 0]} maxBarSize={40}>
                  {yearBars.map((d) => (
                    <Cell
                      key={d.year}
                      fill={Number(d.year) >= 2024 ? ACCENT : alpha('#0369a1', 0.75)}
                    />
                  ))}
                  <LabelList
                    dataKey="count"
                    position="top"
                    style={{ fontSize: 11, fontWeight: 800, fill: INK }}
                  />
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
        </ReportChartCard>

        <Panel sx={{ p: 2 }}>
          <Typography variant="subtitle1" fontWeight={850} letterSpacing="-0.02em">
            Phạm vi hành nghề phổ biến
          </Typography>
          <Typography variant="caption" color="text.secondary" fontWeight={600}>
            Theo trường «Phạm vi hành nghề» của {kpi.withCert} nhân sự có chứng chỉ
          </Typography>
          {data.byScope.length === 0 ? (
            <Typography variant="body2" color="text.secondary" sx={{ mt: 3, textAlign: 'center' }}>
              Chưa có phạm vi hành nghề nào được ghi trên hồ sơ.
            </Typography>
          ) : (
            <Stack spacing={1.1} sx={{ mt: 1.75 }}>
              {data.byScope.map((row, i) => (
                <Box key={row.scope}>
                  <Stack
                    direction="row"
                    justifyContent="space-between"
                    spacing={1}
                    sx={{ mb: 0.4 }}
                  >
                    <MuiTooltip title={row.scope} placement="top-start">
                      <Typography variant="body2" fontWeight={700} noWrap sx={{ minWidth: 0 }}>
                        {row.scope}
                      </Typography>
                    </MuiTooltip>
                    <Typography
                      variant="caption"
                      fontWeight={800}
                      sx={{ color: alpha(INK, 0.6), flexShrink: 0 }}
                    >
                      {row.count} · {row.percent}%
                    </Typography>
                  </Stack>
                  <Box
                    sx={{
                      height: 6,
                      borderRadius: 999,
                      bgcolor: alpha(INK, 0.06),
                      overflow: 'hidden',
                    }}
                  >
                    <Box
                      sx={{
                        width: `${Math.max(2, row.percent)}%`,
                        height: '100%',
                        borderRadius: 999,
                        bgcolor: alpha(ACCENT, i === 0 ? 1 : 0.55),
                      }}
                    />
                  </Box>
                </Box>
              ))}
            </Stack>
          )}
        </Panel>
      </Box>

      <Panel sx={{ p: 2 }}>
        <Typography variant="subtitle1" fontWeight={850} letterSpacing="-0.02em">
          Theo khoa/phòng
        </Typography>
        <Typography variant="caption" color="text.secondary" fontWeight={600}>
          Xếp khoa còn nhiều nhân sự chưa có chứng chỉ lên đầu
        </Typography>
        <TableContainer
          sx={{
            mt: 1.5,
            borderRadius: 2.25,
            border: `1px solid ${alpha(INK, 0.08)}`,
            maxHeight: 380,
            bgcolor: '#fff',
            overflow: 'auto',
          }}
        >
          <Table size="small" stickyHeader sx={stickyTableSx('#eaf4f3', ACCENT)}>
            <TableHead>
              <TableRow>
                <TableCell>Khoa/phòng</TableCell>
                <TableCell align="right">Nhân sự</TableCell>
                <TableCell align="right">Có CCHN</TableCell>
                <TableCell align="right">Chưa có</TableCell>
                <TableCell align="right">Cần xử lý</TableCell>
                <TableCell sx={{ minWidth: 200 }}>Tỷ lệ có CCHN</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {data.byDepartment.map((row) => (
                <TableRow key={row.departmentName} hover>
                  <TableCell sx={{ fontWeight: 750 }}>{row.departmentName}</TableCell>
                  <TableCell align="right">{row.total}</TableCell>
                  <TableCell align="right" sx={{ color: ACCENT, fontWeight: 800 }}>
                    {row.withCert}
                  </TableCell>
                  <TableCell
                    align="right"
                    sx={{
                      color: row.missing > 0 ? STATUS_META.MISSING.color : alpha(INK, 0.4),
                      fontWeight: 800,
                    }}
                  >
                    {row.missing}
                  </TableCell>
                  <TableCell
                    align="right"
                    sx={{
                      color: row.needsAttention > 0 ? STATUS_META.EXPIRED.color : alpha(INK, 0.4),
                      fontWeight: 800,
                    }}
                  >
                    {row.needsAttention}
                  </TableCell>
                  <TableCell>
                    <CoverageBar
                      percent={row.coveragePercent}
                      color={coverageColor(row.coveragePercent)}
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Panel>

      <Panel sx={{ p: 2 }}>
        <Stack
          direction={{ xs: 'column', md: 'row' }}
          spacing={1.25}
          alignItems={{ md: 'center' }}
          justifyContent="space-between"
          sx={{ mb: 1.5 }}
        >
          <Box>
            <Typography variant="subtitle1" fontWeight={850} letterSpacing="-0.02em">
              Danh sách chứng chỉ hành nghề
            </Typography>
            <Typography variant="caption" color="text.secondary" fontWeight={650}>
              {filtered.length} / {data.details.length} người · Xếp theo mức khẩn: hết hạn, sắp hết
              hạn, chưa có, thiếu ngày cấp
            </Typography>
          </Box>
          {(filter !== 'ALL' ||
            certNumberFilter !== 'ALL' ||
            professionFilter !== 'ALL' ||
            deptFilter !== 'ALL' ||
            search) && (
            <Chip
              size="small"
              label="Xoá bộ lọc"
              onClick={() => {
                setFilter('ALL');
                setCertNumberFilter('ALL');
                setProfessionFilter('ALL');
                setDeptFilter('ALL');
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
              lg: '1.4fr 1fr 1fr 1fr 1.6fr',
            },
            gap: 1,
            mb: 1.5,
          }}
        >
          <FormControl size="small">
            <InputLabel>Trạng thái chứng chỉ</InputLabel>
            <Select
              label="Trạng thái chứng chỉ"
              value={filter}
              onChange={(e) => setFilter(e.target.value as Filter)}
              renderValue={(v) => {
                const chip = FILTER_CHIPS.find((c) => c.key === v);
                return chip ? `${chip.label} · ${filterCounts[chip.key] ?? 0}` : String(v);
              }}
            >
              {FILTER_CHIPS.map((c) => {
                const color =
                  c.key === 'ALL'
                    ? ACCENT
                    : c.key === 'ATTENTION'
                      ? STATUS_META.EXPIRED.color
                      : STATUS_META[c.key].color;
                return (
                  <MenuItem key={c.key} value={c.key}>
                    <Box
                      sx={{
                        width: 9,
                        height: 9,
                        borderRadius: '50%',
                        bgcolor: color,
                        mr: 1,
                        flexShrink: 0,
                      }}
                    />
                    <Box sx={{ flex: 1 }}>{c.label}</Box>
                    <Typography variant="caption" color="text.secondary" fontWeight={800}>
                      {filterCounts[c.key] ?? 0}
                    </Typography>
                  </MenuItem>
                );
              })}
            </Select>
          </FormControl>
          <FormControl size="small">
            <InputLabel>Số CCHN</InputLabel>
            <Select
              label="Số CCHN"
              value={certNumberFilter}
              onChange={(e) => setCertNumberFilter(e.target.value as 'ALL' | 'HAS' | 'NONE')}
            >
              <MenuItem value="ALL">Tất cả</MenuItem>
              <MenuItem value="HAS">Đã có số CCHN · {kpi.withCert}</MenuItem>
              <MenuItem value="NONE">Chưa có số CCHN · {kpi.missing}</MenuItem>
            </Select>
          </FormControl>
          <FormControl size="small">
            <InputLabel>Đối tượng</InputLabel>
            <Select
              label="Đối tượng"
              value={professionFilter}
              onChange={(e) => setProfessionFilter(e.target.value)}
            >
              <MenuItem value="ALL">Tất cả đối tượng</MenuItem>
              {professionOptions.map((p) => (
                <MenuItem key={p.code} value={p.code}>
                  {p.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <FormControl size="small">
            <InputLabel>Khoa/phòng</InputLabel>
            <Select
              label="Khoa/phòng"
              value={deptFilter}
              onChange={(e) => setDeptFilter(e.target.value)}
            >
              <MenuItem value="ALL">Tất cả khoa/phòng</MenuItem>
              {departmentOptions.map((name) => (
                <MenuItem key={name} value={name}>
                  {name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <TextField
            size="small"
            placeholder="Tìm tên, mã NV, số CCHN, phạm vi…"
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
            border: `1px solid ${alpha(INK, 0.08)}`,
            maxHeight: 480,
            bgcolor: '#fff',
            overflow: 'auto',
          }}
        >
          <Table
            size="small"
            stickyHeader
            sx={{ ...stickyTableSx('#eaf4f3', ACCENT), tableLayout: 'fixed', minWidth: 980 }}
          >
            {/* Cột có bề rộng cố định: tên khoa dài không còn xé thành 5 dòng,
                số CCHN và phạm vi không chiếm quá nửa bảng. */}
            <colgroup>
              <col style={{ width: '22%' }} />
              <col style={{ width: '17%' }} />
              <col style={{ width: '13%' }} />
              <col style={{ width: '9%' }} />
              <col style={{ width: '11%' }} />
              <col style={{ width: '16%' }} />
              <col style={{ width: '12%' }} />
            </colgroup>
            <TableHead>
              <TableRow>
                {[
                  'Nhân sự',
                  'Khoa/phòng',
                  'Số CCHN',
                  'Ngày cấp',
                  'Hết hạn',
                  'Phạm vi hành nghề',
                  'Trạng thái',
                ].map((h) => (
                  <TableCell key={h} sx={{ whiteSpace: 'nowrap' }}>
                    {h}
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {filtered.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={7} align="center" sx={{ py: 4, color: 'text.secondary' }}>
                    Không có nhân sự khớp bộ lọc
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((d) => (
                  <DetailRow key={d.employeeId} d={d} professionColors={professionColors} />
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Panel>
    </Stack>
  );
}

function DetailRow({
  d,
  professionColors,
}: {
  d: PracticeCertificateDetail;
  professionColors: Record<ProfessionCode, string>;
}) {
  const meta = STATUS_META[d.certStatusCode];
  const urgent = d.certStatusCode === 'EXPIRED' || d.certStatusCode === 'EXPIRING_SOON';
  const expiryHint =
    d.daysToExpiry == null
      ? null
      : d.daysToExpiry < 0
        ? `quá ${Math.abs(d.daysToExpiry)} ngày`
        : `còn ${d.daysToExpiry} ngày`;
  return (
    <TableRow hover sx={{ bgcolor: urgent ? alpha(meta.color, 0.05) : undefined }}>
      <TableCell sx={{ minWidth: 0 }}>
        <Typography variant="body2" fontWeight={750} noWrap title={d.fullName}>
          {d.fullName}
        </Typography>
        <Stack direction="row" alignItems="center" spacing={0.75} sx={{ mt: 0.35, minWidth: 0 }}>
          <Chip
            size="small"
            label={d.professionLabel}
            sx={{
              height: 20,
              fontSize: '0.68rem',
              fontWeight: 750,
              bgcolor: alpha(professionColors[d.professionCode], 0.1),
              color: professionColors[d.professionCode],
              flexShrink: 0,
            }}
          />
          <Typography variant="caption" color="text.secondary" noWrap sx={{ minWidth: 0 }}>
            {d.employeeCode || '—'}
            {d.positionTitle ? ` · ${d.positionTitle}` : ''}
          </Typography>
        </Stack>
      </TableCell>
      <TableCell sx={{ minWidth: 0 }}>
        <MuiTooltip
          title={d.departmentName || ''}
          placement="top-start"
          disableHoverListener={!d.departmentName}
        >
          <Typography variant="body2" noWrap sx={{ fontWeight: 600 }}>
            {d.departmentName || '—'}
          </Typography>
        </MuiTooltip>
      </TableCell>
      <TableCell
        sx={{
          fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
          fontWeight: 700,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
        title={d.certNumber || undefined}
      >
        {d.certNumber || (
          <Box component="span" sx={{ color: STATUS_META.MISSING.color, fontFamily: 'inherit' }}>
            Chưa có
          </Box>
        )}
      </TableCell>
      <TableCell sx={{ whiteSpace: 'nowrap' }}>
        {d.issueDateLabel ? (
          d.issueDateLabel
        ) : d.certDateRaw ? (
          <MuiTooltip title={`Không đọc được: "${d.certDateRaw}"`}>
            <Box
              component="span"
              sx={{
                color: STATUS_META.NO_DATE.color,
                textDecoration: 'underline dotted',
              }}
            >
              {d.certDateRaw}
            </Box>
          </MuiTooltip>
        ) : (
          '—'
        )}
      </TableCell>
      <TableCell sx={{ whiteSpace: 'nowrap' }}>
        {d.expiryDateLabel ? (
          <Box>
            <Typography
              variant="body2"
              fontWeight={urgent ? 800 : 500}
              sx={{ color: urgent ? meta.color : INK }}
            >
              {d.expiryDateLabel}
            </Typography>
            {expiryHint && (
              <Typography
                variant="caption"
                sx={{
                  color: urgent ? meta.color : alpha(INK, 0.5),
                  fontWeight: 700,
                }}
              >
                {expiryHint}
              </Typography>
            )}
          </Box>
        ) : d.certStatusCode === 'UNLIMITED' ? (
          <Typography variant="caption" fontWeight={700} sx={{ color: alpha(INK, 0.5) }}>
            Không thời hạn
          </Typography>
        ) : (
          '—'
        )}
      </TableCell>
      <TableCell sx={{ minWidth: 0 }}>
        <MuiTooltip title={d.scope || ''} placement="top-start" disableHoverListener={!d.scope}>
          <Typography variant="body2" noWrap sx={{ color: d.scope ? INK : alpha(INK, 0.4) }}>
            {d.scope || '—'}
          </Typography>
        </MuiTooltip>
      </TableCell>
      <TableCell>
        <Stack direction="row" alignItems="center" spacing={0.5}>
          {d.needsAttention && (
            <ReportProblemOutlinedIcon sx={{ fontSize: 15, color: meta.color }} />
          )}
          <StatusChip code={d.certStatusCode} label={d.certStatusLabel} />
        </Stack>
      </TableCell>
    </TableRow>
  );
}
