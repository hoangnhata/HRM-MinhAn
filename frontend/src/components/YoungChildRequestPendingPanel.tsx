import ChildCareIcon from '@mui/icons-material/ChildCare';
import HistoryIcon from '@mui/icons-material/History';
import PendingActionsIcon from '@mui/icons-material/PendingActions';
import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import NotesOutlinedIcon from '@mui/icons-material/NotesOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import ToggleOnOutlinedIcon from '@mui/icons-material/ToggleOnOutlined';
import DeleteForeverOutlinedIcon from '@mui/icons-material/DeleteForeverOutlined';
import {
  Alert,
  Badge,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { isHeadDepartmentRole, isHr2Role } from '../utils/roleAccess';
import * as ycs from '../services/youngChildRequestService';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import { ApprovalReviewNoteCard } from './ApprovalReviewNoteCard';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';
import { RequestListTable, formatRequestSubject, type RequestListRow } from './requests/RequestListTable';
import {
  DetailField,
  DetailFields,
  FormSection,
  InfoBanner,
  WorkRequestViewShell,
  detailHeaderChipSx,
} from './work/WorkRequestFormUi';
import { dateTimeFieldSx } from './ui/DateTimeFields';
import { formatDateVi } from '../utils/dateFormat';

function youngChildStatusColor(
  status: string,
): 'default' | 'warning' | 'success' | 'error' {
  if (status === 'PENDING_HR') return 'warning';
  if (status === 'APPROVED') return 'success';
  if (status === 'REJECTED') return 'error';
  return 'default';
}

export function YoungChildRequestPendingPanel({ onChanged }: { onChanged?: () => void }) {
  const theme = useTheme();
  const { user } = useAuth();
  const canReview = user?.role === 'ADMIN' || isHr2Role(user?.role);
  const canRevoke = user?.role === 'ADMIN';
  const isHead = isHeadDepartmentRole(user?.role) || user?.role === 'ADMIN';

  const [pending, setPending] = useState<ycs.YoungChildRequest[]>([]);
  const [history, setHistory] = useState<ycs.YoungChildRequest[]>([]);
  const [mine, setMine] = useState<ycs.YoungChildRequest[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [listLoading, setListLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [detail, setDetail] = useState<ycs.YoungChildRequest | null>(null);
  const [comment, setComment] = useState('');
  const [acting, setActing] = useState(false);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [confirm, setConfirm] = useState<{
    requests: ycs.YoungChildRequest[];
    approved: boolean;
  } | null>(null);
  const [actionBusyId, setActionBusyId] = useState<number | null>(null);
  const [bulkBusy, setBulkBusy] = useState(false);

  const reload = useCallback(() => {
    setListLoading(true);
    const tasks: Promise<unknown>[] = [];
    if (canReview) {
      tasks.push(ycs.fetchPendingYoungChildRequests().then(setPending).catch(() => setPending([])));
      tasks.push(ycs.fetchYoungChildRequestHistory().then(setHistory).catch(() => setHistory([])));
    }
    if (isHead) {
      tasks.push(ycs.fetchMyYoungChildRequests().then(setMine).catch(() => setMine([])));
    }
    Promise.all(tasks)
      .then(() => setErr(null))
      .catch(() => setErr('Không tải được đề xuất nuôi con nhỏ.'))
      .finally(() => setListLoading(false));
  }, [canReview, isHead]);

  useEffect(() => {
    reload();
  }, [reload]);

  useEffect(() => {
    setFilters(EMPTY_REQUEST_FILTERS);
  }, [subTab]);

  const tabs: { key: string; label: string; list: ycs.YoungChildRequest[] }[] = [];
  if (canReview) {
    tabs.push({ key: 'pending', label: 'Chờ duyệt', list: pending });
    tabs.push({ key: 'history', label: 'Lịch sử', list: history });
  }
  if (isHeadDepartmentRole(user?.role)) {
    tabs.push({ key: 'mine', label: 'Đơn tôi lập', list: mine });
  }
  const active = tabs[Math.min(subTab, Math.max(tabs.length - 1, 0))];
  const list = active?.list ?? [];
  const isReviewTab = active?.key === 'pending' || active?.key === 'history';

  const filtered = useMemo(
    () =>
      applyRequestListFilters(list, filters, {
        searchText: (r) =>
          [
            r.employeeName,
            r.employeeCode,
            r.departmentName,
            r.reason,
            r.enabled ? 'bật' : 'tắt',
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
        map.set(r.status, ycs.YOUNG_CHILD_STATUS_LABEL[r.status] || r.status);
      }
    }
    return [...map.entries()].map(([value, label]) => ({ value, label }));
  }, [list]);

  const rows: RequestListRow[] = filtered.map((r) => {
    const reviewable =
      isReviewTab &&
      canReview &&
      (r.status === 'PENDING_HR' || r.status === 'APPROVED' || r.status === 'REJECTED');
    return {
      id: r.id,
      typeLabel: 'Nuôi con nhỏ',
      subject: formatRequestSubject(r.employeeName, r.positionTitle),
      department: r.departmentName,
      summary: `${r.enabled ? 'Đề xuất áp dụng' : 'Đề xuất dừng'} · ${formatDateVi(r.startDate)} – ${formatDateVi(r.endDate)}`,
      meta: r.reason?.trim() || undefined,
      statusLabel: ycs.YOUNG_CHILD_STATUS_LABEL[r.status] || r.status,
      statusColor: youngChildStatusColor(r.status),
      dateLabel: `${formatDateVi(r.startDate)} – ${formatDateVi(r.endDate)}`,
      submittedAtLabel: r.createdAt
        ? formatDateVi(String(r.createdAt).slice(0, 10))
        : undefined,
      pending: r.status === 'PENDING_HR',
      canApprove: reviewable,
      canReject: reviewable,
    };
  });

  const byId = useMemo(() => new Map(list.map((r) => [r.id, r])), [list]);

  async function review(approved: boolean, request?: ycs.YoungChildRequest, note = comment) {
    const target = request ?? detail;
    if (!target) return;
    setActing(true);
    setActionBusyId(target.id);
    setErr(null);
    try {
      await ensureHasSignature();
      await ycs.hrReviewYoungChildRequest(target.id, approved, note);
      setDetail(null);
      setComment('');
      setConfirm(null);
      setMsg(approved ? 'Đã duyệt đề xuất.' : 'Đã từ chối đề xuất.');
      reload();
      onChanged?.();
    } catch (e) {
      setErr(extractApiErrorMessage(e, approved ? 'Duyệt thất bại.' : 'Từ chối thất bại.'));
    } finally {
      setActing(false);
      setActionBusyId(null);
    }
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
          await ycs.hrReviewYoungChildRequest(request.id, approved, '');
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
            ? `Đã duyệt ${ok} đề xuất nuôi con nhỏ.`
            : `Đã từ chối ${ok} đề xuất nuôi con nhỏ.`
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

  async function revoke(request: ycs.YoungChildRequest) {
    if (!window.confirm(`Thu hồi và xoá hẳn đơn của ${request.employeeName}? Đơn sẽ không còn trong phần mềm.`)) return;
    setActing(true);
    setErr(null);
    try {
      await ycs.revokeYoungChildRequest(request.id);
      setDetail(null);
      setMsg('Đã thu hồi và xoá hẳn đơn.');
      reload();
      onChanged?.();
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Không thu hồi được đơn.'));
    } finally {
      setActing(false);
    }
  }

  if (tabs.length === 0) return null;

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Đơn nuôi con nhỏ áp dụng theo khoảng ngày tối đa 1 năm; HCNS duyệt thì hệ thống áp dụng −1 giờ/ngày
        trong đúng thời gian được duyệt.
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
          value={Math.min(subTab, Math.max(tabs.length - 1, 0))}
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
          {tabs.map((t) => (
            <Tab
              key={t.key}
              icon={
                t.key === 'history' ? (
                  <HistoryIcon fontSize="small" />
                ) : (
                  <Badge badgeContent={t.list.length} color="warning" max={99}>
                    <PendingActionsIcon fontSize="small" />
                  </Badge>
                )
              }
              iconPosition="start"
              label={t.key === 'history' ? `Lịch sử (${t.list.length})` : t.label}
            />
          ))}
        </Tabs>
      </Box>

      <RequestListTable
        rows={rows}
        loading={listLoading}
        emptyTitle="Không có đề xuất"
        emptyHint="Khi có đề xuất nuôi con nhỏ, đơn sẽ xuất hiện tại đây."
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
        onView={(row) => {
          const r = byId.get(Number(row.id));
          if (r) {
            setDetail(r);
            setComment(r.hrComment || '');
          }
        }}
        onApprove={
          isReviewTab && canReview
            ? (row) => {
                const r = byId.get(Number(row.id));
                if (r) setConfirm({ requests: [r], approved: true });
              }
            : undefined
        }
        onReject={
          isReviewTab && canReview
            ? (row) => {
                const r = byId.get(Number(row.id));
                if (r) setConfirm({ requests: [r], approved: false });
              }
            : undefined
        }
        onBulkApprove={
          isReviewTab && canReview
            ? (selectedRows) => {
                const list = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is ycs.YoungChildRequest => Boolean(r));
                if (list.length) setConfirm({ requests: list, approved: true });
              }
            : undefined
        }
        onBulkReject={
          isReviewTab && canReview
            ? (selectedRows) => {
                const list = selectedRows
                  .map((row) => byId.get(Number(row.id)))
                  .filter((r): r is ycs.YoungChildRequest => Boolean(r));
                if (list.length) setConfirm({ requests: list, approved: false });
              }
            : undefined
        }
      />

      <WorkRequestViewShell
        open={Boolean(detail)}
        onClose={() => !acting && setDetail(null)}
        loading={acting}
        accent={theme.palette.secondary.main}
        icon={<ChildCareIcon />}
        overline={
          canReview && detail?.status !== 'CANCELLED'
            ? detail?.status === 'APPROVED'
              ? 'Chỉnh sửa sau duyệt'
              : 'Duyệt / đổi quyết định'
            : 'Chi tiết đề xuất'
        }
        title="Chế độ nuôi con nhỏ"
        description={
          detail
            ? `${detail.employeeName}${detail.employeeCode ? ` · ${detail.employeeCode}` : ''}`
            : undefined
        }
        maxWidth="md"
        headerExtra={
          detail ? (
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip
                size="small"
                label={ycs.YOUNG_CHILD_STATUS_LABEL[detail.status] || detail.status}
                color={youngChildStatusColor(detail.status)}
                sx={detailHeaderChipSx.filled}
              />
              <Chip
                size="small"
                variant="outlined"
                label={`${formatDateVi(detail.startDate)} – ${formatDateVi(detail.endDate)}`}
                sx={detailHeaderChipSx.outlined}
              />
              <Chip
                size="small"
                variant="outlined"
                label={detail.enabled ? 'Đề xuất bật' : 'Đề xuất tắt'}
                sx={detailHeaderChipSx.outlined}
              />
            </Stack>
          ) : undefined
        }
        footer={
          <Box
            sx={{
              px: { xs: 2, sm: 3 },
              py: 1.75,
              borderTop: `1px solid ${theme.palette.divider}`,
              bgcolor: '#fff',
            }}
          >
            <Stack direction="row" spacing={1.25} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
              <Button
                onClick={() => setDetail(null)}
                disabled={acting}
                variant="outlined"
                color="inherit"
                sx={{ borderRadius: 2 }}
              >
                Đóng
              </Button>
              {canRevoke && detail && (
                <Button
                  color="error"
                  variant="outlined"
                  startIcon={<DeleteForeverOutlinedIcon />}
                  disabled={acting}
                  onClick={() => revoke(detail)}
                  sx={{ borderRadius: 2 }}
                >
                  Thu hồi đơn
                </Button>
              )}
              {canReview && detail?.status !== 'CANCELLED' &&
                (detail?.status === 'APPROVED' ? (
                  <Button
                    variant="contained"
                    color="secondary"
                    startIcon={
                      acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />
                    }
                    disabled={acting}
                    onClick={() => review(true)}
                    sx={{ borderRadius: 2, px: 2.5, fontWeight: 700 }}
                  >
                    Lưu chỉnh sửa · HCNS
                  </Button>
                ) : (
                  <>
                    <Button
                      color="error"
                      variant="outlined"
                      startIcon={<CloseIcon />}
                      disabled={acting}
                      onClick={() => review(false)}
                      sx={{ borderRadius: 2, fontWeight: 700 }}
                    >
                      Từ chối
                    </Button>
                    <Button
                      variant="contained"
                      color="secondary"
                      startIcon={
                        acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />
                      }
                      disabled={acting}
                      onClick={() => review(true)}
                      sx={{ borderRadius: 2, px: 2.5, fontWeight: 700 }}
                    >
                      Duyệt
                    </Button>
                  </>
                ))}
            </Stack>
          </Box>
        }
      >
        {detail && (
          <>
            {canReview && detail.status !== 'CANCELLED' && (
              <InfoBanner>
                {detail.status === 'APPROVED'
                  ? 'Đơn đã duyệt — có thể sửa ghi chú rồi nhấn Lưu chỉnh sửa. Chữ ký sẽ được cập nhật lại.'
                  : 'HCNS kiểm tra thông tin đề xuất và chọn Duyệt hoặc Từ chối. Khi duyệt, chế độ nuôi con nhỏ sẽ được áp dụng cho tháng đã chọn.'}
              </InfoBanner>
            )}

            <FormSection title="Thông tin nhân viên">
              <DetailFields>
                <DetailField
                  label="Họ tên"
                  value={detail.employeeName}
                  icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
                />
                <DetailField
                  label="Mã nhân viên"
                  value={detail.employeeCode}
                  icon={<BadgeOutlinedIcon sx={{ fontSize: 16 }} />}
                />
                <DetailField
                  label="Khoa/phòng"
                  value={detail.departmentName}
                  icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
                />
                <DetailField
                  label="Người đề xuất"
                  value={detail.requestedByUsername}
                  icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
                />
              </DetailFields>
            </FormSection>

            <FormSection title="Nội dung đề xuất">
              <DetailFields>
                <DetailField
                  label="Thời gian áp dụng"
                  value={`${formatDateVi(detail.startDate)} – ${formatDateVi(detail.endDate)}`}
                  icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
                />
                <DetailField
                  label="Nội dung"
                  value={detail.enabled ? 'Bật chế độ nuôi con nhỏ' : 'Tắt chế độ nuôi con nhỏ'}
                  icon={<ToggleOnOutlinedIcon sx={{ fontSize: 16 }} />}
                />
                <DetailField
                  wide
                  label="Lý do"
                  value={detail.reason || 'Không có lý do ghi kèm.'}
                  icon={<NotesOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </DetailFields>
            </FormSection>

            {(detail.hrReviewedAt || detail.hrReviewerUsername || detail.hrSignatureUrl) && (
              <FormSection title="Kết quả xử lý HCNS">
                <ApprovalReviewNoteCard
                  role={detail.hrReviewerUsername ? `HCNS · ${detail.hrReviewerUsername}` : 'HCNS'}
                  timestamp={detail.hrReviewedAt}
                  comment={detail.hrComment}
                  signatureUrl={detail.hrSignatureUrl}
                />
              </FormSection>
            )}

            {canReview && detail.status !== 'CANCELLED' && (
              <FormSection title="Ý kiến HCNS">
                <TextField
                  label="Ghi chú duyệt (tuỳ chọn)"
                  fullWidth
                  size="small"
                  multiline
                  minRows={3}
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  sx={dateTimeFieldSx}
                />
              </FormSection>
            )}
          </>
        )}
      </WorkRequestViewShell>

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
                {confirm.approved ? 'Duyệt' : 'Từ chối'} <strong>{confirm.requests.length}</strong> đề
                xuất nuôi con nhỏ đã chọn?
              </>
            ) : (
              <>
                {confirm?.approved ? 'Duyệt' : 'Từ chối'} đề xuất nuôi con nhỏ của{' '}
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
                if (confirm) {
                  setDetail(confirm.requests[0]);
                  setComment(confirm.requests[0].hrComment || '');
                }
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
