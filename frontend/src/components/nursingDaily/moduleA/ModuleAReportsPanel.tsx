import AssessmentOutlinedIcon from '@mui/icons-material/AssessmentOutlined';
import DashboardOutlinedIcon from '@mui/icons-material/DashboardOutlined';
import FilterAltOutlinedIcon from '@mui/icons-material/FilterAltOutlined';
import HealingOutlinedIcon from '@mui/icons-material/HealingOutlined';
import MedicationOutlinedIcon from '@mui/icons-material/MedicationOutlined';
import PersonSearchOutlinedIcon from '@mui/icons-material/PersonSearchOutlined';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import WarningAmberOutlinedIcon from '@mui/icons-material/WarningAmberOutlined';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  LinearProgress,
  Paper,
  Stack,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState, type ReactElement } from 'react';
import { useAuth } from '../../../context/AuthContext';
import { extractApiErrorMessage } from '../../../services/approvalSignatureService';
import * as svc from '../../../services/nursingActivityReportService';
import type { ActivityReportQuery, CompareMetric, MetricKind } from '../../../services/nursingActivityReportService';
import { ModuleADepartmentDetailDialog } from './ModuleADepartmentDetailDialog';
import { ModuleAFilterBar } from './ModuleAFilterBar';
import { METRIC_CONFIGS, ModuleAMetricPanel } from './ModuleAMetricPanel';
import { ModuleAOverviewPanel } from './ModuleAOverviewPanel';
import { ModuleATabBar } from './ModuleATabBar';
import { ReportExportButtons } from './ReportExportButtons';
import { MODULE_A_ACCENT, panelHeaderBandSx, panelPaperSx } from './moduleAUiStyles';

const TABS: { id: MetricKind; label: string; shortLabel?: string; icon: ReactElement }[] = [
  { id: 'overview', label: 'Tổng quan', shortLabel: 'Tổng quan', icon: <DashboardOutlinedIcon /> },
  { id: 'falls', label: 'Té ngã', shortLabel: 'Té ngã', icon: <WarningAmberOutlinedIcon /> },
  { id: 'pressure-ulcers', label: 'Loét tì đè', shortLabel: 'Loét', icon: <HealingOutlinedIcon /> },
  { id: 'nurse-bed', label: 'ĐD/NB', shortLabel: 'ĐD/NB', icon: <GroupsOutlinedIcon /> },
  { id: 'id-mixups', label: 'Nhầm NB', shortLabel: 'Nhầm NB', icon: <PersonSearchOutlinedIcon /> },
  { id: 'medication-errors', label: 'Sai sót thuốc', shortLabel: 'Thuốc', icon: <MedicationOutlinedIcon /> },
];

function moduleAErrorMessage(e: unknown): string {
  const status = (e as { response?: { status?: number } })?.response?.status;
  if (status === 403) return 'Bạn không có quyền xem báo cáo hoạt động điều dưỡng.';
  if (status === 404) return 'API báo cáo chưa sẵn sàng — hãy khởi động lại backend.';
  return extractApiErrorMessage(e, 'Không tải được báo cáo hoạt động điều dưỡng.');
}

function formatPeriodLabel(q: ActivityReportQuery, deptName?: string) {
  const pt = q.periodType ?? 'MONTH';
  let period = '';
  if (pt === 'MONTH' && q.yearMonth) {
    const [y, m] = q.yearMonth.split('-');
    period = `Tháng ${Number(m)}/${y}`;
  } else if (pt === 'QUARTER') {
    period = `Quý ${q.quarter ?? 1}/${q.year ?? svc.currentYear()}`;
  } else if (pt === 'HALF_YEAR') {
    period = `${q.half === 2 ? '6 tháng cuối' : '6 tháng đầu'} ${q.year ?? svc.currentYear()}`;
  } else if (pt === 'YEAR') {
    period = `Năm ${q.year ?? svc.currentYear()}`;
  } else if (pt === 'DAY' && q.from) {
    period = `Ngày ${q.from.split('-').reverse().join('/')}`;
  } else if (pt === 'CUSTOM' && q.from && q.to) {
    period = `${q.from.split('-').reverse().join('/')} – ${q.to.split('-').reverse().join('/')}`;
  } else {
    period = 'Kỳ hiện tại';
  }
  return `${period}${deptName ? ` · ${deptName}` : ' · Toàn viện'}`;
}

