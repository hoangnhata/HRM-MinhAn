import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import * as accountService from '../services/accountService';

export function ChangePasswordRequiredPage() {
  const { user, refreshUser } = useAuth();
  const navigate = useNavigate();
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (user && !user.mustChangePassword) {
      navigate('/', { replace: true });
    }
  }, [user, navigate]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (newPassword.length < 6) {
      setErr('Mật khẩu mới tối thiểu 6 ký tự.');
      return;
    }
    if (newPassword !== confirm) {
      setErr('Mật khẩu mới không khớp.');
      return;
    }
    setSaving(true);
    try {
      await accountService.changeAccountPassword({ oldPassword, newPassword });
      await refreshUser();
      navigate('/', { replace: true });
    } catch {
      setErr('Đổi mật khẩu thất bại. Kiểm tra mật khẩu hiện tại (mặc định: 123).');
    } finally {
      setSaving(false);
    }
  }

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'grey.100',
        p: 2,
      }}
    >
      <Card sx={{ maxWidth: 440, width: '100%' }}>
        <CardContent sx={{ p: 3 }}>
          <Typography variant="h6" fontWeight={700} gutterBottom>
            Đổi mật khẩu lần đầu
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2.5 }}>
            Xin chào <strong>{user?.fullName ?? user?.username}</strong>. Vì lý do bảo mật, bạn cần đổi mật
            khẩu trước khi sử dụng hệ thống. Mật khẩu mặc định là <strong>123</strong>.
          </Typography>
          {err && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {err}
            </Alert>
          )}
          <Box component="form" onSubmit={submit}>
            <Stack spacing={2}>
              <TextField
                label="Mật khẩu hiện tại"
                type="password"
                required
                fullWidth
                value={oldPassword}
                onChange={(e) => setOldPassword(e.target.value)}
                autoComplete="current-password"
              />
              <TextField
                label="Mật khẩu mới"
                type="password"
                required
                fullWidth
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                autoComplete="new-password"
              />
              <TextField
                label="Nhập lại mật khẩu mới"
                type="password"
                required
                fullWidth
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                autoComplete="new-password"
              />
              <Button type="submit" variant="contained" fullWidth disabled={saving}>
                {saving ? 'Đang lưu…' : 'Xác nhận đổi mật khẩu'}
              </Button>
            </Stack>
          </Box>
        </CardContent>
      </Card>
    </Box>
  );
}
