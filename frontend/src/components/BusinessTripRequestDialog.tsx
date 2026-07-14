import BusinessCenterOutlinedIcon from '@mui/icons-material/BusinessCenterOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import PlaceOutlinedIcon from '@mui/icons-material/PlaceOutlined';
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

export function BusinessTripRequestDialog({ open, onClose, onSubmitted, defaultFrom }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = theme.palette.warning.dark;
  const today = new Date().toISOString().slice(0, 10);

  const [fromDate, setFromDate] = useState(defaultFrom ?? today);
  const [toDate, setToDate] = useState(defaultFrom ?? today);
  const [location, setLocation] = useState('');
  const [reason, setReason] = useState('');
  const [departmentName, setDepartmentName] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const tripDays = useMemo(() => daysInclusive(fromDate, toDate), [fromDate, toDate]);

  useEffect(() => {
    if (!open) return;
    const d = defaultFrom ?? new Date().toISOString().slice(0, 10);
    setFromDate(d);
    setToDate(d);
    setLocation('');
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
    if (!location.trim()) {
      setErr('Nhập địa điểm công tác.');
      return;
    }
    if (!reason.trim()) {
      setErr('Nhập lý do công tác.');
      return;
    }
    if (toDate < fromDate) {
      setErr('Ngày kết thúc phải sau hoặc bằng ngày bắt đầu.');
      return;
    }
    setLoading(true);
    try {
      await att.submitWorkRequest({
        requestType: 'BUSINESS_TRIP',
        workDate: fromDate,
        endDate: toDate,
        shiftScope: 'FULL_DAY',
        reason: reason.trim(),
        location: location.trim(),
      });
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Gửi đơn thất bại. Kiểm tra khoảng ngày trùng đơn công tác khác.');
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
      icon={<BusinessCenterOutlinedIcon />}
      overline="Đề nghị công tác"
      title="Đơn xin công tác"
      description="Chọn khoảng ngày, địa điểm và lý do. Đơn qua lãnh đạo rồi HCNS duyệt."
      formId="business-trip-request-form"
      submitLabel="Gửi đơn công tác"
      error={err}
      onSubmit={submit}
    >
      <InfoBanner>
        Sau khi HCNS duyệt, các ngày trong khoảng sẽ ghi nhận trạng thái bảng công{' '}
        <strong>Công tác</strong> (đủ công, không tính phụ cấp phần ăn tại viện).
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
        title="Thời gian công tác"
        subtitle={tripDays > 0 ? `Số ngày xin: ${tripDays} ngày` : 'Chọn khoảng ngày công tác'}
      >
        <Grid container spacing={1.5}>
          <Grid item xs={12} sm={6}>
            <DatePickerField label="Từ ngày" required value={fromDate} onChange={setFromDate} sx={fieldSx} />
          </Grid>
          <Grid item xs={12} sm={6}>
            <DatePickerField label="Đến ngày" required value={toDate} onChange={setToDate} sx={fieldSx} />
          </Grid>
        </Grid>
        {tripDays > 0 && (
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            Đơn xin công tác {tripDays} ngày lịch.
          </Typography>
        )}
      </FormSection>

      <FormSection title="Địa điểm công tác">
        <TextField
          fullWidth
          size="small"
          required
          placeholder="Ví dụ: BV Chợ Rẫy, Sở Y tế TP.HCM…"
          value={location}
          onChange={(e) => setLocation(e.target.value)}
          sx={fieldSx}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <PlaceOutlinedIcon fontSize="small" color="action" />
              </InputAdornment>
            ),
          }}
        />
      </FormSection>

      <FormSection title="Lý do công tác">
        <TextField
          fullWidth
          size="small"
          required
          multiline
          minRows={3}
          placeholder="Ví dụ: Hội thảo chuyên môn, làm việc với đối tác…"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
