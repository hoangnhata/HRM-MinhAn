import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import HomeOutlinedIcon from '@mui/icons-material/HomeOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import NotesOutlinedIcon from '@mui/icons-material/NotesOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import PhoneOutlinedIcon from '@mui/icons-material/PhoneOutlined';
import SchoolOutlinedIcon from '@mui/icons-material/SchoolOutlined';
import WcOutlinedIcon from '@mui/icons-material/WcOutlined';
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
import { useTheme } from '@mui/material/styles';
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
import { MainDutyAuthorizationDialog } from './MainDutyAuthorizationDialog';
import { RequestOwnerActions } from './requests/RequestOwnerActions';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import * as mda from '../services/mainDutyAuthorizationService';
import { canEditOwnPendingRequest } from '../utils/requestEditAccess';

type Props = {
  open: boolean;
  authorizationId: number | null;
  onClose: () => void;
  canHeadReview?: boolean;
  canNursingHeadReview?: boolean;
  canDirectorReview?: boolean;
  /** Cho phép thu hồi (ADMIN / người lập). Dialog cũng tự nhận diện người lập. */
  canCancel?: boolean;
  onChanged?: () => void;
};

export function MainDutyAuthorizationDetailDialog({
  open,
  authorizationId,
  onClose,
  canHeadReview = false,
  canNursingHeadReview = false,
  canDirectorReview = false,
  canCancel = false,
  onChanged,
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = '#5b4bb4';
  const [row, setRow] = useState<mda.MainDutyAuthorization | null>(null);
  const [loading, setLoading] = useState(false);
  const [acting, setActing] = useState(false);
  const [headComment, setHeadComment] = useState('');
  const [nursingHeadComment, setNursingHeadComment] = useState('');
  const [directorComment, setDirectorComment] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);

  useEffect(() => {
    if (!open || authorizationId == null) {
      setRow(null);
      setHeadComment('');
      setNursingHeadComment('');
      setDirectorComment('');
      setErr(null);
      return;
    }
    setLoading(true);
    mda
      .fetchMainDutyAuthorizationDetail(authorizationId)
      .then((d) => {
        setRow(d);
        setHeadComment(d.headComment || '');
        setNursingHeadComment(d.nursingHeadComment || '');
        setDirectorComment(d.directorComment || '');
        setErr(null);
      })
      .catch((ex) => setErr(extractApiErrorMessage(ex, 'Không tải được đơn.')))
      .finally(() => setLoading(false));
  }, [open, authorizationId]);

  const reviewLocked = row?.status === 'CANCELLED';
  const directorPending = row?.status === 'PENDING_DIRECTOR';
  const nursingHeadPending = row?.status === 'PENDING_NURSING_HEAD';
  const headPending = row?.status === 'PENDING_HEAD';
  const showDirectorActions =
    canDirectorReview &&
    !reviewLocked &&
    (directorPending || Boolean(row?.directorReviewedAt));
  const showNursingHeadActions =
    canNursingHeadReview &&
    !reviewLocked &&
    !directorPending &&
    (nursingHeadPending || Boolean(row?.nursingHeadReviewedAt));
  const showHeadActions =
    canHeadReview &&
    !reviewLocked &&
    !directorPending &&
    !nursingHeadPending &&
    (headPending || Boolean(row?.headReviewedAt));
  const headCorrecting = Boolean(showHeadActions && !headPending && row?.headReviewedAt);
  const nursingHeadCorrecting = Boolean(
    showNursingHeadActions && !nursingHeadPending && row?.nursingHeadReviewedAt,
  );
  const directorCorrecting = Boolean(
    showDirectorActions && !directorPending && row?.directorReviewedAt,
  );
  const showReviewActions = showHeadActions || showNursingHeadActions || showDirectorActions;
  const isCreator =
    Boolean(row?.requestedByUsername)
    && Boolean(user?.username)
    && row!.requestedByUsername === user!.username;
  const allowCancel = canCancel || user?.role === 'ADMIN' || isCreator;
  const showCancel =
    allowCancel &&
    row != null &&
    row.status !== 'CANCELLED';
  const showEdit = Boolean(row && canEditOwnPendingRequest(row, user));

  function reloadRow() {
    if (authorizationId == null) return;
    mda
      .fetchMainDutyAuthorizationDetail(authorizationId)
      .then((d) => {
        setRow(d);
        setHeadComment(d.headComment || '');
        setNursingHeadComment(d.nursingHeadComment || '');
        setDirectorComment(d.directorComment || '');
      })
      .catch((ex) => setErr(extractApiErrorMessage(ex, 'Không tải được đơn.')));
  }

  function handleEditSaved() {
    reloadRow();
    onChanged?.();
    setEditOpen(false);
  }

  async function review(step: 'head' | 'nursingHead' | 'director', approved: boolean) {
    if (!row) return;
    setActing(true);
    setErr(null);
    try {
      await ensureHasSignature();
      if (step === 'head') {
        await mda.headReviewMainDutyAuthorization(row.id, approved, headComment);
      } else if (step === 'nursingHead') {
        await mda.nursingHeadReviewMainDutyAuthorization(row.id, approved, nursingHeadComment);
      } else {
        await mda.directorReviewMainDutyAuthorization(row.id, approved, directorComment);
      }
      onChanged?.();
      onClose();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Duyệt đơn thất bại.'));
    } finally {
      setActing(false);
    }
  }

  async function handleCancel() {
    if (!row || !window.confirm('Thu hồi đơn trực chính này?')) return;
    setActing(true);
    setErr(null);
    try {
      await mda.cancelMainDutyAuthorization(row.id);
      onChanged?.();
      onClose();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Thu hồi đơn thất bại.'));
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
          onCancel={handleCancel}
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
        {showHeadActions &&
          (headCorrecting ? (
            <Button
              variant="contained"
              startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
              disabled={acting}
              onClick={() => review('head', true)}
              sx={{
                borderRadius: 2,
                px: 2.5,
                fontWeight: 700,
                bgcolor: accent,
                '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
              }}
            >
              Lưu chỉnh sửa · Trưởng khoa
            </Button>
          ) : (
            <>
              <Button
                color="error"
                variant="outlined"
                startIcon={<CloseIcon />}
                disabled={acting}
                onClick={() => review('head', false)}
                sx={{ borderRadius: 2, fontWeight: 700 }}
              >
                Từ chối
              </Button>
              <Button
                variant="contained"
                startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
                disabled={acting}
                onClick={() => review('head', true)}
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
        {showNursingHeadActions &&
          (nursingHeadCorrecting ? (
            <Button
              variant="contained"
              startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
              disabled={acting}
              onClick={() => review('nursingHead', true)}
              sx={{
                borderRadius: 2,
                px: 2.5,
                fontWeight: 700,
                bgcolor: accent,
                '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
              }}
            >
              Lưu chỉnh sửa · Trưởng phòng ĐD
            </Button>
          ) : (
            <>
              <Button
                color="error"
                variant="outlined"
                startIcon={<CloseIcon />}
                disabled={acting}
                onClick={() => review('nursingHead', false)}
                sx={{ borderRadius: 2, fontWeight: 700 }}
              >
                Từ chối
              </Button>
              <Button
                variant="contained"
                startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
                disabled={acting}
                onClick={() => review('nursingHead', true)}
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
              startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
              disabled={acting}
              onClick={() => review('director', true)}
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
                onClick={() => review('director', false)}
                sx={{ borderRadius: 2, fontWeight: 700 }}
              >
                Từ chối
              </Button>
              <Button
                variant="contained"
                startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
                disabled={acting}
                onClick={() => review('director', true)}
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
  );

  return (
    <>
    <WorkRequestViewShell
      open={open}
      onClose={onClose}
      loading={acting || loading}
      accent={accent}
      icon={<NightsStayIcon />}
      overline={
        showHeadActions
          ? 'Duyệt đơn trực chính · Trưởng khoa'
          : showNursingHeadActions
            ? 'Duyệt đơn trực chính · Trưởng phòng ĐD'
            : showDirectorActions
              ? 'Duyệt đơn trực chính · Giám đốc'
              : `Đơn trực chính · ${row?.formTypeLabel ?? ''}`
      }
      title={row?.employeeName ?? 'Chi tiết đơn trực chính'}
      description={
        row
          ? `${row.positionTitle || '—'}${row.departmentName ? ` · ${row.departmentName}` : ''}`
          : loading
            ? 'Đang tải…'
            : err || '—'
      }
      maxWidth="md"
      footer={footer}
      headerExtra={
        row ? (
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Chip size="small" label={row.formTypeLabel} sx={detailHeaderChipSx.filled} />
            <Chip
              size="small"
              color={mda.mainDutyStatusColor(row.status)}
              label={mda.MAIN_DUTY_STATUS_LABEL[row.status] ?? row.status}
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
        <Stack spacing={2.5}>
          {err && (
            <Typography color="error" variant="body2">
              {err}
            </Typography>
          )}
          {showReviewActions && (
            <InfoBanner>
              Duyệt sẽ gắn <strong>chữ ký điện tử</strong> của bạn vào phiếu.
            </InfoBanner>
          )}

          <FormSection title="Nhân viên">
            <DetailFields>
              <DetailField icon={<PersonOutlineIcon />} label="Họ tên" value={row.employeeName} />
              <DetailField
                icon={<BadgeOutlinedIcon />}
                label="Mã NV"
                value={row.employeeCode || '—'}
              />
              <DetailField
                icon={<WorkOutlineIcon />}
                label="Chức danh"
                value={row.positionTitle || '—'}
              />
              <DetailField
                icon={<BusinessOutlinedIcon />}
                label="Khoa/phòng"
                value={row.departmentName || '—'}
              />
            </DetailFields>
          </FormSection>

          <FormSection title="Thời gian trực kèm & hiệu lực">
            <DetailFields>
              <DetailField
                icon={<CalendarMonthOutlinedIcon />}
                label="Trực kèm từ"
                value={mda.formatMainDutyDate(row.accompanyingFrom)}
              />
              <DetailField
                icon={<CalendarMonthOutlinedIcon />}
                label="Trực kèm đến"
                value={mda.formatMainDutyDate(row.accompanyingTo)}
              />
              <DetailField
                icon={<CalendarMonthOutlinedIcon />}
                label="Hiệu lực trực chính"
                value={mda.formatMainDutyDate(row.effectiveFrom)}
              />
            </DetailFields>
          </FormSection>

          {(row.phone || row.address || row.gender || row.degree) && (
            <FormSection title="Thông tin bổ sung">
              <DetailFields>
                {row.phone && (
                  <DetailField icon={<PhoneOutlinedIcon />} label="Điện thoại" value={row.phone} />
                )}
                {row.gender && (
                  <DetailField icon={<WcOutlinedIcon />} label="Giới tính" value={row.gender} />
                )}
                {row.address && (
                  <DetailField icon={<HomeOutlinedIcon />} label="Địa chỉ" value={row.address} />
                )}
                {row.degree && (
                  <DetailField icon={<SchoolOutlinedIcon />} label="Bằng cấp" value={row.degree} />
                )}
              </DetailFields>
            </FormSection>
          )}

          {row.reason && (
            <FormSection title="Lý do / đề nghị">
              <DetailField icon={<NotesOutlinedIcon />} label="Nội dung" value={row.reason} />
            </FormSection>
          )}

          {(row.headComment || row.headReviewedAt || row.headSignatureUrl) && (
            <ApprovalReviewNoteCard
              role={`Trưởng khoa · ${row.headReviewerUsername || '—'}`}
              timestamp={row.headReviewedAt}
              comment={row.headComment}
              signatureUrl={row.headSignatureUrl}
            />
          )}
          {(row.nursingHeadComment ||
            row.nursingHeadReviewedAt ||
            row.nursingHeadSignatureUrl) && (
            <ApprovalReviewNoteCard
              role={`Trưởng phòng ĐD · ${row.nursingHeadReviewerUsername || '—'}`}
              timestamp={row.nursingHeadReviewedAt}
              comment={row.nursingHeadComment}
              signatureUrl={row.nursingHeadSignatureUrl}
            />
          )}
          {(row.hrComment || row.hrReviewedAt || row.hrSignatureUrl) && (
            <ApprovalReviewNoteCard
              role={`HCNS · ${row.hrReviewerUsername || '—'}`}
              timestamp={row.hrReviewedAt}
              comment={row.hrComment}
              signatureUrl={row.hrSignatureUrl}
            />
          )}
          {(row.directorComment || row.directorReviewedAt || row.directorSignatureUrl) && (
            <ApprovalReviewNoteCard
              role={`Giám đốc · ${row.directorReviewerUsername || '—'}`}
              timestamp={row.directorReviewedAt}
              comment={row.directorComment}
              signatureUrl={row.directorSignatureUrl}
            />
          )}

          {showHeadActions && (
            <FormSection title="Ý kiến Trưởng khoa">
              <TextField
                fullWidth
                multiline
                minRows={2}
                size="small"
                label="Ghi chú duyệt (tuỳ chọn)"
                value={headComment}
                onChange={(e) => setHeadComment(e.target.value)}
                sx={dateTimeFieldSx}
              />
            </FormSection>
          )}

          {showNursingHeadActions && (
            <FormSection title="Ý kiến Trưởng phòng Điều dưỡng">
              <TextField
                fullWidth
                multiline
                minRows={2}
                size="small"
                label="Ghi chú duyệt (tuỳ chọn)"
                value={nursingHeadComment}
                onChange={(e) => setNursingHeadComment(e.target.value)}
                sx={dateTimeFieldSx}
              />
            </FormSection>
          )}

          {showDirectorActions && (
            <FormSection title="Ý kiến Giám đốc">
              <TextField
                fullWidth
                multiline
                minRows={2}
                size="small"
                label="Ghi chú duyệt (tuỳ chọn)"
                value={directorComment}
                onChange={(e) => setDirectorComment(e.target.value)}
                sx={dateTimeFieldSx}
              />
            </FormSection>
          )}
        </Stack>
      ) : null}
    </WorkRequestViewShell>
    {row && (
      <MainDutyAuthorizationDialog
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSubmitted={handleEditSaved}
        editAuthorization={row}
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
