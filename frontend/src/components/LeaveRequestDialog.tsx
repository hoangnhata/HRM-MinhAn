import BeachAccessOutlinedIcon from '@mui/icons-material/BeachAccessOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import { Alert, Box, TextField, Typography } from '@mui/material';
import { useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as att from '../services/attendanceService';
import * as employeeService from '../services/employeeService';
import { DatePickerField } from './ui/DateTimeFields';
import {
  FormSection,
  InfoBanner,
  ReadonlyFact,
  RequestFlowSteps,
  WorkRequestDialogShell,
  requestFieldSx,
} from './work/WorkRequestFormUi';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  defaultFrom?: string;
  editRequest?: att.WorkRequest | null;
};

function daysInclusive(from: string, to: string): number {
  const a = new Date(`${from}T12:00:00`);
  const b = new Date(`${to}T12:00:00`);
  if (Number.isNaN(a.getTime()) || Number.isNaN(b.getTime()) || b < a) return 0;
  return Math.round((b.getTime() - a.getTime()) / 86400000) + 1;
}

export function LeaveRequestDialog({ open, onClose, onSubmitted, defaultFrom, editRequest }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = theme.palette.secondary.main;
  const fieldSx = requestFieldSx(accent);
  const today = new Date().toISOString().slice(0, 10);
  const isEditing = Boolean(editRequest);

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
    if (editRequest) {
      setFromDate(editRequest.workDate || d);
      setToDate(editRequest.endDate || editRequest.workDate || d);
      setReason(editRequest.reason || '');
    } else {
      setFromDate(d);
      setToDate(d);
      setReason('');
    }
    setErr(null);
    employeeService
      .fetchMe()
      .then((me) => setDepartmentName(me.departmentName ?? ''))
      .catch(() => setDepartmentName(''));
    att.fetchMyLeaveBalance(new Date(d).getFullYear())
      .then(setBalance)
      .catch(() => setBalance(null));
  }, [open, defaultFrom, editRequest]);

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
      const payload = {
        requestType: 'LEAVE' as const,
        workDate: fromDate,
        endDate: toDate,
        shiftScope: 'FULL_DAY' as const,
        reason: reason.trim(),
      };
      if (isEditing && editRequest) {
        await att.updateWorkRequest(editRequest.id, payload);
      } else {
        await att.submitWorkRequest(payload);
      }
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
      overline={isEditing ? 'Chỉnh sửa đơn' : 'Đề nghị nghỉ phép'}
      title={isEditing ? 'Chỉnh sửa đơn nghỉ phép' : 'Đơn nghỉ phép'}
      description="Chọn khoảng ngày và lý do. Đơn qua Lãnh đạo, HCNS và Giám đốc duyệt."
      formId="leave-request-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi đơn nghỉ phép'}
      error={err}
      onSubmit={submit}
    >
      <RequestFlowSteps
        accent={accent}
        steps={[
          { label: 'Gửi đơn', hint: 'Nhân viên' },
          { label: 'Lãnh đạo duyệt', hint: 'Trưởng khoa / ĐD trưởng' },
          { label: 'HCNS duyệt', hint: 'Hành chính nhân sự' },
          { label: 'Giám đốc duyệt', hint: 'Duyệt cuối' },
        ]}
      />

      <InfoBanner>
        Hạn mức năm: <strong>12 ngày</strong> cơ bản; cứ đủ <strong>5 năm</strong> thâm niên thêm{' '}
        <strong>1 ngày</strong>. Không được vượt số ngày còn lại trong năm.
      </InfoBanner>

      {balance && (
        <Alert
          severity={balance.overLimit || balance.remainingDays <= 2 ? 'warning' : 'info'}
          variant="outlined"
          sx={{ borderRadius: 2.5 }}
        >
          Năm {balance.year}: đã dùng <strong>{balance.usedDays}</strong>
          {balance.pendingDays > 0 ? (
            <>
              {' '}
              · chờ duyệt <strong>{balance.pendingDays}</strong>
            </>
          ) : null}{' '}
          · còn <strong>
            {balance.remainingDays}/{balance.entitlementDays}
          </strong>{' '}
          ngày
          {balance.yearsOfService > 0 ? ` · thâm niên ${balance.yearsOfService} năm` : ''}.
          {balance.warning ? ` ${balance.warning}` : ''}
        </Alert>
      )}

      <FormSection title="Người nộp đơn">
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
            gap: 1.25,
          }}
        >
          <ReadonlyFact
            accent={accent}
            icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
            label="Họ và tên"
            value={user?.fullName ?? ''}
          />
          <ReadonlyFact
            accent={accent}
            icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
            label="Phòng ban"
            value={departmentName}
          />
        </Box>
      </FormSection>

      <FormSection
        title="Thời gian nghỉ"
        subtitle={leaveDays > 0 ? `Số ngày xin: ${leaveDays} ngày` : 'Chọn khoảng ngày nghỉ'}
      >
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
            gap: 1.75,
          }}
        >
          <DatePickerField label="Từ ngày" required value={fromDate} onChange={setFromDate} sx={fieldSx} />
          <DatePickerField label="Đến ngày" required value={toDate} onChange={setToDate} sx={fieldSx} />
        </Box>
        {leaveDays > 0 && balance && leaveDays > balance.remainingDays && (
          <Typography variant="body2" color="error" sx={{ mt: 0.5 }}>
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
