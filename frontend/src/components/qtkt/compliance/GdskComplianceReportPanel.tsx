import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import PictureAsPdfOutlinedIcon from '@mui/icons-material/PictureAsPdfOutlined';
import RefreshOutlinedIcon from '@mui/icons-material/RefreshOutlined';
import SearchOutlinedIcon from '@mui/icons-material/SearchOutlined';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  IconButton,
  InputAdornment,
  MenuItem,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { QtktEvaluationDialog } from '../QtktEvaluationDialog';
import { ReportChartCard } from '../../charts/ReportChartUi';
import {
  ComplianceDepartmentTable,
  ComplianceKpiCards,
  ComplianceTrendChart,
  ResultChip,
} from './ComplianceReportShared';
import { MonthPickerField } from '../../ui/DateTimeFields';
import { useAuth } from '../../../context/AuthContext';
import * as qtkt from '../../../services/qtktEvaluationService';
import * as reportSvc from '../../../services/qtktComplianceReportService';

const GDSK_KPI_LABELS = {
  total: 'Tổng NB được tư vấn',
  passed: 'Tư vấn đạt hiệu quả',
  failed: 'Chưa đạt hiệu quả',
  rate: 'Tỷ lệ GDSK hiệu quả',
  totalHint: 'Số lần tư vấn trong kỳ (đã gửi)',
  passedHint: '≥ 7/10 và đủ tiêu chí bắt buộc 12–14',
  failedHint: 'Chưa đạt tiêu chí bảng kiểm',
  rateHint: '(Đạt / Tổng NB tư vấn) × 100%',
};

