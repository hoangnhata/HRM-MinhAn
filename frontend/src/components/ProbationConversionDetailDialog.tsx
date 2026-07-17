import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import EventAvailableOutlinedIcon from '@mui/icons-material/EventAvailableOutlined';
import HowToRegIcon from '@mui/icons-material/HowToReg';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import {
  Box,
  Button,
  Chip,
  CircularProgress,
  Grid,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { dateTimeFieldSx } from './ui/DateTimeFields';
import { FormSection, InfoBanner, WorkRequestViewShell } from './work/WorkRequestFormUi';
import * as pcs from '../services/probationConversionService';

type Props = {
  open: boolean;
  conversionId: number | null;
  onClose: () => void;
  /** HR/ADMIN khi đơn PENDING_HR */
  canHrReview?: boolean;
  /** DIRECTOR/ADMIN khi đơn PENDING_DIRECTOR */
  canDirectorReview?: boolean;
  onChanged?: () => void;
};

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

function ReviewNoteCard({
  role,
  timestamp,
  comment,
}: {
  role: string;
  timestamp?: string | null;
  comment?: string | null;
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
            {pcs.formatConversionDateTime(timestamp)}
          </Typography>
        )}
      </Stack>
      <Typography variant="body2" sx={{ mt: 0.75, lineHeight: 1.6 }}>
        {comment?.trim() ? comment : 'Không có ghi chú.'}
      </Typography>
    </Box>
  );
}

export function ProbationConversionDetailDialog({
  open,
  conversionId,
  onClose,
  canHrReview = false,
  canDirectorReview = false,
  onChanged,
}: Props) {
  const theme = useTheme();
  const accent = '#15803d';
  const [row, setRow] = useState<pcs.ProbationConversion | null>(null);
  const [loading, setLoading] = useState(false);
  const [acting, setActing] = useState(false);
  const [comment, setComment] = useState('');
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open || conversionId == null) {
      setRow(null);
      setComment('');
      setErr(null);
      return;
    }
    setLoading(true);
    setErr(null);
    pcs
      .fetchConversionDetail(conversionId)
      .then(setRow)
      .catch(() => {
        setRow(null);
        setErr('Không tải được chi tiết đơn.');
      })
      .finally(() => setLoading(false));
  }, [open, conversionId]);

  const showHrActions = canHrReview && row?.status === 'PENDING_HR';
  const showDirectorActions = canDirectorReview && row?.status === 'PENDING_DIRECTOR';
  const showReviewActions = showHrActions || showDirectorActions;

  async function review(approved: boolean) {
    if (!row) return;
    setActing(true);
    setErr(null);
    try {
      if (showHrActions) {
        await pcs.hrReviewConversion(row.id, approved, comment);
      } else {
        await pcs.directorReviewConversion(row.id, approved, comment);
      }
      onChanged?.();
      onClose();
    } catch {
      setErr(approved ? 'Duyệt thất bại.' : 'Từ chối thất bại.');
    } finally {
      setActing(false);
    }
  }

  const footer = showReviewActions ? (
    <Box
      sx={{
        px: 2.5,
        py: 2,
        borderTop: `1px solid ${theme.palette.divider}`,
        bgcolor: alpha(theme.palette.background.default, 0.5),
      }}
    >
      <Stack direction="row" spacing={1.5} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
        <Button onClick={onClose} disabled={acting} variant="outlined" color="inherit" sx={{ borderRadius: 2 }}>
          Đóng
        </Button>
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
      </Stack>
    </Box>
  ) : undefined;

  return (
    <WorkRequestViewShell
      open={open}
      onClose={onClose}
      loading={acting || loading}
      accent={accent}
      icon={<HowToRegIcon />}
      overline={showReviewActions ? 'Duyệt chuyển chính thức' : 'Chi tiết đơn'}
      title="Chuyển thử việc / thực tập lên chính thức"
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
              label={pcs.CONVERSION_STATUS_LABEL[row.status] || row.status}
              color={pcs.conversionStatusColor(row.status)}
            />
            <Chip
              size="small"
              variant="outlined"
              label={`Ngày ${pcs.formatConversionDate(row.officialDate)}`}
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
                ? 'Sau khi HCNS duyệt, đơn chuyển sang Giám đốc. Nhân viên chỉ lên chính thức đúng ngày đã chọn.'
                : 'Sau khi Giám đốc duyệt, hệ thống chuyển nhân viên lên chính thức đúng ngày đã chọn (không chuyển ngay nếu ngày còn ở tương lai).'}
            </InfoBanner>
          )}

          <FormSection title="Thông tin nhân viên">
            <Grid container spacing={1.5}>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Họ tên"
                  value={row.employeeName}
                  icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Mã nhân viên"
                  value={row.employeeCode}
                  icon={<BadgeOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile label="Phòng ban" value={row.departmentName} />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Trạng thái hiện tại"
                  value={
                    row.employeeStatus === 'INTERN'
                      ? 'Thực tập'
                      : row.employeeStatus === 'PROBATION'
                        ? 'Thử việc'
                        : row.employeeStatus || '—'
                  }
                />
              </Grid>
            </Grid>
          </FormSection>

          <FormSection title="Nội dung đề nghị">
            <Grid container spacing={1.5}>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Ngày lên chính thức"
                  value={pcs.formatConversionDate(row.officialDate)}
                  icon={<EventAvailableOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Người lập đơn"
                  value={row.requestedByUsername}
                  icon={<ScheduleOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12}>
                <InfoTile
                  label="Lý do"
                  value={row.reason}
                  icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
            </Grid>
          </FormSection>

          {(row.hrReviewedAt || row.hrReviewerUsername || row.directorReviewedAt || row.appliedAt) && (
            <FormSection title="Lịch sử duyệt">
              <Stack spacing={1.5}>
                {(row.hrReviewedAt || row.hrReviewerUsername) && (
                  <ReviewNoteCard
                    role={`HCNS · ${row.hrReviewerUsername || '—'}`}
                    timestamp={row.hrReviewedAt}
                    comment={row.hrComment}
                  />
                )}
                {(row.directorReviewedAt || row.directorReviewerUsername) && (
                  <ReviewNoteCard
                    role={`Giám đốc · ${row.directorReviewerUsername || '—'}`}
                    timestamp={row.directorReviewedAt}
                    comment={row.directorComment}
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

          {showReviewActions && (
            <FormSection title="Ghi chú duyệt (tuỳ chọn)">
              <TextField
                fullWidth
                size="small"
                multiline
                minRows={2}
                label="Ghi chú"
                value={comment}
                onChange={(e) => setComment(e.target.value)}
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
  );
}
