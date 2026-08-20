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
  FormControl,
  FormControlLabel,
  FormLabel,
  Radio,
  RadioGroup,
  Stack,
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { isHeadDepartmentRole, isHr2Role } from '../utils/roleAccess';
import * as att from '../services/attendanceService';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';
import { RequestListTable, formatRequestSubject, type RequestListRow } from './requests/RequestListTable';
import { WorkRequestDetailDialog } from './work/WorkRequestDetailDialog';

type Props = {
  onChanged?: () => void;
  /** Chỉ hiện các loại đơn này (mặc định: tất cả). */
  types?: att.WorkRequest['requestType'][];
  description?: string;
};

function workRequestSummary(r: att.WorkRequest): string {
  const isRanged =
    r.requestType === 'LEAVE' ||
    r.requestType === 'UNPAID_LEAVE' ||
    r.requestType === 'BUSINESS_TRIP';
  if (r.requestType === 'UPDATE') return att.formatRequestedTimes(r);
  if (r.requestType === 'DEPLOYMENT' && r.requestedStart && r.requestedEnd) {
    return `${r.requestedStart.slice(0, 5)}–${r.requestedEnd.slice(0, 5)}${
      r.location ? ` · ${r.location}` : ''
    }`;
  }
  if (isRanged) {
    const days =
      r.requestType === 'BUSINESS_TRIP' ? r.tripDays : r.leaveDays;
    return `${att.formatLeaveRange(r)}${days != null ? ` · ${days} ngày` : ''}`;
  }
  return att.formatExplanationTimes(r);
}

type ReviewStage = 'head' | 'nursingHead' | 'hr' | 'director';

function reviewStageForWorkRequest(
  r: att.WorkRequest,
  opts: { isHead: boolean; isNursingHead: boolean; isHr: boolean; isDirector: boolean },
): ReviewStage | null {
  if (r.status === 'WITHDRAWN') return null;
  if (opts.isDirector && (r.status === 'PENDING_DIRECTOR' || Boolean(r.directorReviewedAt))) {
    return 'director';
  }
  // Pending nursing-head before HR; correction after HR so ADMIN/HR stages are not stolen.
  if (opts.isNursingHead && r.status === 'PENDING_NURSING_HEAD') {
    return 'nursingHead';
  }
  if (opts.isHr && (r.status === 'PENDING_HR' || Boolean(r.hrReviewedAt))) {
    return 'hr';
  }
  if (opts.isNursingHead && Boolean(r.nursingHeadReviewedAt)) {
    return 'nursingHead';
  }
  if (opts.isHead && (r.status === 'PENDING_HEAD' || Boolean(r.headReviewedAt))) {
    return 'head';
  }
  return null;
}

/** Cập nhật công / giải trình: Giám đốc phải chọn trừ tiền hay miễn phạt. */
function needsDirectorFineDecision(
  r: att.WorkRequest,
  opts: { isHead: boolean; isNursingHead?: boolean; isHr: boolean; isDirector: boolean },
): boolean {
  if (r.requestType !== 'UPDATE' && r.requestType !== 'EXPLANATION') return false;
  return (
    reviewStageForWorkRequest(r, {
      isHead: opts.isHead,
      isNursingHead: opts.isNursingHead ?? false,
      isHr: opts.isHr,
      isDirector: opts.isDirector,
    }) === 'director'
  );
}

