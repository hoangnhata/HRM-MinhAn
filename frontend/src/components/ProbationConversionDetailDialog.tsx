import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import EventAvailableOutlinedIcon from '@mui/icons-material/EventAvailableOutlined';
import FactCheckOutlinedIcon from '@mui/icons-material/FactCheckOutlined';
import HowToRegIcon from '@mui/icons-material/HowToReg';
import NotesOutlinedIcon from '@mui/icons-material/NotesOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import WorkOutlineIcon from '@mui/icons-material/WorkOutline';
import {
  Box,
  Button,
  Chip,
  CircularProgress,
  LinearProgress,
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
import { ProbationConversionDialog } from './ProbationConversionDialog';
import { RequestOwnerActions } from './requests/RequestOwnerActions';
import * as pcs from '../services/probationConversionService';
import {
  ensureHasSignature,
  extractApiErrorMessage,
} from '../services/approvalSignatureService';
import { canEditOwnPendingRequest } from '../utils/requestEditAccess';

type Props = {
  open: boolean;
  conversionId: number | null;
  onClose: () => void;
  canNursingHeadReview?: boolean;
  canHrReview?: boolean;
  canDirectorReview?: boolean;
  canCancel?: boolean;
  onChanged?: () => void;
};

const SCORE_LABELS: Record<string, string> = {
  knowledge: 'Kiến thức chuyên môn',
  clinical: 'Kỹ năng lâm sàng & thực hành',
  admin: 'Nghiệp vụ hành chính',
  attitude: 'Thái độ - đạo đức',
  learning: 'Học tập & phát triển',
  effectiveness: 'Hiệu quả công việc',
  practice: 'Kỹ năng thực hành',
  teamwork: 'Phối hợp & học tập',
};

function criterionMax(formType: pcs.ProbationFormType, code: string) {
  if (formType === 'DOCTOR') return 5;
  if (code === 'knowledge') return 30;
  if (code === 'practice') return 40;
  if (code === 'attitude') return 20;
  if (code === 'teamwork') return 10;
  return 0;
}

function EvaluationComment({ label, value }: { label: string; value: string }) {
  const theme = useTheme();
  return (
    <Box
      sx={{
        p: 1.5,
        borderRadius: 2,
        bgcolor: alpha(theme.palette.primary.main, 0.035),
        border: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
      }}
    >
      <Typography
        variant="caption"
        sx={{
          fontWeight: 700,
          letterSpacing: '0.04em',
          textTransform: 'uppercase',
          fontSize: '0.68rem',
          color: 'text.secondary',
        }}
      >
        {label}
      </Typography>
      <Typography variant="body2" sx={{ mt: 0.5, lineHeight: 1.65, whiteSpace: 'pre-wrap', fontWeight: 600 }}>
        {value}
      </Typography>
    </Box>
  );
}

export function ProbationConversionDetailDialog({
  open,
  conversionId,
  onClose,
  canNursingHeadReview = false,
  canHrReview = false,
  canDirectorReview = false,
  canCancel = false,
  onChanged,
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = '#15803d';
  const [row, setRow] = useState<pcs.ProbationConversion | null>(null);
  const [loading, setLoading] = useState(false);
  const [acting, setActing] = useState(false);
  const [nursingHeadComment, setNursingHeadComment] = useState('');
  const [hrComment, setHrComment] = useState('');
  const [directorComment, setDirectorComment] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);

  useEffect(() => {
    if (!open || conversionId == null) {
      setRow(null);
      setNursingHeadComment('');
      setHrComment('');
      setDirectorComment('');
      setErr(null);
      return;
    }
    setLoading(true);
    setErr(null);
    setNursingHeadComment('');
    setHrComment('');
    setDirectorComment('');
    pcs
      .fetchConversionDetail(conversionId)
      .then((d) => {
        setRow(d);
        setNursingHeadComment(d.nursingHeadComment || '');
        setHrComment(d.hrComment || '');
        setDirectorComment(d.directorComment || '');
      })
      .catch(() => {
        setRow(null);
        setErr('Không tải được chi tiết đơn.');
      })
      .finally(() => setLoading(false));
  }, [open, conversionId]);

  const formType = row?.formType || 'STAFF';
  const scored = true;
  const reviewLocked = row?.status === 'APPLIED' || row?.status === 'CANCELLED';
  const directorPending = row?.status === 'PENDING_DIRECTOR';
  const hrPending = row?.status === 'PENDING_HR';
  const nursingHeadPending = row?.status === 'PENDING_NURSING_HEAD';
  const showDirectorActions =
    canDirectorReview &&
    !reviewLocked &&
    (directorPending || Boolean(row?.directorReviewedAt));
  const showHrActions =
    canHrReview &&
    !reviewLocked &&
    !directorPending &&
    (hrPending || Boolean(row?.hrReviewedAt));
  const showNursingHeadActions =
    canNursingHeadReview &&
    !reviewLocked &&
    !directorPending &&
    !hrPending &&
    (nursingHeadPending || Boolean(row?.nursingHeadReviewedAt));
  const nursingHeadCorrecting = Boolean(
    showNursingHeadActions && !nursingHeadPending && row?.nursingHeadReviewedAt,
  );
  const hrCorrecting = Boolean(showHrActions && !hrPending && row?.hrReviewedAt);
  const directorCorrecting = Boolean(
    showDirectorActions && !directorPending && row?.directorReviewedAt,
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
  const showReviewActions = showNursingHeadActions || showHrActions || showDirectorActions;
  const scores = pcs.parseScoresJson(row?.scoresJson);
  const gradeColor =
    row?.gradeLabel === 'Tốt' || row?.gradeLabel === 'Xuất sắc'
      ? theme.palette.success.main
      : row?.gradeLabel === 'Khá' || row?.gradeLabel === 'Đạt yêu cầu'
        ? theme.palette.info.main
        : theme.palette.warning.main;

  function reloadRow() {
    if (conversionId == null) return;
    pcs
      .fetchConversionDetail(conversionId)
      .then((d) => {
        setRow(d);
        setNursingHeadComment(d.nursingHeadComment || '');
        setHrComment(d.hrComment || '');
        setDirectorComment(d.directorComment || '');
      })
      .catch(() => setErr('Không tải được chi tiết đơn.'));
  }

  function handleEditSaved() {
    reloadRow();
    onChanged?.();
    setEditOpen(false);
  }

  async function reviewNursingHead(approved: boolean) {
    if (!row) return;
    setActing(true);
    setErr(null);
    try {
      await ensureHasSignature();
      await pcs.nursingHeadReviewConversion(row.id, approved, nursingHeadComment || undefined);
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, approved ? 'Duyệt thất bại.' : 'Từ chối thất bại.'));
    } finally {
      setActing(false);
    }
  }

  async function reviewHr(approved: boolean) {
    if (!row) return;
    setActing(true);
    setErr(null);
    try {
      await ensureHasSignature();
      await pcs.hrReviewConversion(row.id, {
        approved,
        comment: hrComment || undefined,
      });
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
      await pcs.directorReviewConversion(row.id, approved, directorComment);
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, approved ? 'Duyệt thất bại.' : 'Từ chối thất bại.'));
    } finally {
      setActing(false);
    }
  }

  async function cancelConversion() {
    if (!row || !window.confirm('Thu hồi đơn chuyển chính thức này?')) return;
    setActing(true);
    setErr(null);
    try {
      await pcs.cancelConversion(row.id);
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Không thu hồi được đơn.'));
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
          onCancel={cancelConversion}
        />
        <Button onClick={onClose} disabled={acting} variant="outlined" color="inherit" sx={{ borderRadius: 2 }}>
          Đóng
        </Button>
        {showNursingHeadActions &&
          (nursingHeadCorrecting ? (
            <Button
              variant="contained"
              disabled={acting || loading}
              startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
              onClick={() => reviewNursingHead(true)}
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
                disabled={acting || loading}
                startIcon={<CloseIcon />}
                onClick={() => reviewNursingHead(false)}
                sx={{ borderRadius: 2, fontWeight: 700 }}
              >
                Từ chối
              </Button>
              <Button
                variant="contained"
                disabled={acting || loading}
                startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <CheckIcon />}
                onClick={() => reviewNursingHead(true)}
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
        {showHrActions &&
          (hrCorrecting ? (
            <Button
              variant="contained"
              disabled={acting || loading}
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
                disabled={acting || loading}
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
      icon={<HowToRegIcon />}
      overline={showReviewActions ? 'Duyệt chuyển chính thức' : 'Chi tiết đơn'}
      title="Đề nghị ký HĐLĐ chính thức"
      description={
        row
          ? `${row.employeeName}${row.employeeCode ? ` · ${row.employeeCode}` : ''}${
              row.formTypeLabel ? ` · ${row.formTypeLabel}` : ''
            }`
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
              label={pcs.CONVERSION_STATUS_LABEL[row.status] || row.status}
              color={pcs.conversionStatusColor(row.status)}
              sx={detailHeaderChipSx.filled}
            />
            {row.formTypeLabel && (
              <Chip
                size="small"
                variant="outlined"
                label={`Mẫu ${row.formTypeLabel}`}
                sx={detailHeaderChipSx.outlined}
              />
            )}
            <Chip
              size="small"
              variant="outlined"
              label={`Ngày ${pcs.formatConversionDate(row.officialDate)}`}
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
              {showNursingHeadActions
                ? 'Sau khi duyệt, đơn chuyển HCNS.'
                : showHrActions
                  ? 'HCNS kiểm tra đơn và chọn Duyệt hoặc Từ chối. Đơn được duyệt sẽ chuyển sang Ban Giám đốc.'
                  : 'Kết luận của Ban Giám đốc: duyệt hoặc từ chối. Nhân viên lên chính thức đúng ngày đã chọn.'}
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
              <DetailField
                label="Phòng ban"
                value={row.departmentName}
                icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Vị trí"
                value={row.positionTitle}
                icon={<WorkOutlineIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Trạng thái hiện tại"
                value={
                  row.employeeStatus === 'INTERN'
                    ? 'Thực tập'
                    : row.employeeStatus === 'PROBATION'
                      ? 'Thử việc'
                      : row.employeeStatus === 'ACTIVE'
                        ? 'Chính thức'
                        : row.employeeStatus || '—'
                }
                icon={<FactCheckOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Mẫu đơn"
                value={row.formTypeLabel || pcs.FORM_TYPE_LABEL[formType]}
                icon={<HowToRegIcon sx={{ fontSize: 16 }} />}
              />
            </DetailFields>
          </FormSection>

          <FormSection title="Nội dung đề nghị">
            <DetailFields>
              <DetailField
                label="Ngày lên chính thức"
                value={pcs.formatConversionDate(row.officialDate)}
                icon={<EventAvailableOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Người lập đơn"
                value={row.requestedByUsername}
                icon={<ScheduleOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                wide
                label="Lý do / nội dung đơn"
                value={row.reason}
                icon={<NotesOutlinedIcon sx={{ fontSize: 16 }} />}
              />
            </DetailFields>
          </FormSection>

          {scored && (
            <FormSection title="Phiếu đánh giá năng lực">
              <Stack spacing={2}>
                <Box
                  sx={{
                    display: 'grid',
                    gridTemplateColumns: { xs: '1fr', sm: 'auto minmax(180px, 1fr)' },
                    alignItems: 'center',
                    gap: { xs: 1.5, sm: 2.5 },
                    p: { xs: 2, sm: 2.25 },
                    borderRadius: 2.5,
                    color: '#fff',
                    background: `linear-gradient(135deg, ${gradeColor}, ${alpha(gradeColor, 0.78)})`,
                    boxShadow: `0 10px 28px ${alpha(gradeColor, 0.2)}`,
                  }}
                >
                  <Stack direction="row" alignItems="center" spacing={1.5}>
                    <Box
                      sx={{
                        width: 44,
                        height: 44,
                        borderRadius: 2.25,
                        display: 'grid',
                        placeItems: 'center',
                        bgcolor: alpha('#fff', 0.16),
                      }}
                    >
                      <FactCheckOutlinedIcon />
                    </Box>
                    <Box>
                      <Typography variant="caption" sx={{ opacity: 0.86, fontWeight: 700 }}>
                        TỔNG KẾT ĐÁNH GIÁ
                      </Typography>
                      <Stack direction="row" alignItems="baseline" spacing={0.75}>
                        <Typography variant="h4" fontWeight={900} lineHeight={1.15}>
                          {row.totalScore ?? '—'}
                        </Typography>
                        <Typography variant="body1" fontWeight={700} sx={{ opacity: 0.82 }}>
                          / {row.maxScore ?? '—'} điểm
                        </Typography>
                      </Stack>
                    </Box>
                  </Stack>
                  <Box
                    sx={{
                      justifySelf: { xs: 'stretch', sm: 'end' },
                      minWidth: { sm: 180 },
                      px: 2,
                      py: 1.25,
                      borderRadius: 2,
                      bgcolor: alpha('#fff', 0.14),
                      border: `1px solid ${alpha('#fff', 0.2)}`,
                    }}
                  >
                    <Typography variant="caption" sx={{ opacity: 0.82 }}>
                      Xếp loại
                    </Typography>
                    <Typography variant="h6" fontWeight={900}>
                      {row.gradeLabel || 'Chưa xếp loại'}
                    </Typography>
                  </Box>
                </Box>

                <Box
                  sx={{
                    border: '1px solid',
                    borderColor: 'divider',
                    borderRadius: 2.5,
                    bgcolor: '#fff',
                    overflow: 'hidden',
                  }}
                >
                  <Box
                    sx={{
                      display: 'grid',
                      gridTemplateColumns: 'minmax(0, 1fr) 90px',
                      px: 2,
                      py: 1.1,
                      bgcolor: alpha('#0f172a', 0.025),
                      borderBottom: '1px solid',
                      borderColor: 'divider',
                    }}
                  >
                    <Typography variant="caption" color="text.secondary" fontWeight={800}>
                      TIÊU CHÍ ĐÁNH GIÁ
                    </Typography>
                    <Typography
                      variant="caption"
                      color="text.secondary"
                      fontWeight={800}
                      textAlign="right"
                    >
                      ĐIỂM
                    </Typography>
                  </Box>
                  {Object.entries(scores).map(([code, score], index, entries) => {
                    const max = criterionMax(formType, code);
                    const percent = max > 0 ? Math.min(100, (score / max) * 100) : 0;
                    return (
                      <Box
                        key={code}
                        sx={{
                          display: 'grid',
                          gridTemplateColumns: 'minmax(0, 1fr) 90px',
                          alignItems: 'center',
                          gap: 2,
                          px: 2,
                          py: 1.4,
                          borderBottom: index < entries.length - 1 ? '1px solid' : 'none',
                          borderColor: 'divider',
                          '&:hover': { bgcolor: alpha('#0f766e', 0.025) },
                        }}
                      >
                        <Box sx={{ minWidth: 0 }}>
                          <Typography variant="body2" fontWeight={700}>
                            {SCORE_LABELS[code] || code}
                          </Typography>
                          <LinearProgress
                            variant="determinate"
                            value={percent}
                            sx={{
                              mt: 0.8,
                              height: 5,
                              borderRadius: 5,
                              bgcolor: alpha('#0f766e', 0.09),
                              '& .MuiLinearProgress-bar': {
                                bgcolor: '#0f766e',
                                borderRadius: 5,
                              },
                            }}
                          />
                        </Box>
                        <Typography
                          variant="body1"
                          fontWeight={900}
                          textAlign="right"
                          color="text.primary"
                        >
                          {score}
                          <Typography component="span" variant="caption" color="text.secondary">
                            {' '}
                            / {max}
                          </Typography>
                        </Typography>
                      </Box>
                    );
                  })}
                </Box>

                {(row.mentorComment ||
                  row.headDeptComment ||
                  row.wardNurseHeadComment ||
                  row.hospitalNurseHeadComment) && (
                  <Box>
                    <Typography variant="subtitle2" fontWeight={800} sx={{ mb: 1.25 }}>
                      Nhận xét chuyên môn
                    </Typography>
                    <Stack spacing={1.25}>
                      {row.mentorComment && (
                        <EvaluationComment
                          label="Ý kiến người hướng dẫn"
                          value={row.mentorComment}
                        />
                      )}
                      {row.headDeptComment && (
                        <EvaluationComment
                          label={
                            formType === 'STAFF'
                              ? 'Đánh giá Trưởng khoa/phòng'
                              : 'Đánh giá Trưởng khoa'
                          }
                          value={row.headDeptComment}
                        />
                      )}
                      {row.wardNurseHeadComment && (
                        <EvaluationComment
                          label="Đánh giá Điều dưỡng trưởng khoa"
                          value={row.wardNurseHeadComment}
                        />
                      )}
                      {row.hospitalNurseHeadComment && (
                        <EvaluationComment
                          label="Đánh giá Điều dưỡng trưởng bệnh viện"
                          value={row.hospitalNurseHeadComment}
                        />
                      )}
                    </Stack>
                  </Box>
                )}
              </Stack>
            </FormSection>
          )}

          {(row.nursingHeadReviewedAt ||
            row.nursingHeadReviewerUsername ||
            row.nursingHeadSignatureUrl ||
            row.hrReviewedAt ||
            row.hrReviewerUsername ||
            row.hrSignatureUrl ||
            row.directorReviewedAt ||
            row.directorReviewerUsername ||
            row.directorSignatureUrl ||
            row.appliedAt) && (
            <FormSection title="Lịch sử duyệt">
              <Stack spacing={1.5}>
                {(row.nursingHeadReviewedAt || row.nursingHeadReviewerUsername) && (
                  <ApprovalReviewNoteCard
                    role={`Trưởng phòng ĐD · ${row.nursingHeadReviewerUsername || '—'}`}
                    timestamp={row.nursingHeadReviewedAt}
                    comment={row.nursingHeadComment}
                    signatureUrl={row.nursingHeadSignatureUrl}
                    formatTimestamp={pcs.formatConversionDateTime}
                  />
                )}
                {(row.hrReviewedAt || row.hrReviewerUsername) && (
                  <ApprovalReviewNoteCard
                    role={`HCNS · ${row.hrReviewerUsername || '—'}`}
                    timestamp={row.hrReviewedAt}
                    comment={row.hrComment}
                    signatureUrl={row.hrSignatureUrl}
                    formatTimestamp={pcs.formatConversionDateTime}
                  />
                )}
                {(row.directorReviewedAt || row.directorReviewerUsername) && (
                  <ApprovalReviewNoteCard
                    role={`Giám đốc · ${row.directorReviewerUsername || '—'}`}
                    timestamp={row.directorReviewedAt}
                    comment={row.directorComment}
                    signatureUrl={row.directorSignatureUrl}
                    formatTimestamp={pcs.formatConversionDateTime}
                  />
                )}
                {row.appliedAt && (
                  <Typography variant="body2" color="success.main" fontWeight={700}>
                    Đã áp dụng lúc {pcs.formatConversionDateTime(row.appliedAt)}
                  </Typography>
                )}
              </Stack>
            </FormSection>
          )}

          {showNursingHeadActions && (
            <FormSection title="Ý kiến Trưởng phòng Điều dưỡng">
              <TextField
                fullWidth
                size="small"
                multiline
                minRows={2}
                label="Ghi chú duyệt (tuỳ chọn)"
                value={nursingHeadComment}
                onChange={(e) => setNursingHeadComment(e.target.value)}
                sx={dateTimeFieldSx}
              />
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
            <FormSection title="Kết luận Ban Giám đốc">
              <TextField
                fullWidth
                size="small"
                multiline
                minRows={2}
                label="Kết luận / ghi chú"
                value={directorComment}
                onChange={(e) => setDirectorComment(e.target.value)}
                sx={dateTimeFieldSx}
              />
            </FormSection>
          )}

          {err && (
            <Typography color="error" variant="body2" sx={{ mt: 1 }}>
              {err}
            </Typography>
          )}
        </>
      ) : null}
    </WorkRequestViewShell>
    {row && (
      <ProbationConversionDialog
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSubmitted={handleEditSaved}
        editConversion={row}
        employee={{
          id: row.employeeId,
          fullName: row.employeeName,
          departmentName: row.departmentName || undefined,
          positionTitle: row.positionTitle || undefined,
          status: row.employeeStatus || undefined,
        }}
      />
    )}
    </>
  );
}
