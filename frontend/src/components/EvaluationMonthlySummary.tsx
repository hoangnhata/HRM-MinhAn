import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import InsightsOutlinedIcon from '@mui/icons-material/InsightsOutlined';
import VisibilityIcon from '@mui/icons-material/Visibility';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { isHeadDepartmentRole, isHr2Role } from '../utils/roleAccess';
import * as ne from '../services/nursingEvaluationService';
import { CollapsibleSection } from './ui/CollapsibleSection';
import { MonthPickerField } from './ui/DateTimeFields';
import { NursingEvaluationDetailDialog, type NursingDetailEditRequest } from './NursingEvaluationDetailDialog';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';

type Props = {
  templateCode: string;
  refreshKey?: number;
  onRequestEditEvaluation?: (p: NursingDetailEditRequest) => void;
};

function cellNum(n: number | null | undefined): string {
  if (n == null || Number.isNaN(Number(n))) return '—';
  return String(n);
}

function gradeChipColor(grade?: string | null): 'default' | 'success' | 'warning' | 'error' | 'info' {
  const g = (grade || '').toLowerCase();
  if (g.includes('xuất sắc') || g.includes('a')) return 'success';
  if (g.includes('khá') || g.includes('b')) return 'info';
  if (g.includes('trung bình') || g.includes('c')) return 'warning';
  if (g.includes('yếu') || g.includes('d')) return 'error';
  return 'default';
}

