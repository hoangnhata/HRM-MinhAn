import HowToRegIcon from '@mui/icons-material/HowToReg';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
} from '@mui/material';
import { useEffect, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import * as probationConversionService from '../services/probationConversionService';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  employee: { id: number; fullName: string; departmentName?: string; status?: string } | null;
};

export function ProbationConversionDialog({ open, onClose, onSubmitted, employee }: Props) {
  const [officialDate, setOfficialDate] = useState('');
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setReason('');
    setOfficialDate(new Date().toISOString().slice(0, 10));
  }, [open, employee?.id]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!employee) return;
    if (!officialDate) {
      setErr('Nhập ngày lên chính thức.');
      return;
    }
    if (!reason.trim()) {
      setErr('Nhập lý do đề nghị.');
      return;
    }
    setLoading(true);
    setErr(null);
    try {
      await probationConversionService.createConversion({
        employeeId: employee.id,
        officialDate,
        reason: reason.trim(),
      });
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Gửi đơn thất bại. Kiểm tra quyền, ngày hiệu lực hoặc đơn đang chờ duyệt.');
    } finally {
      setLoading(false);
    }
  }

  const statusLabel =
    employee?.status === 'INTERN' ? 'thực tập' : employee?.status === 'PROBATION' ? 'thử việc' : 'thử việc/thực tập';

  return (
    <Dialog open={open} onClose={loading ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <HowToRegIcon color="success" />
        Lập đơn chuyển chính thức
      </DialogTitle>
      <DialogContent>
        <Stack component="form" id="probation-conversion-form" onSubmit={submit} spacing={2} sx={{ mt: 1 }}>
          <Alert severity="info">
            Đơn gửi HCNS duyệt, sau đó Giám đốc duyệt. Nhân viên chỉ chuyển lên chính thức đúng{' '}
            <strong>ngày đã chọn</strong> (không chuyển ngay nếu ngày còn ở tương lai).
          </Alert>
          <TextField
            label="Nhân viên"
            value={
              employee
                ? `${employee.fullName}${employee.departmentName ? ` · ${employee.departmentName}` : ''} · ${statusLabel}`
                : ''
            }
            disabled
            fullWidth
            size="small"
          />
          <DatePickerField
            label="Ngày lên chính thức"
            required
            value={officialDate}
            onChange={setOfficialDate}
          />
          <TextField
            required
            fullWidth
            size="small"
            multiline
            minRows={3}
            label="Lý do đề nghị"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
          {err && <Alert severity="error">{err}</Alert>}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={loading}>
          Hủy
        </Button>
        <Button type="submit" form="probation-conversion-form" variant="contained" color="success" disabled={loading}>
          {loading ? 'Đang gửi…' : 'Gửi đơn'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
