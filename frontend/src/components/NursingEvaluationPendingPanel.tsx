import AssignmentTurnedInOutlinedIcon from '@mui/icons-material/AssignmentTurnedInOutlined';
import HistoryIcon from '@mui/icons-material/History';
import PendingActionsIcon from '@mui/icons-material/PendingActions';
import {
  Alert,
  Badge,
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { isHr2Role } from '../utils/roleAccess';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import * as ne from '../services/nursingEvaluationService';
import { formatDateTimeVi } from '../utils/dateFormat';
import { NursingEvaluationDetailDialog } from './NursingEvaluationDetailDialog';
import {
  applyRequestListFilters,
  RequestListFilters,
} from './requests/RequestListFilters';
import { useLazyHistoryList } from './requests/useLazyHistoryList';
import {
  formatRequestSubject,
  RequestListTable,
  type RequestListRow,
} from './requests/RequestListTable';

type Props = {
  refreshKey?: number;
  onChanged?: () => void;
};

function canReviewRow(
  status: string,
  opts: { canNursingHead: boolean; canHr: boolean; canDirector: boolean },
): boolean {
  if (status === 'PENDING_NURSING_HEAD') return opts.canNursingHead;
  if (status === 'PENDING_HR') return opts.canHr;
  if (status === 'PENDING_DIRECTOR') return opts.canDirector;
  return false;
}

export function NursingEvaluationPendingPanel({ refreshKey = 0, onChanged }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [detailId, setDetailId] = useState<number | null>(null);
  const [subTab, setSubTab] = useState(0);
  const [actionBusyId, setActionBusyId] = useState<number | string | null>(null);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [confirm, setConfirm] = useState<{
    rows: ne.NursingEvalRow[];
    approved: boolean;
  } | null>(null);

  const canNursingHead = user?.role === 'ADMIN' || user?.role === 'HEAD_NURSING';
  const canHr = user?.role === 'ADMIN' || isHr2Role(user?.role);
  const canDirector =
    user?.role === 'ADMIN'
    || user?.role === 'DIRECTOR'
    || user?.directorApprovalEnabled === true;
  const canLoad = canNursingHead || canHr || canDirector;
  const reviewOpts = useMemo(
    () => ({ canNursingHead, canHr, canDirector }),
    [canNursingHead, canHr, canDirector],
  );

  const loadPending = useCallback(
    () => ne.fetchNursingPending().catch(() => [] as ne.NursingEvalRow[]),
    [],
  );
  const loadHistory = useCallback(
    (range: { fromDate?: string; toDate?: string }) =>
      ne.fetchNursingEvaluationHistory(range).catch(() => [] as ne.NursingEvalRow[]),
    [],
  );
  const {
    pending,
    history,
    listLoading,
    historyLoaded,
    filters,
    setFilters,
    filterReset,
    clearLabel,
    reload,
  } = useLazyHistoryList({
    historyActive: subTab === 1,
    canLoad,
    loadPending,
    loadHistory,
  });

  useEffect(() => {
    if (refreshKey > 0) reload();
  }, [refreshKey, reload]);

  const tabDefs = useMemo(
    () => [
      { key: 'pending', label: 'Chờ duyệt', count: pending.length, list: pending },
      {
        key: 'history',
        label: historyLoaded ? `Lịch sử duyệt (${history.length})` : 'Lịch sử duyệt',
        count: history.length,
        list: history,
      },
    ],
    [pending, history, historyLoaded],
  );

  const active = tabDefs[subTab] ?? tabDefs[0];
  const sourceRows = active?.list ?? [];
  const isHistory = active?.key === 'history';
  const canActOnTab = active?.key === 'pending';

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

  const byId = useMemo(() => {
    const map = new Map<number, ne.NursingEvalRow>();
    filtered.forEach((r) => map.set(Number(r.id), r));
    return map;
  }, [filtered]);

  const tableRows: RequestListRow[] = useMemo(
    () =>
      filtered.map((r) => {
        const status = String(r.status || '');
        const pendingNow =
          status === 'PENDING_NURSING_HEAD' || status === 'PENDING_HR' || status === 'PENDING_DIRECTOR';
        const reviewable = canActOnTab && canReviewRow(status, reviewOpts);
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
          pending: canActOnTab && pendingNow,
          canApprove: reviewable,
          canReject: reviewable,
        };
      }),
    [filtered, canActOnTab, reviewOpts],
  );

  async function reviewOne(row: ne.NursingEvalRow, approved: boolean) {
    const id = Number(row.id);
    const status = String(row.status || '');
    if (status === 'PENDING_DIRECTOR' && canDirector) {
      await ne.directorReviewNursingEvaluation(id, approved);
      return;
    }
    if (status === 'PENDING_HR' && canHr) {
      await ne.hrReviewNursingEvaluation(id, approved);
      return;
    }
    if (status === 'PENDING_NURSING_HEAD' && canNursingHead) {
      await ne.nursingHeadReviewNursingEvaluation(id, approved);
      return;
    }
    throw new Error('Không xác định được bước duyệt.');
  }

  async function confirmQuickReview() {
    if (!confirm || confirm.rows.length === 0) return;
    const { rows, approved } = confirm;
    if (rows.length > 1) setBulkBusy(true);
    else setActionBusyId(Number(rows[0].id));
    setMsg(null);
    setErr(null);
    try {
      await ensureHasSignature();
      let ok = 0;
      let fail = 0;
      for (const row of rows) {
        try {
          await reviewOne(row, approved);
          ok += 1;
        } catch {
          fail += 1;
        }
      }
      reload();
      onChanged?.();
      setMsg(
        fail === 0
          ? approved
            ? `Đã duyệt ${ok} phiếu đánh giá.`
            : `Đã từ chối ${ok} phiếu đánh giá.`
          : `Hoàn tất ${ok} phiếu, ${fail} phiếu lỗi.`,
      );
      setConfirm(null);
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Thao tác thất bại.'));
    } finally {
      setActionBusyId(null);
      setBulkBusy(false);
    }
  }

  function openConfirm(rows: ne.NursingEvalRow[], approved: boolean) {
    if (rows.length === 0) return;
    setConfirm({ rows, approved });
  }

  if (!canLoad) return null;

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
              Chờ duyệt và lịch sử ký duyệt · Trưởng phòng ĐD → HCNS → Giám đốc · Có thể chọn nhiều phiếu để duyệt
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
                <HistoryIcon fontSize="small" />
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
      {msg && (
        <Alert severity="success" sx={{ mb: 1.5, borderRadius: 2 }} onClose={() => setMsg(null)}>
          {msg}
        </Alert>
      )}

      <Box sx={{ mb: 1.5 }}>
        <RequestListFilters
          value={filters}
          onChange={setFilters}
          title={isHistory ? 'Bộ lọc lịch sử (mặc định tháng này)' : 'Bộ lọc phiếu chờ'}
          hideDateFilters={!isHistory}
          resultCount={filtered.length}
          resultCountLabel="phiếu"
          searchPlaceholder="Tìm tên NV, mã, chức danh…"
          statusOptions={statusOptions}
          departmentOptions={departmentOptions}
          resetFilters={filterReset}
          clearLabel={clearLabel}
        />
      </Box>

      <RequestListTable
        rows={tableRows}
        loading={listLoading}
        emptyTitle={isHistory ? 'Chưa có lịch sử duyệt' : 'Không có phiếu chờ duyệt'}
        emptyHint={
          isHistory
            ? 'Mặc định xem phiếu trong tháng hiện tại. Đổi khoảng ngày để xem thêm.'
            : 'Khi có phiếu gửi đến bước của bạn, danh sách sẽ hiện tại đây. Bấm «Chọn đơn» để duyệt hàng loạt.'
        }
        actionBusyId={actionBusyId}
        bulkBusy={bulkBusy}
        onView={(row) => setDetailId(Number(row.id))}
        onApprove={
          canActOnTab
            ? (row) => {
                const r = byId.get(Number(row.id));
                if (r) openConfirm([r], true);
              }
            : undefined
        }
        onReject={
          canActOnTab
            ? (row) => {
                const r = byId.get(Number(row.id));
                if (r) openConfirm([r], false);
              }
            : undefined
        }
        onBulkApprove={
          canActOnTab
            ? (selectedRows) => {
                const selected = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is ne.NursingEvalRow => Boolean(r));
                if (selected.length) openConfirm(selected, true);
              }
            : undefined
        }
        onBulkReject={
          canActOnTab
            ? (selectedRows) => {
                const selected = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is ne.NursingEvalRow => Boolean(r));
                if (selected.length) openConfirm(selected, false);
              }
            : undefined
        }
      />

      <Dialog
        open={confirm != null}
        onClose={() => !bulkBusy && actionBusyId == null && setConfirm(null)}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle>
          {confirm?.approved
            ? confirm.rows.length > 1
              ? 'Xác nhận duyệt hàng loạt'
              : 'Xác nhận duyệt'
            : confirm && confirm.rows.length > 1
              ? 'Xác nhận từ chối hàng loạt'
              : 'Xác nhận không duyệt'}
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary">
            {confirm && confirm.rows.length > 1 ? (
              <>
                {confirm.approved ? 'Duyệt' : 'Từ chối'} <strong>{confirm.rows.length}</strong> phiếu
                đánh giá đã chọn?
              </>
            ) : (
              <>
                {confirm?.approved ? 'Duyệt' : 'Từ chối'} phiếu của{' '}
                <strong>
                  {String(confirm?.rows[0]?.employeeName || confirm?.rows[0]?.fullName || '—')}
                </strong>
                ?
              </>
            )}
          </Typography>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button
            onClick={() => setConfirm(null)}
            disabled={actionBusyId != null || bulkBusy}
          >
            Hủy
          </Button>
          {confirm && confirm.rows.length === 1 && (
            <Button
              variant="outlined"
              onClick={() => {
                if (confirm) setDetailId(Number(confirm.rows[0].id));
                setConfirm(null);
              }}
              disabled={actionBusyId != null || bulkBusy}
            >
              Xem chi tiết
            </Button>
          )}
          <Button
            color={confirm?.approved ? 'success' : 'error'}
            variant="contained"
            onClick={() => void confirmQuickReview()}
            disabled={actionBusyId != null || bulkBusy}
          >
            {confirm?.approved
              ? confirm.rows.length > 1
                ? `Duyệt ${confirm.rows.length} phiếu`
                : 'Duyệt'
              : confirm && confirm.rows.length > 1
                ? `Từ chối ${confirm.rows.length} phiếu`
                : 'Không duyệt'}
          </Button>
        </DialogActions>
      </Dialog>

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
