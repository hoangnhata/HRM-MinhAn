import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import MenuBookOutlinedIcon from '@mui/icons-material/MenuBookOutlined';
import NotesOutlinedIcon from '@mui/icons-material/NotesOutlined';
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import WorkOutlineIcon from '@mui/icons-material/WorkOutline';
import {
  Box,
  Button,
  Chip,
  CircularProgress,
  Stack,
  Switch,
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
import { RequestOwnerActions } from './requests/RequestOwnerActions';
import { SeminarProposalDialog } from './SeminarProposalDialog';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import * as sps from '../services/seminarProposalService';
import { canEditOwnPendingRequest } from '../utils/requestEditAccess';

type Props = {
  open: boolean;
  proposalId: number | null;
  onClose: () => void;
  canDirectorReview?: boolean;
  canCancel?: boolean;
  onChanged?: () => void;
};

export function SeminarProposalDetailDialog({
  open,
  proposalId,
  onClose,
  canDirectorReview = false,
  canCancel = false,
  onChanged,
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = '#0e7490';
  const [row, setRow] = useState<sps.SeminarProposal | null>(null);
  const [loading, setLoading] = useState(false);
  const [acting, setActing] = useState(false);
  const [comment, setComment] = useState('');
  const [grantSupport, setGrantSupport] = useState(false);
  const [supportAmount, setSupportAmount] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);

  useEffect(() => {
    if (!open || proposalId == null) {
      setRow(null);
      setComment('');
      setGrantSupport(false);
      setSupportAmount('');
      setErr(null);
      return;
    }
    setLoading(true);
    sps
      .fetchSeminarProposalDetail(proposalId)
      .then((d) => {
        setRow(d);
        setComment(d.directorComment || '');
        setGrantSupport(Boolean(d.supportAmount));
        setSupportAmount(d.supportAmount ? String(d.supportAmount) : '');
        setErr(null);
      })
      .catch((ex) => setErr(extractApiErrorMessage(ex, 'Không tải được phiếu.')))
      .finally(() => setLoading(false));
  }, [open, proposalId]);

  const showDirectorActions =
    canDirectorReview &&
    (row?.status === 'PENDING_DIRECTOR' ||
      row?.status === 'DIRECTOR_REJECTED' ||
      row?.status === 'APPROVED');
  const directorCorrecting = Boolean(
    showDirectorActions && row?.status === 'APPROVED' && row?.directorReviewedAt,
  );
  const showCancel =
    (canCancel
      || user?.role === 'ADMIN'
      || (Boolean(row?.requestedByUsername)
        && Boolean(user?.username)
        && row!.requestedByUsername === user!.username)) &&
    row != null &&
    row.status !== 'CANCELLED';
  const showEdit = Boolean(row && canEditOwnPendingRequest(row, user));

  function reloadRow() {
    if (proposalId == null) return;
    sps
      .fetchSeminarProposalDetail(proposalId)
      .then((d) => {
        setRow(d);
        setComment(d.directorComment || '');
        setGrantSupport(Boolean(d.supportAmount));
        setSupportAmount(d.supportAmount ? String(d.supportAmount) : '');
      })
      .catch((ex) => setErr(extractApiErrorMessage(ex, 'Không tải được phiếu.')));
  }

  function handleEditSaved() {
    reloadRow();
    onChanged?.();
    setEditOpen(false);
  }

  async function directorReview(approved: boolean, withPay?: boolean) {
    if (!row) return;
    if (approved && grantSupport && !supportAmount.trim()) {
      setErr('Vui lòng nhập số tiền hỗ trợ hội thảo.');
      return;
    }
    setActing(true);
    setErr(null);
    try {
      await ensureHasSignature();
      await sps.directorReviewSeminarProposal(
        row.id,
        approved,
        approved ? withPay : undefined,
        approved && grantSupport ? supportAmount : undefined,
        comment,
      );
      onChanged?.();
      onClose();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Duyệt phiếu thất bại.'));
    } finally {
      setActing(false);
    }
  }

  async function cancelProposal() {
    if (!row || !window.confirm('Thu hồi phiếu đề xuất hội thảo này?')) return;
    setActing(true);
    setErr(null);
    try {
      await sps.cancelSeminarProposal(row.id);
      onChanged?.();
      onClose();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Không thu hồi được phiếu.'));
    } finally {
      setActing(false);
    }
  }

  const footer = (
    <Box
      sx={{
        px: { xs: 2, sm: 3 },
        py: 1.75,
        borderTop: `1px solid ${theme.palette.divider}`,
        bgcolor: '#fff',
      }}
    >
      <Stack direction="row" spacing={1.25} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
        <RequestOwnerActions
          showEdit={showEdit}
          showCancel={showCancel}
          acting={acting}
          onEdit={() => setEditOpen(true)}
          onCancel={cancelProposal}
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
        {showDirectorActions &&
          (directorCorrecting ? (
            <Button
              variant="contained"
              startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
              disabled={acting}
              onClick={() => directorReview(true, row?.withPay !== false)}
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
                startIcon={<CloseIcon />}
                disabled={acting}
                onClick={() => directorReview(false)}
                sx={{ borderRadius: 2, fontWeight: 700 }}
              >
                Từ chối
              </Button>
              <Button
                variant="outlined"
                disabled={acting}
                onClick={() => directorReview(true, false)}
                sx={{ borderRadius: 2, fontWeight: 700, borderColor: accent, color: accent }}
              >
                Duyệt không công
              </Button>
              <Button
                variant="contained"
                startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
                disabled={acting}
                onClick={() => directorReview(true, true)}
                sx={{
                  borderRadius: 2,
                  px: 2.5,
                  fontWeight: 700,
                  bgcolor: accent,
                  '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
                }}
              >
                Duyệt có công
              </Button>
            </>
          ))}
      </Stack>
    </Box>
  );

  return (
    <>
    <WorkRequestViewShell
      open={open}
      onClose={onClose}
      loading={acting || loading}
      accent={accent}
      icon={<GroupsOutlinedIcon />}
      overline={
        showDirectorActions ? 'Duyệt đề xuất hội thảo · Giám đốc' : 'Chi tiết phiếu'
      }
      title="Cử CBNV tham gia hội thảo"
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
              label={sps.SEMINAR_STATUS_LABEL[row.status] || row.status}
              color={sps.seminarStatusColor(row.status)}
              sx={detailHeaderChipSx.filled}
            />
            {row.withPay != null && (
              <Chip
                size="small"
                variant="outlined"
                label={row.withPay ? 'Có công' : 'Không công'}
                sx={detailHeaderChipSx.outlined}
              />
            )}
            {row.supportAmount && (
              <Chip
                size="small"
                variant="outlined"
                label={`Hỗ trợ ${row.supportAmount}`}
                color="success"
                sx={detailHeaderChipSx.outlined}
              />
            )}
            <Chip
              size="small"
              variant="outlined"
              label={row.plannedPeriod || sps.formatSeminarDate(row.startDate)}
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
          {showDirectorActions && (
            <InfoBanner>
              Chọn <strong>Duyệt có công</strong> hoặc <strong>Duyệt không công</strong>. Bật công tắc{' '}
              <strong>Cấp tiền hỗ trợ</strong> nếu cần và nhập số tiền trước khi duyệt.
            </InfoBanner>
          )}
          {err && (
            <Typography color="error" variant="body2">
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
                label="Vị trí"
                value={row.positionTitle}
                icon={<WorkOutlineIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Khoa/Phòng"
                value={row.departmentName}
                icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Khoa/Phòng đề xuất"
                value={row.proposingDepartment}
                icon={<GroupsOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Người lập phiếu"
                value={row.requestedByUsername}
                icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
              />
            </DetailFields>
          </FormSection>

          <FormSection title="Nội dung hội thảo">
            <DetailFields>
              <DetailField
                wide
                label="Tên hội thảo"
                value={row.seminarName}
                icon={<MenuBookOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Địa điểm"
                value={row.location}
                icon={<LocationOnOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Thời gian"
                value={row.plannedPeriod}
                icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Phạm vi tính công"
                value={sps.seminarScopeLabel(row.attendanceScope)}
                icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                wide
                label="Lý do đề xuất"
                value={row.reason}
                icon={<NotesOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              {row.supportAmount && (
                <DetailField
                  label="Tiền hỗ trợ"
                  value={row.supportAmount}
                  icon={<PaymentsOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              )}
            </DetailFields>
          </FormSection>

          {(row.hrReviewedAt ||
            row.hrReviewerUsername ||
            row.directorReviewedAt ||
            row.directorReviewerUsername) && (
            <FormSection title="Lịch sử duyệt">
              <Stack spacing={1.5}>
                {(row.hrReviewedAt || row.hrReviewerUsername) && (
                  <ApprovalReviewNoteCard
                    role={`HCNS · ${row.hrReviewerUsername || '—'}${
                      row.withPay == null ? '' : row.withPay ? ' · Có công' : ' · Không công'
                    }`}
                    timestamp={row.hrReviewedAt}
                    comment={row.hrComment}
                    signatureUrl={row.hrSignatureUrl}
                    formatTimestamp={sps.formatSeminarDateTime}
                  />
                )}
                {(row.directorReviewedAt || row.directorReviewerUsername) && (
                  <ApprovalReviewNoteCard
                    role={`Giám đốc · ${row.directorReviewerUsername || '—'}${
                      row.withPay == null ? '' : row.withPay ? ' · Có công' : ' · Không công'
                    }${row.supportAmount ? ` · Hỗ trợ ${row.supportAmount}` : ''}`}
                    timestamp={row.directorReviewedAt}
                    comment={row.directorComment}
                    signatureUrl={row.directorSignatureUrl}
                    formatTimestamp={sps.formatSeminarDateTime}
                  />
                )}
              </Stack>
            </FormSection>
          )}

          {showDirectorActions && (
            <FormSection title="Ý kiến Giám đốc">
              <Stack spacing={2}>
                <Box
                  sx={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: 2,
                    px: 1.5,
                    py: 1.25,
                    borderRadius: 2,
                    bgcolor: alpha(accent, 0.06),
                    border: `1px solid ${alpha(accent, 0.15)}`,
                  }}
                >
                  <Typography variant="body2" fontWeight={600}>
                    Cấp tiền hỗ trợ hội thảo
                  </Typography>
                  <Switch
                    checked={grantSupport}
                    onChange={(e) => {
                      setGrantSupport(e.target.checked);
                      if (!e.target.checked) setSupportAmount('');
                    }}
                    sx={{
                      '& .MuiSwitch-switchBase.Mui-checked': { color: accent },
                      '& .MuiSwitch-switchBase.Mui-checked + .MuiSwitch-track': {
                        bgcolor: accent,
                      },
                    }}
                  />
                </Box>
                {grantSupport && (
                  <TextField
                    fullWidth
                    required
                    size="small"
                    label="Số tiền hỗ trợ"
                    placeholder="VD: 2.000.000 đ"
                    value={supportAmount}
                    onChange={(e) => setSupportAmount(e.target.value)}
                    sx={dateTimeFieldSx}
                    autoFocus
                  />
                )}
                <TextField
                  fullWidth
                  size="small"
                  multiline
                  minRows={2}
                  label="Ghi chú duyệt (tuỳ chọn)"
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  sx={dateTimeFieldSx}
                />
              </Stack>
            </FormSection>
          )}
        </>
      ) : null}
    </WorkRequestViewShell>
    {row && (
      <SeminarProposalDialog
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSubmitted={handleEditSaved}
        editProposal={row}
        employee={{
          id: row.employeeId,
          fullName: row.employeeName,
          departmentName: row.departmentName || undefined,
          positionTitle: row.positionTitle || undefined,
          dateOfBirth: row.dateOfBirth,
        }}
      />
    )}
    </>
  );
}