export function GdskComplianceReportPanel() {
  const { user } = useAuth();
  const canPickDept = user?.role === 'ADMIN' || user?.role === 'HEAD_NURSING';

  const [yearMonth, setYearMonth] = useState(reportSvc.currentYearMonth());
  const [departmentId, setDepartmentId] = useState<number | ''>('');
  const [search, setSearch] = useState('');
  const [resultFilter, setResultFilter] = useState<'ALL' | 'PASS' | 'FAIL'>('ALL');
  const [sortDir, setSortDir] = useState<'ASC' | 'DESC'>('DESC');
  const [page, setPage] = useState(0);
  const [size, setSize] = useState(20);

  const [departments, setDepartments] = useState<reportSvc.ComplianceFilterDepartment[]>([]);
  const [employees, setEmployees] = useState<reportSvc.ComplianceFilterEmployee[]>([]);
  const [report, setReport] = useState<reportSvc.ComplianceReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [exporting, setExporting] = useState<'excel' | 'pdf' | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [viewId, setViewId] = useState<number | null>(null);
  const [viewEval, setViewEval] = useState<qtkt.QtktEvaluation | null>(null);
  const [template, setTemplate] = useState<qtkt.QtktTemplate | null>(null);

  const query = useMemo((): reportSvc.ComplianceQuery => ({
    yearMonth,
    departmentId: departmentId || undefined,
    search: search || undefined,
    resultFilter,
    sortDir,
    page,
    size,
  }), [yearMonth, departmentId, search, resultFilter, sortDir, page, size]);

  useEffect(() => {
    reportSvc.fetchComplianceDepartments('GDSK').then(setDepartments).catch(() => {});
    qtkt.fetchQtktTemplate().then(setTemplate).catch(() => {});
  }, []);

  useEffect(() => {
    reportSvc.fetchComplianceEmployees(departmentId || undefined).then(setEmployees).catch(() => {});
  }, [departmentId]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setReport(await reportSvc.fetchGdskCounselingReport(query));
    } catch {
      setError('Không tải được báo cáo tư vấn GDSK.');
    } finally {
      setLoading(false);
    }
  }, [query]);

  useEffect(() => { load(); }, [load]);

  async function openDetail(id: number) {
    try {
      setViewEval(await qtkt.fetchQtktEvaluation(id));
      setViewId(id);
    } catch {
      setError('Không mở được chi tiết phiếu đánh giá.');
    }
  }

  async function exportFile(kind: 'excel' | 'pdf') {
    setExporting(kind);
    try {
      if (kind === 'excel') await reportSvc.downloadGdskCounselingExcel(query);
      else await reportSvc.downloadGdskCounselingPdf(query);
    } catch {
      setError('Xuất báo cáo thất bại.');
    } finally {
      setExporting(null);
    }
  }

  return (
    <Box>
      <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" alignItems={{ sm: 'flex-start' }} spacing={1} sx={{ mb: 1.5 }}>
        <Box sx={{ minWidth: 0 }}>
          <Typography variant="subtitle2" fontWeight={800}>
            Tư vấn, truyền thông GDSK hiệu quả
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.35, lineHeight: 1.45 }}>
            Báo cáo tỷ lệ người bệnh được tư vấn, truyền thông GDSK hiệu quả ở các khoa lâm sàng
            · Đạt khi ≥ 7/10 và đủ điểm tiêu chí bắt buộc 12, 13, 14
          </Typography>
        </Box>
        <Stack direction="row" spacing={1} sx={{ flexShrink: 0 }}>
          <Button size="small" variant="outlined" startIcon={exporting === 'excel' ? <CircularProgress size={14} /> : <FileDownloadOutlinedIcon />} disabled={!!exporting} onClick={() => exportFile('excel')}>Excel</Button>
          <Button size="small" variant="outlined" startIcon={exporting === 'pdf' ? <CircularProgress size={14} /> : <PictureAsPdfOutlinedIcon />} disabled={!!exporting} onClick={() => exportFile('pdf')}>PDF</Button>
        </Stack>
      </Stack>

      <Paper elevation={0} sx={{ p: 1.5, mb: 2, borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
        <Stack direction="row" spacing={1.15} alignItems="center" sx={{ flexWrap: { xs: 'wrap', md: 'nowrap' } }}>
          <MonthPickerField label="Tháng" value={yearMonth} onChange={(v) => { setYearMonth(v); setPage(0); }} size="small" sx={{ minWidth: 178, flex: { md: '0 0 178px' } }} />
          {canPickDept && (
            <TextField select size="small" label="Khoa" value={departmentId} sx={{ minWidth: 160, flex: { md: '0 0 180px' } }} onChange={(e) => { setDepartmentId(e.target.value ? Number(e.target.value) : ''); setPage(0); }}>
              <MenuItem value="">Tất cả khoa lâm sàng</MenuItem>
              {departments.map((d) => <MenuItem key={d.id} value={d.id}>{d.name}</MenuItem>)}
            </TextField>
          )}
          <TextField
            size="small"
            label="Tìm NV / mã BN"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(0); }}
            placeholder="Họ tên hoặc mã bệnh nhân"
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchOutlinedIcon fontSize="small" /></InputAdornment> }}
            sx={{ minWidth: { xs: '100%', md: 220 }, flex: { md: '1 1 220px' } }}
          />
          <Box sx={{ flex: 1, display: { xs: 'none', md: 'block' } }} />
          <IconButton onClick={load} aria-label="Làm mới" sx={{ flexShrink: 0 }}><RefreshOutlinedIcon /></IconButton>
        </Stack>
      </Paper>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}
      {loading && !report && <Box sx={{ py: 6, display: 'grid', placeItems: 'center' }}><CircularProgress /></Box>}

      {report && (
        <Stack spacing={2}>
          <ComplianceKpiCards kpi={report.kpi} labels={GDSK_KPI_LABELS} />
          {report.formulaNote && (
            <Alert severity="info" variant="outlined" sx={{ borderRadius: 2 }}>
              {report.formulaNote}
            </Alert>
          )}
          <ReportChartCard title="Xu hướng tỷ lệ tư vấn GDSK hiệu quả" subtitle="Theo thời gian trong kỳ báo cáo">
            <ComplianceTrendChart trend={report.trend} />
          </ReportChartCard>
          <Paper elevation={0} sx={{ p: 1.5, borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
            <Typography variant="subtitle2" fontWeight={800} sx={{ mb: 1 }}>Thống kê theo khoa lâm sàng</Typography>
            <ComplianceDepartmentTable rows={report.byDepartment} onSelectDepartment={(id) => { setDepartmentId(id); setPage(0); }} />
          </Paper>
          <Paper elevation={0} sx={{ p: 1.5, borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} sx={{ mb: 1.25 }} alignItems={{ sm: 'center' }}>
              <Typography variant="subtitle2" fontWeight={800} sx={{ flex: 1 }}>Danh sách tư vấn chi tiết</Typography>
              <TextField select size="small" label="Kết quả" value={resultFilter} sx={{ minWidth: 130 }} onChange={(e) => { setResultFilter(e.target.value as 'ALL' | 'PASS' | 'FAIL'); setPage(0); }}>
                <MenuItem value="ALL">Tất cả</MenuItem>
                <MenuItem value="PASS">Đạt</MenuItem>
                <MenuItem value="FAIL">Không đạt</MenuItem>
              </TextField>
              <TextField select size="small" label="Sắp xếp ngày" value={sortDir} sx={{ minWidth: 130 }} onChange={(e) => setSortDir(e.target.value as 'ASC' | 'DESC')}>
                <MenuItem value="DESC">Mới nhất</MenuItem>
                <MenuItem value="ASC">Cũ nhất</MenuItem>
              </TextField>
            </Stack>
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Ngày tư vấn</TableCell>
                    <TableCell>Khoa</TableCell>
                    <TableCell>Nhân viên</TableCell>
                    <TableCell>Mã bệnh nhân</TableCell>
                    <TableCell align="right">Điểm</TableCell>
                    <TableCell>Kết quả</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {report.details.items.length === 0 ? (
                    <TableRow><TableCell colSpan={6} align="center" sx={{ py: 3, color: 'text.secondary' }}>Chưa có dữ liệu</TableCell></TableRow>
                  ) : report.details.items.map((row) => (
                    <TableRow key={row.id} hover sx={{ cursor: 'pointer' }} onClick={() => openDetail(row.id)}>
                      <TableCell>{row.evalDateLabel}</TableCell>
                      <TableCell>{row.departmentName}</TableCell>
                      <TableCell>{row.employeeName}</TableCell>
                      <TableCell>{row.patientCode || '—'}</TableCell>
                      <TableCell align="right">{row.totalScore}/{row.maxScore}</TableCell>
                      <TableCell><ResultChip passed={row.passed} label={row.result} /></TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
            <TablePagination component="div" count={report.details.total} page={page} onPageChange={(_, p) => setPage(p)} rowsPerPage={size} onRowsPerPageChange={(e) => { setSize(Number(e.target.value)); setPage(0); }} rowsPerPageOptions={[10, 20, 50]} labelRowsPerPage="Số dòng" />
          </Paper>
        </Stack>
      )}

      {viewId != null && template && viewEval && (
        <QtktEvaluationDialog open template={template} employees={employees.map((e) => ({ ...e, positionTitle: null }))} existing={viewEval} readOnly onClose={() => { setViewId(null); setViewEval(null); }} />
      )}
    </Box>
  );
}
