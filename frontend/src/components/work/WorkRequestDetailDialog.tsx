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
import { useState } from 'react';
import * as att from '../../services/attendanceService';
import { dateTimeFieldSx } from '../ui/DateTimeFields';
import { FormSection, InfoBanner, WorkRequestViewShell } from './WorkRequestFormUi';

type ReviewActions = {
  isHead: boolean;
  isHr: boolean;
  comment: string;
  onCommentChange: (value: string) => void;
  loading?: boolean;
  onHeadReview?: (approved: boolean) => void;
  onHrReview?: (approved: boolean, waiveFine?: boolean) => void;
};

type Props = {
  open: boolean;
  onClose: () => void;
  request: att.WorkRequest | null;
  mode: 'mine' | 'review';
  review?: ReviewActions;
  onWithdraw?: () => void | Promise<void>;
  withdrawLoading?: boolean;
};

const fieldSx = dateTimeFieldSx;

function InfoTile({
  label,
  value,
  icon,
}: {
  label: string;
  value: React.ReactNode;
  icon?: React.ReactNode;
}) {
  const theme = useTheme();
  return (
    <Box
      sx={{
        p: 1.5,
        borderRadius: 2,
        bgcolor: alpha(theme.palette.grey[500], 0.04),
        border: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
        height: '100%',
      }}
    >
      <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 0.5 }}>
        {icon && (
          <Box sx={{ color: 'text.secondary', display: 'flex', alignItems: 'center' }}>{icon}</Box>
        )}
        <Typography variant="caption" color="text.secondary" fontWeight={600}>
          {label}
        </Typography>
      </Stack>
      <Typography variant="body2" fontWeight={700}>
        {value || '—'}
      </Typography>
    </Box>
  );
}

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

function ReviewNoteCard({
  role,
  timestamp,
  comment,
}: {
  role: string;
  timestamp?: string;
  comment?: string;
}) {
  const theme = useTheme();
  return (
    <Box
      sx={{
        p: 1.75,
        borderRadius: 2,
        bgcolor: alpha(theme.palette.grey[500], 0.05),
        border: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
      }}
    >
      <Stack direction="row" justifyContent="space-between" alignItems="center" spacing={1}>
        <Typography variant="subtitle2" fontWeight={700}>
          {role}
        </Typography>
        {timestamp && (
          <Typography variant="caption" color="text.secondary">
            {att.formatReviewTimestamp(timestamp)}
          </Typography>
        )}
      </Stack>
      <Typography variant="body2" sx={{ mt: 0.75, lineHeight: 1.6 }}>
        {comment?.trim() ? comment : 'Không có ghi chú.'}
      </Typography>
    </Box>
  );
}

