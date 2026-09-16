import { Alert, Box, Typography } from '@mui/material';
import type { LeaveBalance } from '../../services/attendanceService';

type Props = {
  balance: LeaveBalance | null;
  /** Số ngày trong đơn đang xem (nếu có). */
  requestDays?: number;
  /** Đơn còn chờ duyệt — số ngày đã nằm trong pendingDays của balance. */
  requestPending?: boolean;
  /** Hiển thị tiêu đề dành cho người duyệt. */
  forReviewer?: boolean;
};

export function LeaveBalanceAlert({
  balance,
  requestDays,
  requestPending,
  forReviewer,
}: Props) {
  if (!balance) return null;

  const requestExceedsRemaining =
    requestDays != null &&
    requestDays > 0 &&
    !requestPending &&
    requestDays > balance.remainingDays;

  const severity =
    balance.overLimit || requestExceedsRemaining
      ? 'error'
      : balance.remainingDays <= 2
        ? 'warning'
        : 'info';

  return (
    <Alert severity={severity} variant="outlined" sx={{ borderRadius: 2.5 }}>
      {forReviewer ? (
        <Typography variant="body2" fontWeight={650} sx={{ mb: 0.5 }}>
          Hạn mức phép năm {balance.year} — tham khảo khi duyệt
        </Typography>
      ) : null}
      <Typography variant="body2" component="div">
        Hạn mức <strong>{balance.entitlementDays}</strong> ngày · đã nghỉ{' '}
        <strong>{balance.usedDays}</strong>
        {balance.pendingDays > 0 ? (
          <>
            {' '}
            · chờ duyệt <strong>{balance.pendingDays}</strong>
          </>
        ) : null}{' '}
        · còn{' '}
        <strong>
          {balance.remainingDays}/{balance.entitlementDays}
        </strong>{' '}
        ngày
        {balance.yearsOfService > 0 ? ` · thâm niên ${balance.yearsOfService} năm` : ''}.
      </Typography>
      {requestDays != null && requestDays > 0 ? (
        <Typography variant="body2" sx={{ mt: 0.75 }}>
          Đơn này: <strong>{requestDays} ngày</strong>
          {requestPending ? ' (đã tính trong chờ duyệt)' : ''}.
          {!requestPending && requestDays > balance.remainingDays ? (
            <> — <Box component="span" sx={{ fontWeight: 700 }}>Vượt số ngày còn lại.</Box>
            </>
          ) : null}
        </Typography>
      ) : null}
      {balance.overLimit ? (
        <Typography variant="body2" color="error.main" fontWeight={650} sx={{ mt: 0.75 }}>
          Đã vượt hạn mức phép (đã nghỉ + chờ duyệt &gt; hạn mức năm).
        </Typography>
      ) : balance.warning ? (
        <Typography variant="body2" sx={{ mt: 0.75 }}>
          {balance.warning}
        </Typography>
      ) : null}
    </Alert>
  );
}
