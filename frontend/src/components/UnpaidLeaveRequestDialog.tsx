import MoneyOffOutlinedIcon from '@mui/icons-material/MoneyOffOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import { Box, TextField, Typography } from '@mui/material';
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

export function UnpaidLeaveRequestDialog({ open, onClose, onSubmitted, defaultFrom, editRequest }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = theme.palette.error.dark;
  const fieldSx = requestFieldSx(accent);
  const today = new Date().toISOString().slice(0, 10);
  const isEditing = Boolean(editRequest);

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
  }, [open, defaultFrom, editRequest]);

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
      const payload = {
        requestType: 'UNPAID_LEAVE' as const,
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
      overline={isEditing ? 'Chỉnh sửa đơn' : 'Đề nghị nghỉ không lương'}
      title={isEditing ? 'Chỉnh sửa đơn nghỉ không lương' : 'Đơn nghỉ không lương'}
      description="Quy trình duyệt giống nghỉ phép; không tính công và không trừ hạn mức phép năm."
      formId="unpaid-leave-request-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi đơn nghỉ không lương'}
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
        Ngày được duyệt sẽ ghi <strong>0 công</strong> trên bảng công. Không trừ ngày phép năm.
      </InfoBanner>

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
        {leaveDays > 0 && (
          <Typography variant="body2" color="text.secondary">
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
