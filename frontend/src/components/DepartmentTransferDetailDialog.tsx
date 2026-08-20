import ApartmentOutlinedIcon from '@mui/icons-material/ApartmentOutlined';
import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import EventAvailableOutlinedIcon from '@mui/icons-material/EventAvailableOutlined';
import NotesOutlinedIcon from '@mui/icons-material/NotesOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import SwapHorizIcon from '@mui/icons-material/SwapHoriz';
import {
  Box,
  Button,
  Chip,
  CircularProgress,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { dateTimeFieldSx } from './ui/DateTimeFields';
import {
  DetailField,
  DetailFields,
  FormSection,
  InfoBanner,
  WorkRequestViewShell,
  detailHeaderChipSx,
} from './work/WorkRequestFormUi';
import { ApprovalReviewNoteCard } from './ApprovalReviewNoteCard';
import { DepartmentTransferDialog } from './DepartmentTransferDialog';
import { RequestOwnerActions } from './requests/RequestOwnerActions';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import * as departmentTransferService from '../services/departmentTransferService';
import { canEditOwnPendingRequest } from '../utils/requestEditAccess';

type Props = {
  open: boolean;
  transferId: number | null;
  onClose: () => void;
  canReview?: boolean;
  canCancel?: boolean;
  onChanged?: () => void;
};

export function DepartmentTransferDetailDialog({
  open,
  transferId,
  onClose,
  canReview = false,
  canCancel = false,
  onChanged,
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = '#0f766e';
  const [row, setRow] = useState<departmentTransferService.DepartmentTransfer | null>(null);
  const [loading, setLoading] = useState(false);
  const [acting, setActing] = useState(false);
  const [comment, setComment] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);

  useEffect(() => {
    if (!open || transferId == null) {
      setRow(null);
      setComment('');
      setErr(null);
      return;
    }
    setLoading(true);
    setErr(null);
    departmentTransferService
      .fetchTransferDetail(transferId)
      .then((d) => {
        setRow(d);
        setComment(d.directorComment || '');
      })
      .catch(() => {
        setRow(null);
        setErr('Không tải được chi tiết đơn.');
      })
      .finally(() => setLoading(false));
  }, [open, transferId]);

  const showReviewActions =
    canReview &&
    row != null &&
    row.status !== 'APPLIED' &&
    row.status !== 'CANCELLED' &&
    (row.status === 'PENDING_DIRECTOR' || row.status === 'REJECTED' || row.status === 'APPROVED');
  const directorCorrecting = Boolean(
    showReviewActions && row?.status === 'APPROVED' && row?.directorReviewedAt,
  );
  const showCancel =
    (canCancel
      || user?.role === 'ADMIN'
      || user?.role === 'HR'
      || (Boolean(row?.requestedByUsername)
        && Boolean(user?.username)
        && row!.requestedByUsername === user!.username)) &&
    row != null &&
    row.status !== 'CANCELLED';
  const showEdit = Boolean(row && canEditOwnPendingRequest(row, user));
  const hasReviewHistory = Boolean(
    row?.directorReviewedAt ||
      row?.directorReviewerUsername ||
      row?.directorComment ||
      row?.directorSignatureUrl ||
      row?.appliedAt,
  );

  function reloadRow() {
    if (transferId == null) return;
    departmentTransferService
      .fetchTransferDetail(transferId)
      .then((d) => {
        setRow(d);
        setComment(d.directorComment || '');
      })
      .catch(() => setErr('Không tải được chi tiết đơn.'));
  }

  function handleEditSaved() {
    reloadRow();
    onChanged?.();
    setEditOpen(false);
  }

  async function review(approved: boolean) {
    if (!row) return;
    setActing(true);
    setErr(null);
    try {
      await ensureHasSignature();
      await departmentTransferService.directorReviewTransfer(row.id, approved, comment);
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, approved ? 'Duyệt thất bại.' : 'Từ chối thất bại.'));
    } finally {
      setActing(false);
    }
  }

  async function cancelTransfer() {
    if (!row || !window.confirm('Thu hồi đề nghị luân chuyển phòng ban này?')) return;
    setActing(true);
    setErr(null);
    try {
      await departmentTransferService.cancelTransfer(row.id);
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Không thu hồi được đề nghị.'));
    } finally {
      setActing(false);
    }
  }

  const footer = showReviewActions || showCancel || showEdit ? (
    <Box
      sx={{
        px: 2.5,
        py: 2,
        borderTop: `1px solid ${theme.palette.divider}`,
        bgcolor: alpha(theme.palette.background.default, 0.5),
      }}
    >
      <Stack direction="row" spacing={1.5} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
        <RequestOwnerActions
          showEdit={showEdit}
          showCancel={showCancel}
          acting={acting || loading}
          onEdit={() => setEditOpen(true)}
          onCancel={cancelTransfer}
        />
        <Button
          onClick={onClose}
          disabled={acting}
          variant="outlined"
          color="inherit"
          sx={{ borderRadius: 2 }}
        >
          Đóng
        </Button>
        {showReviewActions &&
          (directorCorrecting ? (
            <Button
              variant="contained"
              disabled={acting || loading}
              startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
              onClick={() => review(true)}
              sx={{
                borderRadius: 2,
                px: 2.5,
                fontWeight: 700,
                bgcolor: accent,
                '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
              }}
            >
              Lưu chỉnh sửa · Giám đốc
            </Button>
          ) : (
            <>
              <Button
                color="error"
                variant="outlined"
                disabled={acting || loading}
                startIcon={<CloseIcon />}
                onClick={() => review(false)}
                sx={{ borderRadius: 2, fontWeight: 700 }}
              >
                Từ chối
              </Button>
              <Button
                variant="contained"
                disabled={acting || loading}
                startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
                onClick={() => review(true)}
                sx={{
                  borderRadius: 2,
                  px: 2.5,
                  fontWeight: 700,
                  bgcolor: accent,
                  '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
                }}
              >
                Duyệt
              </Button>
            </>
          ))}
      </Stack>
    </Box>
  ) : undefined;

  return (
    <>
    <WorkRequestViewShell
      open={open}
      onClose={onClose}
      loading={acting || loading}
      accent={accent}
      icon={<SwapHorizIcon />}
      overline={
        directorCorrecting
          ? 'Chỉnh sửa sau duyệt'
          : showReviewActions
            ? 'Duyệt luân chuyển'
            : 'Chi tiết đơn'
      }
      title="Luân chuyển phòng ban"
      description={
        row
          ? `${row.employeeName}${row.employeeCode ? ` · ${row.employeeCode}` : ''}`
          : loading
            ? 'Đang tải…'
            : err || '—'
      }
      maxWidth="md"
      footer={footer}
      headerExtra={
        row ? (
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Chip
              size="small"
              label={departmentTransferService.TRANSFER_STATUS_LABEL[row.status] || row.status}
              color={departmentTransferService.transferStatusColor(row.status)}
              sx={detailHeaderChipSx.filled}
            />
            <Chip
              size="small"
              variant="outlined"
              label={`Hiệu lực ${departmentTransferService.formatTransferDate(row.effectiveDate)}`}
              sx={detailHeaderChipSx.outlined}
            />
          </Stack>
        ) : undefined
      }
    >
      {loading && !row ? (
        <Box sx={{ py: 5, textAlign: 'center' }}>
          <CircularProgress size={28} />
        </Box>
      ) : err && !row ? (
        <Typography color="error">{err}</Typography>
      ) : row ? (
        <>
          {showReviewActions && (
            <InfoBanner>
              Sau khi duyệt, hệ thống chỉ chuyển nhân viên đúng <strong>ngày hiệu lực</strong> đã ghi trên đơn
              (không chuyển ngay nếu ngày còn ở tương lai).
            </InfoBanner>
          )}

          <FormSection title="Thông tin nhân viên">
            <DetailFields>
              <DetailField
                label="Họ tên"
                value={row.employeeName}
                icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Mã nhân viên"
                value={row.employeeCode}
                icon={<BadgeOutlinedIcon sx={{ fontSize: 16 }} />}
              />
            </DetailFields>
          </FormSection>

          <FormSection title="Nội dung luân chuyển" subtitle="Phòng ban nguồn / đích và ngày áp dụng.">
            <DetailFields>
              <DetailField
                label="Từ phòng ban"
                value={row.fromDepartmentName}
                icon={<ApartmentOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Đến phòng ban"
                value={
                  row.toPositionTitle
                    ? `${row.toDepartmentName} · ${row.toPositionTitle}`
                    : row.toDepartmentName
                }
                icon={<ApartmentOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Ngày hiệu lực"
                value={departmentTransferService.formatTransferDate(row.effectiveDate)}
                icon={<EventAvailableOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Ngày tạo đơn"
                value={departmentTransferService.formatTransferDateTime(row.createdAt)}
                icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                wide
                label="Lý do luân chuyển"
                value={row.reason}
                icon={<NotesOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Người đề nghị (HCNS)"
                value={row.requestedByUsername}
                icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
              />
              {row.appliedAt && (
                <DetailField
                  label="Đã áp dụng chuyển phòng"
                  value={departmentTransferService.formatTransferDateTime(row.appliedAt)}
                  icon={<ScheduleOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              )}
            </DetailFields>
          </FormSection>

          {hasReviewHistory && (
            <FormSection title="Lịch sử duyệt" subtitle="Ghi chú và thời điểm xử lý của Giám đốc.">
              <ApprovalReviewNoteCard
                role={row.directorReviewerUsername ? `Giám đốc · ${row.directorReviewerUsername}` : 'Giám đốc'}
                timestamp={row.directorReviewedAt}
                comment={row.directorComment}
                signatureUrl={row.directorSignatureUrl}
                formatTimestamp={departmentTransferService.formatTransferDateTime}
              />
            </FormSection>
          )}

          {showReviewActions && (
            <FormSection title="Ghi chú duyệt" subtitle="Tuỳ chọn — ghi chú sẽ lưu vào lịch sử duyệt.">
              <TextField
                fullWidth
                size="small"
                placeholder="Nhập ghi chú (tuỳ chọn)…"
                value={comment}
                onChange={(e) => setComment(e.target.value)}
                disabled={acting}
                multiline
                minRows={3}
                sx={dateTimeFieldSx}
              />
            </FormSection>
          )}

          {err && (
            <Typography color="error" variant="body2">
              {err}
            </Typography>
          )}
        </>
      ) : null}
    </WorkRequestViewShell>
    {row && (
      <DepartmentTransferDialog
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSubmitted={handleEditSaved}
        editTransfer={row}
        employee={{
          id: row.employeeId,
          fullName: row.employeeName,
          departmentName: row.fromDepartmentName,
        }}
      />
    )}
    </>
  );
}
