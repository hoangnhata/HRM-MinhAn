import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import {
  Box,
  Button,
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
import { useEffect, useState } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import { SalaryImportDialog } from '../components/SalaryImportDialog';
import { useAuth } from '../context/AuthContext';
import * as salaryService from '../services/salaryService';

export default function SalaryScalePage() {
  const theme = useTheme();
  const { user } = useAuth();
  const isHrOrAdmin = user?.role === 'ADMIN' || user?.role === 'HR';
  const [tab, setTab] = useState(0);
  const [scales, setScales] = useState<salaryService.AllSalaryScales | null>(null);
  const [directBase, setDirectBase] = useState('');
  const [indirectBase, setIndirectBase] = useState('');
  const baseQual = salaryService.EMPLOYEE_QUALIFICATIONS[2];
  const [directQual, setDirectQual] = useState<string>(baseQual);
  const [indirectQual, setIndirectQual] = useState<string>(baseQual);
  const [msg, setMsg] = useState<string | null>(null);
  const [importOpen, setImportOpen] = useState(false);

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
    salaryService.fetchSalaryScales().then((s) => {
      setScales(s);
      setDirectBase(String(tierBaseTotal(s.employeeDirect, directQual)));
      setIndirectBase(String(tierBaseTotal(s.employeeIndirect, indirectQual)));
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
    reload();
  }, []);

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
      setMsg('Không cập nhật được (cần quyền ADMIN hoặc HR).');
    }
  }

  return (
    <Box>
      <PageHeader
        overline="Thang bảng lương"
        title="Thang bảng lương áp dụng từ 4/2025"
        description="Mọi nhân viên đều xem được. Cập nhật theo Lao động phổ thông (hệ số 1,00): tổng thu nhập các bậc tỷ lệ theo Bậc 1; lương đảm bảo SP giữ nguyên; lương cơ bản đóng BH = tổng thu nhập − lương SP."
        actions={
          isHrOrAdmin ? (
            <Button variant="outlined" startIcon={<CloudUploadIcon />} onClick={() => setImportOpen(true)}>
              Import thang bảng
            </Button>
          ) : undefined
        }
      />

      <SalaryImportDialog open={importOpen} onClose={() => setImportOpen(false)} onImported={reload} />

      <Paper elevation={0} sx={{ ...paperSx, mb: 2 }}>
        <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
          <Tab label="Nhân viên trực tiếp" />
          <Tab label="Nhân viên gián tiếp" />
          <Tab label="Bác sỹ" />
        </Tabs>

        {msg && (
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {msg}
          </Typography>
        )}

        {scales && tab === 0 && (
          <>
            {isHrOrAdmin && (
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

        {scales && tab === 1 && (
          <>
            {isHrOrAdmin && (
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

        {scales && tab === 2 && (
          <TableContainer sx={{ borderRadius: 2, border: `1px solid ${alpha(theme.palette.divider, 0.8)}` }}>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Bằng cấp</TableCell>
                  <TableCell>Mã</TableCell>
                  <TableCell>Thời gian làm việc</TableCell>
                  <TableCell align="right">Tổng thu nhập</TableCell>
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