export function AttendancePendingPanel({ onChanged, types, description }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const [pendingAll, setPendingAll] = useState<att.WorkRequest[]>([]);
  const [historyAll, setHistoryAll] = useState<att.WorkRequest[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [selected, setSelected] = useState<att.WorkRequest | null>(null);
  const [comment, setComment] = useState('');
  const [headComment, setHeadComment] = useState('');
  const [nursingHeadComment, setNursingHeadComment] = useState('');
  const [hrComment, setHrComment] = useState('');
  const [directorComment, setDirectorComment] = useState('');
  const [loading, setLoading] = useState(false);
  const [listLoading, setListLoading] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [confirm, setConfirm] = useState<{
    requests: att.WorkRequest[];
    approved: boolean;
  } | null>(null);
  /** null = chưa chọn; chỉ dùng khi Giám đốc duyệt UPDATE/EXPLANATION */
  const [bulkWaiveFine, setBulkWaiveFine] = useState<boolean | null>(null);
  const [actionBusyId, setActionBusyId] = useState<number | null>(null);
  const [bulkBusy, setBulkBusy] = useState(false);

  const isHead = user?.role === 'ADMIN' || isHeadDepartmentRole(user?.role);
  const isNursingHead = user?.role === 'ADMIN' || user?.role === 'HEAD_NURSING';
  const isHr = user?.role === 'ADMIN' || isHr2Role(user?.role);
  const isDirector =
    user?.role === 'ADMIN' ||
    user?.role === 'DIRECTOR' ||
    user?.directorApprovalEnabled === true;
  const isAdmin = user?.role === 'ADMIN';
  const roleOpts = useMemo(
    () => ({ isHead, isNursingHead, isHr, isDirector }),
    [isHead, isNursingHead, isHr, isDirector],
  );

  const typeSet = useMemo(() => (types && types.length > 0 ? new Set(types) : null), [types]);

  const pending = useMemo(
    () => (typeSet ? pendingAll.filter((r) => typeSet.has(r.requestType)) : pendingAll),
    [pendingAll, typeSet],
  );
  const history = useMemo(
    () => (typeSet ? historyAll.filter((r) => typeSet.has(r.requestType)) : historyAll),
    [historyAll, typeSet],
  );

  const reload = useCallback(() => {
    if (!isHead && !isNursingHead && !isHr && !isDirector) return;
    setListLoading(true);
    Promise.all([
      att.fetchPendingWorkRequests().catch(() => [] as att.WorkRequest[]),
      att.fetchReviewHistoryWorkRequests().catch(() => [] as att.WorkRequest[]),
    ])
      .then(([p, h]) => {
        setPendingAll(p);
        setHistoryAll(h);
      })
      .finally(() => setListLoading(false));
  }, [isHead, isNursingHead, isHr, isDirector]);

  useEffect(() => {
    reload();
  }, [reload]);

  useEffect(() => {
    setFilters(EMPTY_REQUEST_FILTERS);
  }, [subTab]);

  if (!isHead && !isNursingHead && !isHr && !isDirector) return null;

  function openDetail(r: att.WorkRequest) {
    setSelected(r);
    setMsg(null);
    setHeadComment(r.headComment || '');
    setNursingHeadComment(r.nursingHeadComment || '');
    setHrComment(r.hrComment || '');
    setDirectorComment(r.directorComment || '');
    if (isDirector && (r.directorReviewedAt || r.status === 'PENDING_DIRECTOR')) {
      setComment(r.directorComment || '');
    } else if (
      isNursingHead &&
      (r.nursingHeadReviewedAt || r.status === 'PENDING_NURSING_HEAD')
    ) {
      setComment(r.nursingHeadComment || '');
    } else if (isHr && (r.hrReviewedAt || r.status === 'PENDING_HR')) {
      setComment(r.hrComment || '');
    } else if (isHead && (r.headReviewedAt || r.status === 'PENDING_HEAD')) {
      setComment(r.headComment || '');
    } else {
      setComment('');
    }
  }

  function closeDetail() {
    if (loading) return;
    setSelected(null);
    setComment('');
    setHeadComment('');
    setNursingHeadComment('');
    setHrComment('');
    setDirectorComment('');
  }

  async function reviewRequest(
    request: att.WorkRequest,
    approved: boolean,
    note = '',
    waiveFine?: boolean,
  ) {
    const stage = reviewStageForWorkRequest(request, roleOpts);
    if (stage === 'head') {
      await att.headReviewRequest(request.id, approved, note);
    } else if (stage === 'nursingHead') {
      await att.nursingHeadReviewRequest(request.id, approved, { comment: note });
    } else if (stage === 'hr') {
      await att.hrReviewRequest(request.id, approved, { comment: note });
    } else if (stage === 'director') {
      await att.directorReviewRequest(request.id, approved, {
        comment: note,
        waiveForgotFine: waiveFine,
      });
    } else {
      throw new Error('Đơn không còn ở bước chờ duyệt của bạn.');
    }
  }

  async function headAct(approved: boolean) {
    if (!selected) return;
    setLoading(true);
    setMsg(null);
    try {
      await ensureHasSignature();
      await reviewRequest(selected, approved, headComment || comment);
      reload();
      onChanged?.();
      setMsg(approved ? 'Đã xử lý đơn.' : 'Đã từ chối đơn.');
      closeDetail();
    } catch (e) {
      setMsg(extractApiErrorMessage(e, 'Thao tác thất bại.'));
    } finally {
      setLoading(false);
    }
  }

  async function nursingHeadAct(
    approved: boolean,
    deploymentTimes?: {
      requestedStart: string;
      requestedEnd: string;
      requestedAfternoonStart?: string;
      requestedAfternoonEnd?: string;
    },
  ) {
    if (!selected) return;
    setLoading(true);
    setMsg(null);
    try {
      await ensureHasSignature();
      await att.nursingHeadReviewRequest(selected.id, approved, {
        comment: nursingHeadComment || comment,
        ...deploymentTimes,
      });
      reload();
      onChanged?.();
      setMsg(approved ? 'Đã chuyển HCNS duyệt.' : 'Đã từ chối đơn.');
      closeDetail();
    } catch (e) {
      setMsg(extractApiErrorMessage(e, 'Thao tác thất bại.'));
    } finally {
      setLoading(false);
    }
  }

  async function hrAct(
    approved: boolean,
    waiveFine?: boolean,
    deploymentTimes?: {
      requestedStart: string;
      requestedEnd: string;
      requestedAfternoonStart?: string;
      requestedAfternoonEnd?: string;
    },
  ) {
    if (!selected) return;
    setLoading(true);
    setMsg(null);
    try {
      await ensureHasSignature();
      await att.hrReviewRequest(selected.id, approved, {
        comment: hrComment || comment,
        waiveForgotFine: waiveFine,
        ...deploymentTimes,
      });
      reload();
      onChanged?.();
      const needsDirector =
        approved &&
        (selected.requestType === 'UPDATE' ||
          selected.requestType === 'EXPLANATION' ||
          selected.requestType === 'LEAVE' ||
          selected.requestType === 'UNPAID_LEAVE' ||
          selected.requestType === 'DEPLOYMENT');
      setMsg(needsDirector ? 'Đã chuyển Giám đốc duyệt.' : 'Đã xử lý đơn.');
      closeDetail();
    } catch (e) {
      setMsg(extractApiErrorMessage(e, 'Thao tác thất bại.'));
    } finally {
      setLoading(false);
    }
  }

  async function directorAct(approved: boolean, waiveFine?: boolean) {
    if (!selected) return;
    setLoading(true);
    setMsg(null);
    try {
      await ensureHasSignature();
      await att.directorReviewRequest(selected.id, approved, {
        comment: directorComment || comment,
        waiveForgotFine: waiveFine,
      });
      reload();
      onChanged?.();
      setMsg(approved ? 'Đã hoàn tất duyệt đơn.' : 'Đã từ chối đơn.');
      closeDetail();
    } catch (e) {
      setMsg(extractApiErrorMessage(e, 'Thao tác thất bại.'));
    } finally {
      setLoading(false);
    }
  }

  async function withdrawAsAdmin() {
    if (!selected || !isAdmin) return;
    setLoading(true);
    setMsg(null);
    try {
      await att.withdrawWorkRequest(selected.id);
      reload();
      onChanged?.();
      setMsg('Đã thu hồi đơn.');
      setSelected(null);
      setComment('');
    } catch (e) {
      setMsg(extractApiErrorMessage(e, 'Không thu hồi được đơn.'));
    } finally {
      setLoading(false);
    }
  }

  async function confirmQuickReview() {
    if (!confirm || confirm.requests.length === 0) return;
    const { requests, approved } = confirm;
    const fineTargets = approved
      ? requests.filter((r) => needsDirectorFineDecision(r, roleOpts))
      : [];
    if (fineTargets.length > 0 && bulkWaiveFine == null) {
      setMsg('Vui lòng chọn trừ tiền hay không trừ tiền trước khi duyệt.');
      return;
    }
    const multi = requests.length > 1;
    if (multi) setBulkBusy(true);
    else setActionBusyId(requests[0].id);
    setMsg(null);
    try {
      await ensureHasSignature();
      let ok = 0;
      let fail = 0;
      for (const request of requests) {
        try {
          const waive =
            approved && needsDirectorFineDecision(request, roleOpts)
              ? Boolean(bulkWaiveFine)
              : undefined;
          await reviewRequest(request, approved, '', waive);
          ok += 1;
        } catch {
          fail += 1;
        }
      }
      reload();
      onChanged?.();
      if (fail === 0) {
        const fineNote =
          approved && fineTargets.length > 0
            ? bulkWaiveFine
              ? ' (không trừ tiền)'
              : ' (có trừ tiền)'
            : '';
        setMsg(
          approved
            ? `Đã duyệt ${ok} đơn${fineNote}.`
            : `Đã từ chối ${ok} đơn.`,
        );
      } else {
        setMsg(
          `Hoàn tất ${ok} đơn, ${fail} đơn lỗi. Kiểm tra lại các đơn còn lại.`,
        );
      }
      setConfirm(null);
      setBulkWaiveFine(null);
    } catch (e) {
      setMsg(extractApiErrorMessage(e, 'Thao tác thất bại.'));
    } finally {
      setActionBusyId(null);
      setBulkBusy(false);
    }
  }

  function openConfirm(requests: att.WorkRequest[], approved: boolean) {
    setBulkWaiveFine(null);
    setConfirm({ requests, approved });
  }

  function closeConfirm() {
    if (actionBusyId != null || bulkBusy) return;
    setConfirm(null);
    setBulkWaiveFine(null);
  }

  const list = subTab === 0 ? pending : history;
  const filtered = useMemo(
    () =>
      applyRequestListFilters(list, filters, {
        searchText: (r) =>
          [r.employeeName, r.department, r.reason, att.requestTypeLabel(r.requestType), r.status].join(
            ' ',
          ),
        dateValue: (r) => r.createdAt,
        statusValue: (r) => r.status,
        departmentValue: (r) => r.department,
      }),
    [list, filters],
  );

  const statusOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const r of list) {
      if (!map.has(r.status)) {
        map.set(r.status, att.requestStatusLabel(r.status, r.requestType));
      }
    }
    return [...map.entries()].map(([value, label]) => ({ value, label }));
  }, [list]);

  const rows: RequestListRow[] = filtered.map((r) => {
    const reviewable = reviewStageForWorkRequest(r, roleOpts) != null;
    return {
      id: r.id,
      typeLabel: att.requestTypeLabel(r.requestType),
      subject: formatRequestSubject(r.employeeName, r.positionTitle),
      department: r.department,
      summary: workRequestSummary(r),
      meta: r.reason?.trim() || undefined,
      statusLabel: att.requestStatusLabel(r.status, r.requestType),
      statusColor: att.requestStatusColor(r.status),
      dateLabel: att.formatWorkDate(r.workDate),
      submittedAtLabel: r.createdAt ? att.formatWorkDate(String(r.createdAt).slice(0, 10)) : undefined,
      pending: att.isRequestPending(r.status),
      canApprove: reviewable,
      canReject: reviewable,
    };
  });

  const byId = useMemo(() => new Map(list.map((r) => [r.id, r])), [list]);

  return (
    <Stack spacing={2}>
      {description && (
        <Typography variant="body2" color="text.secondary">
          {description}
        </Typography>
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
        emptyTitle={subTab === 0 ? 'Không có đơn chờ duyệt' : 'Chưa có lịch sử duyệt'}
        emptyHint={
          subTab === 0
            ? 'Các đơn mới sẽ xuất hiện tại đây. Dùng bộ lọc để tìm nhanh.'
            : 'Các đơn đã duyệt hoặc từ chối sẽ được lưu tại đây.'
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
        onView={(row) => {
          const r = byId.get(Number(row.id));
          if (r) openDetail(r);
        }}
        onApprove={(row) => {
          const r = byId.get(Number(row.id));
          if (r) openConfirm([r], true);
        }}
        onReject={(row) => {
          const r = byId.get(Number(row.id));
          if (r) openConfirm([r], false);
        }}
        onBulkApprove={(selectedRows) => {
          const list = selectedRows
            .map((row) => byId.get(Number(row.id)))
            .filter((r): r is att.WorkRequest => Boolean(r));
          if (list.length) openConfirm(list, true);
        }}
        onBulkReject={(selectedRows) => {
          const list = selectedRows
            .map((row) => byId.get(Number(row.id)))
            .filter((r): r is att.WorkRequest => Boolean(r));
          if (list.length) openConfirm(list, false);
        }}
      />

      <WorkRequestDetailDialog
        open={selected != null}
        onClose={closeDetail}
        request={selected}
        mode="review"
        review={{
          isHead,
          isNursingHead,
          isHr,
          isDirector,
          stage: selected ? reviewStageForWorkRequest(selected, roleOpts) : null,
          comment,
          onCommentChange: setComment,
          headComment,
          onHeadCommentChange: setHeadComment,
          nursingHeadComment,
          onNursingHeadCommentChange: setNursingHeadComment,
          hrComment,
          onHrCommentChange: setHrComment,
          directorComment,
          onDirectorCommentChange: setDirectorComment,
          loading,
          onHeadReview: headAct,
          onNursingHeadReview: nursingHeadAct,
          onHrReview: hrAct,
          onDirectorReview: directorAct,
        }}
        onWithdraw={isAdmin ? withdrawAsAdmin : undefined}
        allowWithdrawApproved={isAdmin}
        withdrawLoading={loading}
        onChanged={() => {
          reload();
          onChanged?.();
        }}
      />

      <Dialog open={confirm != null} onClose={closeConfirm} maxWidth="xs" fullWidth>
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
          <Stack spacing={2} sx={{ pt: 0.5 }}>
            <Typography variant="body2" color="text.secondary">
              {confirm && confirm.requests.length > 1 ? (
                <>
                  {confirm.approved ? 'Duyệt' : 'Từ chối'} <strong>{confirm.requests.length}</strong> đơn
                  đã chọn?
                </>
              ) : (
                <>
                  {confirm?.approved ? 'Duyệt' : 'Từ chối'} đơn{' '}
                  <strong>
                    {confirm ? att.requestTypeLabel(confirm.requests[0].requestType) : ''}
                  </strong>{' '}
                  của <strong>{confirm?.requests[0]?.employeeName}</strong>?
                </>
              )}
            </Typography>

            {confirm?.approved &&
              confirm.requests.some((r) => needsDirectorFineDecision(r, roleOpts)) && (
                <FormControl component="fieldset" disabled={actionBusyId != null || bulkBusy}>
                  <FormLabel
                    component="legend"
                    sx={{ typography: 'body2', fontWeight: 700, color: 'text.primary', mb: 0.75 }}
                  >
                    Quyết định trừ tiền (Giám đốc)
                  </FormLabel>
                  <Typography variant="caption" color="text.secondary" sx={{ mb: 1, display: 'block' }}>
                    Áp dụng cho đơn cập nhật công / giải trình trong danh sách đã chọn. Nghỉ phép,
                    điều động không bị ảnh hưởng.
                  </Typography>
                  <RadioGroup
                    value={bulkWaiveFine == null ? '' : bulkWaiveFine ? 'waive' : 'fine'}
                    onChange={(_, v) => setBulkWaiveFine(v === 'waive')}
                  >
                    <FormControlLabel
                      value="fine"
                      control={<Radio size="small" />}
                      label="Có trừ tiền (theo quy định phạt)"
                    />
                    <FormControlLabel
                      value="waive"
                      control={<Radio size="small" color="secondary" />}
                      label="Không trừ tiền (miễn phạt)"
                    />
                  </RadioGroup>
                </FormControl>
              )}
          </Stack>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={closeConfirm} disabled={actionBusyId != null || bulkBusy}>
            Hủy
          </Button>
          {confirm && confirm.requests.length === 1 && (
            <Button
              variant="outlined"
              onClick={() => {
                if (confirm) openDetail(confirm.requests[0]);
                closeConfirm();
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
            disabled={
              actionBusyId != null ||
              bulkBusy ||
              (Boolean(confirm?.approved) &&
                Boolean(confirm?.requests.some((r) => needsDirectorFineDecision(r, roleOpts))) &&
                bulkWaiveFine == null)
            }
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
