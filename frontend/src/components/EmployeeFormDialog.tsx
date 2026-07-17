import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Grid,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useEffect, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import * as employeeService from '../services/employeeService';

function toInputDate(s: string | undefined | null): string {
  if (!s) return '';
  return String(s).slice(0, 10);
}

type Props = {
  open: boolean;
  onClose: () => void;
  mode: 'create' | 'edit';
  employeeId?: number;
  onSuccess: () => void;
};

export function EmployeeFormDialog({ open, onClose, mode, employeeId, onSuccess }: Props) {
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [positions, setPositions] = useState<employeeService.PositionOption[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [idCardNumber, setIdCardNumber] = useState('');
  const [dateOfBirth, setDateOfBirth] = useState('');
  const [address, setAddress] = useState('');
  const [gender, setGender] = useState('');
  const [departmentId, setDepartmentId] = useState<number | ''>('');
  const [positionId, setPositionId] = useState<number | ''>('');
  const [hireDate, setHireDate] = useState('');
  const [baseSalary, setBaseSalary] = useState('0');
  const [allowance, setAllowance] = useState('0');
  const [lastRaiseDate, setLastRaiseDate] = useState('');
  const [nextReviewDate, setNextReviewDate] = useState('');
  const [status, setStatus] = useState<'ACTIVE' | 'PROBATION' | 'INTERN' | 'ON_LEAVE' | 'TERMINATED'>('ACTIVE');
  const [accountRole, setAccountRole] = useState<employeeService.EmployeeAccountRole>('EMPLOYEE');

  useEffect(() => {
    if (!open) return;
    setErr(null);
    (async () => {
      const [d, p] = await Promise.all([employeeService.fetchDepartments(), employeeService.fetchPositions()]);
      setDepartments(d);
      setPositions(p);
    })().catch(() => setErr('Không tải được danh sách phòng ban / chức vụ.'));
  }, [open]);

  useEffect(() => {
    if (!open) return;
    if (mode === 'create') {
      setUsername('');
      setPassword('');
      setEmail('');
      setFullName('');
      setPhone('');
      setIdCardNumber('');
      setDateOfBirth('');
      setAddress('');
      setGender('');
      setHireDate(toInputDate(new Date().toISOString()));
      setBaseSalary('0');
      setAllowance('0');
      setLastRaiseDate('');
      setNextReviewDate('');
      setStatus('ACTIVE');
      setAccountRole('EMPLOYEE');
      setErr(null);
      return;
    }
    if (mode === 'edit' && employeeId) {
      setLoading(true);
      setErr(null);
      employeeService
        .fetchEmployee(employeeId)
        .then((e) => {
          setEmail(e.email);
          setFullName(e.fullName);
          setPhone(e.phone ?? '');
          setIdCardNumber(e.idCardNumber ?? '');
          setDateOfBirth(toInputDate(e.dateOfBirth));
          setAddress(e.address ?? '');
          setGender(e.gender ?? '');
          setDepartmentId(e.departmentId);
          setPositionId(e.positionId);
          setHireDate(toInputDate(e.hireDate));
          const sal = e.salary;
          setBaseSalary(sal != null ? String(sal.baseSalary) : '0');
          setAllowance(sal != null ? String(sal.allowance ?? 0) : '0');
          setLastRaiseDate(toInputDate(sal?.lastRaiseDate));
          setNextReviewDate(toInputDate(sal?.nextReviewDate));
          setStatus(e.status as 'ACTIVE' | 'PROBATION' | 'INTERN' | 'ON_LEAVE' | 'TERMINATED');
          setAccountRole((e.role as employeeService.EmployeeAccountRole) || 'EMPLOYEE');
        })
        .catch(() => setErr('Không tải được hồ sơ.'))
        .finally(() => setLoading(false));
    }
  }, [open, mode, employeeId]);

  useEffect(() => {
    if (!open || mode !== 'create' || departments.length === 0) return;
    if (departmentId === '') setDepartmentId(departments[0].id);
  }, [open, mode, departments, departmentId]);

  useEffect(() => {
    if (!open || mode !== 'create' || positions.length === 0) return;
    if (positionId === '') setPositionId(positions[0].id);
  }, [open, mode, positions, positionId]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (mode === 'create') {
      if (!email.trim() || !fullName.trim()) {
        setErr('Điền đủ email và họ tên.');
        return;
      }
      if (accountRole === 'EMPLOYEE') {
        if (!phone.trim()) {
          setErr('Nhập số điện thoại — dùng làm tên đăng nhập (mật khẩu mặc định 123).');
          return;
        }
      } else if (!username.trim() || !password) {
        setErr('Điền username và mật khẩu cho tài khoản quản lý.');
        return;
      }
      if (departmentId === '' || positionId === '') {
        setErr('Chọn phòng ban và chức vụ.');
        return;
      }
      setSaving(true);
      try {
        await employeeService.createEmployee({
          email: email.trim(),
          role: accountRole as employeeService.CreatableUserRole,
          fullName: fullName.trim(),
          phone: phone.trim() || undefined,
          ...(accountRole !== 'EMPLOYEE'
            ? { username: username.trim(), password }
            : {}),
          idCardNumber: idCardNumber.trim() || undefined,
          dateOfBirth: dateOfBirth || undefined,
          address: address.trim() || undefined,
          gender: gender.trim() || undefined,
          departmentId: Number(departmentId),
          positionId: Number(positionId),
          hireDate: hireDate || new Date().toISOString().slice(0, 10),
          baseSalary: Number(baseSalary.replace(/\s/g, '')) || 0,
        });
        onSuccess();
        onClose();
      } catch {
        setErr('Tạo nhân viên thất bại (trùng username hoặc dữ liệu không hợp lệ).');
      } finally {
        setSaving(false);
      }
      return;
    }

    if (mode === 'edit' && employeeId) {
      if (!email.trim()) {
        setErr('Nhập email đăng nhập.');
        return;
      }
      if (departmentId === '' || positionId === '') {
        setErr('Chọn phòng ban và chức vụ.');
        return;
      }
      setSaving(true);
      try {
        const baseSalaryNum = Number(baseSalary.replace(/\s/g, ''));
        const allowanceNum = Number(allowance.replace(/\s/g, ''));
        await employeeService.updateEmployee(employeeId, {
          email: email.trim(),
          role: accountRole,
          fullName: fullName.trim(),
          phone: phone.trim() || undefined,
          idCardNumber: idCardNumber.trim() || undefined,
          dateOfBirth: dateOfBirth || undefined,
          address: address.trim() || undefined,
          gender: gender.trim() || undefined,
          departmentId: Number(departmentId),
          positionId: Number(positionId),
          hireDate: hireDate || undefined,
          status,
          ...(Number.isFinite(baseSalaryNum) ? { baseSalary: baseSalaryNum } : {}),
          ...(Number.isFinite(allowanceNum) ? { allowance: allowanceNum } : {}),
          ...(lastRaiseDate ? { lastRaiseDate } : {}),
          ...(nextReviewDate ? { nextReviewDate } : {}),
        });
        onSuccess();
        onClose();
      } catch {
        setErr('Cập nhật thất bại.');
      } finally {
        setSaving(false);
      }
    }
  }

  return (
    <Dialog open={open} onClose={saving ? undefined : onClose} maxWidth="md" fullWidth>
      <DialogTitle>{mode === 'create' ? 'Thêm nhân viên' : 'Sửa nhân viên'}</DialogTitle>
      <Box component="form" onSubmit={handleSubmit}>
        <DialogContent dividers>
          {err && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {err}
            </Alert>
          )}
          {loading && mode === 'edit' ? (
            <Typography>Đang tải…</Typography>
          ) : (
            <Stack spacing={2}>
              {mode === 'create' && (
                <>
                  <Typography variant="subtitle2" color="text.secondary">
                    Tài khoản đăng nhập
                  </Typography>
                  <Grid container spacing={2}>
                    <Grid item xs={12}>
                      <TextField
                        select
                        label="Vai trò đăng nhập"
                        fullWidth
                        required
                        value={accountRole}
                        onChange={(e) => setAccountRole(e.target.value as employeeService.EmployeeAccountRole)}
                        helperText="HCNS tổng hợp danh sách; Trưởng khoa chấm cột khoa phòng, ĐDT chấm cột Điều dưỡng trưởng."
                      >
                        <MenuItem value="EMPLOYEE">Nhân viên</MenuItem>
                        <MenuItem value="HR">P. HCNS</MenuItem>
                        <MenuItem value="HEAD_DEPARTMENT">Trưởng khoa / phòng</MenuItem>
                        <MenuItem value="HEAD_NURSING">Điều dưỡng trưởng</MenuItem>
                      </TextField>
                    </Grid>
                    {accountRole === 'EMPLOYEE' ? (
                      <>
                        <Grid item xs={12} sm={6}>
                          <TextField
                            label="Số điện thoại (tên đăng nhập)"
                            fullWidth
                            required
                            value={phone}
                            onChange={(e) => setPhone(e.target.value)}
                            helperText="Mật khẩu mặc định: 123 — đổi ngay lần đăng nhập đầu."
                          />
                        </Grid>
                        <Grid item xs={12} sm={6}>
                          <TextField
                            label="Email"
                            type="email"
                            fullWidth
                            required
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                          />
                        </Grid>
                      </>
                    ) : (
                      <>
                        <Grid item xs={12} sm={4}>
                          <TextField
                            label="Tên đăng nhập"
                            fullWidth
                            required
                            value={username}
                            onChange={(e) => setUsername(e.target.value)}
                            autoComplete="off"
                          />
                        </Grid>
                        <Grid item xs={12} sm={4}>
                          <TextField
                            label="Mật khẩu"
                            type="password"
                            fullWidth
                            required
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            autoComplete="new-password"
                          />
                        </Grid>
                        <Grid item xs={12} sm={4}>
                          <TextField
                            label="Email"
                            type="email"
                            fullWidth
                            required
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                          />
                        </Grid>
                      </>
                    )}
                  </Grid>
                </>
              )}
              {mode === 'edit' && (
                <>
                  <Typography variant="subtitle2" color="text.secondary">
                    Tài khoản đăng nhập
                  </Typography>
                  <Grid container spacing={2}>
                    <Grid item xs={12} sm={7}>
                      <TextField
                        label="Email"
                        type="email"
                        fullWidth
                        required
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                      />
                    </Grid>
                    <Grid item xs={12} sm={5}>
                      <TextField
                        select
                        label="Vai trò"
                        fullWidth
                        required
                        value={accountRole}
                        onChange={(e) => setAccountRole(e.target.value as employeeService.EmployeeAccountRole)}
                      >
                        <MenuItem value="ADMIN">Quản trị</MenuItem>
                        <MenuItem value="EMPLOYEE">Nhân viên</MenuItem>
                        <MenuItem value="HR">P. HCNS</MenuItem>
                        <MenuItem value="HEAD_DEPARTMENT">Trưởng khoa / phòng</MenuItem>
                        <MenuItem value="HEAD_NURSING">Điều dưỡng trưởng</MenuItem>
                        <MenuItem value="DIRECTOR">Giám đốc</MenuItem>
                      </TextField>
                    </Grid>
                  </Grid>
                </>
              )}
              <Typography variant="subtitle2" color="text.secondary">
                Thông tin cá nhân
              </Typography>
              <Grid container spacing={2}>
                <Grid item xs={12} sm={6}>
                  <TextField label="Họ và tên" fullWidth required value={fullName} onChange={(e) => setFullName(e.target.value)} />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <TextField label="Điện thoại" fullWidth value={phone} onChange={(e) => setPhone(e.target.value)} />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <TextField label="CCCD/CMND" fullWidth value={idCardNumber} onChange={(e) => setIdCardNumber(e.target.value)} />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <DatePickerField
                    label="Ngày sinh"
                    value={dateOfBirth}
                    onChange={setDateOfBirth}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <TextField select label="Giới tính" fullWidth value={gender} onChange={(e) => setGender(e.target.value)}>
                    <MenuItem value="">—</MenuItem>
                    <MenuItem value="Nam">Nam</MenuItem>
                    <MenuItem value="Nữ">Nữ</MenuItem>
                    <MenuItem value="Khác">Khác</MenuItem>
                  </TextField>
                </Grid>
                <Grid item xs={12}>
                  <TextField label="Địa chỉ" fullWidth multiline minRows={2} value={address} onChange={(e) => setAddress(e.target.value)} />
                </Grid>
              </Grid>
              <Typography variant="subtitle2" color="text.secondary">
                Công việc
              </Typography>
              <Grid container spacing={2}>
                <Grid item xs={12} sm={6}>
                  <TextField
                    select
                    label="Phòng ban"
                    fullWidth
                    required
                    value={departmentId}
                    onChange={(e) => setDepartmentId(Number(e.target.value))}
                  >
                    {departments.map((d) => (
                      <MenuItem key={d.id} value={d.id}>
                        {d.name}
                      </MenuItem>
                    ))}
                  </TextField>
                </Grid>
                <Grid item xs={12} sm={6}>
                  <TextField
                    select
                    label="Chức vụ"
                    fullWidth
                    required
                    value={positionId}
                    onChange={(e) => setPositionId(Number(e.target.value))}
                  >
                    {positions.map((p) => (
                      <MenuItem key={p.id} value={p.id}>
                        {p.title}
                      </MenuItem>
                    ))}
                  </TextField>
                </Grid>
                <Grid item xs={12} sm={6}>
                  <DatePickerField
                    label={
                      status === 'PROBATION' || status === 'INTERN' ? 'Từ ngày (thử việc)' : 'Ngày vào làm'
                    }
                    value={hireDate}
                    onChange={setHireDate}
                  />
                </Grid>
                {mode === 'create' && (
                  <Grid item xs={12} sm={6}>
                    <TextField
                      label="Lương cơ bản (khởi tạo)"
                      type="number"
                      fullWidth
                      value={baseSalary}
                      onChange={(e) => setBaseSalary(e.target.value)}
                      inputProps={{ min: 0, step: 1000 }}
                    />
                  </Grid>
                )}
                {mode === 'edit' && (
                  <>
                    <Grid item xs={12}>
                      <Typography variant="subtitle2" color="text.secondary">
                        Lương & đánh giá lương
                      </Typography>
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <TextField
                        label="Lương cơ bản"
                        type="number"
                        fullWidth
                        value={baseSalary}
                        onChange={(e) => setBaseSalary(e.target.value)}
                        inputProps={{ min: 0, step: 1000 }}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <TextField
                        label="Phụ cấp"
                        type="number"
                        fullWidth
                        value={allowance}
                        onChange={(e) => setAllowance(e.target.value)}
                        inputProps={{ min: 0, step: 1000 }}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <DatePickerField
                        label="Ngày tăng lương gần nhất"
                        value={lastRaiseDate}
                        onChange={setLastRaiseDate}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <DatePickerField
                        label="Ngày xét lương tiếp theo"
                        value={nextReviewDate}
                        onChange={setNextReviewDate}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <TextField
                        select
                        label="Trạng thái"
                        fullWidth
                        required
                        value={status}
                        onChange={(e) => setStatus(e.target.value as typeof status)}
                      >
                        <MenuItem value="ACTIVE">Chính thức</MenuItem>
                        <MenuItem value="PROBATION">Thử việc</MenuItem>
                        <MenuItem value="INTERN">Thực tập</MenuItem>
                        <MenuItem value="ON_LEAVE">Nghỉ phép</MenuItem>
                        <MenuItem value="TERMINATED">Nghỉ việc</MenuItem>
                      </TextField>
                    </Grid>
                  </>
                )}
              </Grid>
            </Stack>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button type="button" onClick={onClose} disabled={saving}>
            Hủy
          </Button>
          <Button type="submit" variant="contained" disabled={saving || loading}>
            {mode === 'create' ? 'Tạo mới' : 'Lưu'}
          </Button>
        </DialogActions>
      </Box>
    </Dialog>
  );
}
