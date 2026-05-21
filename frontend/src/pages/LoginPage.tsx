import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Container,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const LOGO_SRC = '/logo.png';

export default function LoginPage() {
  const theme = useTheme();
  const { login } = useAuth();
  const nav = useNavigate();
  const loc = useLocation();
  const from = (loc.state as { from?: { pathname: string } })?.from?.pathname || '/';

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setLoading(true);
    try {
      await login(username, password);
      nav(from, { replace: true });
    } catch {
      setErr('Đăng nhập thất bại. Kiểm tra tài khoản hoặc mật khẩu.');
    } finally {
      setLoading(false);
    }
  }

  const panelGradient = `linear-gradient(145deg, ${theme.palette.primary.dark} 0%, ${theme.palette.primary.main} 42%, #0a7a76 100%)`;

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Box
        sx={{
          display: { xs: 'flex', md: 'none' },
          alignItems: 'center',
          gap: 2,
          px: 2,
          py: 2.5,
          background: panelGradient,
          color: 'primary.contrastText',
        }}
      >
        <Box
          component="img"
          src={LOGO_SRC}
          alt="Bệnh viện Minh An"
          sx={{
            width: 56,
            height: 56,
            borderRadius: '50%',
            bgcolor: 'white',
            p: 0.75,
            objectFit: 'contain',
            boxShadow: '0 4px 16px rgba(0,0,0,0.2)',
          }}
        />
        <Box>
          <Typography variant="subtitle1" sx={{ fontWeight: 600, letterSpacing: '-0.02em' }}>
            Bệnh viện Minh An
          </Typography>
          <Typography variant="caption" sx={{ opacity: 0.92 }}>
            Hệ thống quản trị nhân sự
          </Typography>
        </Box>
      </Box>

      <Box sx={{ flex: 1, display: 'flex', minHeight: 0 }}>
        <Box
          sx={{
            display: { xs: 'none', md: 'flex' },
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            width: { md: '44%' },
            minHeight: '100%',
            px: 4,
            py: 6,
            background: panelGradient,
            color: 'primary.contrastText',
            position: 'relative',
            overflow: 'hidden',
          }}
        >
          <Box
            sx={{
              position: 'absolute',
              inset: 0,
              opacity: 0.07,
              backgroundImage: `radial-gradient(circle at 20% 30%, white 0%, transparent 45%),
                radial-gradient(circle at 80% 70%, white 0%, transparent 40%)`,
            }}
          />
          <Box sx={{ position: 'relative', textAlign: 'center', maxWidth: 360 }}>
            <Box
              component="img"
              src={LOGO_SRC}
              alt="Bệnh viện Minh An"
              sx={{
                width: 140,
                height: 140,
                mx: 'auto',
                mb: 3,
                borderRadius: '50%',
                bgcolor: 'white',
                p: 1.5,
                objectFit: 'contain',
                boxShadow: `0 12px 40px ${alpha('#000', 0.25)}`,
              }}
            />
            <Typography variant="h4" sx={{ fontWeight: 600, letterSpacing: '-0.025em' }} gutterBottom>
              Bệnh viện Minh An
            </Typography>
            <Typography variant="body1" sx={{ opacity: 0.9, lineHeight: 1.65, fontWeight: 400 }}>
              Hệ thống quản trị nhân sự nội bộ — an toàn, gọn gàng, phù hợp môi trường y tế.
            </Typography>
          </Box>
        </Box>

        <Box
          sx={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            py: { xs: 3, md: 4 },
            px: 2,
            bgcolor: 'background.default',
            position: 'relative',
            overflow: 'hidden',
            '&::before': {
              content: '""',
              position: 'absolute',
              inset: 0,
              opacity: 0.45,
              backgroundImage: `radial-gradient(circle at 15% 20%, ${alpha(theme.palette.primary.main, 0.12)} 0%, transparent 42%),
                radial-gradient(circle at 85% 80%, ${alpha(theme.palette.secondary.main, 0.1)} 0%, transparent 40%)`,
              pointerEvents: 'none',
            },
          }}
        >
          <Container maxWidth="sm" sx={{ position: 'relative', zIndex: 1 }}>
            <Card
              elevation={0}
              sx={{
                overflow: 'visible',
                borderRadius: 3,
                border: `1px solid ${alpha(theme.palette.primary.main, 0.14)}`,
                boxShadow: `0 12px 40px ${alpha(theme.palette.primary.dark, 0.12)}, 0 2px 8px ${alpha('#0f172a', 0.04)}`,
              }}
            >
              <CardContent sx={{ p: { xs: 3, sm: 4 } }}>
                <Typography variant="h5" sx={{ fontWeight: 600, letterSpacing: '-0.02em', color: 'text.primary' }} gutterBottom>
                  Đăng nhập
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 3, lineHeight: 1.6 }}>
                  Dùng tài khoản nội bộ được cấp bởi phòng nhân sự.
                </Typography>
                {err && (
                  <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }}>
                    {err}
                  </Alert>
                )}
                <Box component="form" onSubmit={onSubmit}>
                  <TextField
                    label="Tên đăng nhập"
                    fullWidth
                    margin="normal"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    autoComplete="username"
                    autoFocus
                  />
                  <TextField
                    label="Mật khẩu"
                    type="password"
                    fullWidth
                    margin="normal"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    autoComplete="current-password"
                  />
                  <Button
                    type="submit"
                    variant="contained"
                    color="primary"
                    size="large"
                    fullWidth
                    sx={{ mt: 3, py: 1.35 }}
                    disabled={loading}
                  >
                    {loading ? 'Đang đăng nhập…' : 'Đăng nhập'}
                  </Button>
                </Box>
                <Typography
                  variant="caption"
                  display="block"
                  sx={{
                    mt: 3,
                    color: 'text.secondary',
                    lineHeight: 1.6,
                    p: 1.5,
                    borderRadius: 2,
                    bgcolor: alpha(theme.palette.primary.main, 0.06),
                  }}
                >
                  Tài khoản mẫu: <strong>admin</strong> / Admin@123 · <strong>nhanvien</strong> / Emp@123 ·{' '}
                  <strong>hcns</strong> / Hcns@123 (tổng hợp xếp loại) · <strong>truongkhoa</strong> / Tk@12345 ·{' '}
                  <strong>dieuduongtruong</strong> / Ddt@12345
                </Typography>
              </CardContent>
            </Card>
          </Container>
        </Box>
      </Box>
    </Box>
  );
}
