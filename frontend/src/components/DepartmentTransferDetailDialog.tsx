import ApartmentOutlinedIcon from '@mui/icons-material/ApartmentOutlined';
import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import EventAvailableOutlinedIcon from '@mui/icons-material/EventAvailableOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import SwapHorizIcon from '@mui/icons-material/SwapHoriz';
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
import * as departmentTransferService from '../services/departmentTransferService';

type Props = {
  open: boolean;
  transferId: number | null;
  onClose: () => void;
  canReview?: boolean;
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
            {departmentTransferService.formatTransferDateTime(timestamp)}
          </Typography>
        )}
      </Stack>
      <Typography variant="body2" sx={{ mt: 0.75, lineHeight: 1.6 }}>
        {comment?.trim() ? comment : 'Không có ghi chú.'}
      </Typography>
    </Box>
  );
}

export function DepartmentTransferDetailDialog({
  open,
  transferId,
  onClose,
  canReview = false,
  onChanged,
}: Props) {
  const theme = useTheme();
  const accent = '#0f766e';
  const [row, setRow] = useState<departmentTransferService.DepartmentTransfer | null>(null);
  const [loading, setLoading] = useState(false);
  const [acting, setActing] = useState(false);
  const [comment, setComment] = useState('');
  const [err, setErr] = useState<string | null>(null);

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
      .then(setRow)
      .catch(() => {
        setRow(null);
        setErr('Không tải được chi tiết đơn.');
      })
      .finally(() => setLoading(false));
  }, [open, transferId]);

  const pending = row?.status === 'PENDING_DIRECTOR';
  const showReviewActions = canReview && pending;
  const hasReviewHistory = Boolean(
    row?.directorReviewedAt || row?.directorReviewerUsername || row?.directorComment || row?.appliedAt,
  );

  async function review(approved: boolean) {
    if (!row) return;
    setActing(true);
    setErr(null);
    try {
      await departmentTransferService.directorReviewTransfer(row.id, approved, comment);
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
        <Button
          onClick={onClose}
          disabled={acting}
          variant="outlined"
          color="inherit"
          sx={{ borderRadius: 2 }}
        >
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
      icon={<SwapHorizIcon />}
      overline={showReviewActions ? 'Duyệt luân chuyển' : 'Chi tiết đơn'}
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
            />
            <Chip
              size="small"
              variant="outlined"
              label={`Hiệu lực ${departmentTransferService.formatTransferDate(row.effectiveDate)}`}
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
            </Grid>
          </FormSection>

          <FormSection title="Nội dung luân chuyển" subtitle="Phòng ban nguồn / đích và ngày áp dụng.">
            <Grid container spacing={1.5}>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Từ phòng ban"
                  value={row.fromDepartmentName}
                  icon={<ApartmentOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Đến phòng ban"
                  value={
                    row.toPositionTitle
                      ? `${row.toDepartmentName} · ${row.toPositionTitle}`
                      : row.toDepartmentName
                  }
                  icon={<ApartmentOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Ngày hiệu lực"
                  value={departmentTransferService.formatTransferDate(row.effectiveDate)}
                  icon={<EventAvailableOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Ngày tạo đơn"
                  value={departmentTransferService.formatTransferDateTime(row.createdAt)}
                  icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              <Grid item xs={12}>
                <Box
                  sx={{
                    p: 2,
                    borderRadius: 2.5,
                    bgcolor: alpha(accent, 0.05),
                    border: `1px dashed ${alpha(accent, 0.25)}`,
                  }}
                >
                  <Typography variant="caption" color="text.secondary" fontWeight={600} display="block">
                    Lý do luân chuyển
                  </Typography>
                  <Typography variant="body1" fontWeight={600} sx={{ mt: 0.5, lineHeight: 1.6 }}>
                    {row.reason || '—'}
                  </Typography>
                </Box>
              </Grid>
              <Grid item xs={12} sm={6}>
                <InfoTile
                  label="Người đề nghị (HCNS)"
                  value={row.requestedByUsername}
                  icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
                />
              </Grid>
              {row.appliedAt && (
                <Grid item xs={12} sm={6}>
                  <InfoTile
                    label="Đã áp dụng chuyển phòng"
                    value={departmentTransferService.formatTransferDateTime(row.appliedAt)}
                    icon={<ScheduleOutlinedIcon sx={{ fontSize: 16 }} />}
                  />
                </Grid>
              )}
            </Grid>
          </FormSection>

          {hasReviewHistory && (
            <FormSection title="Lịch sử duyệt" subtitle="Ghi chú và thời điểm xử lý của Giám đốc.">
              <ReviewNoteCard
                role={row.directorReviewerUsername ? `Giám đốc · ${row.directorReviewerUsername}` : 'Giám đốc'}
                timestamp={row.directorReviewedAt}
                comment={row.directorComment}
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
  );
}
