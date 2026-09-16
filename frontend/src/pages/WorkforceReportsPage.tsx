import ApartmentOutlinedIcon from '@mui/icons-material/ApartmentOutlined';
import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import CalendarTodayOutlinedIcon from '@mui/icons-material/CalendarTodayOutlined';
import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import LocalHospitalOutlinedIcon from '@mui/icons-material/LocalHospitalOutlined';
import PersonOffOutlinedIcon from '@mui/icons-material/PersonOffOutlined';
import RefreshOutlinedIcon from '@mui/icons-material/RefreshOutlined';
import SearchOutlinedIcon from '@mui/icons-material/SearchOutlined';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert, Box, Button, Card, CardContent, Chip, CircularProgress, InputAdornment,
  Paper, Stack, Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  TextField, Typography,
} from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { PageHeader } from '../components/layout/PageHeader';
import { DatePickerField } from '../components/ui/DateTimeFields';
import * as reportSvc from '../services/workforceReportService';

function todayIso() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function formatDate(iso: string) {
  const [y, m, d] = iso.split('-');
  return y && m && d ? `${d}/${m}/${y}` : iso;
}

function employeeStatusLabel(value: string) {
  return ({ ACTIVE: 'Chính thức', PROBATION: 'Thử việc', INTERN: 'Thực tập', ON_LEAVE: 'Tạm nghỉ' } as Record<string, string>)[value] || value;
}

function attendanceStatusLabel(value?: string | null) {
  return (
    ({
      PRESENT: 'Đi làm đủ',
      PARTIAL: 'Đi làm thiếu ca',
      SEMINAR: 'Hội thảo + đi làm',
      ABSENT: 'Đã check-in',
    } as Record<string, string>)[value || ''] ||
    value ||
    '—'
  );
}

/** Giờ vào / ra đã chuẩn hóa từ API — không lấy lại punch thô. */
function displayCheckIn(row: { checkIn?: string | null }) {
  return row.checkIn || '—';
}

function displayCheckOut(row: { checkIn?: string | null; checkOut?: string | null }) {
  const out = row.checkOut || '';
  const inn = row.checkIn || '';
  // Chặn trường hợp vào=ra (cùng HH:mm) còn sót từ API cũ / punch trùng phút
  if (!out || (inn && out === inn)) return '—';
  return out;
}

function KpiCard({ icon, label, value, hint, color }: { icon: React.ReactNode; label: string; value: string | number; hint: string; color: string }) {
  return (
    <Card elevation={0} sx={{ flex: '1 1 140px', borderRadius: 2, border: `1px solid ${alpha(color, 0.16)}`, background: `linear-gradient(145deg, ${alpha(color, 0.07)}, #fff 72%)` }}>
      <CardContent sx={{ py: 1.25, px: 1.5, '&:last-child': { pb: 1.25 } }}>
        <Stack direction="row" justifyContent="space-between" alignItems="center" spacing={1}>
          <Box sx={{ minWidth: 0 }}>
            <Typography variant="caption" color="text.secondary" fontWeight={700} sx={{ textTransform: 'uppercase', letterSpacing: '.04em', fontSize: '0.65rem' }}>{label}</Typography>
            <Typography variant="h6" fontWeight={850} sx={{ lineHeight: 1.2, color, fontSize: { xs: '1.1rem', md: '1.25rem' } }}>{value}</Typography>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: 160 }}>{hint}</Typography>
          </Box>
          <Box sx={{ width: 32, height: 32, flexShrink: 0, borderRadius: 1.5, display: 'grid', placeItems: 'center', bgcolor: alpha(color, .12), color }}>{icon}</Box>
        </Stack>
      </CardContent>
    </Card>
  );
}