function currentYearMonth(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

/** Tổng hợp xếp loại theo tháng — khối ĐD */
export function EvaluationMonthlySummary({ templateCode, refreshKey = 0, onRequestEditEvaluation }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const [period, setPeriod] = useState(currentYearMonth);
  const [rows, setRows] = useState<ne.MonthlyEvalSummaryRow[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [detailId, setDetailId] = useState<number | null>(null);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [exporting, setExporting] = useState(false);
  const [exportErr, setExportErr] = useState<string | null>(null);

  const year = Number(period.slice(0, 4));
  const month = Number(period.slice(5, 7));

  const canNursingHead = user?.role === 'ADMIN' || user?.role === 'HEAD_NURSING';
  /** Xuất Excel thống kê xếp loại: chỉ ADMIN / Trưởng phòng Điều dưỡng. */
  const canExportExcel = canNursingHead;
  const canHr = user?.role === 'ADMIN' || isHr2Role(user?.role);
  const canDirector =
    user?.role === 'ADMIN'
    || user?.role === 'DIRECTOR'
    || user?.directorApprovalEnabled === true;

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    ne
      .fetchNursingMonthlySummary(year, month, templateCode)
      .then((r) => {
        if (!cancelled) {
          setRows(r);
          setErr(null);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setErr('Không tải được tổng hợp.');
          setRows([]);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [year, month, templateCode, refreshKey]);

  const statusOptions = useMemo(() => {
    return ne.nursingEvalFilterOptionsPresent(rows.map((r) => r.status));
  }, [rows]);

  const departmentOptions = useMemo(
    () =>
      [...new Set(rows.map((r) => (r.departmentName || '').trim()).filter(Boolean))].sort((a, b) =>
        a.localeCompare(b, 'vi'),
      ),
    [rows],
  );

  const filtered = useMemo(
    () =>
      applyRequestListFilters(rows, filters, {
        searchText: (r) =>
          [r.fullName, r.employeeCode, r.departmentName, r.overallGrade].map((x) => String(x || '')).join(' '),
        dateValue: () => null,
        statusValue: (r) => ne.nursingEvalStatusFilterGroup(r.status),
        departmentValue: (r) => r.departmentName || '',
      }),
    [rows, filters],
  );

  async function exportExcel() {
    setExporting(true);
    setExportErr(null);
    try {
      await ne.downloadNursingMonthlyRankingExcel(year, month, templateCode);
    } catch {
      // Hiện ở phần tiêu đề — vẫn thấy khi thẻ đang thu gọn.
      setExportErr('Không xuất được file Excel — thử lại sau.');
    } finally {
      setExporting(false);
    }
  }

  const stats = useMemo(() => {
    const approved = filtered.filter((r) => r.status === 'APPROVED').length;
    const pending = filtered.filter((r) =>
      String(r.status || '').startsWith('PENDING_'),
    ).length;
    const rejected = filtered.filter((r) => String(r.status || '').includes('REJECTED')).length;
    const avg =
      filtered.length === 0
        ? null
        : filtered.reduce((s, r) => s + Number(r.totalScore ?? r.total100 ?? 0), 0) / filtered.length;
    return { approved, pending, rejected, avg };
  }, [filtered]);

  return (
    <>
    <CollapsibleSection
      storageKey="hrm.evaluations.section.monthlySummary"
      defaultOpen={false}
      accent={theme.palette.primary.main}
      icon={<InsightsOutlinedIcon fontSize="small" />}
      title="Tổng hợp xếp loại theo tháng"
      subtitle={`Theo dõi điểm và trạng thái phiếu khối ĐD–KTV–HS–Thư ký · Tháng ${month}/${year}`}
      summary={
        <>
          <Chip size="small" label={loading ? 'Đang tải…' : `${filtered.length} phiếu`} sx={{ fontWeight: 800, height: 24 }} />
          <Chip size="small" color="success" variant="outlined" label={`${stats.approved} đã duyệt`} sx={{ fontWeight: 650, height: 24 }} />
          <Chip size="small" color="warning" variant="outlined" label={`${stats.pending} chờ duyệt`} sx={{ fontWeight: 650, height: 24 }} />
          <Chip size="small" color="error" variant="outlined" label={`${stats.rejected} từ chối`} sx={{ fontWeight: 650, height: 24 }} />
          {stats.avg != null && (
            <Chip
              size="small"
              color="primary"
              variant="outlined"
              label={`TB điểm: ${stats.avg.toFixed(1)}`}
              sx={{ fontWeight: 650, height: 24 }}
            />
          )}
          {exportErr && (
            <Chip
              size="small"
              color="error"
              label={exportErr}
              onDelete={() => setExportErr(null)}
              sx={{ fontWeight: 700, height: 24 }}
            />
          )}
        </>
      }
      actions={
        <Stack direction="row" spacing={1} alignItems="center">
          <MonthPickerField
            size="small"
            label="Kỳ đánh giá"
            value={period}
            onChange={setPeriod}
            sx={{ width: { xs: 170, sm: 200 } }}
          />
          {canExportExcel && (
          <Button
            variant="contained"
            onClick={() => void exportExcel()}
            disabled={exporting}
            startIcon={exporting ? <CircularProgress size={16} color="inherit" /> : <FileDownloadOutlinedIcon />}
            title={`Xuất Excel thống kê xếp loại tháng ${month}/${year} — phiếu Trưởng phòng ĐD đã duyệt`}
            sx={{ textTransform: 'none', fontWeight: 800, borderRadius: 2, whiteSpace: 'nowrap', boxShadow: 'none' }}
          >
            {exporting ? 'Đang xuất…' : 'Xuất Excel'}
          </Button>
          )}
        </Stack>
      }
    >
      <Box sx={{ mb: 1.5 }}>
        <RequestListFilters
          value={filters}
          onChange={setFilters}
          title="Bộ lọc tổng hợp"
          hideDateFilters
          resultCount={filtered.length}
          resultCountLabel="phiếu"
          searchPlaceholder="Tìm tên, mã NV, xếp loại…"
          statusOptions={statusOptions}
          departmentOptions={departmentOptions}
        />
      </Box>

      {err && (
        <Alert severity="error" sx={{ mb: 1.5, borderRadius: 2 }}>
          {err}
        </Alert>
      )}

      <TableContainer
        sx={{
          borderRadius: 2.5,
          border: `1px solid ${theme.palette.divider}`,
          maxHeight: 'min(620px, 70vh)',
          overflow: 'auto',
        }}
      >
        <Table size="small" stickyHeader sx={{ minWidth: 760 }}>
          <TableHead>
            <TableRow
              sx={{
                '& th': {
                  fontWeight: 800,
                  color: theme.palette.text.primary,
                  whiteSpace: 'nowrap',
                  bgcolor: '#EEF6F5',
                },
              }}
            >
              <TableCell>Khoa / phòng</TableCell>
              <TableCell>Họ tên</TableCell>
              <TableCell align="right">Tổng điểm</TableCell>
              <TableCell>Xếp loại</TableCell>
              <TableCell>Trạng thái</TableCell>
              <TableCell align="center">Chi tiết</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {!loading && filtered.length === 0 && (
              <TableRow>
                <TableCell colSpan={6} sx={{ py: 4 }}>
                  <Typography color="text.secondary" variant="body2" textAlign="center">
                    Không có phiếu khớp bộ lọc trong kỳ này.
                  </Typography>
                </TableCell>
              </TableRow>
            )}
            {filtered.map((r) => (
              <TableRow
                key={r.evaluationId}
                hover
                sx={{
                  '&:nth-of-type(even)': { bgcolor: alpha(theme.palette.primary.main, 0.02) },
                  cursor: 'pointer',
                }}
                onClick={() => setDetailId(r.evaluationId)}
              >
                <TableCell>
                  <Typography variant="body2" fontWeight={650}>
                    {r.departmentName || '—'}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Typography variant="body2" fontWeight={700}>
                    {r.fullName}
                  </Typography>
                  {r.employeeCode && (
                    <Typography variant="caption" color="text.secondary">
                      {r.employeeCode}
                    </Typography>
                  )}
                </TableCell>
                <TableCell align="right">
                  <Typography variant="body2" fontWeight={800} color="primary.main">
                    {cellNum(r.totalScore ?? r.total100)}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip
                    size="small"
                    color={gradeChipColor(r.overallGrade)}
                    variant="outlined"
                    label={r.overallGrade || '—'}
                    sx={{ height: 22, fontWeight: 700, borderRadius: '6px' }}
                  />
                </TableCell>
                <TableCell>
                  <Chip
                    size="small"
                    color={ne.nursingEvalStatusColor(r.status)}
                    label={r.status ? ne.NURSING_EVAL_STATUS_LABEL[r.status] || r.status : '—'}
                    sx={{ height: 22, fontWeight: 650, borderRadius: '6px', maxWidth: 220 }}
                  />
                </TableCell>
                <TableCell align="center" onClick={(e) => e.stopPropagation()}>
                  <Button
                    size="small"
                    variant="outlined"
                    startIcon={<VisibilityIcon />}
                    onClick={() => setDetailId(r.evaluationId)}
                    sx={{ textTransform: 'none', fontWeight: 700, borderRadius: 2 }}
                  >
                    Chi tiết
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </CollapsibleSection>

      <NursingEvaluationDetailDialog
        open={detailId != null}
        evaluationId={detailId}
        onClose={() => setDetailId(null)}
        canNursingHeadReview={canNursingHead}
        canHrReview={canHr}
        canDirectorReview={canDirector}
        canCancel={user?.role === 'ADMIN' || isHeadDepartmentRole(user?.role)}
        onChanged={() => {
          if (detailId != null && onRequestEditEvaluation) {
            const r = rows.find((x) => x.evaluationId === detailId);
            if (r) {
              onRequestEditEvaluation({
                employeeId: r.employeeId,
                periodYear: r.periodYear,
                periodMonth: r.periodMonth,
              });
            }
          }
        }}
      />
    </>
  );
}
