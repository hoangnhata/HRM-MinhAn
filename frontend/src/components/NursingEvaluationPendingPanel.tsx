import AssignmentTurnedInOutlinedIcon from '@mui/icons-material/AssignmentTurnedInOutlined';
import HistoryIcon from '@mui/icons-material/History';
import PendingActionsIcon from '@mui/icons-material/PendingActions';
import {
  Alert,
  Badge,
  Box,
  Chip,
  Stack,
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { isHr2Role } from '../utils/roleAccess';
import * as ne from '../services/nursingEvaluationService';
import { formatDateTimeVi } from '../utils/dateFormat';
import { NursingEvaluationDetailDialog } from './NursingEvaluationDetailDialog';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';
import {
  formatRequestSubject,
  RequestListTable,
  type RequestListRow,
} from './requests/RequestListTable';

type Props = {
  refreshKey?: number;
  onChanged?: () => void;
};

export function NursingEvaluationPendingPanel({ refreshKey = 0, onChanged }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const [pending, setPending] = useState<ne.NursingEvalRow[]>([]);
  const [history, setHistory] = useState<ne.NursingEvalRow[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [detailId, setDetailId] = useState<number | null>(null);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [subTab, setSubTab] = useState(0);

  const canNursingHead = user?.role === 'ADMIN' || user?.role === 'HEAD_NURSING';
  const canHr = user?.role === 'ADMIN' || isHr2Role(user?.role);
  const canDirector =
    user?.role === 'ADMIN'
    || user?.role === 'DIRECTOR'
    || user?.directorApprovalEnabled === true;

  const reload = useCallback(() => {
    setLoading(true);
    Promise.all([
      ne.fetchNursingPending().catch(() => [] as ne.NursingEvalRow[]),
      ne.fetchNursingEvaluationHistory().catch(() => [] as ne.NursingEvalRow[]),
    ])
      .then(([p, h]) => {
        setPending(p);
        setHistory(h);
        setErr(null);
      })
      .catch(() => {
        setErr('Không tải được danh sách phiếu đánh giá.');
        setPending([]);
        setHistory([]);
      })
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    reload();
  }, [reload, refreshKey]);

  useEffect(() => {
    setFilters(EMPTY_REQUEST_FILTERS);
  }, [subTab]);

  const tabDefs = useMemo(
    () => [
      { key: 'pending', label: 'Chờ duyệt', count: pending.length, list: pending },
      { key: 'history', label: 'Lịch sử duyệt', count: history.length, list: history },
    ],
    [pending, history],
  );

  const active = tabDefs[subTab] ?? tabDefs[0];
  const sourceRows = active?.list ?? [];

  const statusOptions = useMemo(() => {
    return ne.nursingEvalFilterOptionsPresent(sourceRows.map((r) => String(r.status || '')));
  }, [sourceRows]);

  const departmentOptions = useMemo(
    () =>
      [...new Set(sourceRows.map((r) => String(r.departmentName || '').trim()).filter(Boolean))].sort(
        (a, b) => a.localeCompare(b, 'vi'),
      ),
    [sourceRows],
  );

  const filtered = useMemo(
    () =>
      applyRequestListFilters(sourceRows, filters, {
        searchText: (r) =>
          [r.employeeName, r.fullName, r.employeeCode, r.positionTitle, r.departmentName]
            .map((x) => String(x || ''))
            .join(' '),
        dateValue: (r) =>
          String(
            r.directorReviewedAt
              || r.hrReviewedAt
              || r.headReviewedAt
              || r.evaluatorSignedAt
              || r.updatedAt
              || r.createdAt
              || '',
          ),
        statusValue: (r) => ne.nursingEvalStatusFilterGroup(String(r.status || '')),
        departmentValue: (r) => String(r.departmentName || ''),
      }),
    [sourceRows, filters],
  );

  const tableRows: RequestListRow[] = useMemo(
    () =>
      filtered.map((r) => {
        const status = String(r.status || '');
        const isPendingTab = active?.key === 'pending';
        const pendingNow =
          status === 'PENDING_NURSING_HEAD' || status === 'PENDING_HR' || status === 'PENDING_DIRECTOR';
        return {
          id: Number(r.id),
          typeLabel: 'Đánh giá ĐD',
          subject: formatRequestSubject(
            String(r.employeeName || r.fullName || ''),
            r.positionTitle != null ? String(r.positionTitle) : null,
          ),
          department: r.departmentName != null ? String(r.departmentName) : null,
          summary:
            r.totalScore != null
              ? `${r.totalScore} điểm${r.overallGrade ? ` · ${r.overallGrade}` : ''}`
              : 'Chưa có điểm',
          meta: `Kỳ ${String(r.periodMonth).padStart(2, '0')}/${r.periodYear}`,
          statusLabel: ne.NURSING_EVAL_STATUS_LABEL[status] || status || '—',
          statusColor: ne.nursingEvalStatusColor(status),
          dateLabel: `${String(r.periodMonth).padStart(2, '0')}/${r.periodYear}`,
          submittedAtLabel: formatDateTimeVi(
            String(
              r.evaluatorSignedAt
                || r.createdAt
                || r.updatedAt
                || '',
            ),
          ),
          pending: isPendingTab && pendingNow,
        };
      }),
    [filtered, active?.key],
  );

  if (!canNursingHead && !canHr && !canDirector) return null;

  return (
    <Box
      sx={{
        mb: 2.5,
        p: { xs: 2, sm: 2.5 },
        borderRadius: 3,
        border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
        bgcolor: alpha(theme.palette.background.paper, 0.98),
        boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
      }}
    >
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={1.5}
        alignItems={{ sm: 'flex-start' }}
        justifyContent="space-between"
        sx={{ mb: 1.5 }}
      >
        <Stack direction="row" spacing={1.25} alignItems="center">
          <Box
            sx={{
              width: 40,
              height: 40,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(theme.palette.warning.main, 0.12),
              color: theme.palette.warning.dark,
            }}
          >
            <AssignmentTurnedInOutlinedIcon fontSize="small" />
          </Box>
          <Box>
            <Typography variant="subtitle1" fontWeight={800} letterSpacing="-0.01em">
              Duyệt phiếu đánh giá
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Chờ duyệt và lịch sử ký duyệt · Trưởng phòng ĐD → HCNS → Giám đốc
            </Typography>
          </Box>
        </Stack>
        <Chip
          size="small"
          color="warning"
          variant="outlined"
          label={`${pending.length} chờ duyệt`}
          sx={{ fontWeight: 700, alignSelf: { xs: 'flex-start', sm: 'center' } }}
        />
      </Stack>

      <Tabs
        value={subTab}
        onChange={(_, v: number) => setSubTab(v)}
        sx={{
          mb: 1.75,
          minHeight: 40,
          '& .MuiTab-root': {
            minHeight: 40,
            textTransform: 'none',
            fontWeight: 700,
            borderRadius: 2,
            mr: 0.5,
          },
        }}
      >
        {tabDefs.map((t) => (
          <Tab
            key={t.key}
            icon={
              t.key === 'pending' ? (
                <Badge badgeContent={t.count} color="warning" max={99}>
                  <PendingActionsIcon fontSize="small" />
                </Badge>
              ) : (
                <Badge badgeContent={t.count} color="default" max={99}>
                  <HistoryIcon fontSize="small" />
                </Badge>
              )
            }
            iconPosition="start"
            label={t.label}
          />
        ))}
      </Tabs>

      {err && (
        <Alert severity="error" sx={{ mb: 1.5, borderRadius: 2 }} onClose={() => setErr(null)}>
          {err}
        </Alert>
      )}

      <Box sx={{ mb: 1.5 }}>
        <RequestListFilters
          value={filters}
          onChange={setFilters}
          title={active?.key === 'history' ? 'Bộ lọc lịch sử' : 'Bộ lọc phiếu chờ'}
          hideDateFilters
          resultCount={filtered.length}
          resultCountLabel="phiếu"
          searchPlaceholder="Tìm tên NV, mã, chức danh…"
          statusOptions={statusOptions}
          departmentOptions={departmentOptions}
        />
      </Box>

      <RequestListTable
        rows={tableRows}
        loading={loading}
        emptyTitle={
          active?.key === 'history' ? 'Chưa có lịch sử duyệt' : 'Không có phiếu chờ duyệt'
        }
        emptyHint={
          active?.key === 'history'
            ? 'Các phiếu bạn đã duyệt hoặc từ chối sẽ hiện tại đây.'
            : 'Khi có phiếu gửi đến bước của bạn, danh sách sẽ hiện tại đây.'
        }
        onView={(row) => setDetailId(Number(row.id))}
      />

      <NursingEvaluationDetailDialog
        open={detailId != null}
        evaluationId={detailId}
        onClose={() => setDetailId(null)}
        canNursingHeadReview={canNursingHead}
        canHrReview={canHr}
        canDirectorReview={canDirector}
        canCancel={user?.role === 'ADMIN'}
        onChanged={() => {
          reload();
          onChanged?.();
        }}
      />
    </Box>
  );
}
