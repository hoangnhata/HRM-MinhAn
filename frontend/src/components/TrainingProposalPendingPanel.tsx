import HistoryIcon from '@mui/icons-material/History';
import InboxOutlinedIcon from '@mui/icons-material/InboxOutlined';
import PendingActionsIcon from '@mui/icons-material/PendingActions';
import {
  Alert,
  Badge,
  Box,
  Button,
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
import { isHeadDepartmentRole, isHr2Role } from '../utils/roleAccess';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import * as tps from '../services/trainingProposalService';
import { TrainingProposalDetailDialog } from './TrainingProposalDetailDialog';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';
import { RequestListTable, formatRequestSubject, type RequestListRow } from './requests/RequestListTable';

export function TrainingProposalPendingPanel({ onChanged }: { onChanged?: () => void }) {
  const theme = useTheme();
  const { user } = useAuth();
  const isHrOrAdmin = user?.role === 'ADMIN' || isHr2Role(user?.role);
  const isDirectorOrAdmin = user?.role === 'ADMIN' || user?.directorApprovalEnabled === true;
  const isHead = isHeadDepartmentRole(user?.role) || user?.role === 'ADMIN';

  const [pendingHr, setPendingHr] = useState<tps.TrainingProposal[]>([]);
  const [pendingDirector, setPendingDirector] = useState<tps.TrainingProposal[]>([]);
  const [history, setHistory] = useState<tps.TrainingProposal[]>([]);
  const [mine, setMine] = useState<tps.TrainingProposal[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [listLoading, setListLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [detailId, setDetailId] = useState<number | null>(null);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [confirm, setConfirm] = useState<{
    requests: tps.TrainingProposal[];
    approved: boolean;
  } | null>(null);
  const [actionBusyId, setActionBusyId] = useState<number | null>(null);
  const [bulkBusy, setBulkBusy] = useState(false);

  const reload = useCallback(() => {
    setListLoading(true);
    const tasks: Promise<void>[] = [];
    if (isHrOrAdmin || isDirectorOrAdmin || isHead) {
      tasks.push(
        tps
          .fetchPendingHrTrainingProposals()
          .then(setPendingHr)
          .catch(() => setPendingHr([])),
      );
      tasks.push(
        tps
          .fetchPendingDirectorTrainingProposals()
          .then(setPendingDirector)
          .catch(() => setPendingDirector([])),
      );
      tasks.push(
        tps
          .fetchTrainingProposalHistory()
          .then(setHistory)
          .catch(() => setHistory([])),
      );
    }
    if (isHead) {
      tasks.push(
        tps
          .fetchMyTrainingProposals()
          .then(setMine)
          .catch(() => setMine([])),
      );
    }
    Promise.all(tasks)
      .then(() => setErr(null))
      .catch(() => setErr('Không tải được danh sách phiếu đào tạo.'))
      .finally(() => setListLoading(false));
  }, [isHrOrAdmin, isDirectorOrAdmin, isHead]);

  useEffect(() => {
    reload();
  }, [reload]);

  const isAdmin = user?.role === 'ADMIN';
  const isApprover = isHrOrAdmin || isDirectorOrAdmin;
  const isCreatorOnly = isHeadDepartmentRole(user?.role);

  const pendingForMe = useMemo(() => {
    const byId = new Map<number, tps.TrainingProposal>();
    const push = (rows: tps.TrainingProposal[]) => {
      rows.forEach((r) => byId.set(r.id, r));
    };
    if (isHr2Role(user?.role)) {
      push(pendingHr);
    } else if (
      user?.role === 'DIRECTOR'
      || (user?.directorApprovalEnabled === true && user?.role !== 'ADMIN')
    ) {
      push(pendingDirector);
    } else if (isAdmin) {
      push(pendingHr);
      push(pendingDirector);
    } else {
      if (isHrOrAdmin) push(pendingHr);
      if (isDirectorOrAdmin) push(pendingDirector);
    }
    return [...byId.values()].sort((a, b) =>
      String(b.createdAt || '').localeCompare(String(a.createdAt || '')),
    );
  }, [
    user?.role,
    user?.directorApprovalEnabled,
    isAdmin,
    isHrOrAdmin,
    isDirectorOrAdmin,
    pendingHr,
    pendingDirector,
  ]);

  const tabDefs = useMemo(() => {
    const tabs: { key: string; label: string; count?: number; list: tps.TrainingProposal[] }[] = [];
    if (isApprover) {
      tabs.push({
        key: 'pending',
        label: 'Chờ duyệt',
        count: pendingForMe.length,
        list: pendingForMe,
      });
      tabs.push({ key: 'history', label: 'Lịch sử', count: history.length, list: history });
    }
    if (isCreatorOnly) {
      tabs.push({ key: 'mine', label: 'Phiếu tôi lập', count: mine.length, list: mine });
    }
    return tabs;
  }, [isApprover, isCreatorOnly, pendingForMe, history, mine]);

  useEffect(() => {
    if (subTab >= tabDefs.length) setSubTab(0);
  }, [tabDefs.length, subTab]);

  useEffect(() => {
    setFilters(EMPTY_REQUEST_FILTERS);
  }, [subTab]);

  const active = tabDefs[subTab];
  const list = active?.list ?? [];
  const canActOnTab = active?.key === 'pending' || active?.key === 'history';

  const filtered = useMemo(
    () =>
      applyRequestListFilters(list, filters, {
        searchText: (r) =>
          [
            r.employeeName,
            r.employeeCode,
            r.proposingDepartment,
            r.courseName,
            r.location,
            r.status,
          ].join(' '),
        dateValue: (r) => r.createdAt,
        statusValue: (r) => r.status,
        departmentValue: (r) => r.proposingDepartment,
      }),
    [list, filters],
  );

  const statusOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const r of list) {
      if (!map.has(r.status)) {
        map.set(r.status, tps.TRAINING_STATUS_LABEL[r.status] || r.status);
      }
    }
    return [...map.entries()].map(([value, label]) => ({ value, label }));
  }, [list]);

  const rows: RequestListRow[] = filtered.map((r) => {
    const reviewable =
      canActOnTab &&
      r.status !== 'COMPLETED' &&
      r.status !== 'CANCELLED' &&
      ((isDirectorOrAdmin && (r.status === 'PENDING_DIRECTOR' || Boolean(r.directorReviewedAt))) ||
        (isHrOrAdmin && (r.status === 'PENDING_HR' || Boolean(r.hrReviewedAt))));
    return {
      id: r.id,
      typeLabel: 'Đào tạo',
      subject: formatRequestSubject(r.employeeName, r.positionTitle),
      department: r.proposingDepartment,
      summary: `${r.courseName} · ${r.location || '—'} · ${r.plannedPeriod || '—'}`,
      meta: r.employeeCode || undefined,
      statusLabel: tps.TRAINING_STATUS_LABEL[r.status] || r.status,
      statusColor: tps.trainingStatusColor(r.status),
      dateLabel: r.plannedPeriod || tps.formatTrainingDate(r.createdAt),
      submittedAtLabel: tps.formatTrainingDate(r.createdAt),
      pending: r.status === 'PENDING_HR' || r.status === 'PENDING_DIRECTOR',
      canApprove: reviewable,
      canReject: reviewable,
    };
  });

  const byId = useMemo(() => new Map(list.map((r) => [r.id, r])), [list]);

  async function reviewOne(request: tps.TrainingProposal, approved: boolean) {
    const asHr =
      isHrOrAdmin &&
      (request.status === 'PENDING_HR' || Boolean(request.hrReviewedAt)) &&
      !(isDirectorOrAdmin && request.status === 'PENDING_DIRECTOR');
    const asDirector =
      isDirectorOrAdmin &&
      (request.status === 'PENDING_DIRECTOR' || Boolean(request.directorReviewedAt));

    if (asDirector && !asHr) {
      await tps.directorReviewTrainingProposal(request.id, approved, '');
      return;
    }
    if (asHr || (isHrOrAdmin && request.status === 'PENDING_HR')) {
      if (approved) {
        const support = request.monthlySupport?.trim();
        const commitment = request.postCourseCommitment?.trim();
        if (!support || !commitment) {
          throw new Error('NEED_HR_FIELDS');
        }
        await tps.hrReviewTrainingProposal(request.id, true, '', support, commitment);
      } else {
        await tps.hrReviewTrainingProposal(request.id, false, '');
      }
      return;
    }
    if (asDirector) {
      await tps.directorReviewTrainingProposal(request.id, approved, '');
      return;
    }
    throw new Error('Không xác định được bước duyệt.');
  }

  async function confirmQuickReview() {
    if (!confirm || confirm.requests.length === 0) return;
    const { requests, approved } = confirm;
    if (requests.length === 1 && approved) {
      const only = requests[0];
      const needsHrFields =
        isHrOrAdmin &&
        (only.status === 'PENDING_HR' || Boolean(only.hrReviewedAt)) &&
        !(isDirectorOrAdmin && only.status === 'PENDING_DIRECTOR') &&
        (!only.monthlySupport?.trim() || !only.postCourseCommitment?.trim());
      if (needsHrFields) {
        setDetailId(only.id);
        setConfirm(null);
        setMsg('Mở chi tiết để nhập hỗ trợ tháng và cam kết trước khi duyệt HCNS.');
        return;
      }
    }
    if (requests.length > 1) setBulkBusy(true);
    else setActionBusyId(requests[0].id);
    setMsg(null);
    setErr(null);
    try {
      await ensureHasSignature();
      let ok = 0;
      let fail = 0;
      let needDetail = 0;
      for (const request of requests) {
        try {
          await reviewOne(request, approved);
          ok += 1;
        } catch (e) {
          if (e instanceof Error && e.message === 'NEED_HR_FIELDS') needDetail += 1;
          else fail += 1;
        }
      }
      reload();
      onChanged?.();
      if (needDetail > 0 && ok === 0 && fail === 0) {
        setMsg(
          `${needDetail} phiếu cần mở chi tiết để nhập hỗ trợ tháng và cam kết trước khi duyệt HCNS.`,
        );
      } else {
        setMsg(
          fail === 0 && needDetail === 0
            ? approved
              ? `Đã duyệt ${ok} phiếu đào tạo.`
              : `Đã từ chối ${ok} phiếu đào tạo.`
            : `Hoàn tất ${ok} phiếu${needDetail ? `, ${needDetail} cần nhập hỗ trợ/cam kết` : ''}${
                fail ? `, ${fail} lỗi` : ''
              }.`,
        );
      }
      setConfirm(null);
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Thao tác thất bại.'));
    } finally {
      setActionBusyId(null);
      setBulkBusy(false);
    }
  }

  if (tabDefs.length === 0) return null;

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Phiếu đề xuất cử CBNV đào tạo / bồi dưỡng: Trưởng khoa hoặc Điều dưỡng trưởng lập → HCNS duyệt →
        Giám đốc duyệt.
      </Typography>

      {err && (
        <Alert severity="error" onClose={() => setErr(null)}>
          {err}
        </Alert>
      )}
      {msg && (
        <Alert severity="info" sx={{ borderRadius: 2 }} onClose={() => setMsg(null)}>
          {msg}
        </Alert>
      )}

      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={1.5}
        alignItems={{ xs: 'stretch', sm: 'center' }}
        justifyContent="space-between"
      >
        <Box
          sx={{
            display: 'inline-flex',
            p: 0.5,
            borderRadius: 2.5,
            bgcolor: alpha(theme.palette.grey[500], 0.06),
            border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
            width: 'fit-content',
            maxWidth: '100%',
            overflowX: 'auto',
          }}
        >
          <Tabs
            value={Math.min(subTab, Math.max(tabDefs.length - 1, 0))}
            onChange={(_, v) => setSubTab(v)}
            sx={{
              minHeight: 40,
              '& .MuiTabs-indicator': { display: 'none' },
              '& .MuiTab-root': {
                minHeight: 40,
                textTransform: 'none',
                fontWeight: 600,
                borderRadius: 2,
                px: 1.75,
                mr: 0.5,
                '&.Mui-selected': {
                  bgcolor: theme.palette.primary.main,
                  color: theme.palette.primary.contrastText,
                },
              },
            }}
          >
            {tabDefs.map((t) => (
              <Tab
                key={t.key}
                icon={
                  t.key === 'history' ? (
                    <HistoryIcon fontSize="small" />
                  ) : t.key === 'mine' ? (
                    <InboxOutlinedIcon fontSize="small" />
                  ) : (
                    <Badge badgeContent={t.count} color="warning" max={99}>
                      <PendingActionsIcon fontSize="small" />
                    </Badge>
                  )
                }
                iconPosition="start"
                label={t.label}
              />
            ))}
          </Tabs>
        </Box>
      </Stack>

      <RequestListTable
        rows={rows}
        loading={listLoading}
        emptyTitle="Không có phiếu trong mục này"
        emptyHint="Khi có phiếu đề xuất đào tạo, chúng sẽ xuất hiện tại đây."
        actionBusyId={actionBusyId}
        bulkBusy={bulkBusy}
        toolbar={
          <RequestListFilters
            value={filters}
            onChange={setFilters}
            statusOptions={statusOptions}
            resultCount={filtered.length}
          />
        }
        onView={(row) => setDetailId(Number(row.id))}
        onApprove={
          canActOnTab
            ? (row) => {
                const r = byId.get(Number(row.id));
                if (r) setConfirm({ requests: [r], approved: true });
              }
            : undefined
        }
        onReject={
          canActOnTab
            ? (row) => {
                const r = byId.get(Number(row.id));
                if (r) setConfirm({ requests: [r], approved: false });
              }
            : undefined
        }
        onBulkApprove={
          canActOnTab
            ? (selectedRows) => {
                const selected = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is tps.TrainingProposal => Boolean(r));
                if (selected.length) setConfirm({ requests: selected, approved: true });
              }
            : undefined
        }
        onBulkReject={
          canActOnTab
            ? (selectedRows) => {
                const selected = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is tps.TrainingProposal => Boolean(r));
                if (selected.length) setConfirm({ requests: selected, approved: false });
              }
            : undefined
        }
      />

      <Dialog open={confirm != null} onClose={() => !bulkBusy && setConfirm(null)} maxWidth="xs" fullWidth>
        <DialogTitle>
          {confirm?.approved
            ? confirm.requests.length > 1
              ? 'Xác nhận duyệt hàng loạt'
              : 'Xác nhận duyệt'
            : confirm && confirm.requests.length > 1
              ? 'Xác nhận từ chối hàng loạt'
              : 'Xác nhận không duyệt'}
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary">
            {confirm && confirm.requests.length > 1 ? (
              <>
                {confirm.approved ? 'Duyệt' : 'Từ chối'} <strong>{confirm.requests.length}</strong> phiếu
                đào tạo đã chọn?
                {confirm.approved
                  ? ' Phiếu chờ HCNS chưa có hỗ trợ/cam kết sẽ cần mở chi tiết.'
                  : ''}
              </>
            ) : (
              <>
                {confirm?.approved ? 'Duyệt' : 'Từ chối'} phiếu đào tạo của{' '}
                <strong>{confirm?.requests[0]?.employeeName}</strong>?
              </>
            )}
          </Typography>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setConfirm(null)} disabled={actionBusyId != null || bulkBusy}>
            Hủy
          </Button>
          {confirm && confirm.requests.length === 1 && (
            <Button
              variant="outlined"
              onClick={() => {
                if (confirm) setDetailId(confirm.requests[0].id);
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
            onClick={confirmQuickReview}
            disabled={actionBusyId != null || bulkBusy}
          >
            {confirm?.approved
              ? confirm.requests.length > 1
                ? `Duyệt ${confirm.requests.length} đơn`
                : 'Duyệt'
              : confirm && confirm.requests.length > 1
                ? `Từ chối ${confirm.requests.length} đơn`
                : 'Không duyệt'}
          </Button>
        </DialogActions>
      </Dialog>

      <TrainingProposalDetailDialog
        open={detailId != null}
        proposalId={detailId}
        onClose={() => setDetailId(null)}
        canHrReview={isHrOrAdmin}
        canDirectorReview={isDirectorOrAdmin}
        canComplete={isHrOrAdmin || isHead}
        canCancel={user?.role === 'ADMIN' || isHeadDepartmentRole(user?.role)}
        onChanged={() => {
          reload();
          onChanged?.();
        }}
      />
    </Stack>
  );
}