export function WorkRequestDetailDialog({ open, onClose, request, mode, review, onWithdraw, withdrawLoading }: Props) {
  const theme = useTheme();
  const [confirmWithdraw, setConfirmWithdraw] = useState(false);
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
  const canHeadAct = mode === 'review' && review?.isHead && request.status === 'PENDING_HEAD';
  const canHrAct = mode === 'review' && review?.isHr && request.status === 'PENDING_HR';
  const canAct = canHeadAct || canHrAct;
  const canWithdraw = mode === 'mine' && att.isRequestWithdrawable(request.status) && Boolean(onWithdraw);
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
    request.hrComment ||
    request.hrReviewedAt;

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

  const description =
    mode === 'review'
      ? `${request.employeeName} · ${request.department}`
      : `${request.department} · Gửi ${att.formatReviewTimestamp(request.createdAt)}`;

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
          {canHeadAct && (
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
          )}
          {canHrAct && request.requestType === 'UPDATE' && (
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
                color="secondary"
                disabled={review.loading}
                onClick={() => review.onHrReview?.(true, true)}
                sx={{ borderRadius: 2 }}
              >
                Duyệt (không trừ tiền)
              </Button>
              <Button
                variant="contained"
                disabled={review.loading}
                startIcon={review.loading ? <CircularProgress size={16} color="inherit" /> : undefined}
                onClick={() => review.onHrReview?.(true, false)}
                sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
              >
                Duyệt (trừ {forgotUnits} lần quên chấm)
              </Button>
            </>
          )}
          {canHrAct && request.requestType === 'EXPLANATION' && (
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
                onClick={() => review.onHrReview?.(true)}
                sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
              >
                Duyệt giải trình
              </Button>
            </>
          )}
          {canHrAct && request.requestType === 'LEAVE' && (
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
                onClick={() => review.onHrReview?.(true)}
                sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
              >
                Duyệt nghỉ phép
              </Button>
            </>
          )}
          {canHrAct && request.requestType === 'UNPAID_LEAVE' && (
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
                onClick={() => review.onHrReview?.(true)}
                sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
              >
                Duyệt nghỉ không lương
              </Button>
            </>
          )}
          {canHrAct && request.requestType === 'BUSINESS_TRIP' && (
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
                onClick={() => review.onHrReview?.(true)}
                sx={{ borderRadius: 2, px: 2.5, bgcolor: accent, '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' } }}
              >
                Duyệt công tác
              </Button>
            </>
          )}
        </Stack>
      </Box>
    ) : canWithdraw ? (
      <Box
        sx={{
          px: 2.5,
          py: 2,
          borderTop: `1px solid ${theme.palette.divider}`,
          bgcolor: alpha(theme.palette.background.default, 0.5),
        }}
      >
        <Stack direction="row" spacing={1.5} justifyContent="space-between" alignItems="center" flexWrap="wrap" useFlexGap>
          <Typography variant="caption" color="text.secondary" sx={{ maxWidth: 320, lineHeight: 1.5 }}>
            Chỉ thu hồi được khi đơn đang chờ duyệt (chưa được HCNS duyệt).
          </Typography>
          <Button
            variant="outlined"
            color="error"
            startIcon={withdrawLoading ? <CircularProgress size={16} color="inherit" /> : <UndoOutlinedIcon />}
            disabled={withdrawLoading}
            onClick={() => setConfirmWithdraw(true)}
            sx={{ borderRadius: 2, fontWeight: 700, flexShrink: 0 }}
          >
            Thu hồi đơn
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
      footer={footer || (!canAct && mode === 'review' ? (
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
          />
          {request.requestType === 'UPDATE' && request.updateKind && (
            <Chip size="small" variant="outlined" label={att.updateKindLabel(request.updateKind)} />
          )}
          {request.requestType === 'LEAVE' && (
            <Chip
              size="small"
              variant="outlined"
              label={`${request.leaveDays ?? 1} ngày phép`}
            />
          )}
          {request.requestType === 'UNPAID_LEAVE' && (
            <Chip
              size="small"
              variant="outlined"
              label={`${request.leaveDays ?? 1} ngày không lương`}
            />
          )}
          {request.requestType === 'BUSINESS_TRIP' && (
            <Chip
              size="small"
              variant="outlined"
              label={`${request.tripDays ?? 1} ngày công tác`}
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
            />
          )}
        </Stack>
      }
    >
      {canHrAct && request.requestType === 'UPDATE' && (
        <InfoBanner>
          Nếu duyệt có phạt quên chấm: trừ <strong>{forgotUnits} lần</strong> (theo bậc phạt tháng). Chọn{' '}
          <strong>Duyệt (không trừ tiền)</strong> nếu miễn phạt.
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

      {request.requestType === 'DEPLOYMENT' && (
        <InfoBanner>
          Đơn điều động áp dụng ngay với hệ số <strong>×1,5</strong>
          {request.deploymentActualHours != null && request.deploymentCreditedHours != null
            ? ` (${request.deploymentActualHours}h thực tế → ${request.deploymentCreditedHours}h công)`
            : ''}
          . Nhân viên đã nhận thông báo.
        </InfoBanner>
      )}

      <FormSection title="Thông tin đơn">
        <Grid container spacing={1.5}>
          <Grid item xs={12} sm={6}>
            <InfoTile
              label={isRanged ? 'Từ ngày' : 'Ngày công'}
              value={att.formatWorkDate(request.workDate)}
              icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
            />
          </Grid>
          {isRanged ? (
            <Grid item xs={12} sm={6}>
              <InfoTile
                label="Đến ngày"
                value={att.formatWorkDate(request.endDate || request.workDate)}
                icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
              />
            </Grid>
          ) : (
            <Grid item xs={12} sm={6}>
              <InfoTile
                label="Phòng ban"
                value={request.department}
                icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
              />
            </Grid>
          )}
          {(request.requestType === 'LEAVE' || request.requestType === 'UNPAID_LEAVE') && (
            <>
              <Grid item xs={12} sm={6}>
                <InfoTile
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
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Phòng ban"
                  value={request.department}
                  icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
            </>
          )}
          {request.requestType === 'BUSINESS_TRIP' && (
            <>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Số ngày"
                  value={`${request.tripDays ?? 1} ngày`}
                  icon={<BusinessCenterOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Địa điểm"
                  value={request.location || '—'}
                  icon={<PlaceOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Phòng ban"
                  value={request.department}
                  icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
            </>
          )}
          {request.requestType === 'DEPLOYMENT' && (
            <>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Khung giờ"
                  value={
                    request.requestedStart && request.requestedEnd
                      ? `${request.requestedStart.slice(0, 5)} – ${request.requestedEnd.slice(0, 5)}`
                      : '—'
                  }
                  icon={<AccessTimeIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Công ×1,5"
                  value={
                    request.deploymentActualHours != null && request.deploymentCreditedHours != null
                      ? `${request.deploymentActualHours}h → ${request.deploymentCreditedHours}h công`
                      : 'Hệ số 1,5'
                  }
                  icon={<SwapHorizOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Phòng ban"
                  value={request.department}
                  icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
            </>
          )}
          {mode === 'review' && (
            <Grid item xs={12} sm={6}>
              <InfoTile
                label="Nhân viên"
                value={request.employeeName}
                icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
              />
            </Grid>
          )}
          <Grid item xs={12} sm={mode === 'review' ? 6 : 12}>
            <InfoTile
              label="Ngày gửi đơn"
              value={att.formatReviewTimestamp(request.createdAt)}
              icon={<ScheduleOutlinedIcon sx={{ fontSize: 16 }} />}
            />
          </Grid>
        </Grid>
      </FormSection>

      <FormSection title="Lý do" subtitle="Nội dung nhân viên trình bày trong đơn.">
        <TextField
          fullWidth
          size="small"
          multiline
          minRows={3}
          value={request.reason}
          disabled
          sx={fieldSx}
        />
      </FormSection>

      {request.requestType === 'UPDATE' && (shifts.morning || shifts.afternoon) && (
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
              {shifts.morning && (
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
              {shifts.afternoon && (
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
            {(request.headComment || request.headReviewedAt) && (
              <ReviewNoteCard
                role="Lãnh đạo"
                timestamp={request.headReviewedAt}
                comment={request.headComment}
              />
            )}
            {(request.hrComment || request.hrReviewedAt) && (
              <ReviewNoteCard role="HCNS" timestamp={request.hrReviewedAt} comment={request.hrComment} />
            )}
          </Stack>
        </FormSection>
      )}

      {canAct && review && (
        <FormSection title="Ghi chú duyệt" subtitle="Tuỳ chọn — ghi chú sẽ lưu vào lịch sử duyệt.">
          <TextField
            fullWidth
            size="small"
            placeholder="Nhập ghi chú (tuỳ chọn)…"
            value={review.comment}
            onChange={(e) => review.onCommentChange(e.target.value)}
            disabled={review.loading}
            multiline
            minRows={3}
            sx={fieldSx}
          />
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
          Đơn sẽ không còn chờ duyệt. Bạn có thể gửi lại đơn mới sau khi thu hồi nếu gửi nhầm.
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
    </>
  );
}
