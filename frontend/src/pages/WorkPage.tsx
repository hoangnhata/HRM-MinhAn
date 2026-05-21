import {
  Box,
  Button,
  FormControl,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import { useAuth } from '../context/AuthContext';
import * as employeeService from '../services/employeeService';
import * as pa from '../services/payrollAttendanceService';

function monthRange() {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 0);
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  return { from: iso(start), to: iso(end) };
}

export default function WorkPage() {
  const theme = useTheme();
  const { user } = useAuth();
  const [employees, setEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [selected, setSelected] = useState<number | ''>('');
  const [att, setAtt] = useState<Record<string, unknown>[]>([]);
  const [pay, setPay] = useState<Record<string, unknown>[]>([]);
  const [notifyMsg, setNotifyMsg] = useState<string | null>(null);

  useEffect(() => {
    if (user?.role === 'ADMIN') {
      employeeService.fetchEmployees({ page: 0, size: 200 }).then((p) => {
        setEmployees(p.content);
        if (p.content.length && selected === '') {
          setSelected(p.content[0].id);
        }
      });
    } else if (user?.employeeId) {
      setSelected(user.employeeId);
    }
  }, [user]);

  useEffect(() => {
    if (selected === '') return;
    const { from, to } = monthRange();
    pa.fetchAttendance(Number(selected), from, to).then(setAtt);
    pa.fetchPayrollForEmployee(Number(selected)).then(setPay);
  }, [selected]);

  async function sendAttendanceNotify() {
    setNotifyMsg(null);
    if (selected === '' || user?.role !== 'ADMIN') return;
    const now = new Date();
    try {
      await pa.notifyAttendanceMonth(Number(selected), now.getFullYear(), now.getMonth() + 1);
      setNotifyMsg('Đã gửi thông báo bảng công tháng hiện tại tới nhân viên.');
    } catch {
      setNotifyMsg('Không gửi được thông báo.');
    }
  }

  return (
    <Box>
      <PageHeader
        overline="Lương & công"
        title="Bảng công & bảng lương"
        description="Nhân viên chỉ xem dữ liệu của chính mình. Quản trị viên có thể chọn nhân viên và gửi thông báo sau khi cập nhật công."
      />

      {user?.role === 'ADMIN' && (
        <FormControl sx={{ minWidth: 300, mb: 2.5 }} size="small">
          <InputLabel>Nhân viên</InputLabel>
          <Select
            label="Nhân viên"
            value={selected}
            onChange={(e) => setSelected(e.target.value as number)}
          >
            {employees.map((e) => (
              <MenuItem key={e.id} value={e.id}>
                {e.employeeCode ? `[${e.employeeCode}] ` : ''}
                {e.fullName}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      )}

      <Stack direction={{ xs: 'column', sm: 'row' }} alignItems={{ sm: 'center' }} spacing={2} sx={{ mt: 2 }}>
        <Typography variant="h6" sx={{ flex: 1 }}>
          Bảng công (tháng hiện tại)
        </Typography>
        {user?.role === 'ADMIN' && selected !== '' && (
          <Button variant="outlined" size="small" onClick={sendAttendanceNotify}>
            Gửi TB bảng công (tháng này)
          </Button>
        )}
      </Stack>
      {notifyMsg && (
        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
          {notifyMsg}
        </Typography>
      )}
      <TableContainer
        component={Paper}
        elevation={0}
        sx={{
          mt: 1,
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.divider, 1)}`,
          overflow: 'hidden',
          boxShadow: `0 4px 20px ${alpha('#0f172a', 0.05)}`,
        }}
      >
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Ngày</TableCell>
              <TableCell>Vào</TableCell>
              <TableCell>Ra</TableCell>
              <TableCell>Trạng thái</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {att.map((r) => (
              <TableRow key={String(r.id)}>
                <TableCell>{String(r.workDate)}</TableCell>
                <TableCell>{String(r.checkIn || '—')}</TableCell>
                <TableCell>{String(r.checkOut || '—')}</TableCell>
                <TableCell>{String(r.status)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      <Typography variant="h6" sx={{ mt: 3 }}>
        Bảng lương theo kỳ
      </Typography>
      <TableContainer
        component={Paper}
        elevation={0}
        sx={{
          mt: 2,
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.divider, 1)}`,
          overflow: 'hidden',
          boxShadow: `0 4px 20px ${alpha('#0f172a', 0.05)}`,
        }}
      >
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Kỳ</TableCell>
              <TableCell>Ngày công</TableCell>
              <TableCell>Gross</TableCell>
              <TableCell>Khấu trừ</TableCell>
              <TableCell>Thực lĩnh</TableCell>
              <TableCell>Chốt</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {pay.map((r) => (
              <TableRow key={String(r.id)}>
                <TableCell>
                  {String(r.periodMonth)}/{String(r.periodYear)}
                </TableCell>
                <TableCell>{String(r.workingDays ?? '—')}</TableCell>
                <TableCell>{String(r.grossAmount)}</TableCell>
                <TableCell>{String(r.deductionAmount)}</TableCell>
                <TableCell>{String(r.netAmount)}</TableCell>
                <TableCell>{String(r.finalized)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
