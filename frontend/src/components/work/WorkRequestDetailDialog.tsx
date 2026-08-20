import AccessTimeIcon from '@mui/icons-material/AccessTime';
import BeachAccessOutlinedIcon from '@mui/icons-material/BeachAccessOutlined';
import BusinessCenterOutlinedIcon from '@mui/icons-material/BusinessCenterOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import DescriptionOutlinedIcon from '@mui/icons-material/DescriptionOutlined';
import EditCalendarOutlinedIcon from '@mui/icons-material/EditCalendarOutlined';
import GavelIcon from '@mui/icons-material/Gavel';
import MoneyOffOutlinedIcon from '@mui/icons-material/MoneyOffOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import PlaceOutlinedIcon from '@mui/icons-material/PlaceOutlined';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import SwapHorizOutlinedIcon from '@mui/icons-material/SwapHorizOutlined';
import TimelineIcon from '@mui/icons-material/Timeline';
import UndoOutlinedIcon from '@mui/icons-material/UndoOutlined';
import WbSunnyOutlinedIcon from '@mui/icons-material/WbSunnyOutlined';
import WbTwilightIcon from '@mui/icons-material/WbTwilight';
import {
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  Grid,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import * as att from '../../services/attendanceService';
import { ApprovalReviewNoteCard } from '../ApprovalReviewNoteCard';
import { AttendanceExplanationDialog } from '../AttendanceExplanationDialog';
import { AttendanceUpdateRequestDialog } from '../AttendanceUpdateRequestDialog';
import { DeploymentRequestDialog } from '../DeploymentRequestDialog';
import { LeaveRequestDialog } from '../LeaveRequestDialog';
import { RequestOwnerActions } from '../requests/RequestOwnerActions';
import { UnpaidLeaveRequestDialog } from '../UnpaidLeaveRequestDialog';
import { dateTimeFieldSx, TimePickerField } from '../ui/DateTimeFields';
import { canEditWorkRequest } from '../../utils/requestEditAccess';
import {
  DetailField,
  DetailFields,
  FormSection,
  InfoBanner,
  RequestFlowSteps,
  WorkRequestViewShell,
  detailHeaderChipSx,
} from './WorkRequestFormUi';
import { workRequestDetailFlow } from '../../utils/nursingBlock';

type ReviewActions = {
  isHead: boolean;
  isNursingHead?: boolean;
  isHr: boolean;
  isDirector?: boolean;
  stage?: 'head' | 'nursingHead' | 'hr' | 'director' | null;
  comment: string;
  onCommentChange: (value: string) => void;
  headComment?: string;
  onHeadCommentChange?: (value: string) => void;
  nursingHeadComment?: string;
  onNursingHeadCommentChange?: (value: string) => void;
  hrComment?: string;
  onHrCommentChange?: (value: string) => void;
  directorComment?: string;
  onDirectorCommentChange?: (value: string) => void;
  loading?: boolean;
  onHeadReview?: (approved: boolean) => void;
  onNursingHeadReview?: (
    approved: boolean,
    deploymentTimes?: {
      requestedStart: string;
      requestedEnd: string;
      requestedAfternoonStart?: string;
      requestedAfternoonEnd?: string;
    },
  ) => void;
  onHrReview?: (
    approved: boolean,
    waiveFine?: boolean,
    deploymentTimes?: {
      requestedStart: string;
      requestedEnd: string;
      requestedAfternoonStart?: string;
      requestedAfternoonEnd?: string;
    },
  ) => void;
  onDirectorReview?: (approved: boolean, waiveFine?: boolean) => void;
};

type Props = {
  open: boolean;
  onClose: () => void;
  request: att.WorkRequest | null;
  mode: 'mine' | 'review';
  review?: ReviewActions;
  onWithdraw?: () => void | Promise<void>;
  withdrawLoading?: boolean;
  /** ADMIN: cho phép thu hồi đơn đã duyệt / đã từ chối (gỡ công đã áp dụng nếu còn). */
  allowWithdrawApproved?: boolean;
  onChanged?: () => void;
};

const fieldSx = dateTimeFieldSx;

function ShiftTimeReadonly({
  title,
  icon,
  accent,
  start,
  end,
}: {
  title: string;
  icon: React.ReactNode;
  accent: string;
  start: string;
  end: string;
}) {
  return (
    <Box
      sx={{
        p: 1.75,
        borderRadius: 2,
        bgcolor: alpha(accent, 0.04),
        border: `1px solid ${alpha(accent, 0.16)}`,
        height: '100%',
      }}
    >
      <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.5 }}>
        {icon}
        <Typography variant="subtitle2" fontWeight={700}>
          {title}
        </Typography>
      </Stack>
      <Grid container spacing={1.5}>
        <Grid item xs={6}>
          <Typography variant="caption" color="text.secondary" display="block">
            Vào ca
          </Typography>
          <Typography variant="h6" fontWeight={800} lineHeight={1.3}>
            {start || '—'}
          </Typography>
        </Grid>
        <Grid item xs={6}>
          <Typography variant="caption" color="text.secondary" display="block">
            Ra ca
          </Typography>
          <Typography variant="h6" fontWeight={800} lineHeight={1.3}>
            {end || '—'}
          </Typography>
        </Grid>
      </Grid>
    </Box>
  );
}

