import MoneyOffOutlinedIcon from '@mui/icons-material/MoneyOffOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import { Grid, InputAdornment, TextField, Typography } from '@mui/material';
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

export function UnpaidLeaveRequestDialog({ open, onClose, onSubmitted, defaultFrom }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = theme.palette.error.dark;
  const today = new Date().toISOString().slice(0, 10);

  const [fromDate, setFromDate] = useState(defaultFrom ?? today);
  const [toDate, setToDate] = useState(defaultFrom ?? today);
  const [reason, setReason] = useState('');
  const [departmentName, setDepartmentName] = useState('');
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
  }, [open, defaultFrom]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!reason.trim()) {
      setErr('Nhập lý do nghỉ không lương.');
      return;
    }
    if (toDate < fromDate) {
      setErr('Ngày kết thúc phải sau hoặc bằng ngày bắt đầu.');
      return;
    }
    setLoading(true);
    try {
      await att.submitWorkRequest({
        requestType: 'UNPAID_LEAVE',
        workDate: fromDate,
        endDate: toDate,
        shiftScope: 'FULL_DAY',
        reason: reason.trim(),
      });
      onSubmitted?.();
      onClose();
    } catch (ex: unknown) {
      const msg =
        ex && typeof ex === 'object' && 'response' in ex
          ? String((ex as { response?: { data?: { message?: string } } }).response?.data?.message ?? '')
          : '';
      setErr(msg || 'Gửi đơn thất bại. Kiểm tra khoảng ngày trùng đơn nghỉ khác.');
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
      icon={<MoneyOffOutlinedIcon />}
      overline="Đề nghị nghỉ không lương"
      title="Đơn nghỉ không lương"
      description="Giống nghỉ phép về quy trình duyệt, nhưng không tính công và không trừ hạn mức phép năm."
      formId="unpaid-leave-request-form"
      submitLabel="Gửi đơn nghỉ không lương"
      error={err}
      onSubmit={submit}
    >
      <InfoBanner>
        Ngày được duyệt sẽ ghi <strong>0 công</strong> trên bảng công (không hưởng lương theo công). Không trừ ngày
        phép năm. Đơn qua lãnh đạo rồi HCNS duyệt.
      </InfoBanner>

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
        {leaveDays > 0 && (
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            Các ngày này sẽ không được tính công khi đơn được HCNS duyệt.
          </Typography>
        )}
      </FormSection>

      <FormSection title="Lý do nghỉ không lương">
        <TextField
          fullWidth
          size="small"
          required
          multiline
          minRows={3}
          placeholder="Ví dụ: Việc riêng, không dùng phép năm…"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
