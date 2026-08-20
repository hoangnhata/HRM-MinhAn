import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import LockOutlinedIcon from '@mui/icons-material/LockOutlined';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  MenuItem,
  Paper,
  Stack,
  Tab,
  Tabs,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { PageHeader } from '../components/layout/PageHeader';
import { SalaryImportDialog } from '../components/SalaryImportDialog';
import { useAuth } from '../context/AuthContext';
import * as salaryService from '../services/salaryService';

type ViewerScope = 'ALL' | 'DIRECT' | 'INDIRECT' | 'DOCTOR' | 'NONE';

const SCOPE_TAB: Record<Exclude<ViewerScope, 'ALL' | 'NONE'>, number> = {
  DIRECT: 0,
  INDIRECT: 1,
  DOCTOR: 2,
};

const SCOPE_LABEL: Record<Exclude<ViewerScope, 'ALL' | 'NONE'>, string> = {
  DIRECT: 'Nhân viên trực tiếp',
  INDIRECT: 'Nhân viên gián tiếp',
  DOCTOR: 'Bác sỹ',
};

export default function SalaryScalePage() {
  const theme = useTheme();
  const { user } = useAuth();
  const location = useLocation();
  const selfOnly = location.pathname === '/salary-scales/me';
  const isAdmin = user?.role === 'ADMIN' || user?.role === 'HR';
  const manageMode = isAdmin && !selfOnly;
  const [tab, setTab] = useState(0);
  const [viewerScope, setViewerScope] = useState<ViewerScope>('NONE');
  const [scales, setScales] = useState<salaryService.AllSalaryScales | null>(null);
  const [directBase, setDirectBase] = useState('');
  const [indirectBase, setIndirectBase] = useState('');
  const baseQual = salaryService.EMPLOYEE_QUALIFICATIONS[2];
  const [directQual, setDirectQual] = useState<string>(baseQual);
  const [indirectQual, setIndirectQual] = useState<string>(baseQual);
  const [msg, setMsg] = useState<string | null>(null);
  const [importOpen, setImportOpen] = useState(false);
  const [salaryUnlocked, setSalaryUnlocked] = useState(
    () => !manageMode || Boolean(salaryService.getSalaryAccessToken()),
  );
  const [unlockOpen, setUnlockOpen] = useState(false);
  const [unlockPassword, setUnlockPassword] = useState('');
  const [unlockBusy, setUnlockBusy] = useState(false);
  const [unlockError, setUnlockError] = useState<string | null>(null);

  const paperSx = {
    p: 2.25,
    borderRadius: 2.5,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
    bgcolor: alpha(theme.palette.background.paper, 0.92),
    boxShadow: `0 4px 20px ${alpha('#0f172a', 0.04)}`,
  };

  function tierBaseTotal(scale: salaryService.EmployeeScale, qual: string) {
    const tier = scale.tiers.find((t) => t.tierLabel === qual);
    return tier?.grades[0]?.totalIncome ?? scale.baseTotalAtCoef1 ?? '';
  }

  function reload() {
    salaryService.fetchSalaryScales(selfOnly)
      .then((s) => {
        const scope = (s.viewerScope as ViewerScope) || 'NONE';
        setViewerScope(scope);
        setScales(s);
        setDirectBase(String(tierBaseTotal(s.employeeDirect, directQual)));
        setIndirectBase(String(tierBaseTotal(s.employeeIndirect, indirectQual)));
        if (scope !== 'ALL' && scope !== 'NONE') setTab(SCOPE_TAB[scope]);
      })
      .catch(() => {
        if (manageMode) {
          salaryService.clearSalaryAccess();
          setSalaryUnlocked(false);
          setScales(null);
        }
      });
  }

  function onQualChange(
    qual: string,
    scale: salaryService.EmployeeScale,
    setQual: (q: string) => void,
    setBase: (v: string) => void,
  ) {
    setQual(qual);
    setBase(String(tierBaseTotal(scale, qual)));
  }

  useEffect(() => {
    if (!manageMode || salaryUnlocked) reload();
  }, []);

  async function handleUnlock() {
    if (!unlockPassword) return;
    setUnlockBusy(true);
    setUnlockError(null);
    try {
      await salaryService.unlockSalaryAccess(unlockPassword);
      setSalaryUnlocked(true);
      setUnlockOpen(false);
      setUnlockPassword('');
      reload();
    } catch {
      salaryService.clearSalaryAccess();
      setUnlockPassword('');
      setUnlockError('Sai mật khẩu, vui lòng nhập lại.');
    } finally {
      setUnlockBusy(false);
    }
  }

  const visibleTabs = useMemo(() => {
    if (viewerScope === 'ALL') {
      return [
        { index: 0, label: 'Nhân viên trực tiếp' },
        { index: 1, label: 'Nhân viên gián tiếp' },
        { index: 2, label: 'Bác sỹ' },
      ];
    }
    if (viewerScope === 'NONE') return [];
    return [{ index: SCOPE_TAB[viewerScope], label: SCOPE_LABEL[viewerScope] }];
  }, [viewerScope]);

  async function saveBase(type: 'EMPLOYEE_DIRECT' | 'EMPLOYEE_INDIRECT', value: string, qualification: string) {
    setMsg(null);
    const n = Number(value.replace(/\./g, '').replace(/,/g, ''));
    if (!n || n <= 0) {
      setMsg('Giá trị tổng thu nhập hệ số 1 không hợp lệ.');
      return;
    }
    try {
      await salaryService.updateScaleBase(type, n, qualification);
      setMsg('Đã cập nhật thang bảng lương. Tổng thu nhập các bậc đã điều chỉnh; lương SP giữ nguyên; lương BH = tổng − SP.');
      reload();
    } catch {
      setMsg('Không cập nhật được (cần quyền ADMIN/HCNS 1 và mật khẩu phần lương).');
    }
  }

  const description =
    manageMode && !salaryUnlocked
      ? 'Nhập mật khẩu phần lương để xem toàn bộ thang bảng lương.'
      : viewerScope === 'ALL'
      ? 'ADMIN/HCNS 1 đã mở khóa và được xem toàn bộ thang bảng lương.'
      : viewerScope === 'NONE'
        ? 'Chưa có đối tượng lương trên hồ sơ — liên hệ HCNS để cấu hình trước khi xem thang bảng.'
        : `Bạn đang xem thang bảng đối tượng: ${SCOPE_LABEL[viewerScope]}. Không hiển thị các khối lương khác.`;

  return (
    <Box>
      <PageHeader
        overline="Thang bảng lương"
        title="Thang bảng lương áp dụng từ 4/2025"
        description={description}
        actions={
          manageMode ? (
            salaryUnlocked ? (
              <Button variant="outlined" startIcon={<CloudUploadIcon />} onClick={() => setImportOpen(true)}>
                Import thang bảng
              </Button>
            ) : (
              <Button
                variant="contained"
                startIcon={<LockOutlinedIcon />}
                onClick={() => {
                  setUnlockError(null);
                  setUnlockOpen(true);
                }}
              >
                Nhập mật khẩu
              </Button>
            )
          ) : undefined
        }
      />

      <SalaryImportDialog open={importOpen} onClose={() => setImportOpen(false)} onImported={reload} />
      <Dialog open={unlockOpen} onClose={() => !unlockBusy && setUnlockOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Mở khóa thang bảng lương</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            ADMIN/HCNS 1 cần nhập mật khẩu phần lương để xem toàn bộ các đối tượng.
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

      <Paper elevation={0} sx={{ ...paperSx, mb: 2 }}>
        {manageMode && !salaryUnlocked ? (
          <Alert severity="warning" icon={<LockOutlinedIcon />}>
            Thang bảng lương đang được khóa. Nhập mật khẩu phần lương để tiếp tục.
          </Alert>
        ) : viewerScope === 'NONE' ? (
          <Alert severity="info">
            Hồ sơ lương chưa gắn đối tượng (Trực tiếp / Gián tiếp / Bác sĩ). Sau khi HCNS cấu hình, bạn sẽ xem đúng
            thang bảng tương ứng.
          </Alert>
        ) : (
          <>
            {visibleTabs.length > 1 ? (
              <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
                {visibleTabs.map((t) => (
                  <Tab key={t.index} value={t.index} label={t.label} />
                ))}
              </Tabs>
            ) : (
              <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 2 }}>
                {visibleTabs[0]?.label}
              </Typography>
            )}

            {msg && (
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                {msg}
              </Typography>
            )}

            {scales && tab === 0 && (viewerScope === 'ALL' || viewerScope === 'DIRECT') && (
              <>
                {manageMode && (
                  <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} sx={{ mb: 2 }} alignItems="center" flexWrap="wrap">
                    <TextField
                      size="small"
                      select
                      label="Trình độ"
                      value={directQual}
                      onChange={(e) =>
                        scales && onQualChange(e.target.value, scales.employeeDirect, setDirectQual, setDirectBase)
                      }
                      sx={{ minWidth: 220 }}
                    >
                      {salaryService.EMPLOYEE_QUALIFICATIONS.map((q) => (
                        <MenuItem key={q} value={q}>
                          {q}
                        </MenuItem>
                      ))}
                    </TextField>
                    <TextField
                      size="small"
                      label="Tổng thu nhập Bậc 1 (hệ số 1,00 = Lao động phổ thông)"
                      value={directBase}
                      onChange={(e) => setDirectBase(e.target.value)}
                      sx={{ minWidth: 280 }}
                    />
                    <Button variant="contained" onClick={() => saveBase('EMPLOYEE_DIRECT', directBase, directQual)}>
                      Cập nhật
                    </Button>
                  </Stack>
                )}
                {scales.employeeDirect.tiers.length === 0 ? (
                  <Typography color="text.secondary">Chưa có dữ liệu — import file thang bảng lương ma.xlsx.</Typography>
                ) : (
                  scales.employeeDirect.tiers.map((tier) => (
                    <Box key={tier.tierLabel} sx={{ mb: 3 }}>
                      <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 1 }}>
                        {tier.tierLabel}
                      </Typography>
                      <EmployeeScaleTable grades={tier.grades} />
                    </Box>
                  ))
                )}
              </>
            )}

            {scales && tab === 1 && (viewerScope === 'ALL' || viewerScope === 'INDIRECT') && (
              <>
                {manageMode && (
                  <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} sx={{ mb: 2 }} alignItems="center" flexWrap="wrap">
                    <TextField
                      size="small"
                      select
                      label="Trình độ"
                      value={indirectQual}
                      onChange={(e) =>
                        scales && onQualChange(e.target.value, scales.employeeIndirect, setIndirectQual, setIndirectBase)
                      }
                      sx={{ minWidth: 220 }}
                    >
                      {salaryService.EMPLOYEE_QUALIFICATIONS.map((q) => (
                        <MenuItem key={q} value={q}>
                          {q}
                        </MenuItem>
                      ))}
                    </TextField>
                    <TextField
                      size="small"
                      label="Tổng thu nhập Bậc 1 (hệ số 1,00 = Lao động phổ thông)"
                      value={indirectBase}
                      onChange={(e) => setIndirectBase(e.target.value)}
                      sx={{ minWidth: 280 }}
                    />
                    <Button variant="contained" onClick={() => saveBase('EMPLOYEE_INDIRECT', indirectBase, indirectQual)}>
                      Cập nhật
                    </Button>
                  </Stack>
                )}
                {scales.employeeIndirect.tiers.length === 0 ? (
                  <Typography color="text.secondary">Chưa có dữ liệu — import file thang bảng lương ma.xlsx.</Typography>
                ) : (
                  scales.employeeIndirect.tiers.map((tier) => (
                    <Box key={tier.tierLabel} sx={{ mb: 3 }}>
                      <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 1 }}>
                        {tier.tierLabel}
                      </Typography>
                      <EmployeeScaleTable grades={tier.grades} />
                    </Box>
                  ))
                )}
              </>
            )}

            {scales && tab === 2 && (viewerScope === 'ALL' || viewerScope === 'DOCTOR') && (
              <TableContainer sx={{ borderRadius: 2, border: `1px solid ${alpha(theme.palette.divider, 0.8)}` }}>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Bằng cấp</TableCell>
                      <TableCell>Mã</TableCell>
                      <TableCell>Thời gian làm việc</TableCell>
                      <TableCell align="right">Thang bảng lương (tổng)</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {scales.doctor.length === 0 ? (
                      <TableRow>
                        <TableCell colSpan={4} align="center">
                          Chưa có dữ liệu bác sỹ — import thang bảng lương.
                        </TableCell>
                      </TableRow>
                    ) : (
                      scales.doctor.map((d) => (
                        <TableRow key={d.id}>
                          <TableCell>{d.qualificationName}</TableCell>
                          <TableCell>{d.qualificationCode}</TableCell>
                          <TableCell>{d.timeLabel}</TableCell>
                          <TableCell align="right">{salaryService.formatMoney(d.totalSalary)}</TableCell>
                        </TableRow>
                      ))
                    )}
                  </TableBody>
                </Table>
              </TableContainer>
            )}
          </>
        )}
      </Paper>
    </Box>
  );
}

function EmployeeScaleTable({ grades }: { grades: salaryService.EmployeeScaleGrade[] }) {
  return (
    <TableContainer sx={{ borderRadius: 2, border: '1px solid', borderColor: 'divider' }}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Bậc</TableCell>
            <TableCell>Thâm niên</TableCell>
            <TableCell align="right">Hệ số</TableCell>
            <TableCell align="right">Lương cơ bản đóng BH</TableCell>
            <TableCell align="right">Lương đảm bảo SP</TableCell>
            <TableCell align="right">Tổng thu nhập</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {grades.map((g) => (
            <TableRow key={g.gradeLevel}>
              <TableCell>{g.gradeLabel}</TableCell>
              <TableCell>{g.yearsRange}</TableCell>
              <TableCell align="right">{g.coefficient}</TableCell>
              <TableCell align="right">{salaryService.formatMoney(g.insuranceSalary)}</TableCell>
              <TableCell align="right">{salaryService.formatMoney(g.productSalary)}</TableCell>
              <TableCell align="right">{salaryService.formatMoney(g.totalIncome)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
