import BeachAccessOutlinedIcon from '@mui/icons-material/BeachAccessOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import { Alert, Grid, InputAdornment, TextField, Typography } from '@mui/material';
import { useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as att from '../services/attendanceService';
import * as employeeService from '../services/employeeService';
import { DatePickerField, dateTimeFieldSx } from './ui/DateTimeFields';
import { FormSection, InfoBanner, WorkRequestDialogShell } from './work/WorkRequestFormUi';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  defaultFrom?: string;
};

const fieldSx = dateTimeFieldSx;

function daysInclusive(from: string, to: string): number {
  const a = new Date(`${from}T12:00:00`);
  const b = new Date(`${to}T12:00:00`);
  if (Number.isNaN(a.getTime()) || Number.isNaN(b.getTime()) || b < a) return 0;
  return Math.round((b.getTime() - a.getTime()) / 86400000) + 1;
}

export function LeaveRequestDialog({ open, onClose, onSubmitted, defaultFrom }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = theme.palette.secondary.main;
  const today = new Date().toISOString().slice(0, 10);

  const [fromDate, setFromDate] = useState(defaultFrom ?? today);
  const [toDate, setToDate] = useState(defaultFrom ?? today);
  const [reason, setReason] = useState('');
  const [departmentName, setDepartmentName] = useState('');
  const [balance, setBalance] = useState<att.LeaveBalance | null>(null);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const leaveDays = useMemo(() => daysInclusive(fromDate, toDate), [fromDate, toDate]);

  useEffect(() => {
    if (!open) return;
    const d = defaultFrom ?? new Date().toISOString().slice(0, 10);
    setFromDate(d);
    setToDate(d);
    setReason('');
    setErr(null);
    employeeService
      .fetchMe()
      .then((me) => setDepartmentName(me.departmentName ?? ''))
      .catch(() => setDepartmentName(''));
    att.fetchMyLeaveBalance(new Date(d).getFullYear())
      .then(setBalance)
      .catch(() => setBalance(null));
  }, [open, defaultFrom]);

  useEffect(() => {
    if (!open || !fromDate) return;
    const y = Number(fromDate.slice(0, 4));
    if (!Number.isFinite(y)) return;
    att.fetchMyLeaveBalance(y).then(setBalance).catch(() => setBalance(null));
  }, [open, fromDate]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!reason.trim()) {
      setErr('Nhập lý do nghỉ phép.');
      return;
    }
    if (toDate < fromDate) {
      setErr('Ngày kết thúc phải sau hoặc bằng ngày bắt đầu.');
      return;
    }
    if (balance && leaveDays > balance.remainingDays) {
      setErr(
        `Vượt hạn mức phép: còn ${balance.remainingDays}/${balance.entitlementDays} ngày, đơn xin ${leaveDays} ngày.`,
      );
      return;
    }
    setLoading(true);
    try {
      await att.submitWorkRequest({
        requestType: 'LEAVE',
        workDate: fromDate,
        endDate: toDate,
        shiftScope: 'FULL_DAY',
        reason: reason.trim(),
      });
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Gửi đơn thất bại. Kiểm tra hạn mức phép hoặc khoảng ngày trùng đơn khác.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={accent}
      maxWidth="md"
      icon={<BeachAccessOutlinedIcon />}
      overline="Đề nghị nghỉ phép"
      title="Đơn nghỉ phép"
      description="Chọn từ ngày — đến ngày và lý do. Đơn qua lãnh đạo rồi HCNS duyệt."
      formId="leave-request-form"
      submitLabel="Gửi đơn nghỉ phép"
      error={err}
      onSubmit={submit}
    >
      <InfoBanner>
        Hạn mức năm: <strong>12 ngày</strong> cơ bản; cứ đủ <strong>5 năm</strong> thâm niên thêm{' '}
        <strong>1 ngày</strong> (5 năm → 13, 10 năm → 14…). Không được vượt số ngày còn lại trong năm.
      </InfoBanner>

      {balance && (
        <Alert
          severity={balance.overLimit || balance.remainingDays <= 2 ? 'warning' : 'info'}
          variant="outlined"
          sx={{ borderRadius: 2 }}
        >
          Năm {balance.year}: đã dùng <strong>{balance.usedDays}</strong>
          {balance.pendingDays > 0 ? (
            <>
              {' '}
              · chờ duyệt <strong>{balance.pendingDays}</strong>
            </>
          ) : null}{' '}
          · còn <strong>{balance.remainingDays}/{balance.entitlementDays}</strong> ngày
          {balance.yearsOfService > 0 ? ` · thâm niên ${balance.yearsOfService} năm` : ''}.
          {balance.warning ? ` ${balance.warning}` : ''}
        </Alert>
      )}

      <FormSection title="Người nộp đơn">
        <Grid container spacing={1.5}>
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              size="small"
              label="Họ và tên"
              value={user?.fullName ?? ''}
              disabled
              sx={fieldSx}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <PersonOutlineIcon fontSize="small" color="action" />
                  </InputAdornment>
                ),
              }}
            />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              size="small"
              label="Phòng ban"
              value={departmentName || '—'}
              disabled
              sx={fieldSx}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <BusinessOutlinedIcon fontSize="small" color="action" />
                  </InputAdornment>
                ),
              }}
            />
          </Grid>
        </Grid>
      </FormSection>

      <FormSection
        title="Thời gian nghỉ"
        subtitle={leaveDays > 0 ? `Số ngày xin: ${leaveDays} ngày` : 'Chọn khoảng ngày nghỉ'}
      >
        <Grid container spacing={1.5}>
          <Grid item xs={12} sm={6}>
            <DatePickerField label="Từ ngày" required value={fromDate} onChange={setFromDate} sx={fieldSx} />
          </Grid>
          <Grid item xs={12} sm={6}>
            <DatePickerField label="Đến ngày" required value={toDate} onChange={setToDate} sx={fieldSx} />
          </Grid>
        </Grid>
        {leaveDays > 0 && balance && leaveDays > balance.remainingDays && (
          <Typography variant="body2" color="error" sx={{ mt: 1 }}>
            Đơn xin {leaveDays} ngày nhưng chỉ còn {balance.remainingDays} ngày phép.
          </Typography>
        )}
      </FormSection>

      <FormSection title="Lý do nghỉ phép">
        <TextField
          fullWidth
          size="small"
          required
          multiline
          minRows={3}
          placeholder="Ví dụ: Nghỉ phép năm, việc gia đình…"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
