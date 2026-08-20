import ChildCareIcon from '@mui/icons-material/ChildCare';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import { Box, TextField } from '@mui/material';
import { useEffect, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import {
  FormSection,
  InfoBanner,
  ReadonlyFact,
  RequestFlowSteps,
  WorkRequestDialogShell,
  requestFieldSx,
} from './work/WorkRequestFormUi';
import * as ycs from '../services/youngChildRequestService';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  editRequest?: ycs.YoungChildRequest | null;
  employeeId: number;
  employeeName: string;
  departmentName?: string;
  year: number;
  month: number;
};

const ACCENT = '#c2410c';

export function YoungChildProposeDialog({
  open,
  onClose,
  onSubmitted,
  editRequest,
  employeeId,
  employeeName,
  departmentName,
  year,
  month,
}: Props) {
  const isEditing = Boolean(editRequest);
  const fieldSx = requestFieldSx(ACCENT);
  const defaultStart = `${year}-${String(month).padStart(2, '0')}-01`;
  const defaultEnd = new Date(Date.UTC(year, month, 0)).toISOString().slice(0, 10);
  const [startDate, setStartDate] = useState(defaultStart);
  const [endDate, setEndDate] = useState(defaultEnd);
  const [reason, setReason] = useState('');
  const [enabled, setEnabled] = useState(true);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    if (editRequest) {
      setStartDate(editRequest.startDate || defaultStart);
      setEndDate(editRequest.endDate || defaultEnd);
      setReason(editRequest.reason || '');
      setEnabled(editRequest.enabled);
    } else {
      setStartDate(defaultStart);
      setEndDate(defaultEnd);
      setReason('');
      setEnabled(true);
    }
    setErr(null);
  }, [open, defaultStart, defaultEnd, editRequest]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!reason.trim()) {
      setErr('Nhập lý do đề xuất.');
      return;
    }
    if (!startDate || !endDate || endDate < startDate) {
      setErr('Ngày kết thúc không được trước ngày bắt đầu.');
      return;
    }
    const [startYear, startMonth, startDay] = startDate.split('-').map(Number);
    const maxEnd = new Date(Date.UTC(startYear + 1, startMonth - 1, startDay));
    maxEnd.setUTCDate(maxEnd.getUTCDate() - 1);
    if (endDate > maxEnd.toISOString().slice(0, 10)) {
      setErr('Khoảng thời gian áp dụng không được quá 1 năm.');
      return;
    }
    setLoading(true);
    try {
      const payload = {
        employeeId,
        startDate,
        endDate,
        enabled,
        reason: reason.trim(),
      };
      if (isEditing && editRequest) {
        await ycs.updateYoungChildRequest(editRequest.id, payload);
      } else {
        await ycs.createYoungChildRequest(payload);
      }
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Không gửi được đề xuất. Kiểm tra quyền hoặc đề xuất đang chờ duyệt.');
    } finally {
      setLoading(false);
    }
  }

  const periodLabel = `${startDate.split('-').reverse().join('/')} – ${endDate.split('-').reverse().join('/')}`;

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={ACCENT}
      maxWidth="md"
      icon={<ChildCareIcon />}
      overline={isEditing ? 'Chỉnh sửa đề xuất' : 'Chế độ nuôi con nhỏ'}
      title={isEditing ? 'Chỉnh sửa chế độ nuôi con nhỏ' : 'Đề xuất chế độ nuôi con nhỏ'}
      description="Giảm 1 giờ/ngày · tối thiểu 7h = 1 công · thời gian tối đa 1 năm"
      formId="young-child-propose-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi đề xuất'}
      error={err}
      onSubmit={submit}
    >
      <RequestFlowSteps
        accent={ACCENT}
        steps={[
          { label: 'Đề xuất', hint: 'Trưởng khoa' },
          { label: 'HCNS duyệt', hint: 'Áp dụng tháng' },
        ]}
      />

      <InfoBanner>
        Sau khi HCNS duyệt, hệ thống áp dụng chế độ trong đúng khoảng ngày đã chọn và tính lại bảng công liên quan.
      </InfoBanner>

      <FormSection title="Nhân viên">
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
            gap: 1.25,
          }}
        >
          <ReadonlyFact
            accent={ACCENT}
            icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
            label="Họ và tên"
            value={employeeName}
          />
          <ReadonlyFact accent={ACCENT} label="Khoa/phòng" value={departmentName || '—'} />
          <ReadonlyFact accent={ACCENT} label="Thời gian dự kiến" value={periodLabel} />
        </Box>
      </FormSection>

      <FormSection title="Thời gian áp dụng" subtitle="Chọn khoảng ngày, tối đa 1 năm">
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
            gap: 1.25,
            width: '100%',
          }}
        >
          <DatePickerField
            required
            fullWidth
            size="small"
            label="Ngày bắt đầu"
            value={startDate}
            onChange={setStartDate}
            sx={fieldSx}
          />
          <DatePickerField
            required
            fullWidth
            size="small"
            label="Ngày kết thúc"
            value={endDate}
            onChange={setEndDate}
            sx={fieldSx}
          />
        </Box>
      </FormSection>

      <FormSection title="Nội dung đề xuất">
        <TextField
          required
          fullWidth
          size="small"
          multiline
          minRows={3}
          label="Lý do đề xuất"
          placeholder="Nhập lý do đề xuất bật/tắt chế độ nuôi con nhỏ…"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