export function WorkRequestDetailDialog({
  open,
  onClose,
  request,
  mode,
  review,
  onWithdraw,
  withdrawLoading,
  allowWithdrawApproved = false,
  onChanged,
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const [confirmWithdraw, setConfirmWithdraw] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [deploymentStart, setDeploymentStart] = useState('');
  const [deploymentEnd, setDeploymentEnd] = useState('');
  const [deploymentAfternoonStart, setDeploymentAfternoonStart] = useState('');
  const [deploymentAfternoonEnd, setDeploymentAfternoonEnd] = useState('');
  const [deploymentTimeError, setDeploymentTimeError] = useState<string | null>(null);

  useEffect(() => {
    setDeploymentStart(request?.requestedStart?.slice(0, 5) ?? '');
    setDeploymentEnd(request?.requestedEnd?.slice(0, 5) ?? '');
    setDeploymentAfternoonStart(request?.requestedAfternoonStart?.slice(0, 5) ?? '');
    setDeploymentAfternoonEnd(request?.requestedAfternoonEnd?.slice(0, 5) ?? '');
    setDeploymentTimeError(null);
  }, [request?.id, request?.requestedStart, request?.requestedEnd, request?.requestedAfternoonStart, request?.requestedAfternoonEnd]);

  if (!request) return null;

  const accent =
    request.requestType === 'EXPLANATION'
      ? theme.palette.info.main
      : request.requestType === 'LEAVE'
        ? theme.palette.secondary.main
        : request.requestType === 'UNPAID_LEAVE'
          ? theme.palette.error.dark
          : request.requestType === 'BUSINESS_TRIP'
            ? theme.palette.warning.dark
            : request.requestType === 'DEPLOYMENT'
              ? '#0f766e'
              : theme.palette.primary.main;
  const reviewLocked = request.status === 'WITHDRAWN';
  const headPending =
    review?.stage === 'head' || (!review?.stage && request.status === 'PENDING_HEAD');
  const nursingHeadPending =
    review?.stage === 'nursingHead' ||
    (!review?.stage && request.status === 'PENDING_NURSING_HEAD');
  const hrPending =
    review?.stage === 'hr' || (!review?.stage && request.status === 'PENDING_HR');
  const directorPending =
    review?.stage === 'director' || (!review?.stage && request.status === 'PENDING_DIRECTOR');
  /** Đã duyệt qua bước này → cho phép sửa lại ghi chú / quyền duyệt. */
  const canHeadCorrect =
    Boolean(request.headReviewedAt) && !reviewLocked && !headPending;
  const canNursingHeadCorrect =
    Boolean(request.nursingHeadReviewedAt) && !reviewLocked && !nursingHeadPending;
  const canHrCorrect = Boolean(request.hrReviewedAt) && !reviewLocked && !hrPending;
  const canDirectorCorrect =
    Boolean(request.directorReviewedAt) && !reviewLocked && !directorPending;
  const canHeadAct =
    mode === 'review' && review?.isHead && (headPending || canHeadCorrect);
  const canNursingHeadAct =
    mode === 'review' &&
    Boolean(review?.isNursingHead) &&
    (nursingHeadPending || canNursingHeadCorrect);
  const canHrAct = mode === 'review' && review?.isHr && (hrPending || canHrCorrect);
  const canDirectorAct =
    mode === 'review' && review?.isDirector && (directorPending || canDirectorCorrect);
  const canAct = canHeadAct || canNursingHeadAct || canHrAct || canDirectorAct;
  const canEditDeploymentTimes =
    request.requestType === 'DEPLOYMENT' && (canHrAct || canNursingHeadAct);
  const headCorrecting = canHeadAct && canHeadCorrect;
  const nursingHeadCorrecting = canNursingHeadAct && canNursingHeadCorrect;
  const hrCorrecting = canHrAct && canHrCorrect;
  const directorCorrecting = canDirectorAct && canDirectorCorrect;
  const canWithdraw =
    Boolean(onWithdraw) &&
    att.isRequestWithdrawable(request.status, { asAdmin: allowWithdrawApproved });
  const showEdit = canEditWorkRequest(request, user);

  function handleEditSaved() {
    onChanged?.();
    setEditOpen(false);
  }

  const ownerActions = (
    <RequestOwnerActions
      showEdit={showEdit}
      showCancel={canWithdraw}
      acting={withdrawLoading}
      onEdit={() => setEditOpen(true)}
      onCancel={() => setConfirmWithdraw(true)}
    />
  );
  const withdrawingFinalized = !att.isRequestPending(request.status);
  const shifts = att.resolveRequestShiftTimes(request);
  const explanationTimes = att.formatExplanationTimes(request);
  const forgotUnits = request.forgotFineUnits ?? att.forgotFineUnitsForUpdateKind(request.updateKind);
  const isRanged =
    request.requestType === 'LEAVE' ||
    request.requestType === 'UNPAID_LEAVE' ||
    request.requestType === 'BUSINESS_TRIP';
  const hasReviewHistory =
    request.headComment ||
    request.headReviewedAt ||
    request.headSignatureUrl ||
    request.nursingHeadComment ||
    request.nursingHeadReviewedAt ||
    request.nursingHeadSignatureUrl ||
    request.hrComment ||
    request.hrReviewedAt ||
    request.hrSignatureUrl ||
    request.directorComment ||
    request.directorReviewedAt ||
    request.directorSignatureUrl;
  const attendancePunchTimes = [...new Set((request.attendancePunchTimes ?? [])
    .map((time) => String(time).slice(0, 5))
    .filter(Boolean))].sort();
  const selectedDeploymentTimes = new Set([
    deploymentStart,
    deploymentEnd,
    deploymentAfternoonStart,
    deploymentAfternoonEnd,
  ].filter(Boolean));

  function approveDeploymentAsHr() {
    approveDeploymentTimes((times) => review?.onHrReview?.(true, undefined, times));
  }

  function approveDeploymentAsNursingHead() {
    approveDeploymentTimes((times) => review?.onNursingHeadReview?.(true, times));
  }

  function approveDeploymentTimes(
    onApprove: (times: {
      requestedStart: string;
      requestedEnd: string;
      requestedAfternoonStart?: string;
      requestedAfternoonEnd?: string;
    }) => void,
  ) {
    if (!request) return;
    if (!deploymentStart || !deploymentEnd || deploymentStart === deploymentEnd) {
      setDeploymentTimeError('Nhập khung giờ điều động hợp lệ.');
      return;
    }
    const hasAfternoon = Boolean(
      request.requestedAfternoonStart ||
      request.requestedAfternoonEnd ||
      deploymentAfternoonStart ||
      deploymentAfternoonEnd,
    );
    if (hasAfternoon && (!deploymentAfternoonStart || !deploymentAfternoonEnd || deploymentAfternoonStart === deploymentAfternoonEnd)) {
      setDeploymentTimeError('Nhập đủ khung giờ điều động buổi chiều.');
      return;
    }
    setDeploymentTimeError(null);
    onApprove({
      requestedStart: deploymentStart,
      requestedEnd: deploymentEnd,
      ...(hasAfternoon
        ? {
            requestedAfternoonStart: deploymentAfternoonStart,
            requestedAfternoonEnd: deploymentAfternoonEnd,
          }
        : {}),
    });
  }

  const icon =
    mode === 'review' ? (
      <GavelIcon />
    ) : request.requestType === 'EXPLANATION' ? (
      <DescriptionOutlinedIcon />
    ) : request.requestType === 'LEAVE' ? (
      <BeachAccessOutlinedIcon />
    ) : request.requestType === 'UNPAID_LEAVE' ? (
      <MoneyOffOutlinedIcon />
    ) : request.requestType === 'BUSINESS_TRIP' ? (
      <BusinessCenterOutlinedIcon />
    ) : request.requestType === 'DEPLOYMENT' ? (
      <SwapHorizOutlinedIcon />
    ) : (
      <EditCalendarOutlinedIcon />
    );

  const description = `${request.employeeName}${request.department ? ` · ${request.department}` : ''}`;

  const footer =
    canAct && review ? (
      <Box
        sx={{
          px: 2.5,
          py: 2,
          borderTop: `1px solid ${theme.palette.divider}`,
          bgcolor: alpha(theme.palette.background.default, 0.5),
        }}
      >
        <Stack direction="row" spacing={1.5} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
          {ownerActions}
          {canHeadAct &&
            (headCorrecting ? (
              <Button
                variant="contained"
                disabled={review.loading}
                startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                onClick={() => review.onHeadReview?.(true)}
                sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
              >
                Lưu chỉnh sửa · Trưởng khoa
              </Button>
            ) : (
              <>
                <Button
                  variant="outlined"
                  color="error"
                  disabled={review.loading}
                  onClick={() => review.onHeadReview?.(false)}
                  sx={{ borderRadius: 2 }}
                >
                  Không duyệt
                </Button>
                <Button
                  variant="contained"
                  disabled={review.loading}
                  startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                  onClick={() => review.onHeadReview?.(true)}
                  sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
                >
                  Duyệt — chuyển HCNS
                </Button>
              </>
            ))}
          {canNursingHeadAct &&
            (nursingHeadCorrecting ? (
              <Button
                variant="contained"
                disabled={review.loading}
                startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                onClick={() =>
                  request.requestType === 'DEPLOYMENT'
                    ? approveDeploymentAsNursingHead()
                    : review.onNursingHeadReview?.(true)
                }
                sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
              >
                Lưu chỉnh sửa · Trưởng phòng ĐD
              </Button>
            ) : (
              <>
                <Button
                  variant="outlined"
                  color="error"
                  disabled={review.loading}
                  onClick={() => review.onNursingHeadReview?.(false)}
                  sx={{ borderRadius: 2 }}
                >
                  Không duyệt
                </Button>
                <Button
                  variant="contained"
                  disabled={review.loading}
                  startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                  onClick={() =>
                    request.requestType === 'DEPLOYMENT'
                      ? approveDeploymentAsNursingHead()
                      : review.onNursingHeadReview?.(true)
                  }
                  sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
                >
                  Duyệt — chuyển HCNS
                </Button>
              </>
            ))}
          {canHrAct &&
            (hrCorrecting ? (
              <Button
                variant="contained"
                disabled={review.loading}
                startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                onClick={() =>
                  request.requestType === 'DEPLOYMENT'
                    ? approveDeploymentAsHr()
                    : review.onHrReview?.(true)
                }
                sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
              >
                Lưu chỉnh sửa · HCNS
              </Button>
            ) : (
              <>
                <Button
                  variant="outlined"
                  color="error"
                  disabled={review.loading}
                  onClick={() => review.onHrReview?.(false)}
                  sx={{ borderRadius: 2 }}
                >
                  Không duyệt
                </Button>
                <Button
                  variant="contained"
                  disabled={review.loading}
                  startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                  onClick={() =>
                    request.requestType === 'DEPLOYMENT'
                      ? approveDeploymentAsHr()
                      : review.onHrReview?.(true)
                  }
                  sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
                >
                  {request.requestType === 'BUSINESS_TRIP'
                    ? 'Duyệt công tác'
                    : 'Duyệt — chuyển Giám đốc'}
                </Button>
              </>
            ))}
          {canDirectorAct &&
            (directorCorrecting ? (
              <Button
                variant="contained"
                disabled={review.loading}
                startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                onClick={() =>
                  review.onDirectorReview?.(
                    true,
                    request.status === 'APPROVED_NO_FINE' ? true : false,
                  )
                }
                sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
              >
                Lưu chỉnh sửa · Giám đốc
              </Button>
            ) : (
              <>
                <Button
                  variant="outlined"
                  color="error"
                  disabled={review.loading}
                  onClick={() => review.onDirectorReview?.(false)}
                  sx={{ borderRadius: 2 }}
                >
                  Không duyệt
                </Button>
                {(request.requestType === 'UPDATE' || request.requestType === 'EXPLANATION') && (
                  <>
                    <Button
                      variant="contained"
                      color="secondary"
                      disabled={review.loading}
                      onClick={() => review.onDirectorReview?.(true, true)}
                      sx={{ borderRadius: 2 }}
                    >
                      Duyệt (không trừ tiền)
                    </Button>
                    <Button
                      variant="contained"
                      disabled={review.loading}
                      startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                      onClick={() => review.onDirectorReview?.(true, false)}
                      sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
                    >
                      {request.requestType === 'UPDATE'
                        ? `Duyệt (trừ ${forgotUnits} lần quên chấm)`
                        : 'Duyệt (có phạt muộn/sớm)'}
                    </Button>
                  </>
                )}
                {(request.requestType === 'LEAVE' ||
                  request.requestType === 'UNPAID_LEAVE' ||
                  request.requestType === 'DEPLOYMENT') && (
                  <Button
                    variant="contained"
                    disabled={review.loading}
                    startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                    onClick={() => review.onDirectorReview?.(true)}
                    sx={{
                      borderRadius: 2,
                      px: 2.5,
                      bgcolor: accent,
                      '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
                    }}
                  >
                    {request.requestType === 'DEPLOYMENT'
                      ? 'Duyệt và áp dụng điều động'
                      : request.requestType === 'UNPAID_LEAVE'
                        ? 'Duyệt nghỉ không lương'
                        : 'Duyệt nghỉ phép'}
                  </Button>
                )}
              </>
            ))}
        </Stack>
      </Box>
    ) : mode === 'mine' || showEdit || canWithdraw ? (
      <Box
        sx={{
          px: 2.5,
          py: 2,
          borderTop: `1px solid ${theme.palette.divider}`,
          bgcolor: alpha(theme.palette.background.default, 0.5),
        }}
      >
        <Stack direction="row" spacing={1.5} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
          {ownerActions}
          {canWithdraw && mode !== 'mine' && (
            <Typography variant="caption" color="text.secondary" sx={{ maxWidth: 320, lineHeight: 1.5, mr: 'auto' }}>
              {withdrawingFinalized
                ? 'Thu hồi sẽ gỡ công / điều động đã áp dụng (nếu còn) và đánh dấu đơn đã thu hồi.'
                : 'Đơn sẽ không còn chờ duyệt sau khi thu hồi.'}
            </Typography>
          )}
          <Button onClick={onClose} variant={mode === 'mine' ? 'outlined' : 'contained'} color={mode === 'mine' ? 'inherit' : undefined} sx={{ borderRadius: 2, fontWeight: 700 }}>
            Đóng
          </Button>
        </Stack>
      </Box>
    ) : undefined;

  return (
    <>
    <WorkRequestViewShell
      open={open}
      onClose={onClose}
      loading={review?.loading}
      accent={accent}
      icon={icon}
      overline={mode === 'review' && canAct ? 'Duyệt đơn công' : 'Chi tiết đơn'}
      title={att.requestTypeLabel(request.requestType)}
      description={description}
      footer={footer ?? (mode === 'review' && !canAct ? (
        <Box
          sx={{
            px: 2.5,
            py: 1.75,
            borderTop: `1px solid ${theme.palette.divider}`,
            bgcolor: alpha(theme.palette.background.default, 0.5),
            display: 'flex',
            justifyContent: 'flex-end',
          }}
        >
          <Button onClick={onClose} variant="contained" sx={{ borderRadius: 2, fontWeight: 700 }}>
            Đóng
          </Button>
        </Box>
      ) : undefined)}
      headerExtra={
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
          <Chip
            size="small"
            label={att.requestStatusLabel(request.status, request.requestType)}
            color={att.requestStatusColor(request.status)}
            sx={detailHeaderChipSx.filled}
          />
          {request.requestType === 'UPDATE' && request.updateKind && (
            <Chip
              size="small"
              variant="outlined"
              label={att.updateKindLabel(request.updateKind, request.continuousShift)}
              sx={detailHeaderChipSx.outlined}
            />
          )}
          {request.requestType === 'LEAVE' && (
            <Chip
              size="small"
              variant="outlined"
              label={`${request.leaveDays ?? 1} ngày phép`}
              sx={detailHeaderChipSx.outlined}
            />
          )}
          {request.requestType === 'UNPAID_LEAVE' && (
            <Chip
              size="small"
              variant="outlined"
              label={`${request.leaveDays ?? 1} ngày không lương`}
              sx={detailHeaderChipSx.outlined}
            />
          )}
          {request.requestType === 'BUSINESS_TRIP' && (
            <Chip
              size="small"
              variant="outlined"
              label={`${request.tripDays ?? 1} ngày công tác`}
              sx={detailHeaderChipSx.outlined}
            />
          )}
          {request.requestType === 'DEPLOYMENT' && (
            <Chip
              size="small"
              variant="outlined"
              label={
                request.deploymentCreditedHours != null
                  ? `×1,5 · ${request.deploymentCreditedHours}h công`
                  : 'Điều động'
              }
              sx={detailHeaderChipSx.outlined}
            />
          )}
          <Chip
            size="small"
            variant="outlined"
            label={
              isRanged
                ? `${att.formatWorkDate(request.workDate)} → ${att.formatWorkDate(request.endDate || request.workDate)}`
                : att.formatWorkDate(request.workDate)
            }
            sx={detailHeaderChipSx.outlined}
          />
        </Stack>
      }
    >
      {(() => {
        const flow = workRequestDetailFlow(request);
        return <RequestFlowSteps accent={accent} steps={flow.steps} activeIndex={flow.activeIndex} />;
      })()}

      {canHrAct && (request.requestType === 'UPDATE' || request.requestType === 'EXPLANATION') && (
        <InfoBanner>
          HCNS chỉ xác nhận hồ sơ. Sau khi duyệt, đơn chuyển <strong>Giám đốc</strong> quyết định trừ tiền hay không.
        </InfoBanner>
      )}

      {canNursingHeadAct && request.requestType === 'DEPLOYMENT' && (
        <InfoBanner>
          Sau khi duyệt, đơn chuyển <strong>HCNS</strong>.
        </InfoBanner>
      )}

      {canDirectorAct && request.requestType === 'UPDATE' && (
        <InfoBanner>
          Nếu duyệt có phạt quên chấm: trừ <strong>{forgotUnits} lần</strong> (theo bậc phạt tháng). Chọn{' '}
          <strong>Duyệt (không trừ tiền)</strong> nếu miễn phạt.
        </InfoBanner>
      )}

      {canDirectorAct && request.requestType === 'EXPLANATION' && (
        <InfoBanner>
          Giờ giải trình sẽ được áp vào bảng công. Chọn <strong>Duyệt (không trừ tiền)</strong> để miễn phạt
          muộn/sớm, hoặc <strong>Duyệt (có phạt)</strong> để tính phạt theo giờ sau giải trình.
        </InfoBanner>
      )}

      {request.requestType === 'LEAVE' && (
        <InfoBanner>
          Sau khi HCNS duyệt, các ngày trong khoảng sẽ chuyển trạng thái bảng công thành <strong>Phép</strong> (có
          tính công).
        </InfoBanner>
      )}

      {request.requestType === 'UNPAID_LEAVE' && (
        <InfoBanner>
          Sau khi HCNS duyệt, các ngày trong khoảng ghi <strong>Không lương</strong> với <strong>0 công</strong> —
          không trừ hạn mức phép năm.
        </InfoBanner>
      )}

      {request.requestType === 'BUSINESS_TRIP' && (
        <InfoBanner>
          Sau khi HCNS duyệt, các ngày trong khoảng sẽ chuyển trạng thái bảng công thành{' '}
          <strong>Công tác</strong>.
        </InfoBanner>
      )}

      {request.requestType === 'DEPLOYMENT' && !canNursingHeadAct && (
        <InfoBanner>
          Đơn điều động (khối ĐD): <strong>Trưởng phòng Điều dưỡng</strong> → <strong>HCNS</strong> →{' '}
          <strong>Giám đốc duyệt cuối</strong>. Với điều động trong ca, duyệt đơn chỉ xác nhận khung giờ; hệ
          thống chỉ áp dụng công <strong>×1,5</strong> khi có đủ giờ chấm vào/ra phù hợp. Điều động ngoài ca
          giữ cách tính hiện tại
          {request.deploymentActualHours != null && request.deploymentCreditedHours != null
            ? ` (${request.deploymentActualHours}h thực tế → ${request.deploymentCreditedHours}h công)`
            : ''}
          .
        </InfoBanner>
      )}

      {canEditDeploymentTimes && (
        <FormSection
          title={
            canNursingHeadAct
              ? 'Trưởng phòng ĐD hiệu chỉnh khung giờ'
              : 'HCNS hiệu chỉnh khung giờ'
          }
          subtitle={
            canNursingHeadAct
              ? 'Đối chiếu log máy chấm và sửa thời gian trước khi chuyển HCNS duyệt.'
              : 'Kiểm tra và sửa lại thời gian chính xác trước khi chuyển Giám đốc duyệt.'
          }
        >
          <Box
            sx={{
              p: 2,
              borderRadius: 2.5,
              bgcolor: alpha(accent, 0.045),
              border: `1px solid ${alpha(accent, 0.2)}`,
            }}
          >
            <Box
              sx={{
                mb: 2,
                p: 1.5,
                borderRadius: 2,
                bgcolor: '#fff',
                border: `1px solid ${alpha(accent, 0.16)}`,
              }}
            >
              <Stack
                direction={{ xs: 'column', sm: 'row' }}
                justifyContent="space-between"
                alignItems={{ xs: 'flex-start', sm: 'center' }}
                spacing={0.75}
                sx={{ mb: attendancePunchTimes.length > 0 ? 1.25 : 0.5 }}
              >
                <Box>
                  <Typography variant="subtitle2" fontWeight={800}>
                    Log máy chấm ngày {att.formatWorkDate(request.workDate)}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    Toàn bộ lần quẹt của {request.employeeName}, sắp xếp theo thời gian.
                  </Typography>
                </Box>
                <Chip
                  size="small"
                  label={`${attendancePunchTimes.length} lần chấm`}
                  color={attendancePunchTimes.length > 0 ? 'primary' : 'default'}
                  variant="outlined"
                  sx={{ fontWeight: 750 }}
                />
              </Stack>
              {attendancePunchTimes.length > 0 ? (
                <Stack direction="row" spacing={0.75} flexWrap="wrap" useFlexGap>
                  {attendancePunchTimes.map((time, index) => {
                    const selected = selectedDeploymentTimes.has(time);
                    return (
                      <Chip
                        key={`${time}-${index}`}
                        icon={<AccessTimeIcon />}
                        label={`${index + 1}. ${time}`}
                        color={selected ? 'primary' : 'default'}
                        variant={selected ? 'filled' : 'outlined'}
                        sx={{ fontWeight: 800, fontVariantNumeric: 'tabular-nums' }}
                      />
                    );
                  })}
                </Stack>
              ) : (
                <Typography variant="body2" color="warning.dark" fontWeight={650}>
                  Chưa ghi nhận log máy chấm nào của nhân viên trong ngày này.
                </Typography>
              )}
              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
                Mốc trùng với giờ đang hiệu chỉnh được tô màu. Đối chiếu các log này trước khi sửa khung giờ bên dưới.
              </Typography>
            </Box>
            <Grid container spacing={1.5}>
              <Grid item xs={12} sm={6}>
                <TimePickerField
                  required
                  label={request.requestedAfternoonStart ? 'Bắt đầu buổi sáng' : 'Bắt đầu điều động'}
                  value={deploymentStart}
                  onChange={(value) => { setDeploymentStart(value); setDeploymentTimeError(null); }}
                  sx={fieldSx}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TimePickerField
                  required
                  label={request.requestedAfternoonEnd ? 'Kết thúc buổi sáng' : 'Kết thúc điều động'}
                  value={deploymentEnd}
                  onChange={(value) => { setDeploymentEnd(value); setDeploymentTimeError(null); }}
                  sx={fieldSx}
                />
              </Grid>
              {(request.requestedAfternoonStart || request.requestedAfternoonEnd) && (
                <>
                  <Grid item xs={12} sm={6}>
                    <TimePickerField
                      required label="Bắt đầu buổi chiều"
                      value={deploymentAfternoonStart}
                      onChange={(value) => { setDeploymentAfternoonStart(value); setDeploymentTimeError(null); }}
                      sx={fieldSx}
                    />
                  </Grid>
                  <Grid item xs={12} sm={6}>
                    <TimePickerField
                      required label="Kết thúc buổi chiều"
                      value={deploymentAfternoonEnd}
                      onChange={(value) => { setDeploymentAfternoonEnd(value); setDeploymentTimeError(null); }}
                      sx={fieldSx}
                    />
                  </Grid>
                </>
              )}
            </Grid>
            {deploymentTimeError && (
              <Typography variant="caption" color="error" fontWeight={650} sx={{ display: 'block', mt: 1 }}>
                {deploymentTimeError}
              </Typography>
            )}
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
              {canNursingHeadAct
                ? 'Giờ Trưởng phòng ĐD xác nhận sẽ thay thế giờ đề nghị và chuyển HCNS duyệt.'
                : 'Giờ HCNS xác nhận sẽ thay thế giờ đề nghị ban đầu và là khung giờ Giám đốc duyệt cuối.'}
            </Typography>
          </Box>
        </FormSection>
      )}

      <FormSection title="Thông tin nhân viên">
        <DetailFields>
          <DetailField
            label="Họ tên"
            value={request.employeeName}
            icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
          />
          <DetailField
            label="Phòng ban"
            value={request.department}
            icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
          />
          <DetailField
            label="Ngày gửi đơn"
            value={att.formatReviewTimestamp(request.createdAt)}
            icon={<ScheduleOutlinedIcon sx={{ fontSize: 16 }} />}
          />
          {request.requestType === 'UPDATE' && request.updateKind && (
            <DetailField
              label="Loại cập nhật"
              value={att.updateKindLabel(request.updateKind, request.continuousShift)}
              icon={<EditCalendarOutlinedIcon sx={{ fontSize: 16 }} />}
            />
          )}
        </DetailFields>
      </FormSection>

      <FormSection title="Nội dung đơn">
        <DetailFields>
          <DetailField
            label={isRanged ? 'Từ ngày' : 'Ngày công'}
            value={att.formatWorkDate(request.workDate)}
            icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
          />
          {isRanged && (
            <DetailField
              label="Đến ngày"
              value={att.formatWorkDate(request.endDate || request.workDate)}
              icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
            />
          )}
          {(request.requestType === 'LEAVE' || request.requestType === 'UNPAID_LEAVE') && (
            <DetailField
              label="Số ngày"
              value={`${request.leaveDays ?? 1} ngày`}
              icon={
                request.requestType === 'UNPAID_LEAVE' ? (
                  <MoneyOffOutlinedIcon sx={{ fontSize: 16 }} />
                ) : (
                  <BeachAccessOutlinedIcon sx={{ fontSize: 16 }} />
                )
              }
            />
          )}
          {request.requestType === 'BUSINESS_TRIP' && (
            <>
              <DetailField
                label="Số ngày"
                value={`${request.tripDays ?? 1} ngày`}
                icon={<BusinessCenterOutlinedIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Địa điểm"
                value={request.location || '—'}
                icon={<PlaceOutlinedIcon sx={{ fontSize: 16 }} />}
              />
            </>
          )}
          {request.requestType === 'DEPLOYMENT' && (
            <>
              <DetailField
                label="Khung giờ"
                value={
                  request.requestedStart && request.requestedEnd
                    ? `${request.requestedStart.slice(0, 5)} – ${request.requestedEnd.slice(0, 5)}`
                    : '—'
                }
                icon={<AccessTimeIcon sx={{ fontSize: 16 }} />}
              />
              <DetailField
                label="Công ×1,5"
                value={
                  request.deploymentActualHours != null && request.deploymentCreditedHours != null
                    ? `${request.deploymentActualHours}h → ${request.deploymentCreditedHours}h công`
                    : 'Hệ số 1,5'
                }
                icon={<SwapHorizOutlinedIcon sx={{ fontSize: 16 }} />}
              />
            </>
          )}
          <DetailField
            wide
            label="Lý do / nội dung đơn"
            value={request.reason}
            icon={<DescriptionOutlinedIcon sx={{ fontSize: 16 }} />}
          />
        </DetailFields>
      </FormSection>

      {request.requestType === 'UPDATE' && (shifts.single || shifts.morning || shifts.afternoon) && (
        <FormSection title="Khung giờ đề nghị" subtitle="Thời gian công nhân viên yêu cầu bổ sung.">
          <Box
            sx={{
              p: 2,
              borderRadius: 2.5,
              bgcolor: alpha(accent, 0.05),
              border: `1px dashed ${alpha(accent, 0.25)}`,
            }}
          >
            <Grid container spacing={2}>
              {shifts.single && (
                <Grid item xs={12}>
                  <ShiftTimeReadonly
                    title={shifts.single.label}
                    icon={<TimelineIcon sx={{ fontSize: 18, color: accent }} />}
                    accent={accent}
                    start={shifts.single.start}
                    end={shifts.single.end}
                  />
                </Grid>
              )}
              {!shifts.single && shifts.morning && (
                <Grid item xs={12} md={shifts.afternoon ? 6 : 12}>
                  <ShiftTimeReadonly
                    title="Ca sáng"
                    icon={<WbSunnyOutlinedIcon sx={{ fontSize: 18, color: accent }} />}
                    accent={accent}
                    start={shifts.morning.start}
                    end={shifts.morning.end}
                  />
                </Grid>
              )}
              {!shifts.single && shifts.afternoon && (
                <Grid item xs={12} md={shifts.morning ? 6 : 12}>
                  <ShiftTimeReadonly
                    title="Ca chiều"
                    icon={<WbTwilightIcon sx={{ fontSize: 18, color: accent }} />}
                    accent={accent}
                    start={shifts.afternoon.start}
                    end={shifts.afternoon.end}
                  />
                </Grid>
              )}
            </Grid>
          </Box>
        </FormSection>
      )}

      {request.requestType === 'EXPLANATION' && explanationTimes && (
        <FormSection title="Thời gian giải trình">
          <Box
            sx={{
              p: 2,
              borderRadius: 2.5,
              bgcolor: alpha(accent, 0.05),
              border: `1px dashed ${alpha(accent, 0.25)}`,
            }}
          >
            <Stack direction="row" spacing={1} alignItems="center">
              <AccessTimeIcon sx={{ fontSize: 18, color: accent }} />
              <Typography variant="body1" fontWeight={600}>
                {explanationTimes}
              </Typography>
            </Stack>
          </Box>
        </FormSection>
      )}

      {hasReviewHistory && (
        <FormSection title="Lịch sử duyệt" subtitle="Ghi chú và thời điểm xử lý từng bước.">
          <Stack spacing={1.5}>
            {(request.headComment || request.headReviewedAt || request.headSignatureUrl) && (
              <ApprovalReviewNoteCard
                role={`Lãnh đạo · ${request.headReviewerName || request.headReviewerUsername || request.flowHeadName || '—'}`}
                timestamp={request.headReviewedAt}
                comment={request.headComment}
                signatureUrl={request.headSignatureUrl}
                formatTimestamp={att.formatReviewTimestamp}
              />
            )}
            {(request.nursingHeadComment ||
              request.nursingHeadReviewedAt ||
              request.nursingHeadSignatureUrl) && (
              <ApprovalReviewNoteCard
                role={`Trưởng phòng Điều dưỡng · ${request.nursingHeadReviewerName || request.nursingHeadReviewerUsername || request.flowNursingHeadName || '—'}`}
                timestamp={request.nursingHeadReviewedAt}
                comment={request.nursingHeadComment}
                signatureUrl={request.nursingHeadSignatureUrl}
                formatTimestamp={att.formatReviewTimestamp}
              />
            )}
            {(request.hrComment || request.hrReviewedAt || request.hrSignatureUrl) && (
              <ApprovalReviewNoteCard
                role={`HCNS · ${request.hrReviewerName || request.hrReviewerUsername || request.flowHrName || '—'}`}
                timestamp={request.hrReviewedAt}
                comment={request.hrComment}
                signatureUrl={request.hrSignatureUrl}
                formatTimestamp={att.formatReviewTimestamp}
              />
            )}
            {(request.directorComment || request.directorReviewedAt || request.directorSignatureUrl) && (
              <ApprovalReviewNoteCard
                role={`Giám đốc · ${request.directorReviewerName || request.directorReviewerUsername || request.flowDirectorName || '—'}`}
                timestamp={request.directorReviewedAt}
                comment={request.directorComment}
                signatureUrl={request.directorSignatureUrl}
                formatTimestamp={att.formatReviewTimestamp}
              />
            )}
          </Stack>
        </FormSection>
      )}

      {canAct && review && (
        <FormSection
          title={
            headCorrecting || nursingHeadCorrecting || hrCorrecting || directorCorrecting
              ? 'Chỉnh sửa ghi chú duyệt'
              : 'Ghi chú duyệt'
          }
          subtitle={
            headCorrecting || nursingHeadCorrecting || hrCorrecting || directorCorrecting
              ? 'Sửa ghi chú / quyền duyệt rồi nhấn Lưu chỉnh sửa. Chữ ký sẽ được cập nhật lại.'
              : 'Tuỳ chọn — ghi chú sẽ lưu vào lịch sử duyệt.'
          }
        >
          <Stack spacing={2}>
            {canHeadAct && (
              <TextField
                fullWidth
                size="small"
                label={
                  canNursingHeadAct || canHrAct || canDirectorAct ? 'Ghi chú Trưởng khoa' : undefined
                }
                placeholder="Nhập ghi chú (tuỳ chọn)…"
                value={review.headComment ?? review.comment}
                onChange={(e) =>
                  (review.onHeadCommentChange ?? review.onCommentChange)(e.target.value)
                }
                disabled={review.loading}
                multiline
                minRows={2}
                sx={fieldSx}
              />
            )}
            {canNursingHeadAct && (
              <TextField
                fullWidth
                size="small"
                label={
                  canHeadAct || canHrAct || canDirectorAct
                    ? 'Ghi chú Trưởng phòng ĐD'
                    : undefined
                }
                placeholder="Nhập ghi chú (tuỳ chọn)…"
                value={review.nursingHeadComment ?? review.comment}
                onChange={(e) =>
                  (review.onNursingHeadCommentChange ?? review.onCommentChange)(e.target.value)
                }
                disabled={review.loading}
                multiline
                minRows={2}
                sx={fieldSx}
              />
            )}
            {canHrAct && (
              <TextField
                fullWidth
                size="small"
                label={
                  canHeadAct || canNursingHeadAct || canDirectorAct ? 'Ghi chú HCNS' : undefined
                }
                placeholder="Nhập ghi chú (tuỳ chọn)…"
                value={review.hrComment ?? review.comment}
                onChange={(e) =>
                  (review.onHrCommentChange ?? review.onCommentChange)(e.target.value)
                }
                disabled={review.loading}
                multiline
                minRows={2}
                sx={fieldSx}
              />
            )}
            {canDirectorAct && (
              <TextField
                fullWidth
                size="small"
                label={
                  canHeadAct || canNursingHeadAct || canHrAct ? 'Ghi chú Giám đốc' : undefined
                }
                placeholder="Nhập ghi chú (tuỳ chọn)…"
                value={review.directorComment ?? review.comment}
                onChange={(e) =>
                  (review.onDirectorCommentChange ?? review.onCommentChange)(e.target.value)
                }
                disabled={review.loading}
                multiline
                minRows={2}
                sx={fieldSx}
              />
            )}
          </Stack>
        </FormSection>
      )}
    </WorkRequestViewShell>

    <Dialog
      open={confirmWithdraw}
      onClose={() => !withdrawLoading && setConfirmWithdraw(false)}
      maxWidth="xs"
      fullWidth
      PaperProps={{ sx: { borderRadius: 3 } }}
    >
      <DialogTitle sx={{ fontWeight: 800 }}>Thu hồi đơn?</DialogTitle>
      <DialogContent>
        <DialogContentText sx={{ lineHeight: 1.65 }}>
          {withdrawingFinalized
            ? 'Đơn sẽ được thu hồi. Nếu trước đó đã duyệt, công / điều động còn trên bảng công sẽ được gỡ. Bạn có thể gửi đơn mới sau nếu cần.'
            : 'Đơn sẽ không còn chờ duyệt. Bạn có thể gửi lại đơn mới sau khi thu hồi nếu gửi nhầm.'}
        </DialogContentText>
      </DialogContent>
      <DialogActions sx={{ px: 2.5, pb: 2 }}>
        <Button onClick={() => setConfirmWithdraw(false)} disabled={withdrawLoading} sx={{ borderRadius: 2 }}>
          Hủy
        </Button>
        <Button
          color="error"
          variant="contained"
          disabled={withdrawLoading}
          startIcon={withdrawLoading ? <CircularProgress size={16} color="inherit" /> : <UndoOutlinedIcon />}
          onClick={async () => {
            await onWithdraw?.();
            setConfirmWithdraw(false);
          }}
          sx={{ borderRadius: 2, fontWeight: 700 }}
        >
          Thu hồi
        </Button>
      </DialogActions>
    </Dialog>
    {request.requestType === 'LEAVE' && (
      <LeaveRequestDialog
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSubmitted={handleEditSaved}
        editRequest={request}
      />
    )}
    {request.requestType === 'UNPAID_LEAVE' && (
      <UnpaidLeaveRequestDialog
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSubmitted={handleEditSaved}
        editRequest={request}
      />
    )}
    {request.requestType === 'UPDATE' && (
      <AttendanceUpdateRequestDialog
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSubmitted={handleEditSaved}
        editRequest={request}
        employeeId={request.employeeId}
        continuousShift={request.continuousShift}
      />
    )}
    {request.requestType === 'EXPLANATION' && (
      <AttendanceExplanationDialog
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSubmitted={handleEditSaved}
        editRequest={request}
        employeeId={request.employeeId}
        continuousShift={request.continuousShift}
      />
    )}
    {request.requestType === 'DEPLOYMENT' && (
      <DeploymentRequestDialog
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSubmitted={handleEditSaved}
        editRequest={request}
        employeeId={request.employeeId}
        employeeName={request.employeeName}
        positionTitle={request.positionTitle}
        workDate={request.workDate}
      />
    )}
    </>
  );
}
