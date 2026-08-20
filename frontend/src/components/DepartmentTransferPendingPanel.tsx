import HistoryIcon from '@mui/icons-material/History';
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
import * as departmentTransferService from '../services/departmentTransferService';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import { DepartmentTransferDetailDialog } from './DepartmentTransferDetailDialog';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';
import { RequestListTable, formatRequestSubject, type RequestListRow } from './requests/RequestListTable';

export function DepartmentTransferPendingPanel({ onChanged }: { onChanged?: () => void }) {
  const theme = useTheme();
  const { user } = useAuth();
  const canReview = user?.role === 'ADMIN' || user?.role === 'DIRECTOR';

  const [pending, setPending] = useState<departmentTransferService.DepartmentTransfer[]>([]);
  const [history, setHistory] = useState<departmentTransferService.DepartmentTransfer[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [listLoading, setListLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [detailId, setDetailId] = useState<number | null>(null);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [confirm, setConfirm] = useState<{
    requests: departmentTransferService.DepartmentTransfer[];
    approved: boolean;
  } | null>(null);
  const [actionBusyId, setActionBusyId] = useState<number | null>(null);
  const [bulkBusy, setBulkBusy] = useState(false);

  const reload = useCallback(() => {
    setListLoading(true);
    Promise.all([
      departmentTransferService
        .fetchPendingTransfers()
        .catch(() => [] as departmentTransferService.DepartmentTransfer[]),
      departmentTransferService
        .fetchTransferHistory()
        .catch(() => [] as departmentTransferService.DepartmentTransfer[]),
    ])
      .then(([p, h]) => {
        setPending(p);
        setHistory(h);
        setErr(null);
      })
      .catch(() => setErr('Không tải được danh sách luân chuyển.'))
      .finally(() => setListLoading(false));
  }, []);

  useEffect(() => {
    reload();
  }, [reload]);

  useEffect(() => {
    setFilters(EMPTY_REQUEST_FILTERS);
  }, [subTab]);

  const list = subTab === 0 ? pending : history;

  const filtered = useMemo(
    () =>
      applyRequestListFilters(list, filters, {
        searchText: (r) =>
          [
            r.employeeName,
            r.employeeCode,
            r.fromDepartmentName,
            r.toDepartmentName,
            r.reason,
            r.status,
          ].join(' '),
        dateValue: (r) => r.createdAt,
        statusValue: (r) => r.status,
        departmentValue: (r) => r.fromDepartmentName || r.toDepartmentName,
      }),
    [list, filters],
  );

  const statusOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const r of list) {
      if (!map.has(r.status)) {
        map.set(
          r.status,
          departmentTransferService.TRANSFER_STATUS_LABEL[r.status] || r.status,
        );
      }
    }
    return [...map.entries()].map(([value, label]) => ({ value, label }));
  }, [list]);

  const rows: RequestListRow[] = filtered.map((r) => {
    const reviewable =
      canReview &&
      (r.status === 'PENDING_DIRECTOR' || r.status === 'REJECTED' || r.status === 'APPROVED');
    return {
      id: r.id,
      typeLabel: 'Luân chuyển',
      subject: formatRequestSubject(r.employeeName, r.positionTitle),
      department: r.fromDepartmentName,
      summary: `${r.fromDepartmentName} → ${r.toDepartmentName}${
        r.toPositionTitle ? ` · ${r.toPositionTitle}` : ''
      } · hiệu lực ${departmentTransferService.formatTransferDate(r.effectiveDate)}`,
      meta: r.reason?.trim() || undefined,
      statusLabel: departmentTransferService.TRANSFER_STATUS_LABEL[r.status] || r.status,
      statusColor: departmentTransferService.transferStatusColor(r.status),
      dateLabel: departmentTransferService.formatTransferDate(r.effectiveDate),
      submittedAtLabel: departmentTransferService.formatTransferDate(r.createdAt),
      pending: r.status === 'PENDING_DIRECTOR',
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
          await departmentTransferService.directorReviewTransfer(request.id, approved, '');
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
            ? `Đã duyệt ${ok} đơn luân chuyển.`
            : `Đã từ chối ${ok} đơn luân chuyển.`
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

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Đề nghị luân chuyển do HCNS gửi. Sau khi Giám đốc duyệt, hệ thống chỉ chuyển nhân viên đúng{' '}
        <strong>ngày hiệu lực</strong>. Bấm xem để mở chi tiết đơn.
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
          }}
        >
          <Tabs
            value={subTab}
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
            <Tab
              icon={
                <Badge badgeContent={pending.length} color="warning" max={99}>
                  <PendingActionsIcon fontSize="small" />
                </Badge>
              }
              iconPosition="start"
              label="Chờ duyệt"
            />
            <Tab
              icon={<HistoryIcon fontSize="small" />}
              iconPosition="start"
              label={`Lịch sử (${history.length})`}
            />
          </Tabs>
        </Box>
      </Stack>

      <RequestListTable
        rows={rows}
        loading={listLoading}
        emptyTitle={subTab === 0 ? 'Không có đơn chờ duyệt' : 'Chưa có lịch sử luân chuyển'}
        emptyHint={
          subTab === 0
            ? 'Khi HCNS gửi đề nghị luân chuyển, đơn sẽ xuất hiện tại đây.'
            : 'Các đơn đã duyệt, từ chối, đã chuyển hoặc hủy sẽ lưu tại đây.'
        }
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
          canReview
            ? (row) => {
                const r = byId.get(Number(row.id));
                if (r) setConfirm({ requests: [r], approved: true });
              }
            : undefined
        }
        onReject={
          canReview
            ? (row) => {
                const r = byId.get(Number(row.id));
                if (r) setConfirm({ requests: [r], approved: false });
              }
            : undefined
        }
        onBulkApprove={
          canReview
            ? (selectedRows) => {
                const list = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is departmentTransferService.DepartmentTransfer => Boolean(r));
                if (list.length) setConfirm({ requests: list, approved: true });
              }
            : undefined
        }
        onBulkReject={
          canReview
            ? (selectedRows) => {
                const list = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is departmentTransferService.DepartmentTransfer => Boolean(r));
                if (list.length) setConfirm({ requests: list, approved: false });
              }
            : undefined
        }
      />

      <DepartmentTransferDetailDialog
        open={detailId != null}
        transferId={detailId}
        onClose={() => setDetailId(null)}
        canReview={canReview}
        canCancel={user?.role === 'ADMIN' || user?.role === 'HR'}
        onChanged={() => {
          reload();
          onChanged?.();
        }}
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
                luân chuyển đã chọn?
              </>
            ) : (
              <>
                {confirm?.approved ? 'Duyệt' : 'Từ chối'} đơn luân chuyển của{' '}
                <strong>{confirm?.requests[0]?.employeeName}</strong>?
                {confirm?.approved ? ' Có thể mở chi tiết nếu cần ghi chú.' : ''}
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
    </Stack>
  );
}
