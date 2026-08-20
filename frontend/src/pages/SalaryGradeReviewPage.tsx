import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import DownloadOutlinedIcon from '@mui/icons-material/DownloadOutlined';
import EventAvailableOutlinedIcon from '@mui/icons-material/EventAvailableOutlined';
import LockOutlinedIcon from '@mui/icons-material/LockOutlined';
import VisibilityIcon from '@mui/icons-material/Visibility';
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined';
import SearchOutlinedIcon from '@mui/icons-material/SearchOutlined';
import TrendingUpOutlinedIcon from '@mui/icons-material/TrendingUpOutlined';
import {
  Alert, Box, Button, Chip, CircularProgress, Grid, IconButton, InputAdornment, MenuItem, Paper,
  Stack, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, TextField,
  Tooltip, Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { PageHeader } from '../components/layout/PageHeader';
import * as salaryService from '../services/salaryService';
import { formatDateVi } from '../utils/dateFormat';

function normalize(value: string) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd').toLowerCase();
}

function Stat({ label, value, hint, color, icon }: { label: string; value: string; hint: string; color: string; icon: React.ReactNode }) {
  return (
    <Paper elevation={0} sx={{ p: 2.25, height: '100%', borderRadius: 3, border: `1px solid ${alpha(color, 0.18)}`, bgcolor: alpha(color, 0.045) }}>
      <Stack direction="row" spacing={1.5} alignItems="center">
        <Box sx={{ width: 44, height: 44, borderRadius: 2.25, display: 'grid', placeItems: 'center', bgcolor: alpha(color, 0.14), color }}>{icon}</Box>
        <Box>
          <Typography variant="caption" color="text.secondary" fontWeight={700} textTransform="uppercase">{label}</Typography>
          <Typography variant="h5" fontWeight={850} lineHeight={1.15}>{value}</Typography>
          <Typography variant="caption" color="text.secondary">{hint}</Typography>
        </Box>
      </Stack>
    </Paper>
  );
}

function timingChip(status: salaryService.SalaryGradeReviewRow['timingStatus'], days: number) {
  if (status === 'TODAY') return <Chip size="small" color="error" label="Đến hạn hôm nay" />;
  if (status === 'PASSED') return <Chip size="small" color="warning" label={`Đã đến hạn ${Math.abs(days)} ngày`} />;
  return <Chip size="small" color="success" variant="outlined" label={`Còn ${days} ngày`} />;
}

