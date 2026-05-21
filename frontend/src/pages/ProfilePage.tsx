import AdminPanelSettingsOutlinedIcon from '@mui/icons-material/AdminPanelSettingsOutlined';
import CalendarTodayOutlinedIcon from '@mui/icons-material/CalendarTodayOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import DoNotDisturbAltOutlinedIcon from '@mui/icons-material/DoNotDisturbAltOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import {
  Alert,
  Avatar,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Divider,
  FormControl,
  Grid,
  InputLabel,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  MenuItem,
  Select,
  Snackbar,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import { useAuth } from '../context/AuthContext';
import * as accountService from '../services/accountService';
import * as departmentService from '../services/departmentService';
import { getRoleLabel } from '../utils/roleLabels';

function avatarProps(name: string) {
  const colors = ['#ec407a', '#ab47bc', '#5c6bc0', '#26a69a', '#ffa726', '#78909c'];
  let h = 0;
  for (let i = 0; i < name.length; i++) h = name.charCodeAt(i) + ((h << 5) - h);
  const bg = colors[Math.abs(h) % colors.length];
  return {
    sx: {
      width: 92,
      height: 92,
      fontSize: '2rem',
      fontWeight: 700,
      bgcolor: bg,
      color: '#fff',
      cursor: 'default',
    },
    children: (name || '?').charAt(0).toUpperCase(),
  };
}

export default function ProfilePage() {
  const theme = useTheme();
  const { refreshUser } = useAuth();
  const [account, setAccount] = useState<accountService.AccountMe | null>(null);
  const [loadErr, setLoadErr] = useState<string | null>(null);

  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [fullNameProfile, setFullNameProfile] = useState('');
  const [departmentId, setDepartmentId] = useState<number | ''>('');
  const [departments, setDepartments] = useState<departmentService.DepartmentRow[]>([]);
  const [saving, setSaving] = useState(false);

  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [pwdLoading, setPwdLoading] = useState(false);

  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' | 'info' }>(
    { open: false, message: '', severity: 'success' }
  );

  useEffect(() => {
    let c = false;
    (async () => {
      try {
        const a = await accountService.fetchAccountMe();
        if (!c) {
          setAccount(a);
          setEmail(a.email || '');
          setPhone(a.phone || '');
          setAddress(a.address || '');
          setFullNameProfile(a.fullName || '');
          setDepartmentId(a.departmentId ?? '');
        }
      } catch {
        if (!c) setLoadErr('Không tải được thông tin tài khoản.');
      }
    })();
    return () => {
      c = true;
    };
  }, []);

  useEffect(() => {
    let c = false;
    departmentService
      .fetchDepartments()
      .then((list) => {
        if (!c) setDepartments(list);
      })
      .catch(() => {
        if (!c) setDepartments([]);
      });
    return () => {
      c = true;
    };
  }, []);

  const joinedLabel = useMemo(() => {
    if (!account?.createdAt) return '—';
    try {
      return new Date(account.createdAt).toLocaleDateString('vi-VN', {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      });
    } catch {
      return '—';
    }
  }, [account?.createdAt]);

  async function handleSaveProfile() {
    if (!account) return;
    if (account.employeeId != null) {
      if (!fullNameProfile.trim()) {
        setSnackbar({ open: true, message: 'Vui lòng nhập họ và tên.', severity: 'info' });
        return;
      }
      if (departmentId === '' || typeof departmentId !== 'number') {
        setSnackbar({ open: true, message: 'Vui lòng chọn phòng ban.', severity: 'info' });
        return;
      }
    }
    setSaving(true);
    try {
      const updated = await accountService.updateAccount({
        email: email.trim(),
        phone: phone.trim(),
        address: address.trim(),
        ...(account.employeeId != null
          ? {
              fullName: fullNameProfile.trim(),
              departmentId: typeof departmentId === 'number' ? departmentId : undefined,
            }
          : {}),
      });
      setAccount(updated);
      setFullNameProfile(updated.fullName || '');
      setDepartmentId(updated.departmentId ?? '');
      await refreshUser();
      setSnackbar({ open: true, message: 'Đã cập nhật thông tin.', severity: 'success' });
    } catch {
      setSnackbar({ open: true, message: 'Cập nhật thất bại.', severity: 'error' });
    } finally {
      setSaving(false);
    }
  }

  async function handleChangePassword() {
    if (!oldPassword || !newPassword || !confirmPassword) {
      setSnackbar({ open: true, message: 'Vui lòng điền đủ các ô mật khẩu.', severity: 'info' });
      return;
    }
    if (newPassword.length < 6) {
      setSnackbar({ open: true, message: 'Mật khẩu mới ít nhất 6 ký tự.', severity: 'info' });
      return;
    }
    if (newPassword !== confirmPassword) {
      setSnackbar({ open: true, message: 'Xác nhận mật khẩu không khớp.', severity: 'info' });
      return;
    }
    setPwdLoading(true);
    try {
      await accountService.changeAccountPassword({ oldPassword, newPassword });
      setOldPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setSnackbar({ open: true, message: 'Đã đổi mật khẩu.', severity: 'success' });
    } catch {
      setSnackbar({ open: true, message: 'Đổi mật khẩu thất bại (kiểm tra mật khẩu hiện tại).', severity: 'error' });
    } finally {
      setPwdLoading(false);
    }
  }

  if (loadErr) {
    return (
      <Box>
        <PageHeader title="Trang cá nhân" description={loadErr} />
      </Box>
    );
  }

  if (!account) {
    return (
      <Box sx={{ py: 8, textAlign: 'center' }}>
        <CircularProgress />
        <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
          Đang tải…
        </Typography>
      </Box>
    );
  }

  return (
    <Box>
      <PageHeader
        overline="Tài khoản"
        title="Trang cá nhân"
        description="Quản lý thông tin liên hệ và bảo mật đăng nhập."
      />

      <Snackbar
        open={snackbar.open}
        autoHideDuration={5000}
        onClose={() => setSnackbar((s) => ({ ...s, open: false }))}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert severity={snackbar.severity} variant="filled" onClose={() => setSnackbar((s) => ({ ...s, open: false }))}>
          {snackbar.message}
        </Alert>
      </Snackbar>

      <Grid container spacing={3}>
        <Grid item xs={12} md={4}>
          <Card
            sx={{
              borderRadius: 3,
              border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
              textAlign: 'center',
              p: 2,
            }}
          >
            <Box sx={{ display: 'flex', justifyContent: 'center', mb: 2 }}>
              <Tooltip title="Ảnh đại diện theo chữ cái (HRM chưa lưu file ảnh)">
                <Avatar {...avatarProps(fullNameProfile || account.username)} />
              </Tooltip>
            </Box>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
              Màu avatar phân biệt theo tên — tương tự web quản lý tài sản
            </Typography>
            <Typography variant="h6" sx={{ fontWeight: 700 }}>
              {fullNameProfile || account.fullName}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              {account.email}
            </Typography>
            <List dense disablePadding sx={{ mt: 2, textAlign: 'left' }}>
              <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.75 }}>
                <ListItemIcon sx={{ minWidth: 40, color: 'primary.main', mt: 0.15 }}>
                  <AdminPanelSettingsOutlinedIcon fontSize="small" />
                </ListItemIcon>
                <ListItemText
                  primary="Vai trò"
                  secondary={getRoleLabel(account.role)}
                  primaryTypographyProps={{ variant: 'caption', color: 'text.secondary', fontWeight: 600 }}
                  secondaryTypographyProps={{ variant: 'body2', color: 'text.primary' }}
                />
              </ListItem>
              <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.75 }}>
                <ListItemIcon sx={{ minWidth: 40, color: 'primary.main', mt: 0.15 }}>
                  <PersonOutlineIcon fontSize="small" />
                </ListItemIcon>
                <ListItemText
                  primary="Tài khoản"
                  secondary={account.username}
                  primaryTypographyProps={{ variant: 'caption', color: 'text.secondary', fontWeight: 600 }}
                  secondaryTypographyProps={{ variant: 'body2', color: 'text.primary' }}
                />
              </ListItem>
              <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.75 }}>
                <ListItemIcon sx={{ minWidth: 40, color: 'primary.main', mt: 0.15 }}>
                  <CalendarTodayOutlinedIcon fontSize="small" />
                </ListItemIcon>
                <ListItemText
                  primary="Ngày tham gia"
                  secondary={joinedLabel}
                  primaryTypographyProps={{ variant: 'caption', color: 'text.secondary', fontWeight: 600 }}
                  secondaryTypographyProps={{ variant: 'body2', color: 'text.primary' }}
                />
              </ListItem>
              <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.75 }}>
                <ListItemIcon sx={{ minWidth: 40, color: 'primary.main', mt: 0.15 }}>
                  {account.enabled ? (
                    <CheckCircleOutlineIcon fontSize="small" />
                  ) : (
                    <DoNotDisturbAltOutlinedIcon fontSize="small" />
                  )}
                </ListItemIcon>
                <ListItemText
                  primary="Trạng thái"
                  secondary={account.enabled ? 'Đang hoạt động' : 'Bị khóa'}
                  primaryTypographyProps={{ variant: 'caption', color: 'text.secondary', fontWeight: 600 }}
                  secondaryTypographyProps={{ variant: 'body2', color: 'text.primary' }}
                />
              </ListItem>
            </List>
          </Card>
        </Grid>

        <Grid item xs={12} md={8}>
          <Card sx={{ borderRadius: 3, border: `1px solid ${alpha(theme.palette.divider, 1)}` }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ mb: 2, fontWeight: 700 }}>
                Thông tin cá nhân
              </Typography>
              <Grid container spacing={2}>
                <Grid item xs={12} md={6}>
                  <TextField
                    label="Họ và tên"
                    value={fullNameProfile}
                    onChange={(e) => setFullNameProfile(e.target.value)}
                    fullWidth
                    disabled={account.employeeId == null}
                    helperText={account.employeeId == null ? 'Tài khoản quản trị không gắn hồ sơ NV.' : undefined}
                  />
                </Grid>
                <Grid item xs={12} md={6}>
                  <TextField label="Email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} fullWidth />
                </Grid>
                <Grid item xs={12} md={6}>
                  <TextField label="Số điện thoại" value={phone} onChange={(e) => setPhone(e.target.value)} fullWidth />
                </Grid>
                <Grid item xs={12} md={6}>
                  {account.employeeId == null ? (
                    <TextField label="Phòng ban" value="—" fullWidth disabled />
                  ) : (
                    <FormControl fullWidth size="medium">
                      <InputLabel id="profile-dept-label">Phòng ban</InputLabel>
                      <Select
                        labelId="profile-dept-label"
                        label="Phòng ban"
                        value={departmentId === '' ? '' : departmentId}
                        onChange={(e) => setDepartmentId(Number(e.target.value))}
                      >
                        {departments.map((d) => (
                          <MenuItem key={d.id} value={d.id}>
                            {d.name}
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                  )}
                </Grid>
                <Grid item xs={12}>
                  <TextField
                    label="Địa chỉ"
                    value={address}
                    onChange={(e) => setAddress(e.target.value)}
                    fullWidth
                    multiline
                    minRows={2}
                  />
                </Grid>
              </Grid>
              <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 3 }}>
                <Button variant="contained" size="large" disabled={saving} onClick={handleSaveProfile}>
                  {saving ? <CircularProgress size={22} color="inherit" /> : 'Lưu thông tin'}
                </Button>
              </Box>
            </CardContent>
          </Card>

          <Card sx={{ borderRadius: 3, border: `1px solid ${alpha(theme.palette.divider, 1)}`, mt: 3 }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ mb: 2, fontWeight: 700 }}>
                Đổi mật khẩu
              </Typography>
              <Stack spacing={2}>
                <TextField
                  label="Mật khẩu hiện tại"
                  type="password"
                  value={oldPassword}
                  onChange={(e) => setOldPassword(e.target.value)}
                  autoComplete="current-password"
                />
                <TextField
                  label="Mật khẩu mới"
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  autoComplete="new-password"
                />
                <TextField
                  label="Xác nhận mật khẩu mới"
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  autoComplete="new-password"
                />
              </Stack>
              <Divider sx={{ my: 2.5 }} />
              <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 1 }}>
                <Button
                  variant="outlined"
                  onClick={() => {
                    setOldPassword('');
                    setNewPassword('');
                    setConfirmPassword('');
                  }}
                >
                  Làm mới
                </Button>
                <Button variant="contained" disabled={pwdLoading} onClick={handleChangePassword}>
                  {pwdLoading ? <CircularProgress size={22} color="inherit" /> : 'Cập nhật mật khẩu'}
                </Button>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}