export function ModuleAReportsPanel() {
  const { user } = useAuth();
  const canPickDept = user?.role === 'ADMIN' || user?.role === 'HEAD_NURSING';

  const [tab, setTab] = useState<MetricKind>('overview');
  const [query, setQuery] = useState<ActivityReportQuery>({
    periodType: 'MONTH',
    yearMonth: svc.currentYearMonth(),
  });
  const [compareMetric, setCompareMetric] = useState<CompareMetric>('FALL_RATE');
  const [sortBy, setSortBy] = useState<'RATE' | 'FREQUENCY'>('RATE');
  const [sortDir, setSortDir] = useState<'ASC' | 'DESC'>('DESC');
  const [deptSearch, setDeptSearch] = useState('');

  const [departments, setDepartments] = useState<svc.FilterDepartment[]>([]);
  const [report, setReport] = useState<svc.ActivityReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState<'excel' | 'pdf' | null>(null);

  const [detailDeptId, setDetailDeptId] = useState<number | null>(null);
  const [detail, setDetail] = useState<svc.DepartmentDetailReport | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const deptLabel = useMemo(() => {
    if (!query.departmentId) return undefined;
    return departments.find((d) => d.id === query.departmentId)?.name;
  }, [query.departmentId, departments]);

  const periodChip = useMemo(() => formatPeriodLabel(query, deptLabel), [query, deptLabel]);

  const fullQuery = useMemo((): ActivityReportQuery => ({
    ...query,
    compareMetric: tab === 'overview' ? compareMetric : undefined,
    sortBy: tab === 'falls' || tab === 'pressure-ulcers' ? sortBy : undefined,
    sortDir,
  }), [query, compareMetric, sortBy, sortDir, tab]);

  useEffect(() => {
    svc.fetchFilterDepartments().then(setDepartments).catch(() => {});
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setReport(await svc.fetchReportByKind(tab, fullQuery));
    } catch (e) {
      setError(moduleAErrorMessage(e));
      setReport(null);
    } finally {
      setLoading(false);
    }
  }, [tab, fullQuery]);

  useEffect(() => { void load(); }, [load]);

  async function openDepartmentDetail(id: number) {
    setDetailDeptId(id);
    setDetailLoading(true);
    setDetail(null);
    try {
      setDetail(await svc.fetchDepartmentDetail(id, query));
    } catch {
      setDetail(null);
    } finally {
      setDetailLoading(false);
    }
  }

  async function exportFile(kind: 'excel' | 'pdf') {
    setExporting(kind);
    try {
      if (kind === 'excel') await svc.downloadExcel(tab, fullQuery);
      else await svc.downloadPdf(tab, fullQuery);
    } catch {
      setError('Xuất báo cáo thất bại.');
    } finally {
      setExporting(null);
    }
  }

  const metricConfig = tab !== 'overview' ? METRIC_CONFIGS[tab] : null;
  const activeTabMeta = TABS.find((t) => t.id === tab);

  return (
    <Paper elevation={0} sx={panelPaperSx()}>
      <Box sx={panelHeaderBandSx()}>
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          justifyContent="space-between"
          alignItems={{ sm: 'center' }}
          spacing={1.25}
        >
          <Stack direction="row" spacing={1.25} alignItems="flex-start">
            <Box
              sx={{
                width: 42,
                height: 42,
                borderRadius: 2.25,
                display: 'grid',
                placeItems: 'center',
                bgcolor: alpha(MODULE_A_ACCENT, 0.12),
                color: MODULE_A_ACCENT,
                flexShrink: 0,
                border: `1px solid ${alpha(MODULE_A_ACCENT, 0.18)}`,
              }}
            >
              <AssessmentOutlinedIcon />
            </Box>
            <Box>
              <Typography variant="subtitle1" fontWeight={850} sx={{ letterSpacing: '-0.02em', lineHeight: 1.25 }}>
                Báo cáo hoạt động điều dưỡng
              </Typography>
              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.25 }}>
                Tự động tính từ báo cáo hằng ngày
              </Typography>
            </Box>
          </Stack>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap alignItems="center">
            <Chip
              size="small"
              icon={<FilterAltOutlinedIcon sx={{ fontSize: '15px !important' }} />}
              label={periodChip}
              sx={{
                fontWeight: 750,
                bgcolor: alpha(MODULE_A_ACCENT, 0.1),
                color: MODULE_A_ACCENT,
                border: `1px solid ${alpha(MODULE_A_ACCENT, 0.18)}`,
                '& .MuiChip-icon': { color: MODULE_A_ACCENT },
              }}
            />
            {tab === 'overview' && (
              <ReportExportButtons onExport={exportFile} exporting={exporting} />
            )}
          </Stack>
        </Stack>
      </Box>

      <Box sx={{ px: { xs: 1.5, sm: 2 }, pt: 1.75, pb: 2.5 }}>
        <ModuleAFilterBar
          query={query}
          onChange={setQuery}
          departments={departments}
          canPickDept={canPickDept}
          onRefresh={load}
        />

        <ModuleATabBar tabs={TABS} value={tab} onChange={setTab} />

        {loading && (
          <LinearProgress
            sx={{
              mb: 2,
              borderRadius: 99,
              height: 3,
              bgcolor: alpha(MODULE_A_ACCENT, 0.08),
              '& .MuiLinearProgress-bar': { bgcolor: MODULE_A_ACCENT },
            }}
          />
        )}

        {error && (
          <Alert
            severity="error"
            sx={{ mb: 2, borderRadius: 2 }}
            onClose={() => setError(null)}
            action={
              <Button color="inherit" size="small" onClick={() => void load()} sx={{ fontWeight: 700 }}>
                Thử lại
              </Button>
            }
          >
            {error}
          </Alert>
        )}

        {loading && !report && (
          <Box sx={{ py: 8, display: 'grid', placeItems: 'center' }}>
            <CircularProgress sx={{ color: MODULE_A_ACCENT }} />
          </Box>
        )}

        {report && tab === 'overview' && (
          <ModuleAOverviewPanel
            report={report}
            compareMetric={compareMetric}
            onCompareMetricChange={setCompareMetric}
            onSelectDepartment={openDepartmentDetail}
            deptSearch={deptSearch}
            onDeptSearchChange={setDeptSearch}
          />
        )}

        {metricConfig && report && (
          <ModuleAMetricPanel
            config={metricConfig}
            report={report}
            loading={loading}
            sortBy={sortBy}
            sortDir={sortDir}
            onSortByChange={setSortBy}
            onSortDirChange={setSortDir}
            onExport={exportFile}
            exporting={exporting}
            onSelectDepartment={openDepartmentDetail}
          />
        )}

        {!loading && !report && !error && (
          <Box
            sx={{
              py: 6,
              textAlign: 'center',
              color: 'text.secondary',
              borderRadius: 2.5,
              border: `1px dashed ${alpha(MODULE_A_ACCENT, 0.25)}`,
              bgcolor: alpha('#f8fafc', 0.6),
            }}
          >
            <Typography variant="body2" fontWeight={600}>
              Chưa có dữ liệu cho {activeTabMeta?.label ?? 'báo cáo'} trong kỳ đã chọn
            </Typography>
          </Box>
        )}
      </Box>

      <ModuleADepartmentDetailDialog
        open={detailDeptId != null}
        detail={detail}
        loading={detailLoading}
        onClose={() => { setDetailDeptId(null); setDetail(null); }}
      />
    </Paper>
  );
}