export default function SalaryGradeReviewPage() {
  const theme = useTheme();
  const now = new Date();
  const [period, setPeriod] = useState(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`);
  const [report, setReport] = useState<salaryService.SalaryGradeReviewReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [password, setPassword] = useState('');
  const [unlocking, setUnlocking] = useState(false);
  const [unlocked, setUnlocked] = useState(() => Boolean(salaryService.getSalaryAccessToken()));
  const [search, setSearch] = useState('');
  const [department, setDepartment] = useState('');
  const [category, setCategory] = useState('');
  const [timing, setTiming] = useState('');
  const [source, setSource] = useState('');
  const [sort, setSort] = useState('date');
  const [page, setPage] = useState(0);
  const pageSize = 20;
  const [year, month] = period.split('-').map(Number);

  useEffect(() => {
    if (!unlocked || !year || !month) return;
    setLoading(true); setError(null);
    salaryService.fetchSalaryGradeReviews(year, month)
      .then(setReport)
      .catch(() => {
        salaryService.clearSalaryAccess();
        setUnlocked(false);
        setError('Phiên mở khóa đã hết hạn. Vui lòng nhập lại mật khẩu phần lương.');
      })
      .finally(() => setLoading(false));
  }, [unlocked, year, month]);

  useEffect(() => setPage(0), [search, department, category, timing, source, sort, period]);

  const departments = useMemo(() => [...new Set((report?.rows ?? []).map(r => r.department).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'vi')), [report]);
  const filtered = useMemo(() => {
    const q = normalize(search.trim());
    const rows = (report?.rows ?? []).filter(r => {
      if (q && !normalize(`${r.employeeCode} ${r.fullName} ${r.department} ${r.position}`).includes(q)) return false;
      if (department && r.department !== department) return false;
      if (category && r.salaryCategory !== category) return false;
      if (timing && r.timingStatus !== timing) return false;
      if (source && r.reviewSource !== source) return false;
      return true;
    });
    return [...rows].sort((a, b) => {
      if (sort === 'name') return a.fullName.localeCompare(b.fullName, 'vi');
      if (sort === 'department') return a.department.localeCompare(b.department, 'vi') || a.fullName.localeCompare(b.fullName, 'vi');
      if (sort === 'increase') return b.increaseAmount - a.increaseAmount;
      return a.effectiveDate.localeCompare(b.effectiveDate) || a.fullName.localeCompare(b.fullName, 'vi');
    });
  }, [report, search, department, category, timing, source, sort]);
  const visible = filtered.slice(page * pageSize, (page + 1) * pageSize);
  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize));

  async function unlock() {
    if (!password) return;
    setUnlocking(true); setError(null);
    try { await salaryService.unlockSalaryAccess(password); setUnlocked(true); setPassword(''); }
    catch { setError('Mật khẩu phần lương không đúng.'); }
    finally { setUnlocking(false); }
  }

  async function exportExcel() {
    setExporting(true); setError(null);
    try { await salaryService.downloadSalaryGradeReviewExcel(year, month); }
    catch { setError('Không xuất được file Excel. Vui lòng thử lại.'); }
    finally { setExporting(false); }
  }

  return (
    <Box>
      <PageHeader
        overline="Lương"
        title="Nâng bậc lương"
        description="Theo dõi nhân viên đến kỳ nâng bậc trong tháng, mức lương dự kiến và chênh lệch sau nâng bậc."
        actions={unlocked ? <Button variant="contained" startIcon={<DownloadOutlinedIcon />} disabled={exporting || loading} onClick={exportExcel}>{exporting ? 'Đang xuất…' : 'Xuất Excel'}</Button> : undefined}
      />

      {!unlocked ? (
        <Paper elevation={0} sx={{ maxWidth: 620, mx: 'auto', mt: 5, p: 4, borderRadius: 4, textAlign: 'center', border: '1px solid', borderColor: 'divider' }}>
          <Box sx={{ width: 64, height: 64, mx: 'auto', mb: 2, borderRadius: 3, display: 'grid', placeItems: 'center', bgcolor: alpha(theme.palette.primary.main, .1), color: 'primary.main' }}><LockOutlinedIcon fontSize="large" /></Box>
          <Typography variant="h6" fontWeight={800}>Mở khóa danh sách nâng bậc lương</Typography>
          <Typography color="text.secondary" sx={{ mt: 1, mb: 2.5 }}>Dữ liệu lương được bảo vệ bằng mật khẩu riêng của khu vực Lương.</Typography>
          {error && <Alert severity="error" sx={{ mb: 2, textAlign: 'left' }}>{error}</Alert>}
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.25}>
            <TextField fullWidth type="password" label="Mật khẩu phần lương" value={password} onChange={e => setPassword(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') void unlock(); }} />
            <Button variant="contained" disabled={unlocking || !password} onClick={unlock} sx={{ minWidth: 130 }}>{unlocking ? <CircularProgress size={20} /> : 'Mở khóa'}</Button>
          </Stack>
        </Paper>
      ) : (
        <Stack spacing={2.5}>
          {error && <Alert severity="error" onClose={() => setError(null)}>{error}</Alert>}
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6} lg={3}><Stat label="Tổng đến kỳ" value={String(report?.total ?? 0)} hint={`Trong tháng ${month}/${year}`} color={theme.palette.primary.main} icon={<CalendarMonthOutlinedIcon />} /></Grid>
            <Grid item xs={12} sm={6} lg={3}><Stat label="Sắp đến hạn" value={String(report?.upcoming ?? 0)} hint="Từ ngày hiện tại trở đi" color="#059669" icon={<EventAvailableOutlinedIcon />} /></Grid>
            <Grid item xs={12} sm={6} lg={3}><Stat label="Đã đến hạn" value={String((report?.today ?? 0) + (report?.passed ?? 0))} hint="Cần rà soát trong tháng" color="#d97706" icon={<TrendingUpOutlinedIcon />} /></Grid>
            <Grid item xs={12} sm={6} lg={3}><Stat label="Tổng chênh lệch" value={salaryService.formatMoney(report?.increaseTotal ?? 0)} hint="Dự kiến sau nâng bậc" color="#7c3aed" icon={<PaymentsOutlinedIcon />} /></Grid>
          </Grid>

          <Paper elevation={0} sx={{ p: 2, borderRadius: 3, border: '1px solid', borderColor: 'divider' }}>
            <Grid container spacing={1.5}>
              <Grid item xs={12} md={3}><TextField fullWidth size="small" label="Tháng nâng bậc" type="month" value={period} onChange={e => setPeriod(e.target.value)} InputLabelProps={{ shrink: true }} /></Grid>
              <Grid item xs={12} md={3}><TextField fullWidth size="small" label="Tìm nhân viên" value={search} onChange={e => setSearch(e.target.value)} InputProps={{ startAdornment: <InputAdornment position="start"><SearchOutlinedIcon fontSize="small" /></InputAdornment> }} /></Grid>
              <Grid item xs={12} sm={6} md={3}><TextField select fullWidth size="small" label="Khoa/phòng" value={department} onChange={e => setDepartment(e.target.value)}><MenuItem value="">Tất cả</MenuItem>{departments.map(d => <MenuItem key={d} value={d}>{d}</MenuItem>)}</TextField></Grid>
              <Grid item xs={12} sm={6} md={3}><TextField select fullWidth size="small" label="Đối tượng lương" value={category} onChange={e => setCategory(e.target.value)}><MenuItem value="">Tất cả</MenuItem><MenuItem value="EMPLOYEE">Nhân viên</MenuItem><MenuItem value="DOCTOR">Bác sĩ</MenuItem></TextField></Grid>
              <Grid item xs={12} sm={4}><TextField select fullWidth size="small" label="Tiến độ" value={timing} onChange={e => setTiming(e.target.value)}><MenuItem value="">Tất cả</MenuItem><MenuItem value="UPCOMING">Sắp đến hạn</MenuItem><MenuItem value="TODAY">Đến hạn hôm nay</MenuItem><MenuItem value="PASSED">Đã đến hạn</MenuItem></TextField></Grid>
              <Grid item xs={12} sm={4}><TextField select fullWidth size="small" label="Nguồn xác định" value={source} onChange={e => setSource(e.target.value)}><MenuItem value="">Tất cả</MenuItem><MenuItem value="SENIORITY_SCALE">Thâm niên/thang lương</MenuItem><MenuItem value="MANUAL_REVIEW_DATE">Ngày xét lương hồ sơ</MenuItem></TextField></Grid>
              <Grid item xs={12} sm={4}><TextField select fullWidth size="small" label="Sắp xếp" value={sort} onChange={e => setSort(e.target.value)}><MenuItem value="date">Ngày nâng bậc gần nhất</MenuItem><MenuItem value="name">Tên nhân viên</MenuItem><MenuItem value="department">Khoa/phòng</MenuItem><MenuItem value="increase">Mức tăng cao nhất</MenuItem></TextField></Grid>
            </Grid>
          </Paper>

          <Paper elevation={0} sx={{ borderRadius: 3, border: '1px solid', borderColor: 'divider', overflow: 'hidden' }}>
            <Box sx={{ px: 2.5, py: 1.75, borderBottom: '1px solid', borderColor: 'divider', display: 'flex', justifyContent: 'space-between' }}>
              <Typography fontWeight={800}>Danh sách nâng bậc <Typography component="span" color="text.secondary" fontWeight={500}>({filtered.length} nhân viên)</Typography></Typography>
              <Typography variant="caption" color="text.secondary">Trang {page + 1}/{pageCount}</Typography>
            </Box>
            {loading ? <Box sx={{ py: 8, textAlign: 'center' }}><CircularProgress /></Box> : (
              <TableContainer
                sx={{
                  maxHeight: { xs: '58vh', md: 'calc(100vh - 330px)' },
                  overflowX: 'auto',
                }}
              >
                <Table
                  size="small"
                  sx={{
                    width: '100%',
                    minWidth: { xs: 1180, xl: 1220 },
                    tableLayout: 'fixed',
                    '& th, & td': {
                      px: { xs: 0.75, lg: 1 },
                      py: 1,
                      fontSize: { xs: '0.74rem', lg: '0.78rem' },
                      verticalAlign: 'top',
                    },
                    '& th': {
                      lineHeight: 1.2,
                      whiteSpace: 'normal',
                    },
                    '& th:nth-of-type(1), & td:nth-of-type(1)': { width: 140 },
                    '& th:nth-of-type(2), & td:nth-of-type(2)': { width: 190 },
                    '& th:nth-of-type(3), & td:nth-of-type(3)': { width: 150 },
                    '& th:nth-of-type(4), & td:nth-of-type(4)': { width: 128 },
                    '& th:nth-of-type(5), & td:nth-of-type(5)': { width: 78 },
                    '& th:nth-of-type(6), & td:nth-of-type(6)': { width: 90 },
                    '& th:nth-of-type(7), & td:nth-of-type(7)': { width: 112 },
                    '& th:nth-of-type(8), & td:nth-of-type(8)': { width: 116 },
                    '& th:nth-of-type(9), & td:nth-of-type(9)': { width: 118 },
                    '& th:nth-of-type(10), & td:nth-of-type(10)': { width: 120 },
                    '& th:nth-of-type(11), & td:nth-of-type(11)': { width: 66, textAlign: 'center' },
                  }}
                >
                  <TableHead><TableRow>
                    {['Nhân viên', 'Khoa/phòng · Chức vụ', 'Đối tượng · Trình độ', 'Ngày nâng bậc', 'Bậc hiện tại', 'Bậc dự kiến', 'Lương hiện tại', 'Lương dự kiến', 'Chênh lệch', 'Tiến độ', 'Thao tác'].map(h => <TableCell key={h} sx={{ fontWeight: 800, bgcolor: '#f4f8f7' }}>{h}</TableCell>)}
                  </TableRow></TableHead>
                  <TableBody>
                    {visible.length === 0 ? <TableRow><TableCell colSpan={11} align="center" sx={{ py: 7, color: 'text.secondary' }}>Không có nhân viên nâng bậc phù hợp trong tháng đã chọn.</TableCell></TableRow> : visible.map((r) => (
                      <TableRow hover key={`${r.employeeId}-${r.effectiveDate}`}>
                        <TableCell><Typography component={Link} to={`/salary?employeeId=${r.employeeId}`} color="primary" fontWeight={750} sx={{ textDecoration: 'none' }}>{r.fullName}</Typography><Typography variant="caption" display="block" color="text.secondary">{r.employeeCode || 'Chưa có mã'}</Typography></TableCell>
                        <TableCell><Typography variant="body2" fontWeight={650}>{r.department || '—'}</Typography><Typography variant="caption" color="text.secondary">{r.position || '—'}</Typography></TableCell>
                        <TableCell><Chip size="small" variant="outlined" label={r.salaryCategory === 'DOCTOR' ? 'Bác sĩ' : r.employeeBlock === 'DIRECT' ? 'NV trực tiếp' : 'NV gián tiếp'} /><Typography variant="caption" display="block" color="text.secondary" sx={{ mt: .5 }}>{r.qualification || '—'}</Typography></TableCell>
                        <TableCell><Typography fontWeight={750}>{formatDateVi(r.effectiveDate)}</Typography><Typography variant="caption" color="text.secondary">Thâm niên {salaryService.formatYears(r.seniorityYears)} năm</Typography></TableCell>
                        <TableCell>{r.currentGrade || '—'}</TableCell>
                        <TableCell><Chip size="small" color="primary" label={r.nextGrade || '—'} /></TableCell>
                        <TableCell align="right">{salaryService.formatMoney(r.currentSalary)}</TableCell>
                        <TableCell align="right"><Typography fontWeight={750}>{salaryService.formatMoney(r.nextSalary)}</Typography></TableCell>
                        <TableCell align="right"><Typography color="success.main" fontWeight={800}>+{salaryService.formatMoney(r.increaseAmount)}</Typography><Typography variant="caption" color="text.secondary">+{r.increasePercent.toLocaleString('vi-VN')}%</Typography></TableCell>
                        <TableCell>{timingChip(r.timingStatus, r.daysUntil)}</TableCell>
                        <TableCell>
                          <Tooltip title="Xem thông tin lương">
                            <IconButton
                              component={Link}
                              to={`/salary?employeeId=${r.employeeId}`}
                              size="small"
                              color="primary"
                              aria-label={`Xem thông tin lương của ${r.fullName}`}
                            >
                              <VisibilityIcon fontSize="small" />
                            </IconButton>
                          </Tooltip>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            )}
            <Stack direction="row" justifyContent="flex-end" spacing={1} sx={{ p: 1.5, borderTop: '1px solid', borderColor: 'divider' }}>
              <Button size="small" disabled={page === 0} onClick={() => setPage(p => p - 1)}>Trang trước</Button>
              <Button size="small" disabled={page >= pageCount - 1} onClick={() => setPage(p => p + 1)}>Trang sau</Button>
            </Stack>
          </Paper>
        </Stack>
      )}
    </Box>
  );
}
