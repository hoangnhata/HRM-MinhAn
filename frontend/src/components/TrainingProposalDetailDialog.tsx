import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import MenuBookOutlinedIcon from '@mui/icons-material/MenuBookOutlined';
import NotesOutlinedIcon from '@mui/icons-material/NotesOutlined';
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import SchoolOutlinedIcon from '@mui/icons-material/SchoolOutlined';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import WorkOutlineIcon from '@mui/icons-material/WorkOutline';
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
import { RequestOwnerActions } from './requests/RequestOwnerActions';
import { TrainingProposalDialog } from './TrainingProposalDialog';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import * as tps from '../services/trainingProposalService';
import { canEditOwnPendingRequest } from '../utils/requestEditAccess';

type Props = {
  open: boolean;
  proposalId: number | null;
  onClose: () => void;
  canHrReview?: boolean;
  canDirectorReview?: boolean;
  canComplete?: boolean;
  canCancel?: boolean;
  onChanged?: () => void;
};

export function TrainingProposalDetailDialog({
  open,
  proposalId,
  onClose,
  canHrReview = false,
  canDirectorReview = false,
  canComplete = false,
  canCancel = false,
  onChanged,
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = '#0369a1';
  const [row, setRow] = useState<tps.TrainingProposal | null>(null);
  const [loading, setLoading] = useState(false);
  const [acting, setActing] = useState(false);
  const [hrComment, setHrComment] = useState('');
  const [directorComment, setDirectorComment] = useState('');
  const [monthlySupport, setMonthlySupport] = useState('');
  const [postCourseCommitment, setPostCourseCommitment] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);

  useEffect(() => {
    if (!open || proposalId == null) {
      setRow(null);
      setHrComment('');
      setDirectorComment('');
      setMonthlySupport('');
      setPostCourseCommitment('');
      setErr(null);
      return;
    }
    setLoading(true);
    tps
      .fetchTrainingProposalDetail(proposalId)
      .then((d) => {
        setRow(d);
        setHrComment(d.hrComment || '');
        setDirectorComment(d.directorComment || '');
        setMonthlySupport(d.monthlySupport || '');
        setPostCourseCommitment(d.postCourseCommitment || '');
        setErr(null);
      })
      .catch(() => setErr('Không tải được chi tiết phiếu.'))
      .finally(() => setLoading(false));
  }, [open, proposalId]);

  const reviewLocked = row?.status === 'COMPLETED' || row?.status === 'CANCELLED';
  const directorPending = row?.status === 'PENDING_DIRECTOR';
  const hrPending = row?.status === 'PENDING_HR';
  const showDirectorActions =
    canDirectorReview &&
    !reviewLocked &&
    (directorPending || Boolean(row?.directorReviewedAt));
  const showHrActions =
    canHrReview &&
    !reviewLocked &&
    (hrPending || Boolean(row?.hrReviewedAt));
  const hrCorrecting = Boolean(showHrActions && !hrPending && row?.hrReviewedAt);
  const directorCorrecting = Boolean(
    showDirectorActions && !directorPending && row?.directorReviewedAt,
  );
  const showComplete = canComplete && row?.status === 'APPROVED';
  const showCancel =
    (canCancel
      || user?.role === 'ADMIN'
      || (Boolean(row?.requestedByUsername)
        && Boolean(user?.username)
        && row!.requestedByUsername === user!.username)) &&
    row != null &&
    row.status !== 'CANCELLED';
  const showEdit = Boolean(row && canEditOwnPendingRequest(row, user));
  const showReviewActions = showHrActions || showDirectorActions;

  function reloadRow() {
    if (proposalId == null) return;
    tps
      .fetchTrainingProposalDetail(proposalId)
      .then((d) => {
        setRow(d);
        setHrComment(d.hrComment || '');
        setDirectorComment(d.directorComment || '');
        setMonthlySupport(d.monthlySupport || '');
        setPostCourseCommitment(d.postCourseCommitment || '');
      })
      .catch(() => setErr('Không tải được chi tiết phiếu.'));
  }

  function handleEditSaved() {
    reloadRow();
    onChanged?.();
    setEditOpen(false);
  }

  async function reviewHr(approved: boolean) {
    if (!row) return;
    if (approved) {
      if (!monthlySupport.trim()) {
        setErr('Vui lòng nhập tiền hỗ trợ hàng tháng.');
        return;
      }
      if (!postCourseCommitment.trim()) {
        setErr('Vui lòng nhập thời gian cam kết sau khóa học.');
        return;
      }
    }
    setActing(true);
    setErr(null);
    try {
      await ensureHasSignature();
      await tps.hrReviewTrainingProposal(
        row.id,
        approved,
        hrComment,
        monthlySupport,
        postCourseCommitment,
      );
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, approved ? 'Duyệt thất bại.' : 'Từ chối thất bại.'));
    } finally {
      setActing(false);
    }
  }

  async function reviewDirector(approved: boolean) {
    if (!row) return;
    setActing(true);
    setErr(null);
    try {
      await ensureHasSignature();
      await tps.directorReviewTrainingProposal(row.id, approved, directorComment);
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, approved ? 'Duyệt thất bại.' : 'Từ chối thất bại.'));
    } finally {
      setActing(false);
    }
  }

  async function markComplete() {
    if (!row) return;
    setActing(true);
    setErr(null);
    try {
      await tps.completeTrainingProposal(row.id);
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Không đánh dấu hoàn thành được.'));
    } finally {
      setActing(false);
    }
  }

  async function cancelProposal() {
    if (!row || !window.confirm('Thu hồi phiếu đề xuất đào tạo này?')) return;
    setActing(true);
    setErr(null);
    try {
      await tps.cancelTrainingProposal(row.id);
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Không thu hồi được phiếu.'));
    } finally {
      setActing(false);
    }
  }

  const hrApproveReady =
    monthlySupport.trim().length > 0 && postCourseCommitment.trim().length > 0;

  const footer =
    showReviewActions || showComplete || showCancel || showEdit ? (
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
          onCancel={cancelProposal}
        />
        <Button onClick={onClose} disabled={acting} variant="outlined" color="inherit" sx={{ borderRadius: 2 }}>
          Đóng
        </Button>
        {showHrActions &&
          (hrCorrecting ? (
            <Button
              variant="contained"
              disabled={acting || loading || !hrApproveReady}
              startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
              onClick={() => reviewHr(true)}
              sx={{
                borderRadius: 2,
                px: 2.5,
                fontWeight: 700,
                bgcolor: accent,
                '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
              }}
            >
              Lưu chỉnh sửa · HCNS
            </Button>
          ) : (
            <>
              <Button
                color="error"
                variant="outlined"
                disabled={acting || loading}
                startIcon={<CloseIcon />}
                onClick={() => reviewHr(false)}
                sx={{ borderRadius: 2, fontWeight: 700 }}
              >
                Từ chối
              </Button>
              <Button
                variant="contained"
                disabled={acting || loading || !hrApproveReady}
                startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
                onClick={() => reviewHr(true)}
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
        {showDirectorActions &&
          (directorCorrecting ? (
            <Button
              variant="contained"
              disabled={acting || loading}
              startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
              onClick={() => reviewDirector(true)}
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
                onClick={() => reviewDirector(false)}
                sx={{ borderRadius: 2, fontWeight: 700 }}
              >
                Từ chối
              </Button>
              <Button
                variant="contained"
                disabled={acting || loading}
                startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
                onClick={() => reviewDirector(true)}
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
        {showComplete && (
          <Button
            variant="contained"
            disabled={acting || loading}
            startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
            onClick={() => markComplete()}
            sx={{
              borderRadius: 2,
              px: 2.5,
              fontWeight: 700,
              bgcolor: '#ca8a04',
              '&:hover': { bgcolor: '#ca8a04', filter: 'brightness(0.92)' },
            }}
          >
            Hoàn thành đào tạo
          </Button>
        )}
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
      icon={<SchoolOutlinedIcon />}
      overline={showReviewActions ? 'Duyệt đề xuất đào tạo' : 'Chi tiết phiếu'}
      title="Cử CBNV đào tạo, bồi dưỡng"
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
              label={tps.TRAINING_STATUS_LABEL[row.status] || row.status}
              color={tps.trainingStatusColor(row.status)}
              sx={detailHeaderChipSx.filled}
            />
            <Chip
              size="small"
              variant="outlined"
              label={row.courseName}
              sx={{ ...detailHeaderChipSx.outlined, maxWidth: 280 }}
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
              {showHrActions
                ? 'HCNS nhập tiền hỗ trợ hàng tháng và thời gian cam kết sau khóa học, sau đó chọn Duyệt để chuyển Ban Giám đốc.'
                : 'Giám đốc kết luận duyệt hoặc từ chối trước khi ký quyết định đào tạo chính thức.'}
            </InfoBanner>
          )}
          {showDirectorActions && row.monthlySupport && row.postCourseCommitment && (
            <InfoBanner>
              HCNS đã xác nhận hỗ trợ <strong>{row.monthlySupport}</strong>/tháng, cam kết làm việc{' '}
              <strong>{row.postCourseCommitment}</strong> sau khóa học.
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
                label="Ngày sinh"
                value={tps.formatTrainingDate(row.dateOfBirth)}
                icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
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
                icon={<SchoolOutlinedIcon sx={{ fontSize: 16 }} />}
              />
            </DetailFields>
          </FormSection>

          <FormSection title="Nội dung đào tạo">
            <DetailFields>
              <DetailField
                wide
                label="Tên khoá học"
                value={row.courseName}
                icon={<MenuBookOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Địa điểm học"
                value={row.location}
                icon={<LocationOnOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Thời gian dự kiến"
                value={row.plannedPeriod}
                icon={<ScheduleOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Học phí khóa học"
                value={row.tuitionFee}
                icon={<PaymentsOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              {(row.monthlySupport || row.postCourseCommitment) && (
                <>
                  <DetailField
                    label="Tiền hỗ trợ hàng tháng"
                    value={row.monthlySupport}
                    icon={<PaymentsOutlinedIcon sx={{ fontSize: 16 }} />}
                  />
                  <DetailField
                    label="Cam kết sau khóa học"
                    value={row.postCourseCommitment}
                    icon={<ScheduleOutlinedIcon sx={{ fontSize: 16 }} />}
                  />
                </>
              )}
              <DetailField
                wide
                label="Mục tiêu đào tạo"
                value={row.trainingGoal}
                icon={<NotesOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                wide
                label="Lý do đề xuất"
                value={row.reason}
                icon={<NotesOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Người lập phiếu"
                value={row.requestedByUsername}
                icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Ngày tạo"
                value={tps.formatTrainingDateTime(row.createdAt)}
                icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
              />
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
                      row.monthlySupport ? ` · Hỗ trợ ${row.monthlySupport}/tháng` : ''
                    }${row.postCourseCommitment ? ` · Cam kết ${row.postCourseCommitment}` : ''}`}
                    timestamp={row.hrReviewedAt}
                    comment={row.hrComment}
                    signatureUrl={row.hrSignatureUrl}
                    formatTimestamp={tps.formatTrainingDateTime}
                  />
                )}
                {(row.directorReviewedAt || row.directorReviewerUsername) && (
                  <ApprovalReviewNoteCard
                    role={`Giám đốc · ${row.directorReviewerUsername || '—'}`}
                    timestamp={row.directorReviewedAt}
                    comment={row.directorComment}
                    signatureUrl={row.directorSignatureUrl}
                    formatTimestamp={tps.formatTrainingDateTime}
                  />
                )}
              </Stack>
            </FormSection>
          )}

          {showHrActions && (
            <FormSection title="Thông tin HCNS bổ sung">
              <Stack spacing={2}>
                <TextField
                  fullWidth
                  required
                  size="small"
                  label="Tiền hỗ trợ hàng tháng"
                  placeholder="VD: 5.000.000 đ"
                  value={monthlySupport}
                  onChange={(e) => setMonthlySupport(e.target.value)}
                  sx={dateTimeFieldSx}
                />
                <TextField
                  fullWidth
                  required
                  size="small"
                  label="Thời gian cam kết sau khóa học"
                  placeholder="VD: 24 tháng"
                  value={postCourseCommitment}
                  onChange={(e) => setPostCourseCommitment(e.target.value)}
                  sx={dateTimeFieldSx}
                />
              </Stack>
            </FormSection>
          )}

          {showHrActions && (
            <FormSection title="Ý kiến HCNS">
              <TextField
                fullWidth
                size="small"
                multiline
                minRows={2}
                label="Ghi chú duyệt (tuỳ chọn)"
                value={hrComment}
                onChange={(e) => setHrComment(e.target.value)}
                sx={dateTimeFieldSx}
              />
            </FormSection>
          )}

          {showDirectorActions && (
            <FormSection title="Ý kiến Giám đốc">
              <TextField
                fullWidth
                size="small"
                multiline
                minRows={2}
                label="Ghi chú duyệt (tuỳ chọn)"
                value={directorComment}
                onChange={(e) => setDirectorComment(e.target.value)}
                sx={dateTimeFieldSx}
              />
            </FormSection>
          )}
        </>
      ) : null}
    </WorkRequestViewShell>
    {row && (
      <TrainingProposalDialog
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
