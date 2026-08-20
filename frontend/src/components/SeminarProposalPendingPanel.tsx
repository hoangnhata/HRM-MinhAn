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
import * as sps from '../services/seminarProposalService';
import { SeminarProposalDetailDialog } from './SeminarProposalDetailDialog';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';
import { RequestListTable, formatRequestSubject, type RequestListRow } from './requests/RequestListTable';

export function SeminarProposalPendingPanel({ onChanged }: { onChanged?: () => void }) {
  const theme = useTheme();
  const { user } = useAuth();
  const isHrOrAdmin = user?.role === 'ADMIN' || isHr2Role(user?.role);
  const isDirectorOrAdmin = user?.role === 'ADMIN' || user?.directorApprovalEnabled === true;
  const isHead = isHeadDepartmentRole(user?.role) || user?.role === 'ADMIN';
  const canView = isHrOrAdmin || isDirectorOrAdmin || isHead;

  const [pendingDirector, setPendingDirector] = useState<sps.SeminarProposal[]>([]);
  const [history, setHistory] = useState<sps.SeminarProposal[]>([]);
  const [mine, setMine] = useState<sps.SeminarProposal[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [listLoading, setListLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [detailId, setDetailId] = useState<number | null>(null);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [confirm, setConfirm] = useState<{
    requests: sps.SeminarProposal[];
    approved: boolean;
  } | null>(null);
  const [actionBusyId, setActionBusyId] = useState<number | null>(null);
  const [bulkBusy, setBulkBusy] = useState(false);

  const reload = useCallback(() => {
    setListLoading(true);
    const tasks: Promise<void>[] = [];
    if (canView) {
      tasks.push(
        sps
          .fetchPendingDirectorSeminarProposals()
          .then(setPendingDirector)
          .catch(() => setPendingDirector([])),
      );
      tasks.push(
        sps
          .fetchSeminarProposalHistory()
          .then(setHistory)
          .catch(() => setHistory([])),
      );
    }
    if (isHead) {
      tasks.push(
        sps
          .fetchMySeminarProposals()
          .then(setMine)
          .catch(() => setMine([])),
      );
    }
    Promise.all(tasks)
      .then(() => setErr(null))
      .catch(() => setErr('Không tải được danh sách phiếu hội thảo.'))
      .finally(() => setListLoading(false));
  }, [canView, isHead]);

  useEffect(() => {
    reload();
  }, [reload]);

  const isCreatorOnly = isHeadDepartmentRole(user?.role);

  const tabDefs = useMemo(() => {
    const tabs: { key: string; label: string; count?: number; list: sps.SeminarProposal[] }[] = [];
    if (isDirectorOrAdmin) {
      tabs.push({
        key: 'pending',
        label: 'Chờ duyệt',
        count: pendingDirector.length,
        list: pendingDirector,
      });
    }
    if (isHrOrAdmin || isDirectorOrAdmin) {
      tabs.push({ key: 'history', label: 'Lịch sử', count: history.length, list: history });
    }
    if (isCreatorOnly) {
      tabs.push({ key: 'mine', label: 'Phiếu tôi lập', count: mine.length, list: mine });
    }
    return tabs;
  }, [isHrOrAdmin, isDirectorOrAdmin, isCreatorOnly, pendingDirector, history, mine]);

  useEffect(() => {
    if (subTab >= tabDefs.length) setSubTab(0);
  }, [tabDefs.length, subTab]);

  useEffect(() => {
    setFilters(EMPTY_REQUEST_FILTERS);
  }, [subTab]);

  const active = tabDefs[subTab];
  const list = active?.list ?? [];
  const canActOnTab =
    (active?.key === 'pending' || active?.key === 'history') && isDirectorOrAdmin;

  const filtered = useMemo(
    () =>
      applyRequestListFilters(list, filters, {
        searchText: (r) =>
          [
            r.employeeName,
            r.employeeCode,
            r.proposingDepartment,
            r.seminarName,
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
        map.set(r.status, sps.SEMINAR_STATUS_LABEL[r.status] || r.status);
      }
    }
    return [...map.entries()].map(([value, label]) => ({ value, label }));
  }, [list]);

  const rows: RequestListRow[] = filtered.map((r) => {
    const payLabel =
      r.withPay != null ? (r.withPay ? ' · Có công' : ' · Không công') : '';
    const reviewable =
      canActOnTab &&
      (r.status === 'PENDING_DIRECTOR' ||
        r.status === 'DIRECTOR_REJECTED' ||
        r.status === 'APPROVED');
    return {
      id: r.id,
      typeLabel: 'Hội thảo',
      subject: formatRequestSubject(r.employeeName, r.positionTitle),
      department: r.proposingDepartment,
      summary: `${r.seminarName} · ${r.location || '—'} · ${
        r.plannedPeriod || sps.formatSeminarDate(r.startDate)
      }`,
      meta: r.employeeCode || undefined,
      statusLabel: `${sps.SEMINAR_STATUS_LABEL[r.status] || r.status}${payLabel}`,
      statusColor: sps.seminarStatusColor(r.status),
      dateLabel: sps.formatSeminarDate(r.startDate),
      submittedAtLabel: sps.formatSeminarDate(r.createdAt),
      pending: r.status === 'PENDING_DIRECTOR' || r.status === 'PENDING_HR',
      canApprove: reviewable,
      canReject: reviewable,
    };
  });

  const byId = useMemo(() => new Map(list.map((r) => [r.id, r])), [list]);

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
          const withPay = approved ? request.withPay !== false : undefined;
          await sps.directorReviewSeminarProposal(
            request.id,
            approved,
            withPay,
            approved ? request.supportAmount || undefined : undefined,
            '',
          );
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
            ? `Đã duyệt ${ok} phiếu hội thảo (mặc định có công nếu chưa chọn).`
            : `Đã từ chối ${ok} phiếu hội thảo.`
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

  if (tabDefs.length === 0) return null;

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Phiếu đề xuất cử CBNV hội thảo / công tác: Trưởng khoa / Điều dưỡng trưởng lập →{' '}
        <strong>Giám đốc</strong> duyệt (có công / không công, tuỳ chọn cấp tiền hỗ trợ).
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
                  t.key === 'director' ? (
                    <Badge badgeContent={t.count} color="warning" max={99}>
                      <PendingActionsIcon fontSize="small" />
                    </Badge>
                  ) : t.key === 'history' ? (
                    <HistoryIcon fontSize="small" />
                  ) : (
                    <InboxOutlinedIcon fontSize="small" />
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
        emptyHint="Khi có phiếu đề xuất hội thảo, chúng sẽ xuất hiện tại đây."
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
                  .filter((r): r is sps.SeminarProposal => Boolean(r));
                if (selected.length) setConfirm({ requests: selected, approved: true });
              }
            : undefined
        }
        onBulkReject={
          canActOnTab
            ? (selectedRows) => {
                const selected = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is sps.SeminarProposal => Boolean(r));
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
                hội thảo đã chọn?
                {confirm.approved
                  ? ' Duyệt nhanh dùng trạng thái có công hiện có (mặc định có công); muốn chọn không công / hỗ trợ thì mở chi tiết.'
                  : ''}
              </>
            ) : (
              <>
                {confirm?.approved ? 'Duyệt' : 'Từ chối'} phiếu hội thảo của{' '}
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

      <SeminarProposalDetailDialog
        open={detailId != null}
        proposalId={detailId}
        onClose={() => setDetailId(null)}
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
