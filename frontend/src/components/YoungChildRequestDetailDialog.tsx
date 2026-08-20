import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import ChildCareIcon from '@mui/icons-material/ChildCare';
import NotesOutlinedIcon from '@mui/icons-material/NotesOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import ToggleOnOutlinedIcon from '@mui/icons-material/ToggleOnOutlined';
import { Box, Button, Chip, CircularProgress, Stack, Typography } from '@mui/material';
import { useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { ApprovalReviewNoteCard } from './ApprovalReviewNoteCard';
import { RequestOwnerActions } from './requests/RequestOwnerActions';
import { YoungChildProposeDialog } from './YoungChildProposeDialog';
import {
  DetailField,
  DetailFields,
  FormSection,
  WorkRequestViewShell,
  detailHeaderChipSx,
} from './work/WorkRequestFormUi';
import * as ycs from '../services/youngChildRequestService';
import { formatDateVi } from '../utils/dateFormat';
import { canEditOwnPendingRequest } from '../utils/requestEditAccess';

type Props = {
  open: boolean;
  requestId: number | null;
  onClose: () => void;
  onChanged?: () => void;
};

export function YoungChildRequestDetailDialog({ open, requestId, onClose, onChanged }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const [row, setRow] = useState<ycs.YoungChildRequest | null>(null);
  const [loading, setLoading] = useState(false);
  const [acting, setActing] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open || requestId == null) {
      setRow(null);
      setErr(null);
      return;
    }
    setLoading(true);
    ycs
      .fetchYoungChildRequestDetail(requestId)
      .then((d) => {
        setRow(d);
        setErr(null);
      })
      .catch(() => {
        setRow(null);
        setErr('Không tải được chi tiết đề xuất.');
      })
      .finally(() => setLoading(false));
  }, [open, requestId]);

  const showCancel =
    row != null &&
    row.status !== 'CANCELLED' &&
    (user?.role === 'ADMIN'
      || (Boolean(row.requestedByUsername)
        && Boolean(user?.username)
        && row.requestedByUsername === user?.username));
  const showEdit = Boolean(row && canEditOwnPendingRequest(row, user));

  function reloadRow() {
    if (requestId == null) return;
    ycs
      .fetchYoungChildRequestDetail(requestId)
      .then(setRow)
      .catch(() => setErr('Không tải được chi tiết đề xuất.'));
  }

  function handleEditSaved() {
    reloadRow();
    onChanged?.();
    setEditOpen(false);
  }

  async function cancelRequest() {
    if (!row || !window.confirm('Thu hồi đề xuất chế độ nuôi con nhỏ này?')) return;
    setActing(true);
    setErr(null);
    try {
      await ycs.cancelYoungChildRequest(row.id);
      onChanged?.();
      onClose();
    } catch {
      setErr('Không thu hồi được đề xuất.');
    } finally {
      setActing(false);
    }
  }

  const startParts = row?.startDate?.slice(0, 10).split('-').map(Number) ?? [];
  const editYear = startParts[0] || new Date().getFullYear();
  const editMonth = startParts[1] || new Date().getMonth() + 1;

  return (
    <>
      <WorkRequestViewShell
        open={open}
        onClose={onClose}
        loading={loading || acting}
        accent={theme.palette.secondary.main}
        icon={<ChildCareIcon />}
        overline="Chi tiết đề xuất"
        title="Chế độ nuôi con nhỏ"
        description={
          row
            ? `${row.employeeName}${row.employeeCode ? ` · ${row.employeeCode}` : ''}`
            : undefined
        }
        maxWidth="md"
        headerExtra={
          row ? (
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip
                size="small"
                label={ycs.YOUNG_CHILD_STATUS_LABEL[row.status] || row.status}
                color={
                  row.status === 'PENDING_HR'
                    ? 'warning'
                    : row.status === 'APPROVED'
                      ? 'success'
                      : row.status === 'REJECTED'
                        ? 'error'
                        : 'default'
                }
                sx={detailHeaderChipSx.filled}
              />
              <Chip
                size="small"
                variant="outlined"
                label={`${formatDateVi(row.startDate)} – ${formatDateVi(row.endDate)}`}
                sx={detailHeaderChipSx.outlined}
              />
              <Chip
                size="small"
                variant="outlined"
                label={row.enabled ? 'Đề xuất bật' : 'Đề xuất tắt'}
                sx={detailHeaderChipSx.outlined}
              />
            </Stack>
          ) : undefined
        }
        footer={
          <Box sx={{ px: { xs: 2, sm: 3 }, py: 1.75 }}>
            <Stack direction="row" spacing={1.25} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
              <RequestOwnerActions
                showEdit={showEdit}
                showCancel={showCancel}
                acting={acting}
                onEdit={() => setEditOpen(true)}
                onCancel={cancelRequest}
              />
              <Button onClick={onClose} variant="outlined" color="inherit" sx={{ borderRadius: 2 }}>
                Đóng
              </Button>
            </Stack>
          </Box>
        }
      >
        {loading && !row ? (
          <Stack alignItems="center" py={4}>
            <CircularProgress size={28} />
          </Stack>
        ) : null}
        {err && !row ? <Typography color="error">{err}</Typography> : null}
        {row && (
          <>
            {err && (
              <Typography color="error" variant="body2" sx={{ mb: 1 }}>
                {err}
              </Typography>
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
                <DetailField
                  label="Khoa/phòng"
                  value={row.departmentName}
                  icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
                />
                <DetailField
                  label="Người đề xuất"
                  value={row.requestedByUsername}
                  icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
                />
              </DetailFields>
            </FormSection>

            <FormSection title="Nội dung đề xuất">
              <DetailFields>
                <DetailField
                  label="Thời gian áp dụng"
                  value={`${formatDateVi(row.startDate)} – ${formatDateVi(row.endDate)}`}
                  icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
                />
                <DetailField
                  label="Nội dung"
                  value={row.enabled ? 'Bật chế độ nuôi con nhỏ' : 'Tắt chế độ nuôi con nhỏ'}
                  icon={<ToggleOnOutlinedIcon sx={{ fontSize: 16 }} />}
                />
                <DetailField
                  wide
                  label="Lý do"
                  value={row.reason || 'Không có lý do ghi kèm.'}
                  icon={<NotesOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </DetailFields>
            </FormSection>

            {(row.hrReviewedAt || row.hrReviewerUsername || row.hrSignatureUrl) && (
              <FormSection title="Kết quả xử lý HCNS">
                <ApprovalReviewNoteCard
                  role={row.hrReviewerUsername ? `HCNS · ${row.hrReviewerUsername}` : 'HCNS'}
                  timestamp={row.hrReviewedAt}
                  comment={row.hrComment}
                  signatureUrl={row.hrSignatureUrl}
                />
              </FormSection>
            )}
          </>
        )}
      </WorkRequestViewShell>
      {row && (
        <YoungChildProposeDialog
          open={editOpen}
          onClose={() => setEditOpen(false)}
          onSubmitted={handleEditSaved}
          editRequest={row}
          employeeId={row.employeeId}
          employeeName={row.employeeName}
          departmentName={row.departmentName || undefined}
          year={editYear}
          month={editMonth}
        />
      )}
    </>
  );
}
