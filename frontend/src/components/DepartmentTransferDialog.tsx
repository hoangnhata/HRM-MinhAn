import SwapHorizIcon from '@mui/icons-material/SwapHoriz';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  MenuItem,
  Stack,
  TextField,
} from '@mui/material';
import { useEffect, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import * as departmentTransferService from '../services/departmentTransferService';
import * as employeeService from '../services/employeeService';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  employee: { id: number; fullName: string; departmentName?: string } | null;
};

export function DepartmentTransferDialog({ open, onClose, onSubmitted, employee }: Props) {
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
    setReason('');
    setToDepartmentId('');
    setToPositionId('');
    setEffectiveDate(new Date().toISOString().slice(0, 10));
    employeeService.fetchDepartments().then(setDepartments).catch(() => setDepartments([]));
    employeeService.fetchPositions().then(setPositions).catch(() => setPositions([]));
  }, [open, employee?.id]);

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
      await departmentTransferService.createTransfer({
        employeeId: employee.id,
        toDepartmentId: Number(toDepartmentId),
        toPositionId: toPositionId === '' ? null : Number(toPositionId),
        effectiveDate,
        reason: reason.trim(),
      });
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Gửi đề nghị thất bại. Kiểm tra ngày/phòng ban hoặc đề nghị đang chờ.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open={open} onClose={loading ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <SwapHorizIcon color="primary" />
        Luân chuyển nhân viên
      </DialogTitle>
      <DialogContent>
        <Stack component="form" id="dept-transfer-form" onSubmit={submit} spacing={2} sx={{ mt: 1 }}>
          <Alert severity="info">
            Đề nghị sẽ gửi Giám đốc duyệt. Nhân viên chỉ chuyển phòng ban vào ngày hiệu lực đã nhập
            (không chuyển ngay khi duyệt nếu ngày còn ở tương lai).
          </Alert>
          <TextField
            label="Nhân viên"
            value={
              employee
                ? `${employee.fullName}${employee.departmentName ? ` · ${employee.departmentName}` : ''}`
                : ''
            }
            disabled
            fullWidth
            size="small"
          />
          <TextField
            select
            required
            fullWidth
            size="small"
            label="Phòng ban đích"
            value={toDepartmentId}
            onChange={(e) => setToDepartmentId(e.target.value === '' ? '' : Number(e.target.value))}
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
          />
          <TextField
            required
            fullWidth
            size="small"
            multiline
            minRows={3}
            label="Lý do luân chuyển"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
          {err && <Alert severity="error">{err}</Alert>}
        </Stack>
      </DialogContent>
      <DialogActions sx={{ px: 3, pb: 2 }}>
        <Button onClick={onClose} disabled={loading}>
          Hủy
        </Button>
        <Button type="submit" form="dept-transfer-form" variant="contained" disabled={loading}>
          Gửi Giám đốc duyệt
        </Button>
      </DialogActions>
    </Dialog>
  );
}
