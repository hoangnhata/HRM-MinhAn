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
import * as mda from '../services/mainDutyAuthorizationService';
import { MainDutyAuthorizationDetailDialog } from './MainDutyAuthorizationDetailDialog';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';
import { RequestListTable, formatRequestSubject, type RequestListRow } from './requests/RequestListTable';

export function MainDutyAuthorizationPendingPanel({ onChanged }: { onChanged?: () => void }) {
  const theme = useTheme();
  const { user } = useAuth();
  const isHrOrAdmin = user?.role === 'ADMIN' || isHr2Role(user?.role);
  const isDirectorOrAdmin = user?.role === 'ADMIN' || user?.directorApprovalEnabled === true;
  const isHead = isHeadDepartmentRole(user?.role) || user?.role === 'ADMIN';
  const isNursingHead = user?.role === 'HEAD_NURSING' || user?.role === 'ADMIN';

  const [pendingHead, setPendingHead] = useState<mda.MainDutyAuthorization[]>([]);
  const [pendingNursingHead, setPendingNursingHead] = useState<mda.MainDutyAuthorization[]>([]);
  const [pendingHr, setPendingHr] = useState<mda.MainDutyAuthorization[]>([]);
  const [pendingDirector, setPendingDirector] = useState<mda.MainDutyAuthorization[]>([]);
  const [history, setHistory] = useState<mda.MainDutyAuthorization[]>([]);
  const [mine, setMine] = useState<mda.MainDutyAuthorization[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [listLoading, setListLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [detailId, setDetailId] = useState<number | null>(null);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [confirm, setConfirm] = useState<{
    requests: mda.MainDutyAuthorization[];
    approved: boolean;
  } | null>(null);
  const [actionBusyId, setActionBusyId] = useState<number | null>(null);
  const [bulkBusy, setBulkBusy] = useState(false);

  const reload = useCallback(() => {
    setListLoading(true);
    const tasks: Promise<void>[] = [];
    if (isHead) {
      tasks.push(
        mda
          .fetchPendingHeadMainDutyAuthorizations()
          .then(setPendingHead)
          .catch(() => setPendingHead([])),
      );
    }
    if (isNursingHead) {
      tasks.push(
        mda
          .fetchPendingNursingHeadMainDutyAuthorizations()
          .then(setPendingNursingHead)
          .catch(() => setPendingNursingHead([])),
      );
    }
    if (isHrOrAdmin) {
      tasks.push(
        mda
          .fetchPendingHrMainDutyAuthorizations()
          .then(setPendingHr)
          .catch(() => setPendingHr([])),
      );
    }
    if (isDirectorOrAdmin) {
      tasks.push(
        mda
          .fetchPendingDirectorMainDutyAuthorizations()
          .then(setPendingDirector)
          .catch(() => setPendingDirector([])),
      );
    }
    if (isNursingHead || isHrOrAdmin || isDirectorOrAdmin || isHead) {
      tasks.push(
        mda.fetchMainDutyAuthorizationHistory().then(setHistory).catch(() => setHistory([])),
      );
    }
    if (isHeadDepartmentRole(user?.role) || user?.role === 'ADMIN') {
      tasks.push(mda.fetchMyMainDutyAuthorizations().then(setMine).catch(() => setMine([])));
    } else {
      setMine([]);
    }
    Promise.all(tasks)
      .then(() => setErr(null))
      .catch(() => setErr('Không tải được danh sách đơn trực chính.'))
      .finally(() => setListLoading(false));
  }, [isHrOrAdmin, isDirectorOrAdmin, isHead, isNursingHead, user?.role]);

  useEffect(() => {
    reload();
  }, [reload]);

  const isAdmin = user?.role === 'ADMIN';
  const isApprover = isHead || isNursingHead || isDirectorOrAdmin || isHrOrAdmin;
  const isCreator = isHeadDepartmentRole(user?.role);

  const pendingForMe = useMemo(() => {
    const byId = new Map<number, mda.MainDutyAuthorization>();
    const push = (rows: mda.MainDutyAuthorization[]) => {
      rows.forEach((r) => byId.set(r.id, r));
    };
    if (isAdmin) {
      push(pendingHead);
      push(pendingNursingHead);
      push(pendingHr);
      push(pendingDirector);
    } else {
      if (isHead) push(pendingHead);
      if (isNursingHead) push(pendingNursingHead);
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
    isHead,
    isNursingHead,
    isHrOrAdmin,
    isDirectorOrAdmin,
    pendingHead,
    pendingNursingHead,
    pendingHr,
    pendingDirector,
  ]);

  const tabDefs = useMemo(() => {
    const tabs: { key: string; label: string; count?: number; list: mda.MainDutyAuthorization[] }[] =
      [];
    if (isApprover) {
      tabs.push({
        key: 'pending',
        label: 'Chờ duyệt',
        count: pendingForMe.length,
        list: pendingForMe,
      });
      tabs.push({ key: 'history', label: 'Lịch sử', count: history.length, list: history });
    }
    if (isCreator) {
      tabs.push({ key: 'mine', label: 'Đơn tôi lập', count: mine.length, list: mine });
    }
    return tabs;
  }, [isApprover, isCreator, pendingForMe, history, mine]);

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
            r.departmentName,
            r.formTypeLabel,
            r.accompanyingPeriod,
            r.status,
          ].join(' '),
        dateValue: (r) => r.createdAt,
        statusValue: (r) => r.status,
        departmentValue: (r) => r.departmentName,
      }),
    [list, filters],
  );

  const statusOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const r of list) {
      if (!map.has(r.status)) {
        map.set(r.status, mda.MAIN_DUTY_STATUS_LABEL[r.status] || r.status);
      }
    }
    return [...map.entries()].map(([value, label]) => ({ value, label }));
  }, [list]);

  const rows: RequestListRow[] = filtered.map((r) => {
    const reviewable =
      canActOnTab &&
      r.status !== 'CANCELLED' &&
      ((isDirectorOrAdmin && (r.status === 'PENDING_DIRECTOR' || Boolean(r.directorReviewedAt))) ||
        (isNursingHead &&
          (r.status === 'PENDING_NURSING_HEAD' || Boolean(r.nursingHeadReviewedAt))) ||
        (isHead && (r.status === 'PENDING_HEAD' || Boolean(r.headReviewedAt))));
    return {
      id: r.id,
      typeLabel: `Trực chính · ${r.formTypeLabel}`,
      subject: formatRequestSubject(r.employeeName, r.positionTitle),
      department: r.departmentName,
      summary: `Trực kèm: ${
        r.accompanyingPeriod ||
        `${mda.formatMainDutyDate(r.accompanyingFrom)} – ${mda.formatMainDutyDate(r.accompanyingTo)}`
      } · hiệu lực ${mda.formatMainDutyDate(r.effectiveFrom)}`,
      statusLabel: mda.MAIN_DUTY_STATUS_LABEL[r.status] ?? r.status,
      statusColor: mda.mainDutyStatusColor(r.status),
      dateLabel: mda.formatMainDutyDate(r.effectiveFrom),
      submittedAtLabel: mda.formatMainDutyDate(r.createdAt),
      pending:
        r.status === 'PENDING_HEAD' ||
        r.status === 'PENDING_NURSING_HEAD' ||
        r.status === 'PENDING_HR' ||
        r.status === 'PENDING_DIRECTOR',
      canApprove: reviewable,
      canReject: reviewable,
    };
  });

  const byId = useMemo(() => new Map(list.map((r) => [r.id, r])), [list]);

  async function reviewOne(request: mda.MainDutyAuthorization, approved: boolean) {
    const asDirector =
      isDirectorOrAdmin &&
      (request.status === 'PENDING_DIRECTOR' || Boolean(request.directorReviewedAt));
    const asNursingHead =
      isNursingHead &&
      (request.status === 'PENDING_NURSING_HEAD' || Boolean(request.nursingHeadReviewedAt)) &&
      !asDirector;
    const asHead =
      isHead &&
      (request.status === 'PENDING_HEAD' || Boolean(request.headReviewedAt)) &&
      !asDirector &&
      !asNursingHead;

    if (asDirector) {
      await mda.directorReviewMainDutyAuthorization(request.id, approved, '');
      return;
    }
    if (asNursingHead || (isNursingHead && request.status === 'PENDING_NURSING_HEAD')) {
      await mda.nursingHeadReviewMainDutyAuthorization(request.id, approved, '');
      return;
    }
    if (asHead || (isHead && request.status === 'PENDING_HEAD')) {
      await mda.headReviewMainDutyAuthorization(request.id, approved, '');
      return;
    }
    throw new Error('Không xác định được bước duyệt.');
  }

  async function confirmQuickReview() {
    if (!confirm || confirm.requests.length === 0) return;
    const { requests, approved } = confirm;
    if (requests.length > 1) setBulkBusy(true);
    else setActionBusyId(requests[0].id);
    setMsg(null);
    setErr(null);
    try {
      await ensureHasSignature();
      let ok = 0;
      let fail = 0;
      for (const request of requests) {
        try {
          await reviewOne(request, approved);
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
            ? `Đã duyệt ${ok} đơn trực chính.`
            : `Đã từ chối ${ok} đơn trực chính.`
          : `Hoàn tất ${ok} đơn, ${fail} đơn lỗi.`,
      );
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
        Đơn được trực chính khối Điều dưỡng: lập đơn → <strong>Trưởng phòng Điều dưỡng</strong> →{' '}
        <strong>Giám đốc</strong> duyệt. Sau khi duyệt, nhân viên được chọn ca trực 1 / 3 / 5 (ngoài Trực
        kèm).
      </Typography>

      {err && (
        <Alert severity="error" variant="outlined" sx={{ borderRadius: 2 }} onClose={() => setErr(null)}>
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
            variant="scrollable"
            scrollButtons="auto"
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
        emptyTitle="Không có đơn trong mục này"
        emptyHint="Khi có đơn được trực chính, chúng sẽ xuất hiện tại đây."
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
                  .filter((r): r is mda.MainDutyAuthorization => Boolean(r));
                if (selected.length) setConfirm({ requests: selected, approved: true });
              }
            : undefined
        }
        onBulkReject={
          canActOnTab
            ? (selectedRows) => {
                const selected = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is mda.MainDutyAuthorization => Boolean(r));
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
                {confirm.approved ? 'Duyệt' : 'Từ chối'} <strong>{confirm.requests.length}</strong> đơn
                trực chính đã chọn?
              </>
            ) : (
              <>
                {confirm?.approved ? 'Duyệt' : 'Từ chối'} đơn của{' '}
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

      <MainDutyAuthorizationDetailDialog
        open={detailId != null}
        authorizationId={detailId}
        onClose={() => setDetailId(null)}
        canHeadReview={isHead}
        canNursingHeadReview={isNursingHead}
        canDirectorReview={isDirectorOrAdmin}
        canCancel={user?.role === 'ADMIN' || isHeadDepartmentRole(user?.role)}
        onChanged={() => {
          reload();
          onChanged?.();
        }}
      />
    </Stack>
  );
}
