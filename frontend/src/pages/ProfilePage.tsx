import AdminPanelSettingsOutlinedIcon from '@mui/icons-material/AdminPanelSettingsOutlined';
import CalendarTodayOutlinedIcon from '@mui/icons-material/CalendarTodayOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import DoNotDisturbAltOutlinedIcon from '@mui/icons-material/DoNotDisturbAltOutlined';
import KeyIcon from '@mui/icons-material/VpnKey';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import PhotoCameraIcon from '@mui/icons-material/PhotoCamera';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import {
  Alert,
  Avatar,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  FormControl,
  Grid,
  IconButton,
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
import { useEffect, useMemo, useRef, useState } from 'react';
import { Link as RouterLink } from 'react-router-dom';
import { PageHeader } from '../components/layout/PageHeader';
import { DatePickerField } from '../components/ui/DateTimeFields';
import { useAuth } from '../context/AuthContext';
import * as accountService from '../services/accountService';
import * as departmentService from '../services/departmentService';
import { formatDateVi } from '../utils/dateFormat';
import { getRoleLabel } from '../utils/roleLabels';

function avatarProps(name: string, imageUrl?: string | null) {
  const colors = ['#ec407a', '#ab47bc', '#5c6bc0', '#26a69a', '#ffa726', '#78909c'];
  let h = 0;
  for (let i = 0; i < name.length; i++) h = name.charCodeAt(i) + ((h << 5) - h);
  const bg = colors[Math.abs(h) % colors.length];
  return {
    sx: {
      width: 96,
      height: 96,
      fontSize: '2rem',
      fontWeight: 700,
      bgcolor: bg,
      color: '#fff',
    },
    src: imageUrl && imageUrl.trim() ? imageUrl : undefined,
    children: (name || '?').charAt(0).toUpperCase(),
  };
}

export default function ProfilePage() {
  const theme = useTheme();
  const { refreshUser, avatarUrl } = useAuth();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [account, setAccount] = useState<accountService.AccountMe | null>(null);
  const [loadErr, setLoadErr] = useState<string | null>(null);

  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [fullNameProfile, setFullNameProfile] = useState('');
  const [dateOfBirth, setDateOfBirth] = useState('');
  const [departmentId, setDepartmentId] = useState<number | ''>('');
  const [departments, setDepartments] = useState<departmentService.DepartmentRow[]>([]);
  const [saving, setSaving] = useState(false);
  const [avatarBusy, setAvatarBusy] = useState(false);

  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [pwSaving, setPwSaving] = useState(false);

  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' | 'info' }>(
    { open: false, message: '', severity: 'success' }
  );

  const erpLinked = Boolean(account?.erpLinked);

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
          setDateOfBirth(a.dateOfBirth || '');
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
    return formatDateVi(account.createdAt);
  }, [account?.createdAt]);

  const profileDepartments = useMemo(() => {
    const list = [...departments];
    if (
      account?.departmentId != null &&
      account.departmentName?.trim() &&
      !list.some((department) => department.id === account.departmentId)
    ) {
      list.push({
        id: account.departmentId,
        code: `DEPT-${account.departmentId}`,
        name: account.departmentName.trim(),
        description: null,
      });
    }
    return list.sort((a, b) => a.name.localeCompare(b.name, 'vi'));
  }, [account?.departmentId, account?.departmentName, departments]);

  async function handleSaveProfile() {
    if (!account) return;
    if (!fullNameProfile.trim()) {
      setSnackbar({ open: true, message: 'Vui lòng nhập họ và tên.', severity: 'info' });
      return;
    }
    if (account.employeeId != null) {
      if (departmentId === '' || typeof departmentId !== 'number') {
        setSnackbar({ open: true, message: 'Vui lòng chọn phòng ban.', severity: 'info' });
        return;
      }
    }
    setSaving(true);
    try {
      const updated = await accountService.updateAccount({
        email: email.trim(),
        fullName: fullNameProfile.trim(),
        address: address.trim(),
        ...(account.employeeId != null && typeof departmentId === 'number' ? { departmentId } : {}),
        ...(erpLinked
          ? { dateOfBirth: dateOfBirth.trim() || undefined }
          : { phone: phone.trim() }),
      });
      setAccount(updated);
      setEmail(updated.email || '');
      setPhone(updated.phone || '');
      setAddress(updated.address || '');
      setFullNameProfile(updated.fullName || '');
      setDateOfBirth(updated.dateOfBirth || '');
      setDepartmentId(updated.departmentId ?? '');
      await refreshUser();
      setSnackbar({
        open: true,
        message: 'Đã cập nhật thông tin.',
        severity: 'success',
      });
    } catch (err: unknown) {
      const msg =
        err && typeof err === 'object' && 'response' in err
          ? String((err as { response?: { data?: { message?: string } } }).response?.data?.message || '')
          : '';
      setSnackbar({
        open: true,
        message: msg || 'Cập nhật thất bại.',
        severity: 'error',
      });
    } finally {
      setSaving(false);
    }
  }

  async function handleChangePassword() {
    if (newPassword.length < 6) {
      setSnackbar({ open: true, message: 'Mật khẩu mới tối thiểu 6 ký tự.', severity: 'info' });
      return;
    }
    if (newPassword !== confirmPassword) {
      setSnackbar({ open: true, message: 'Mật khẩu xác nhận không khớp.', severity: 'info' });
      return;
    }
    setPwSaving(true);
    try {
      await accountService.changeAccountPassword({ oldPassword, newPassword });
      setOldPassword('');
      setNewPassword('');
      setConfirmPassword('');
      await refreshUser();
      setSnackbar({ open: true, message: 'Đã đổi mật khẩu thành công.', severity: 'success' });
    } catch (err: unknown) {
      const msg =
        err && typeof err === 'object' && 'response' in err
          ? String((err as { response?: { data?: { message?: string } } }).response?.data?.message || '')
          : '';
      setSnackbar({
        open: true,
        message: msg || 'Đổi mật khẩu thất bại. Kiểm tra mật khẩu hiện tại.',
        severity: 'error',
      });
    } finally {
      setPwSaving(false);
    }
  }

  async function onAvatarFile(file: File | null) {
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      setSnackbar({ open: true, message: 'Chỉ chấp nhận ảnh PNG/JPG.', severity: 'info' });
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setSnackbar({ open: true, message: 'Ảnh tối đa 2MB.', severity: 'info' });
      return;
    }
    setAvatarBusy(true);
    try {
      const dataUrl = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(String(reader.result));
        reader.onerror = () => reject(new Error('read failed'));
        reader.readAsDataURL(file);
      });
      const updated = await accountService.saveMyAvatar(dataUrl);
      setAccount(updated);
      await refreshUser();
      setSnackbar({ open: true, message: 'Đã cập nhật ảnh đại diện.', severity: 'success' });
    } catch {
      setSnackbar({ open: true, message: 'Không lưu được ảnh đại diện.', severity: 'error' });
    } finally {
      setAvatarBusy(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  }

  async function removeAvatar() {
    if (!window.confirm('Xóa ảnh đại diện hiện tại?')) return;
    setAvatarBusy(true);
    try {
      const updated = await accountService.deleteMyAvatar();
      setAccount(updated);
      await refreshUser();
      setSnackbar({ open: true, message: 'Đã xóa ảnh đại diện.', severity: 'success' });
    } catch {
      setSnackbar({ open: true, message: 'Không xóa được ảnh đại diện.', severity: 'error' });
    } finally {
      setAvatarBusy(false);
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

  const cardBorder = {
    borderRadius: 3,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
    boxShadow: `0 6px 24px ${alpha('#0f172a', 0.04)}`,
  };

  return (
    <Box>
      <PageHeader
        overline="Tài khoản"
        title="Trang cá nhân"
        description="Cập nhật thông tin liên hệ, ảnh đại diện và đổi mật khẩu đăng nhập HRM."
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
          <Card sx={{ ...cardBorder, textAlign: 'center', p: 2.5 }}>
            <Box sx={{ position: 'relative', display: 'inline-flex', mb: 1.5 }}>
              <Avatar {...avatarProps(fullNameProfile || account.username, avatarUrl)} />
              <Tooltip title="Đổi ảnh đại diện">
                <IconButton
                  size="small"
                  disabled={avatarBusy}
                  onClick={() => fileInputRef.current?.click()}
                  sx={{
                    position: 'absolute',
                    right: -4,
                    bottom: -4,
                    bgcolor: 'primary.main',
                    color: 'primary.contrastText',
                    boxShadow: 2,
                    '&:hover': { bgcolor: 'primary.dark' },
                  }}
                >
                  {avatarBusy ? <CircularProgress size={16} color="inherit" /> : <PhotoCameraIcon fontSize="small" />}
                </IconButton>
              </Tooltip>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/png,image/jpeg"
                hidden
                onChange={(e) => void onAvatarFile(e.target.files?.[0] ?? null)}
              />
            </Box>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1 }}>
              PNG/JPG · tối đa 2MB
            </Typography>
            {(account.hasAvatar || avatarUrl) && (
              <Button
                size="small"
                color="inherit"
                startIcon={<DeleteOutlineIcon />}
                disabled={avatarBusy}
                onClick={() => void removeAvatar()}
                sx={{ mb: 1.5 }}
              >
                Xóa ảnh
              </Button>
            )}
            <Typography variant="h6" sx={{ fontWeight: 700 }}>
              {fullNameProfile || account.fullName}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              {email || account.email}
            </Typography>
            <List dense disablePadding sx={{ mt: 1, textAlign: 'left' }}>
              <ListItem alignItems="flex-start" sx={{ px: 0, py: 0.75 }}>
                <ListItemIcon sx={{ minWidth: 40, color: 'primary.main', mt: 0.15 }}>
                  <AdminPanelSettingsOutlinedIcon fontSize="small" />
                </ListItemIcon>
                <ListItemText
                  primary="Vai trò"
                  secondary={getRoleLabel(account.role, account.positionTitle)}
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
            {account.employeeId != null && (
              <Button
                component={RouterLink}
                to={`/employees/${account.employeeId}`}
                variant="outlined"
                fullWidth
                sx={{ mt: 2 }}
              >
                Xem hồ sơ nhân viên chi tiết
              </Button>
            )}
          </Card>
        </Grid>

        <Grid item xs={12} md={8}>
          <Stack spacing={2.5}>
            <Card sx={cardBorder}>
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
                      helperText={
                        account.employeeId == null
                          ? 'Tên hiển thị trên hệ thống (tài khoản chưa gắn hồ sơ NV).'
                          : undefined
                      }
                    />
                  </Grid>
                  <Grid item xs={12} md={6}>
                    <TextField
                      label="Email"
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      fullWidth
                    />
                  </Grid>
                  <Grid item xs={12} md={6}>
                    <TextField
                      label="Số điện thoại"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      fullWidth
                      disabled={erpLinked}
                      helperText={erpLinked ? 'SĐT lấy từ ERP (không sửa tại đây).' : undefined}
                    />
                  </Grid>
                  <Grid item xs={12} md={6}>
                    {account.employeeId == null ? (
                      <TextField
                        label="Phòng ban"
                        value={account.departmentName || '—'}
                        fullWidth
                        disabled
                        helperText="Chưa gắn hồ sơ nhân viên HRM."
                      />
                    ) : (
                      <FormControl fullWidth size="medium">
                        <InputLabel id="profile-dept-label">Phòng ban</InputLabel>
                        <Select
                          labelId="profile-dept-label"
                          label="Phòng ban"
                          value={departmentId === '' ? '' : departmentId}
                          onChange={(e) => setDepartmentId(Number(e.target.value))}
                        >
                          {profileDepartments.map((d) => (
                            <MenuItem key={d.id} value={d.id}>
                              {d.name}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    )}
                  </Grid>
                  {erpLinked && (
                    <Grid item xs={12} md={6}>
                      <DatePickerField
                        label="Ngày sinh"
                        value={dateOfBirth ? String(dateOfBirth).slice(0, 10) : ''}
                        onChange={setDateOfBirth}
                      />
                    </Grid>
                  )}
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

            <Card sx={cardBorder}>
              <CardContent sx={{ p: 3 }}>
                <Stack direction="row" spacing={1.25} alignItems="center" sx={{ mb: 2 }}>
                  <KeyIcon color="primary" />
                  <Typography variant="h6" fontWeight={700}>
                    Đổi mật khẩu
                  </Typography>
                </Stack>
                <Alert severity="info" sx={{ mb: 2.5 }}>
                  Đổi mật khẩu đăng nhập HRM tại đây. Mật khẩu mới tối thiểu 6 ký tự.
                </Alert>
                <Grid container spacing={2}>
                  <Grid item xs={12} md={4}>
                    <TextField
                      label="Mật khẩu hiện tại"
                      type="password"
                      value={oldPassword}
                      onChange={(e) => setOldPassword(e.target.value)}
                      fullWidth
                      autoComplete="current-password"
                    />
                  </Grid>
                  <Grid item xs={12} md={4}>
                    <TextField
                      label="Mật khẩu mới"
                      type="password"
                      value={newPassword}
                      onChange={(e) => setNewPassword(e.target.value)}
                      fullWidth
                      autoComplete="new-password"
                    />
                  </Grid>
                  <Grid item xs={12} md={4}>
                    <TextField
                      label="Xác nhận mật khẩu mới"
                      type="password"
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      fullWidth
                      autoComplete="new-password"
                    />
                  </Grid>
                </Grid>
                <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 3 }}>
                  <Button
                    variant="contained"
                    size="large"
                    disabled={pwSaving || !oldPassword || !newPassword}
                    onClick={() => void handleChangePassword()}
                    startIcon={pwSaving ? <CircularProgress size={18} color="inherit" /> : <KeyIcon />}
                  >
                    Đổi mật khẩu
                  </Button>
                </Box>
              </CardContent>
            </Card>
          </Stack>
        </Grid>
      </Grid>
    </Box>
  );
}
