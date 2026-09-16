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
  ComplianceBucketTable,
  ComplianceDepartmentTable,
  ComplianceKpiCards,
  ComplianceTrendChart,
  ResultChip,
} from './ComplianceReportShared';
import { MonthPickerField } from '../../ui/DateTimeFields';
import { useAuth } from '../../../context/AuthContext';
import * as qtkt from '../../../services/qtktEvaluationService';
import * as reportSvc from '../../../services/qtktComplianceReportService';

export function HandHygieneComplianceReportPanel() {
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
    reportSvc.fetchComplianceDepartments().then(setDepartments).catch(() => {});
    qtkt.fetchQtktTemplate().then(setTemplate).catch(() => {});
  }, []);

  useEffect(() => {
    reportSvc.fetchComplianceEmployees(departmentId || undefined).then(setEmployees).catch(() => {});
  }, [departmentId]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setReport(await reportSvc.fetchHandHygieneReport(query));
    } catch {
      setError('Không tải được báo cáo tuân thủ vệ sinh tay.');
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
      if (kind === 'excel') await reportSvc.downloadHandHygieneExcel(query);
      else await reportSvc.downloadHandHygienePdf(query);
    } catch {
      setError('Xuất báo cáo thất bại.');
    } finally {
      setExporting(null);
    }
  }

  return (
    <Box>
      <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" alignItems={{ sm: 'center' }} spacing={1} sx={{ mb: 1.5 }}>
        <Box>
          <Typography variant="subtitle2" fontWeight={800}>Tuân thủ vệ sinh tay</Typography>
          <Typography variant="caption" color="text.secondary">Tự động từ phiếu rửa tay thường quy · Đạt = 10/10</Typography>
        </Box>
        <Stack direction="row" spacing={1}>
          <Button size="small" variant="outlined" startIcon={exporting === 'excel' ? <CircularProgress size={14} /> : <FileDownloadOutlinedIcon />} disabled={!!exporting} onClick={() => exportFile('excel')}>Excel</Button>
          <Button size="small" variant="outlined" startIcon={exporting === 'pdf' ? <CircularProgress size={14} /> : <PictureAsPdfOutlinedIcon />} disabled={!!exporting} onClick={() => exportFile('pdf')}>PDF</Button>
        </Stack>
      </Stack>

      <Paper elevation={0} sx={{ p: 1.5, mb: 2, borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
        <Stack direction="row" spacing={1.15} alignItems="center" sx={{ flexWrap: { xs: 'wrap', md: 'nowrap' } }}>
          <MonthPickerField label="Tháng" value={yearMonth} onChange={(v) => { setYearMonth(v); setPage(0); }} size="small" sx={{ minWidth: 178, flex: { md: '0 0 178px' } }} />
          {canPickDept && (
            <TextField select size="small" label="Khoa" value={departmentId} sx={{ minWidth: 160, flex: { md: '0 0 180px' } }} onChange={(e) => { setDepartmentId(e.target.value ? Number(e.target.value) : ''); setPage(0); }}>
              <MenuItem value="">Tất cả</MenuItem>
              {departments.map((d) => <MenuItem key={d.id} value={d.id}>{d.name}</MenuItem>)}
            </TextField>
          )}
          <TextField
            size="small"
            label="Tìm theo tên"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(0); }}
            placeholder="Nhập họ tên nhân viên"
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchOutlinedIcon fontSize="small" /></InputAdornment> }}
            sx={{ minWidth: { xs: '100%', md: 200 }, flex: { md: '1 1 200px' } }}
          />
          <Box sx={{ flex: 1, display: { xs: 'none', md: 'block' } }} />
          <IconButton onClick={load} aria-label="Làm mới" sx={{ flexShrink: 0 }}><RefreshOutlinedIcon /></IconButton>
        </Stack>
      </Paper>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}
      {loading && !report && <Box sx={{ py: 6, display: 'grid', placeItems: 'center' }}><CircularProgress /></Box>}

      {report && (
        <Stack spacing={2}>
          <ComplianceKpiCards kpi={report.kpi} />
          <ReportChartCard title="Xu hướng tỷ lệ tuân thủ" subtitle="Vệ sinh tay theo thời gian trong kỳ">
            <ComplianceTrendChart trend={report.trend} />
          </ReportChartCard>
          <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', lg: '1fr 1fr' }, gap: 2 }}>
            <Paper elevation={0} sx={{ p: 1.5, borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
              <Typography variant="subtitle2" fontWeight={800} sx={{ mb: 1 }}>Thống kê theo khoa</Typography>
              <ComplianceDepartmentTable rows={report.byDepartment} onSelectDepartment={(id) => { setDepartmentId(id); setPage(0); }} />
            </Paper>
            <Paper elevation={0} sx={{ p: 1.5, borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
              <ComplianceBucketTable title="Thống kê theo thời điểm vệ sinh tay" rows={report.byCheckContext ?? []} nameHeader="Thời điểm" nameKey="checkContextLabel" />
            </Paper>
          </Box>
          <Paper elevation={0} sx={{ p: 1.5, borderRadius: 2.5, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} sx={{ mb: 1.25 }} alignItems={{ sm: 'center' }}>
              <Typography variant="subtitle2" fontWeight={800} sx={{ flex: 1 }}>Danh sách chi tiết</Typography>
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
                    <TableCell>Ngày kiểm tra</TableCell>
                    <TableCell>Khoa</TableCell>
                    <TableCell>Nhân viên</TableCell>
                    <TableCell>Thời điểm vệ sinh tay</TableCell>
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
                      <TableCell>{row.checkContextLabel || '—'}</TableCell>
                      <TableCell align="right">{row.totalScore}</TableCell>
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