export default function WorkforceReportsPage() {
  const theme = useTheme();
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const daily = pathname.includes('/daily-workforce');
  const [date, setDate] = useState(todayIso);
  const [report, setReport] = useState<reportSvc.WorkforceReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      setReport(daily ? await reportSvc.fetchDailyWorkforceReport(date) : await reportSvc.fetchHospitalWorkforceReport());
    } catch {
      setError('Không tải được dữ liệu báo cáo. Vui lòng thử lại.');
    } finally { setLoading(false); }
  }, [daily, date]);

  useEffect(() => {
    setReport(null);
    setSearch('');
    void load();
  }, [load]);

  const filteredDetails = useMemo(() => {
    if (!report) return [];
    const q = search.trim().toLocaleLowerCase('vi');
    if (!q) return report.details;
    return report.details.filter((r) => `${r.employeeCode || ''} ${r.fullName} ${r.departmentName} ${r.positionTitle} ${r.categoryLabel}`.toLocaleLowerCase('vi').includes(q));
  }, [report, search]);

  const filteredAbsentByDepartment = useMemo(() => {
    if (!report?.absentByDepartment?.length) return [];
    const q = search.trim().toLocaleLowerCase('vi');
    if (!q) return report.absentByDepartment;
    return report.absentByDepartment
      .map((dept) => {
        const employees = dept.employees.filter((r) =>
          `${r.employeeCode || ''} ${r.fullName} ${r.departmentName} ${r.positionTitle || ''}`.toLocaleLowerCase('vi').includes(q),
        );
        return { ...dept, employees, total: employees.length };
      })
      .filter((dept) => dept.total > 0);
  }, [report, search]);

  const filteredAbsentTotal = useMemo(
    () => filteredAbsentByDepartment.reduce((sum, d) => sum + d.total, 0),
    [filteredAbsentByDepartment],
  );

  const topCategory = useMemo(() => {
    if (!report) return null;
    return report.categories.map((c) => ({ ...c, value: report.totals[c.key] || 0 })).sort((a, b) => b.value - a.value)[0];
  }, [report]);

  const matrixLayout = useMemo(() => {
    const catCount = report?.categories.length ?? 0;
    const deptPct = catCount >= 14 ? 15 : catCount >= 11 ? 17 : 20;
    const totalPct = 4;
    const catPct = (100 - deptPct - totalPct) / Math.max(catCount, 1);
    const headFs = catCount >= 14 ? '0.58rem' : catCount >= 11 ? '0.62rem' : '0.68rem';
    const bodyFs = catCount >= 14 ? '0.6rem' : '0.66rem';
    return { catCount, deptPct, totalPct, catPct, headFs, bodyFs };
  }, [report?.categories.length]);

  async function exportExcel() {
    setExporting(true);
    setError(null);
    try {
      await reportSvc.downloadWorkforceReport(daily ? 'DAILY' : 'HOSPITAL', date);
    } catch (e: unknown) {
      if (report) {
        try {
          await reportSvc.downloadWorkforceReportFallback(report);
        } catch {
          const msg =
            (e as { message?: string })?.message || 'Không xuất được file Excel báo cáo.';
          setError(msg);
        }
      } else {
        setError('Không xuất được file Excel báo cáo.');
      }
    } finally {
      setExporting(false);
    }
  }

  return (
    <Box>
      <PageHeader
        mb={1.5}
        overline="Báo cáo"
        title={daily ? 'Nhân lực đi làm hằng ngày' : 'Nhân lực toàn viện'}
        description={daily
          ? 'Quân số có mặt theo Khoa/Phòng và chức vụ trong ngày. Có check-in/out sáng hoặc chiều đều tính đi làm.'
          : 'Nhân lực biên chế theo Khoa/Phòng và chức vụ trên hồ sơ.'}
        actions={<Button variant="contained" startIcon={exporting ? <CircularProgress size={17} color="inherit" /> : <FileDownloadOutlinedIcon />} onClick={exportExcel} disabled={exporting || !report}>{exporting ? 'Đang tạo Excel…' : 'Xuất Excel'}</Button>}
      />

      <Paper elevation={0} sx={{ p: 1.25, mb: 1.5, borderRadius: 2, border: `1px solid ${theme.palette.divider}` }}>
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={1} alignItems={{ md: 'center' }}>
          <Stack
            direction="row"
            spacing={0.5}
            sx={{
              p: 0.35,
              borderRadius: 1.5,
              bgcolor: alpha(theme.palette.primary.main, 0.06),
              border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
            }}
          >
            <Button
              size="small"
              variant={!daily ? 'contained' : 'text'}
              onClick={() => navigate('/reports/hospital-workforce')}
              sx={{ whiteSpace: 'nowrap', borderRadius: 1.25, py: 0.5 }}
            >
              Toàn viện
            </Button>
            <Button
              size="small"
              variant={daily ? 'contained' : 'text'}
              onClick={() => navigate('/reports/daily-workforce')}
              sx={{ whiteSpace: 'nowrap', borderRadius: 1.25, py: 0.5 }}
            >
              Đi làm hằng ngày
            </Button>
          </Stack>
          {daily && <DatePickerField label="Ngày báo cáo" value={date} onChange={setDate} sx={{ minWidth: 200 }} />}
          <TextField size="small" fullWidth label="Tìm trong danh sách chi tiết" value={search} onChange={(e) => setSearch(e.target.value)} InputProps={{ startAdornment: <InputAdornment position="start"><SearchOutlinedIcon fontSize="small" /></InputAdornment> }} />
          <Button
            size="small"
            variant="outlined"
            startIcon={<RefreshOutlinedIcon fontSize="small" />}
            onClick={load}
            disabled={loading}
            sx={{
              minWidth: 96,
              minHeight: 36,
              flexShrink: 0,
              whiteSpace: 'nowrap',
              gap: 0.5,
              '& .MuiButton-startIcon': { m: 0 },
            }}
          >
            Làm mới
          </Button>
        </Stack>
      </Paper>

      {error && <Alert severity="error" sx={{ mb: 1.5 }}>{error}</Alert>}
      {loading && !report ? <Box sx={{ py: 10, display: 'grid', placeItems: 'center' }}><CircularProgress /></Box> : report && (
        <>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mb: 1.5 }}>
            <KpiCard icon={<GroupsOutlinedIcon fontSize="small" />} label={daily ? 'Có mặt' : 'Tổng nhân lực'} value={report.grandTotal} hint={daily ? `Ngày ${formatDate(report.reportDate)}` : 'Không gồm nghỉ việc'} color={theme.palette.primary.main} />
            {daily && (
              <KpiCard
                icon={<PersonOffOutlinedIcon fontSize="small" />}
                label="Không đi làm"
                value={report.absentTotal ?? 0}
                hint={`${report.absentDepartmentCount ?? 0} khoa/phòng`}
                color="#0e7490"
              />
            )}
            <KpiCard icon={<ApartmentOutlinedIcon fontSize="small" />} label="Khoa / Phòng" value={report.departmentCount} hint="Đơn vị có dữ liệu" color="#0e7490" />
            <KpiCard icon={<BadgeOutlinedIcon fontSize="small" />} label="Chức vụ nhiều nhất" value={topCategory?.value || 0} hint={topCategory?.label || '—'} color="#b7791f" />
            <KpiCard icon={<CalendarTodayOutlinedIcon fontSize="small" />} label="Ngày báo cáo" value={formatDate(report.reportDate)} hint="Thời điểm tải" color="#6d4c9d" />
          </Stack>

          <Paper elevation={0} sx={{ mb: 1.5, borderRadius: 2, overflow: 'hidden', border: `1px solid ${theme.palette.divider}` }}>
            <Box sx={{ px: 1.75, py: 1, bgcolor: alpha(theme.palette.primary.main, .045), borderBottom: `1px solid ${theme.palette.divider}` }}>
              <Typography variant="subtitle1" fontWeight={800}>Ma trận nhân lực theo Khoa/Phòng</Typography>
              <Typography variant="caption" color="text.secondary">
                Cột chức vụ = nhân viên chính thức; thêm cột Bác sĩ thử việc và Nhân viên thử việc.
              </Typography>
            </Box>
            <TableContainer
              sx={{
                bgcolor: '#fff',
                overflowX: 'hidden',
                overflowY: 'visible',
              }}
            >
              <Table
                size="small"
                sx={{
                  width: '100%',
                  tableLayout: 'fixed',
                  borderCollapse: 'separate',
                  borderSpacing: 0,
                  '& .MuiTableCell-root': {
                    borderColor: alpha('#0f172a', 0.075),
                    borderRight: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
                    px: matrixLayout.catCount >= 14 ? 0.2 : 0.35,
                    '&:last-of-type': { borderRight: 0 },
                  },
                  // Theme mặc định whiteSpace:nowrap trên header — ghi đè để tiêu đề dài xuống dòng trong khung màn hình
                  '& .MuiTableCell-head': {
                    whiteSpace: 'normal !important',
                    height: 'auto',
                    verticalAlign: 'middle',
                  },
                }}
              >
                <TableHead>
                  <TableRow>
                    <TableCell
                      align="center"
                      sx={{
                        width: `${matrixLayout.deptPct}%`,
                        py: 0.75,
                        fontWeight: 900,
                        fontSize: matrixLayout.headFs,
                        lineHeight: 1.2,
                        color: '#123b3a',
                        bgcolor: '#e5f1f0',
                        borderBottom: `2px solid ${alpha(theme.palette.primary.main, 0.3)}`,
                      }}
                    >
                      KHOA / PHÒNG
                    </TableCell>
                    {report.categories.map((c) => (
                      <TableCell
                        key={c.key}
                        align="center"
                        title={c.label}
                        sx={{
                          width: `${matrixLayout.catPct}%`,
                          py: 0.7,
                          fontWeight: 850,
                          fontSize: c.label.length > 12 ? `calc(${matrixLayout.headFs} - 0.02rem)` : matrixLayout.headFs,
                          lineHeight: 1.15,
                          wordBreak: 'keep-all',
                          overflowWrap: 'break-word',
                          hyphens: 'manual',
                          color: '#244846',
                          bgcolor: '#eaf4f3',
                          borderBottom: `2px solid ${alpha(theme.palette.primary.main, 0.3)}`,
                        }}
                      >
                        {c.label}
                      </TableCell>
                    ))}
                    <TableCell
                      align="center"
                      sx={{
                        width: `${matrixLayout.totalPct}%`,
                        py: 0.7,
                        fontWeight: 900,
                        fontSize: matrixLayout.headFs,
                        color: '#fff',
                        bgcolor: theme.palette.primary.main,
                        borderBottom: `2px solid ${theme.palette.primary.dark}`,
                      }}
                    >
                      TỔNG
                    </TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {report.rows.map((row, rowIndex) => {
                    const rowBg = rowIndex % 2 === 0 ? '#ffffff' : '#f7faf9';
                    return (
                      <TableRow
                        key={row.departmentId}
                        sx={{
                          bgcolor: rowBg,
                          transition: 'background-color .15s ease',
                          '&:hover': { bgcolor: '#eef7f6' },
                        }}
                      >
                        <TableCell align="center" sx={{ py: 0.4, bgcolor: rowBg }}>
                          <Typography
                            sx={{
                              fontSize: matrixLayout.bodyFs,
                              lineHeight: 1.2,
                              whiteSpace: 'normal',
                              wordBreak: 'keep-all',
                              overflowWrap: 'break-word',
                              textAlign: 'center',
                            }}
                            fontWeight={800}
                            color="#123b3a"
                            title={row.departmentName}
                          >
                            {row.departmentName}
                          </Typography>
                        </TableCell>
                        {report.categories.map((c) => {
                          const value = row.counts[c.key] || 0;
                          return (
                            <TableCell key={c.key} align="center" sx={{ py: 0.25 }}>
                              <Box
                                component="span"
                                sx={{
                                  display: 'inline-grid',
                                  placeItems: 'center',
                                  minWidth: 14,
                                  height: 17,
                                  px: 0.1,
                                  borderRadius: 1,
                                  fontWeight: value ? 850 : 500,
                                  fontSize: matrixLayout.bodyFs,
                                  fontVariantNumeric: 'tabular-nums',
                                  color: value ? theme.palette.primary.dark : alpha('#64748b', 0.62),
                                  bgcolor: value ? alpha(theme.palette.primary.main, 0.1) : 'transparent',
                                }}
                              >
                                {value}
                              </Box>
                            </TableCell>
                          );
                        })}
                        <TableCell align="center" sx={{ py: 0.25, bgcolor: alpha(theme.palette.primary.main, 0.045) }}>
                          <Box
                            component="span"
                            sx={{
                              display: 'inline-grid',
                              placeItems: 'center',
                              minWidth: 16,
                              height: 17,
                              px: 0.1,
                              borderRadius: 1,
                              bgcolor: alpha(theme.palette.primary.main, 0.14),
                              color: theme.palette.primary.dark,
                              fontWeight: 950,
                              fontSize: matrixLayout.bodyFs,
                              fontVariantNumeric: 'tabular-nums',
                            }}
                          >
                            {row.total}
                          </Box>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                  <TableRow
                    sx={{
                      '& td': {
                        py: 0.65,
                        bgcolor: `${theme.palette.primary.main} !important`,
                        color: '#fff',
                        fontWeight: 900,
                        borderBottom: 0,
                        fontVariantNumeric: 'tabular-nums',
                        fontSize: matrixLayout.bodyFs,
                        whiteSpace: 'normal',
                        wordBreak: 'keep-all',
                        overflowWrap: 'break-word',
                        lineHeight: 1.2,
                      },
                    }}
                  >
                    <TableCell align="center">
                      TỔNG CỘNG
                    </TableCell>
                    {report.categories.map((c) => <TableCell key={c.key} align="center">{report.totals[c.key] || 0}</TableCell>)}
                    <TableCell align="center" sx={{ bgcolor: `${theme.palette.primary.dark} !important` }}>{report.grandTotal}</TableCell>
                  </TableRow>
                </TableBody>
              </Table>
            </TableContainer>
          </Paper>

          <Paper elevation={0} sx={{ borderRadius: 2, overflow: 'hidden', border: `1px solid ${theme.palette.divider}` }}>
            <Box sx={{ px: 1.75, py: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'center', bgcolor: alpha('#0e7490', .04), borderBottom: `1px solid ${theme.palette.divider}` }}>
              <Box><Typography variant="subtitle1" fontWeight={800}>Danh sách nhân viên chi tiết</Typography><Typography variant="caption" color="text.secondary">{filteredDetails.length} nhân viên khớp bộ lọc</Typography></Box>
              <Chip size="small" icon={<LocalHospitalOutlinedIcon />} label={daily ? 'Thực tế đi làm' : 'Nhân lực hiện có'} color="primary" variant="outlined" />
            </Box>
            <TableContainer
              sx={{
                maxHeight: 520,
                bgcolor: '#fff',
                scrollbarColor: `${alpha(theme.palette.primary.main, 0.35)} transparent`,
                '&::-webkit-scrollbar': { width: 9, height: 9 },
                '&::-webkit-scrollbar-thumb': { bgcolor: alpha(theme.palette.primary.main, 0.3), borderRadius: 999, border: '2px solid #fff' },
              }}
            >
              <Table
                stickyHeader
                size="small"
                sx={{
                  minWidth: daily ? 1080 : 860,
                  borderCollapse: 'separate',
                  borderSpacing: 0,
                  '& .MuiTableCell-root': { borderColor: alpha('#0f172a', 0.075) },
                  '& .MuiTableCell-stickyHeader': {
                    zIndex: 4,
                    py: 1.1,
                    bgcolor: '#eaf4f3',
                    color: '#244846',
                    fontWeight: 850,
                    borderBottom: `2px solid ${alpha(theme.palette.primary.main, 0.28)}`,
                  },
                }}
              >
                <TableHead><TableRow>
                  <TableCell>Mã NV</TableCell><TableCell>Họ và tên</TableCell><TableCell>Khoa/Phòng</TableCell><TableCell>Chức vụ</TableCell>
                  {daily ? <><TableCell>Ca</TableCell><TableCell align="center">Giờ vào</TableCell><TableCell align="center">Giờ ra</TableCell><TableCell align="center">Công</TableCell><TableCell>Trạng thái</TableCell></> : <TableCell>Trạng thái nhân viên</TableCell>}
                </TableRow></TableHead>
                <TableBody>
                  {filteredDetails.map((r, rowIndex) => (
                    <TableRow
                      key={r.employeeId}
                      sx={{
                        bgcolor: rowIndex % 2 === 0 ? '#fff' : '#f8fbfa',
                        '&:hover': { bgcolor: '#eef7f6' },
                      }}
                    >
                      <TableCell sx={{ color: 'text.secondary', fontWeight: 650, fontVariantNumeric: 'tabular-nums' }}>{r.employeeCode || '—'}</TableCell>
                      <TableCell><Typography variant="body2" fontWeight={800} color="#123b3a">{r.fullName}</Typography></TableCell>
                      <TableCell>{r.departmentName}</TableCell>
                      <TableCell>{r.positionTitle}</TableCell>
                      {daily ? <>
                        <TableCell>
                          <Chip
                            size="small"
                            label={r.shiftKindLabel || (r.shiftKind === 'CONTINUOUS' ? 'Ca thông tầm' : 'Ca sáng–chiều')}
                            color={r.shiftKind === 'CONTINUOUS' ? 'info' : 'default'}
                            variant="outlined"
                            sx={{ fontWeight: 700 }}
                          />
                        </TableCell>
                        <TableCell align="center" sx={{ fontWeight: 750, fontVariantNumeric: 'tabular-nums' }}>{displayCheckIn(r)}</TableCell>
                        <TableCell align="center" sx={{ fontWeight: 750, fontVariantNumeric: 'tabular-nums' }}>{displayCheckOut(r)}</TableCell>
                        <TableCell align="center"><Chip size="small" label={Number(r.workUnits || 0).toFixed(2).replace('.', ',')} color="success" variant="outlined" sx={{ minWidth: 58, fontWeight: 850 }} /></TableCell>
                        <TableCell><Chip size="small" label={attendanceStatusLabel(r.attendanceStatus)} color={r.attendanceStatus === 'PRESENT' ? 'success' : 'warning'} variant="outlined" /></TableCell>
                      </> : <TableCell><Chip size="small" label={employeeStatusLabel(r.employeeStatus)} color={r.employeeStatus === 'ACTIVE' ? 'success' : 'warning'} variant="outlined" /></TableCell>}
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </Paper>

          {daily && (
            <Paper
              elevation={0}
              sx={{
                mt: 1.5,
                borderRadius: 2,
                overflow: 'hidden',
                border: `1px solid ${theme.palette.divider}`,
                bgcolor: '#fff',
              }}
            >
              <Box
                sx={{
                  px: 1.75,
                  py: 1.1,
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  gap: 1,
                  bgcolor: alpha(theme.palette.primary.main, 0.045),
                  borderBottom: `1px solid ${theme.palette.divider}`,
                }}
              >
                <Box>
                  <Typography variant="subtitle1" fontWeight={800} color="#123b3a">
                    Nhân viên không đi làm theo khoa
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {filteredAbsentTotal} người · {filteredAbsentByDepartment.length} khoa/phòng · Bấm khoa để phóng to / thu gọn danh sách
                  </Typography>
                </Box>
                <Chip
                  size="small"
                  icon={<PersonOffOutlinedIcon />}
                  label="Vắng mặt"
                  variant="outlined"
                  color="primary"
                  sx={{ fontWeight: 750 }}
                />
              </Box>

              {filteredAbsentByDepartment.length === 0 ? (
                <Box sx={{ py: 5, textAlign: 'center' }}>
                  <Typography variant="body2" color="text.secondary">
                    Không có nhân viên vắng mặt khớp bộ lọc.
                  </Typography>
                </Box>
              ) : (
                <Box
                  sx={{
                    maxHeight: 560,
                    overflow: 'auto',
                    px: 0.75,
                    py: 0.5,
                    scrollbarColor: `${alpha(theme.palette.primary.main, 0.3)} transparent`,
                    '&::-webkit-scrollbar': { width: 8, height: 8 },
                    '&::-webkit-scrollbar-thumb': {
                      bgcolor: alpha(theme.palette.primary.main, 0.28),
                      borderRadius: 999,
                      border: '2px solid #fff',
                    },
                  }}
                >
                  {filteredAbsentByDepartment.map((dept, deptIdx) => (
                    <Accordion
                      key={dept.departmentId}
                      defaultExpanded={deptIdx === 0}
                      disableGutters
                      elevation={0}
                      sx={{
                        mb: 0.75,
                        borderRadius: '10px !important',
                        border: `1px solid ${alpha('#0f172a', 0.08)}`,
                        overflow: 'hidden',
                        bgcolor: '#fff',
                        '&:before': { display: 'none' },
                        '&.Mui-expanded': {
                          borderColor: alpha(theme.palette.primary.main, 0.28),
                          boxShadow: `0 1px 0 ${alpha(theme.palette.primary.main, 0.06)}`,
                        },
                      }}
                    >
                      <AccordionSummary
                        expandIcon={<ExpandMoreIcon sx={{ color: theme.palette.primary.main }} />}
                        sx={{
                          minHeight: 48,
                          px: 1.5,
                          bgcolor: alpha(theme.palette.primary.main, 0.03),
                          '& .MuiAccordionSummary-content': { my: 0.75 },
                          '&.Mui-expanded': {
                            bgcolor: alpha(theme.palette.primary.main, 0.06),
                            borderBottom: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
                          },
                        }}
                      >
                        <Stack direction="row" spacing={1.25} alignItems="center" sx={{ width: '100%', pr: 1 }}>
                          <Box
                            sx={{
                              width: 32,
                              height: 32,
                              borderRadius: 1.25,
                              display: 'grid',
                              placeItems: 'center',
                              flexShrink: 0,
                              bgcolor: alpha(theme.palette.primary.main, 0.1),
                              color: theme.palette.primary.dark,
                            }}
                          >
                            <ApartmentOutlinedIcon sx={{ fontSize: 18 }} />
                          </Box>
                          <Box sx={{ flex: 1, minWidth: 0 }}>
                            <Typography variant="body2" fontWeight={800} color="#123b3a" noWrap title={dept.departmentName}>
                              {dept.departmentName}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                              Nhân viên không chấm công trong ngày
                            </Typography>
                          </Box>
                          <Chip
                            size="small"
                            label={`${dept.total} người`}
                            color="primary"
                            variant="outlined"
                            sx={{ fontWeight: 750, height: 26 }}
                          />
                        </Stack>
                      </AccordionSummary>
                      <AccordionDetails sx={{ px: 0, pt: 0, pb: 0 }}>
                        <Table size="small">
                          <TableHead>
                            <TableRow>
                              <TableCell sx={{ py: 0.85, fontWeight: 800, color: '#244846', bgcolor: '#f4f8f7', width: 120 }}>Mã NV</TableCell>
                              <TableCell sx={{ py: 0.85, fontWeight: 800, color: '#244846', bgcolor: '#f4f8f7' }}>Họ và tên</TableCell>
                              <TableCell sx={{ py: 0.85, fontWeight: 800, color: '#244846', bgcolor: '#f4f8f7' }}>Chức vụ</TableCell>
                              <TableCell sx={{ py: 0.85, fontWeight: 800, color: '#244846', bgcolor: '#f4f8f7', width: 140 }}>Trạng thái</TableCell>
                            </TableRow>
                          </TableHead>
                          <TableBody>
                            {dept.employees.map((r, idx) => (
                              <TableRow
                                key={r.employeeId}
                                sx={{
                                  bgcolor: idx % 2 === 0 ? '#fff' : '#f8fbfa',
                                  '&:hover': { bgcolor: '#eef7f6' },
                                  '& td': { borderColor: alpha('#0f172a', 0.06), py: 0.9 },
                                }}
                              >
                                <TableCell sx={{ color: 'text.secondary', fontWeight: 650, fontVariantNumeric: 'tabular-nums' }}>
                                  {r.employeeCode || '—'}
                                </TableCell>
                                <TableCell>
                                  <Typography variant="body2" fontWeight={800} color="#123b3a">
                                    {r.fullName}
                                  </Typography>
                                </TableCell>
                                <TableCell sx={{ color: 'text.secondary' }}>{r.positionTitle || '—'}</TableCell>
                                <TableCell>
                                  <Chip
                                    size="small"
                                    label={employeeStatusLabel(r.employeeStatus)}
                                    variant="outlined"
                                    color={r.employeeStatus === 'ACTIVE' ? 'success' : 'default'}
                                    sx={{ fontWeight: 650 }}
                                  />
                                </TableCell>
                              </TableRow>
                            ))}
                          </TableBody>
                        </Table>
                      </AccordionDetails>
                    </Accordion>
                  ))}
                </Box>
              )}
            </Paper>
          )}
        </>
      )}
    </Box>
  );
}
