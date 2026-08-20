import AccessTimeIcon from '@mui/icons-material/AccessTime';
import NotesOutlinedIcon from '@mui/icons-material/NotesOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import WbSunnyIcon from '@mui/icons-material/WbSunny';
import { Box, Button, Chip, CircularProgress, Stack, Typography } from '@mui/material';
import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { ApprovalReviewNoteCard } from './ApprovalReviewNoteCard';
import { RequestOwnerActions } from './requests/RequestOwnerActions';
import { ShiftConfigChangeProposeDialog } from './ShiftConfigChangeProposeDialog';
import {
  DetailField,
  DetailFields,
  FormSection,
  WorkRequestViewShell,
  detailHeaderChipSx,
} from './work/WorkRequestFormUi';
import * as scc from '../services/shiftConfigChangeRequestService';
import { canEditOwnPendingRequest } from '../utils/requestEditAccess';

type Props = {
  open: boolean;
  requestId: number | null;
  onClose: () => void;
  onChanged?: () => void;
};

export function ShiftConfigChangeDetailDialog({ open, requestId, onClose, onChanged }: Props) {
  const accent = '#0369a1';
  const { user } = useAuth();
  const [row, setRow] = useState<scc.ShiftConfigChangeRequest | null>(null);
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
    scc
      .fetchShiftConfigChangeRequestDetail(requestId)
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
    scc
      .fetchShiftConfigChangeRequestDetail(requestId)
      .then(setRow)
      .catch(() => setErr('Không tải được chi tiết đề xuất.'));
  }

  function handleEditSaved() {
    reloadRow();
    onChanged?.();
    setEditOpen(false);
  }

  async function cancelRequest() {
    if (!row || !window.confirm('Thu hồi đề xuất thay đổi ca này?')) return;
    setActing(true);
    setErr(null);
    try {
      await scc.cancelShiftConfigChangeRequest(row.id);
      onChanged?.();
      onClose();
    } catch {
      setErr('Không thu hồi được đề xuất.');
    } finally {
      setActing(false);
    }
  }

  return (
    <>
      <WorkRequestViewShell
        open={open}
        onClose={onClose}
        loading={loading || acting}
        accent={accent}
        icon={<WbSunnyIcon />}
        overline="Chi tiết đề xuất"
        title="Chỉnh ca sáng / chiều"
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
                label={scc.SHIFT_CONFIG_CHANGE_STATUS_LABEL[row.status] || row.status}
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
                label={row.seasonLabel || row.season}
                sx={detailHeaderChipSx.outlined}
              />
            </Stack>
          ) : undefined
        }
        footer={
          <Box sx={{ px: 3, py: 1.75 }}>
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
                <DetailField label="Khoa/phòng" value={row.departmentName} />
                <DetailField label="Mùa" value={row.seasonLabel || row.season} />
                <DetailField label="Người đề xuất" value={row.requestedByUsername} />
              </DetailFields>
            </FormSection>
            <FormSection title="Cấu hình đề xuất">
              <DetailFields>
                {row.season === 'BOTH' ? (
                  <>
                    <DetailField
                      label="Mùa hè · Ca sáng"
                      value={scc.formatShiftTimeRange(row.morningStart, row.morningEnd)}
                      icon={<AccessTimeIcon sx={{ fontSize: 16 }} />}
                    />
                    <DetailField
                      label="Mùa hè · Ca chiều"
                      value={scc.formatShiftTimeRange(row.afternoonStart, row.afternoonEnd)}
                      icon={<AccessTimeIcon sx={{ fontSize: 16 }} />}
                    />
                    <DetailField
                      label="Mùa đông · Ca sáng"
                      value={scc.formatShiftTimeRange(row.winterMorningStart, row.winterMorningEnd)}
                      icon={<AccessTimeIcon sx={{ fontSize: 16 }} />}
                    />
                    <DetailField
                      label="Mùa đông · Ca chiều"
                      value={scc.formatShiftTimeRange(
                        row.winterAfternoonStart,
                        row.winterAfternoonEnd,
                      )}
                      icon={<AccessTimeIcon sx={{ fontSize: 16 }} />}
                    />
                  </>
                ) : (
                  <>
                    <DetailField
                      label="Ca sáng"
                      value={scc.formatShiftTimeRange(row.morningStart, row.morningEnd)}
                      icon={<AccessTimeIcon sx={{ fontSize: 16 }} />}
                    />
                    <DetailField
                      label="Ca chiều"
                      value={scc.formatShiftTimeRange(row.afternoonStart, row.afternoonEnd)}
                      icon={<AccessTimeIcon sx={{ fontSize: 16 }} />}
                    />
                  </>
                )}
              </DetailFields>
            </FormSection>
            {row.reason && (
              <FormSection title="Lý do">
                <DetailField
                  label="Nội dung"
                  value={row.reason}
                  icon={<NotesOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </FormSection>
            )}
            {(row.hrComment || row.hrReviewedAt || row.hrSignatureUrl) && (
              <ApprovalReviewNoteCard
                role={`HCNS · ${row.hrReviewerUsername || '—'}`}
                timestamp={row.hrReviewedAt}
                comment={row.hrComment}
                signatureUrl={row.hrSignatureUrl}
              />
            )}
          </>
        )}
      </WorkRequestViewShell>
      {row && (
        <ShiftConfigChangeProposeDialog
          open={editOpen}
          onClose={() => setEditOpen(false)}
          onSubmitted={handleEditSaved}
          editRequest={row}
          employeeId={row.employeeId}
          employeeName={row.employeeName}
          departmentName={row.departmentName || undefined}
        />
      )}
    </>
  );
}
