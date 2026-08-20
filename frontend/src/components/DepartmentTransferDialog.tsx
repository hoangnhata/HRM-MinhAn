import ApartmentOutlinedIcon from '@mui/icons-material/ApartmentOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import SwapHorizIcon from '@mui/icons-material/SwapHoriz';
import { Box, MenuItem, TextField } from '@mui/material';
import { useEffect, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import * as departmentTransferService from '../services/departmentTransferService';
import * as employeeService from '../services/employeeService';
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
  editTransfer?: departmentTransferService.DepartmentTransfer | null;
  employee: { id: number; fullName: string; departmentName?: string } | null;
};

const ACCENT = '#0f766e';

export function DepartmentTransferDialog({ open, onClose, onSubmitted, editTransfer, employee }: Props) {
  const isEditing = Boolean(editTransfer);
  const fieldSx = requestFieldSx(ACCENT);
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [positions, setPositions] = useState<employeeService.PositionOption[]>([]);
  const [toDepartmentId, setToDepartmentId] = useState<number | ''>('');
  const [toPositionId, setToPositionId] = useState<number | ''>('');
  const [effectiveDate, setEffectiveDate] = useState('');
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    if (editTransfer) {
      setToDepartmentId(editTransfer.toDepartmentId);
      setToPositionId(editTransfer.toPositionId ?? '');
      setEffectiveDate(editTransfer.effectiveDate || '');
      setReason(editTransfer.reason || '');
    } else {
      setReason('');
      setToDepartmentId('');
      setToPositionId('');
      setEffectiveDate(new Date().toISOString().slice(0, 10));
    }
    employeeService.fetchDepartments().then(setDepartments).catch(() => setDepartments([]));
    employeeService.fetchPositions().then(setPositions).catch(() => setPositions([]));
  }, [open, employee?.id, editTransfer]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!employee) return;
    if (!toDepartmentId) {
      setErr('Chọn phòng ban đích.');
      return;
    }
    if (!effectiveDate) {
      setErr('Nhập ngày luân chuyển.');
      return;
    }
    if (!reason.trim()) {
      setErr('Nhập lý do luân chuyển.');
      return;
    }
    setLoading(true);
    setErr(null);
    try {
      const payload = {
        employeeId: employee.id,
        toDepartmentId: Number(toDepartmentId),
        toPositionId: toPositionId === '' ? undefined : Number(toPositionId),
        effectiveDate,
        reason: reason.trim(),
      };
      if (isEditing && editTransfer) {
        await departmentTransferService.updateTransfer(editTransfer.id, payload);
      } else {
        await departmentTransferService.createTransfer(payload);
      }
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Gửi đề nghị thất bại. Kiểm tra ngày/phòng ban hoặc đề nghị đang chờ.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={ACCENT}
      icon={<SwapHorizIcon />}
      overline={isEditing ? 'Chỉnh sửa đề nghị luân chuyển' : 'Đề nghị luân chuyển'}
      title={isEditing ? 'Chỉnh sửa luân chuyển phòng ban' : 'Luân chuyển phòng ban'}
      description={
        employee
          ? `${employee.fullName}${employee.departmentName ? ` · ${employee.departmentName}` : ''}`
          : ''
      }
      formId="dept-transfer-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi Giám đốc duyệt'}
      error={err}
      onSubmit={submit}
      maxWidth="md"
    >
      <RequestFlowSteps
        accent={ACCENT}
        steps={[
          { label: 'HCNS lập phiếu', hint: 'Hành chính nhân sự' },
          { label: 'Giám đốc duyệt', hint: 'Ban Giám đốc' },
        ]}
      />

      <InfoBanner>
        Nhân viên chỉ chuyển phòng ban đúng <strong>ngày hiệu lực</strong> đã chọn (không chuyển ngay
        nếu ngày còn ở tương lai).
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
            label="Họ tên"
            value={employee?.fullName || ''}
          />
          <ReadonlyFact
            accent={ACCENT}
            icon={<ApartmentOutlinedIcon sx={{ fontSize: 16 }} />}
            label="Phòng ban hiện tại"
            value={employee?.departmentName || ''}
          />
        </Box>
      </FormSection>

      <FormSection title="Nội dung luân chuyển" subtitle="Phòng ban đích và ngày áp dụng.">
        <TextField
          select
          required
          fullWidth
          size="small"
          label="Phòng ban đích"
          value={toDepartmentId}
          onChange={(e) => setToDepartmentId(e.target.value === '' ? '' : Number(e.target.value))}
          sx={fieldSx}
        >
          <MenuItem value="">— Chọn —</MenuItem>
          {departments.map((d) => (
            <MenuItem key={d.id} value={d.id}>
              {d.name}
            </MenuItem>
          ))}
        </TextField>
        <TextField
          select
          fullWidth
          size="small"
          label="Chức vụ mới (tuỳ chọn)"
          value={toPositionId}
          onChange={(e) => setToPositionId(e.target.value === '' ? '' : Number(e.target.value))}
          sx={fieldSx}
        >
          <MenuItem value="">Giữ chức vụ hiện tại</MenuItem>
          {positions.map((p) => (
            <MenuItem key={p.id} value={p.id}>
              {p.title}
            </MenuItem>
          ))}
        </TextField>
        <DatePickerField
          label="Ngày luân chuyển (hiệu lực)"
          required
          value={effectiveDate}
          onChange={setEffectiveDate}
          sx={fieldSx}
        />
      </FormSection>

      <FormSection title="Lý do luân chuyển">
        <TextField
          required
          fullWidth
          size="small"
          multiline
          minRows={3}
          label="Lý do"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
          placeholder="Nêu rõ lý do điều chuyển nhân sự…"
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
