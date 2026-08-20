import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import PaymentsIcon from '@mui/icons-material/Payments';
import LockOutlinedIcon from '@mui/icons-material/LockOutlined';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Grid,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { Link as RouterLink } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import * as salaryService from '../services/salaryService';

type Props = {
  employeeId: number;
};

function SummaryItem({ label, value }: { label: string; value: string }) {
  return (
    <Box>
      <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600 }}>
        {label}
      </Typography>
      <Typography variant="body2" fontWeight={700} sx={{ mt: 0.25 }}>
        {value}
      </Typography>
    </Box>
  );
}

export function EmployeeSalarySummaryCard({ employeeId }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const isAdmin = user?.role === 'ADMIN' || user?.role === 'HR';
  const isOwnProfile = user?.employeeId === employeeId;
  const salaryDetailPath = isOwnProfile
    ? '/salary/me'
    : `/salary?employeeId=${employeeId}`;
  const [profile, setProfile] = useState<salaryService.EmployeeSalaryProfile | null>(null);
  const [unlocked, setUnlocked] = useState(() => Boolean(salaryService.getSalaryAccessToken()));
  const [loading, setLoading] = useState(!isAdmin || unlocked);
  const [forbidden, setForbidden] = useState(false);
  const [unlockOpen, setUnlockOpen] = useState(false);
  const [unlockPassword, setUnlockPassword] = useState('');
  const [unlockBusy, setUnlockBusy] = useState(false);
  const [unlockError, setUnlockError] = useState<string | null>(null);

  useEffect(() => {
    if (isAdmin && !unlocked) {
      setLoading(false);
      setProfile(null);
      setForbidden(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setForbidden(false);
    salaryService
      .fetchSalaryProfile(employeeId)
      .then((p) => {
        if (!cancelled) setProfile(p);
      })
      .catch(() => {
        if (!cancelled) {
          setProfile(null);
          setForbidden(true);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [employeeId, isAdmin, unlocked]);

  async function handleUnlock() {
    if (!unlockPassword) return;
    setUnlockBusy(true);
    setUnlockError(null);
    try {
      await salaryService.unlockSalaryAccess(unlockPassword);
      setUnlocked(true);
      setUnlockOpen(false);
      setUnlockPassword('');
    } catch {
      salaryService.clearSalaryAccess();
      setUnlocked(false);
      setUnlockPassword('');
      setUnlockError('Sai mật khẩu, vui lòng nhập lại.');
    } finally {
      setUnlockBusy(false);
    }
  }

  if (loading) {
    return (
      <Card variant="outlined" sx={{ height: '100%' }}>
        <CardContent sx={{ py: 4, textAlign: 'center' }}>
          <CircularProgress size={28} />
        </CardContent>
      </Card>
    );
  }

  if (forbidden) {
    return null;
  }

  if (isAdmin && !unlocked) {
    return (
      <>
        <Card
          variant="outlined"
          sx={{
            height: '100%',
            borderColor: alpha(theme.palette.warning.main, 0.3),
            bgcolor: alpha(theme.palette.warning.main, 0.035),
          }}
        >
          <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
            <Stack direction="row" spacing={1.5} alignItems="center" justifyContent="space-between">
              <Stack direction="row" spacing={1.5} alignItems="center">
                <Box
                  sx={{
                    width: 40,
                    height: 40,
                    borderRadius: 2,
                    display: 'grid',
                    placeItems: 'center',
                    bgcolor: alpha(theme.palette.warning.main, 0.14),
                    color: theme.palette.warning.dark,
                  }}
                >
                  <LockOutlinedIcon fontSize="small" />
                </Box>
                <Box>
                  <Typography variant="subtitle1" fontWeight={700}>
                    Bảng lương & thâm niên
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Dữ liệu lương đang được bảo vệ
                  </Typography>
                </Box>
              </Stack>
              <Button
                size="small"
                variant="contained"
                startIcon={<LockOutlinedIcon fontSize="small" />}
                onClick={() => {
                  setUnlockError(null);
                  setUnlockOpen(true);
                }}
              >
                Mở khóa
              </Button>
            </Stack>
          </CardContent>
        </Card>

        <Dialog open={unlockOpen} onClose={() => !unlockBusy && setUnlockOpen(false)} maxWidth="xs" fullWidth>
          <DialogTitle>Mở khóa thông tin lương</DialogTitle>
          <DialogContent>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Nhập mật khẩu phần lương để xem thông tin của nhân viên này.
            </Typography>
            {unlockError && <Alert severity="error" sx={{ mb: 2 }}>{unlockError}</Alert>}
            <TextField
              autoFocus
              fullWidth
              type="password"
              label="Mật khẩu phần lương"
              value={unlockPassword}
              onChange={(e) => setUnlockPassword(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') void handleUnlock();
              }}
              disabled={unlockBusy}
            />
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2.5 }}>
            <Button onClick={() => setUnlockOpen(false)} disabled={unlockBusy}>Hủy</Button>
            <Button
              variant="contained"
              onClick={() => void handleUnlock()}
              disabled={unlockBusy || !unlockPassword}
            >
              {unlockBusy ? 'Đang kiểm tra…' : 'Mở khóa'}
            </Button>
          </DialogActions>
        </Dialog>
      </>
    );
  }

  const grade = profile?.computedGrade;
  const gradeLabel =
    grade && grade.gradeLabel !== '—'
      ? `${grade.gradeLabel}${grade.yearsRange !== '—' ? ` · ${grade.yearsRange}` : ''}`
      : '—';

  const categoryLabel =
    profile?.salaryCategory === 'DOCTOR'
      ? 'Bác sỹ'
      : profile?.employeeBlock === 'INDIRECT'
        ? 'Nhân viên gián tiếp'
        : profile?.employeeBlock === 'DIRECT'
          ? 'Nhân viên trực tiếp'
          : profile?.salaryCategory
            ? 'Nhân viên'
            : '—';

  const seniorityLabel = profile?.ldg
    ? 'LĐG'
    : profile?.salaryCategory
      ? `${salaryService.formatYears(profile.seniorityYears)} năm`
      : '—';

  return (
    <Card
      variant="outlined"
      sx={{
        height: '100%',
        borderColor: alpha(theme.palette.success.main, 0.25),
        bgcolor: alpha(theme.palette.success.main, 0.03),
      }}
    >
      <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
        <Stack direction="row" spacing={1.5} alignItems="flex-start" justifyContent="space-between" sx={{ mb: 2 }}>
          <Stack direction="row" spacing={1.5} alignItems="center">
            <Box
              sx={{
                width: 40,
                height: 40,
                borderRadius: 2,
                display: 'grid',
                placeItems: 'center',
                bgcolor: alpha(theme.palette.success.main, 0.12),
                color: theme.palette.success.dark,
              }}
            >
              <PaymentsIcon fontSize="small" />
            </Box>
            <Box>
              <Typography variant="subtitle1" fontWeight={700}>
                Bảng lương & thâm niên
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {profile?.salaryCategory ? categoryLabel : 'Chưa cấu hình hồ sơ lương'}
              </Typography>
            </Box>
          </Stack>
          <Button
            component={RouterLink}
            to={salaryDetailPath}
            size="small"
            variant="outlined"
            endIcon={<OpenInNewIcon fontSize="small" />}
          >
            Xem chi tiết
          </Button>
        </Stack>

        {profile?.salaryCategory ? (
          <Grid container spacing={2}>
            <Grid item xs={6} sm={4}>
              <SummaryItem label="Thâm niên tính lương" value={seniorityLabel} />
            </Grid>
            <Grid item xs={6} sm={4}>
              <SummaryItem label="Bậc lương" value={gradeLabel} />
            </Grid>
            <Grid item xs={6} sm={4}>
              <SummaryItem
                label="Tổng lương"
                value={salaryService.formatMoney(profile.totalSalary)}
              />
            </Grid>
            <Grid item xs={6} sm={4}>
              <SummaryItem
                label="Lương cơ bản (BH)"
                value={salaryService.formatMoney(grade?.insuranceSalary)}
              />
            </Grid>
            <Grid item xs={6} sm={4}>
              <SummaryItem
                label="Lương đảm bảo SP"
                value={salaryService.formatMoney(grade?.productSalary)}
              />
            </Grid>
          </Grid>
        ) : (
          <Typography variant="body2" color="text.secondary">
            Chưa có dữ liệu lương. Bấm <strong>Xem chi tiết</strong> để cấu hình hoặc kiểm tra sau khi import Excel.
          </Typography>
        )}
      </CardContent>
    </Card>
  );
}
