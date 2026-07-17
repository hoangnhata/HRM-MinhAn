import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import DownloadIcon from '@mui/icons-material/Download';
import RefreshIcon from '@mui/icons-material/Refresh';
import SaveIcon from '@mui/icons-material/Save';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import WorkHistoryIcon from '@mui/icons-material/WorkHistory';
import MilitaryTechIcon from '@mui/icons-material/MilitaryTech';
import PaymentsIcon from '@mui/icons-material/Payments';
import {
  Alert,
  Box,
  Button,
  Chip,
  Divider,
  Grid,
  Link as MuiLink,
  MenuItem,
  Paper,
  Snackbar,
  Stack,
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
import { Link } from 'react-router-dom';
import { EmployeeFilterPanel, formatEmployeeLabel } from '../components/EmployeeFilterPanel';
import { PageHeader } from '../components/layout/PageHeader';
import { SalaryImportDialog } from '../components/SalaryImportDialog';
import { useAuth } from '../context/AuthContext';
import * as employeeService from '../services/employeeService';
import * as pa from '../services/payrollAttendanceService';
import * as salaryService from '../services/salaryService';

function StatCard({
  icon,
  label,
  value,
  accent,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  accent?: string;
}) {
  const theme = useTheme();
  const color = accent ?? theme.palette.primary.main;
  return (
    <Paper
      elevation={0}
      sx={{
        p: 2,
        height: '100%',
        borderRadius: 2.5,
        border: `1px solid ${alpha(color, 0.18)}`,
        bgcolor: alpha(color, 0.04),
        transition: 'box-shadow 0.2s',
        '&:hover': { boxShadow: `0 6px 24px ${alpha(color, 0.12)}` },
      }}
    >
      <Stack direction="row" spacing={1.5} alignItems="flex-start">
        <Box
          sx={{
            width: 40,
            height: 40,
            borderRadius: 2,
            display: 'grid',
            placeItems: 'center',
            bgcolor: alpha(color, 0.12),
            color,
            flexShrink: 0,
          }}
        >
          {icon}
        </Box>
        <Box sx={{ minWidth: 0 }}>
          <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600, letterSpacing: '0.04em' }}>
            {label}
          </Typography>
          <Typography variant="h6" fontWeight={700} sx={{ mt: 0.25, lineHeight: 1.3 }}>
            {value}
          </Typography>
        </Box>
      </Stack>
    </Paper>
  );
}

function DetailLine({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <Stack
      direction="row"
      justifyContent="space-between"
      alignItems="baseline"
      spacing={2}
      sx={{
        py: 1.25,
        borderBottom: '1px solid',
        borderColor: 'divider',
        '&:last-of-type': { borderBottom: 'none' },
      }}
    >
      <Typography variant="body2" color="text.secondary" sx={{ fontWeight: 500 }}>
        {label}
      </Typography>
      <Typography
        variant="body2"
        fontWeight={highlight ? 700 : 600}
        color={highlight ? 'primary.main' : 'text.primary'}
        sx={{ textAlign: 'right' }}
      >
        {value}
      </Typography>
    </Stack>
  );
}

export default function SalaryPage() {
  const theme = useTheme();
  const { user } = useAuth();
  const [employees, setEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [selected, setSelected] = useState<number | ''>('');
  const [qInput, setQInput] = useState('');
  const [q, setQ] = useState('');
  const [filterDept, setFilterDept] = useState<number | ''>('');
  const [filterStatus, setFilterStatus] = useState('ACTIVE');
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [profile, setProfile] = useState<salaryService.EmployeeSalaryProfile | null>(null);
  const [pay, setPay] = useState<Record<string, unknown>[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);
  const [saveOk, setSaveOk] = useState(true);
  const [saving, setSaving] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [bulkBusy, setBulkBusy] = useState(false);

  const isHrOrAdmin = user?.role === 'ADMIN' || user?.role === 'HR';

  const [form, setForm] = useState<salaryService.EmployeeSalaryProfileRequest>({
    salaryCategory: 'EMPLOYEE',
    employeeBlock: 'DIRECT',
    qualification: salaryService.EMPLOYEE_QUALIFICATIONS[2],
    tierGroup: 3,
    doctorQualificationCode: 'CCHN',
    qualificationNote: '',
    degreeConversionYears: 0,
    priorRaiseYears: 0,
    professionalAttractionSalary: 0,
  });

  function syncFormFromProfile(p: salaryService.EmployeeSalaryProfile) {
    if (!p.salaryCategory) return;
    setForm({
      salaryCategory: p.salaryCategory,
      employeeBlock: p.employeeBlock,
      qualification: p.qualification ?? salaryService.EMPLOYEE_QUALIFICATIONS[2],
      tierGroup: p.tierGroup,
      doctorQualificationCode: p.doctorQualificationCode,
      qualificationNote: p.qualificationNote ?? '',
      degreeConversionYears: p.degreeConversionYears,
      priorRaiseYears: p.priorRaiseYears,
      professionalAttractionSalary: p.professionalAttractionSalary,
    });
  }

  const selectedEmployee = useMemo(
    () => employees.find((e) => e.id === selected),
    [employees, selected],
  );

  const category = profile?.salaryCategory ?? form.salaryCategory;
  const grade = profile?.computedGrade;
  const isConfigured = Boolean(profile?.salaryCategory);

  const paperSx = {
    borderRadius: 2.5,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
    bgcolor: alpha(theme.palette.background.paper, 0.96),
    boxShadow: `0 4px 24px ${alpha('#0f172a', 0.05)}`,
    overflow: 'hidden',
  };

  useEffect(() => {
    const t = setTimeout(() => setQ(qInput), 400);
    return () => clearTimeout(t);
  }, [qInput]);

  useEffect(() => {
    if (isHrOrAdmin) {
      employeeService.fetchDepartments().then(setDepartments).catch(() => {});
    }
  }, [isHrOrAdmin]);

  useEffect(() => {
    if (!isHrOrAdmin) return;
    let cancelled = false;
    (async () => {
      const p = await employeeService.fetchEmployees({
        page: 0,
        size: 1000,
        q: q.trim() || undefined,
        departmentId: filterDept === '' ? undefined : filterDept,
        status: filterStatus || undefined,
      });
      if (cancelled) return;
      setEmployees(p.content);
      if (p.content.length === 0) {
        setSelected('');
        return;
      }
      setSelected((prev) => (prev !== '' && p.content.some((e) => e.id === prev) ? prev : p.content[0].id));
    })();
    return () => {
      cancelled = true;
    };
  }, [isHrOrAdmin, q, filterDept, filterStatus]);

  useEffect(() => {
    if (isHrOrAdmin) return;
    if (user?.employeeId) setSelected(user.employeeId);
  }, [user]);

  useEffect(() => {
    if (selected === '') return;
    setErr(null);
    salaryService
      .fetchSalaryProfile(Number(selected))
      .then((p) => {
        setProfile(p);
        syncFormFromProfile(p);
      })
      .catch(() => {
        setProfile(null);
        setErr('Không tải được hồ sơ lương (kiểm tra quyền).');
      });
    pa.fetchPayrollForEmployee(Number(selected)).then(setPay).catch(() => setPay([]));
  }, [selected]);

  async function saveProfile() {
    if (selected === '' || !profile?.canEdit) return;
    setSaving(true);
    try {
      const updated = await salaryService.upsertSalaryProfile(Number(selected), form);
      setProfile(updated);
      setSaveOk(true);
      setSaveMsg('Đã lưu hồ sơ lương.');
    } catch {
      setSaveOk(false);
      setSaveMsg('Không lưu được hồ sơ lương.');
    } finally {
      setSaving(false);
    }
  }

  async function handleRecalculateAll() {
    setBulkBusy(true);
    try {
      const r = await salaryService.recalculateAllSalaries();
      setSaveOk(true);
      setSaveMsg(`Đã tính lại ${r.recalculated} hồ sơ.`);
      if (selected !== '') {
        const p = await salaryService.fetchSalaryProfile(Number(selected));
        setProfile(p);
      }
    } catch {
      setSaveOk(false);
      setSaveMsg('Không tính lại được (cần quyền ADMIN/HR).');
    } finally {
      setBulkBusy(false);
    }
  }

  async function handleExport() {
    setBulkBusy(true);
    try {
      const rows = await salaryService.exportSalaryProfiles();
      salaryService.downloadSalaryExport(rows);
      setSaveOk(true);
      setSaveMsg(`Đã xuất ${rows.length} dòng.`);
    } catch {
      setSaveOk(false);
      setSaveMsg('Không xuất được bảng lương.');
    } finally {
      setBulkBusy(false);
    }
  }

  const gradeLabel =
    grade && grade.gradeLabel !== '—'
      ? `${grade.gradeLabel}${grade.yearsRange !== '—' ? ` · ${grade.yearsRange}` : ''}`
      : isConfigured
        ? '—'
        : 'Chưa cấu hình';

  return (
    <Box>
      <PageHeader
        overline="Lương"
        title="Bảng lương & thâm niên"
        description="Bậc lương tính từ thâm niên theo thang bảng. Thâm niên = số năm công tác + thời hạn nâng lương trước (bác sỹ thêm thời gian chuyển đổi bằng cấp)."
        actions={
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            {isHrOrAdmin && (
              <>
                <Button variant="outlined" startIcon={<CloudUploadIcon />} onClick={() => setImportOpen(true)}>
                  Import Excel
                </Button>
                <Button
                  variant="outlined"
                  startIcon={<RefreshIcon />}
                  onClick={handleRecalculateAll}
                  disabled={bulkBusy}
                >
                  Tính lại tất cả
                </Button>
                <Button
                  variant="outlined"
                  startIcon={<DownloadIcon />}
                  onClick={handleExport}
                  disabled={bulkBusy}
                >
                  Xuất bảng lương
                </Button>
              </>
            )}
            <Button component={Link} to="/salary-scales" variant="outlined" endIcon={<OpenInNewIcon />}>
              Thang bảng lương
            </Button>
          </Stack>
        }
      />

      <SalaryImportDialog
        open={importOpen}
        onClose={() => setImportOpen(false)}
        onImported={() => {
          if (selected !== '') {
            salaryService
              .fetchSalaryProfile(Number(selected))
              .then((p) => {
                setProfile(p);
                syncFormFromProfile(p);
              })
              .catch(() => {});
          }
        }}
      />

      {isHrOrAdmin && (
        <EmployeeFilterPanel
          qInput={qInput}
          onQInputChange={setQInput}
          filterDept={filterDept}
          onFilterDeptChange={setFilterDept}
          filterStatus={filterStatus}
          onFilterStatusChange={setFilterStatus}
          departments={departments}
          employees={employees}
          selected={selected}
          onSelectedChange={setSelected}
        />
      )}

      {err && (
        <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }}>
          {err}
        </Alert>
      )}

      {profile && (
        <>
          {!isConfigured && profile.canEdit && (
            <Alert severity="info" sx={{ mb: 2, borderRadius: 2 }}>
              Chưa lưu hồ sơ lương. Chọn đối tượng bên dưới rồi bấm <strong>Lưu cấu hình</strong> để tính bậc.
            </Alert>
          )}

          <Grid container spacing={2} sx={{ mb: 2.5 }}>
            <Grid item xs={6} md={3}>
              <StatCard
                icon={<WorkHistoryIcon fontSize="small" />}
                label="Năm công tác"
                value={`${salaryService.formatYears(profile.yearsOfService)} năm`}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <StatCard
                icon={<TrendingUpIcon fontSize="small" />}
                label="Thâm niên tính lương"
                value={`${salaryService.formatYears(profile.seniorityYears)} năm`}
                accent={theme.palette.info.main}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <StatCard
                icon={<MilitaryTechIcon fontSize="small" />}
                label="Bậc lương"
                value={gradeLabel}
                accent={theme.palette.warning.main}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <StatCard
                icon={<PaymentsIcon fontSize="small" />}
                label="Tổng lương"
                value={salaryService.formatMoney(profile.totalSalary)}
                accent={theme.palette.success.main}
              />
            </Grid>
          </Grid>

          <Grid container spacing={2.5}>
            {profile.canEdit && (
              <Grid item xs={12} lg={7}>
                <Paper elevation={0} sx={paperSx}>
                  <Box sx={{ px: 2.5, py: 2, bgcolor: alpha(theme.palette.primary.main, 0.04) }}>
                    <Stack
                      direction={{ xs: 'column', sm: 'row' }}
                      alignItems={{ xs: 'stretch', sm: 'flex-start' }}
                      justifyContent="space-between"
                      spacing={2}
                    >
                      <Box>
                        <Typography variant="subtitle1" fontWeight={700}>
                          Cấu hình hồ sơ lương
                        </Typography>
                        {selectedEmployee && isHrOrAdmin && (
                          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                            {formatEmployeeLabel(selectedEmployee)}
                          </Typography>
                        )}
                      </Box>
                      <Button
                        variant="contained"
                        startIcon={<SaveIcon />}
                        onClick={saveProfile}
                        disabled={saving}
                        sx={{ flexShrink: 0, borderRadius: 2, alignSelf: { xs: 'stretch', sm: 'auto' } }}
                      >
                        {saving ? 'Đang lưu…' : 'Lưu cấu hình'}
                      </Button>
                    </Stack>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1.25 }}>
                      Thay đổi cấu hình cần bấm lưu để tính lại bậc lương.
                    </Typography>
                  </Box>
                  <Divider />
                  <Box sx={{ p: 2.5 }}>
                    <Grid container spacing={2}>
                      <Grid item xs={12} sm={6}>
                        <TextField
                          fullWidth
                          size="small"
                          select
                          label="Đối tượng lương"
                          value={form.salaryCategory}
                          onChange={(e) =>
                            setForm((f) => ({
                              ...f,
                              salaryCategory: e.target.value as 'DOCTOR' | 'EMPLOYEE',
                            }))
                          }
                        >
                          <MenuItem value="DOCTOR">Bác sỹ</MenuItem>
                          <MenuItem value="EMPLOYEE">Nhân viên</MenuItem>
                        </TextField>
                      </Grid>
                      {form.salaryCategory === 'EMPLOYEE' && (
                        <>
                          <Grid item xs={12} sm={6}>
                            <TextField
                              fullWidth
                              size="small"
                              select
                              label="Khối"
                              value={form.employeeBlock ?? 'DIRECT'}
                              onChange={(e) =>
                                setForm((f) => ({
                                  ...f,
                                  employeeBlock: e.target.value as 'DIRECT' | 'INDIRECT',
                                }))
                              }
                            >
                              <MenuItem value="DIRECT">Trực tiếp</MenuItem>
                              <MenuItem value="INDIRECT">Gián tiếp</MenuItem>
                            </TextField>
                          </Grid>
                          <Grid item xs={12} sm={6}>
                            <TextField
                              fullWidth
                              size="small"
                              select
                              label="Trình độ"
                              value={form.qualification ?? salaryService.EMPLOYEE_QUALIFICATIONS[2]}
                              onChange={(e) => setForm((f) => ({ ...f, qualification: e.target.value }))}
                            >
                              {salaryService.EMPLOYEE_QUALIFICATIONS.map((q) => (
                                <MenuItem key={q} value={q}>
                                  {q}
                                </MenuItem>
                              ))}
                            </TextField>
                          </Grid>
                        </>
                      )}
                      {form.salaryCategory === 'DOCTOR' && (
                        <>
                          <Grid item xs={12} sm={6}>
                            <TextField
                              fullWidth
                              size="small"
                              select
                              label="Trình độ (thang bảng)"
                              value={form.doctorQualificationCode ?? 'CCHN'}
                              onChange={(e) => setForm((f) => ({ ...f, doctorQualificationCode: e.target.value }))}
                            >
                              {salaryService.DOCTOR_QUALIFICATIONS.map((q) => (
                                <MenuItem key={q.code} value={q.code}>
                                  {q.label}
                                </MenuItem>
                              ))}
                            </TextField>
                          </Grid>
                          <Grid item xs={12} sm={6}>
                            <TextField
                              fullWidth
                              size="small"
                              label="Chuyển đổi bằng cấp (năm)"
                              type="number"
                              inputProps={{ min: 0, step: 0.1 }}
                              value={form.degreeConversionYears ?? 0}
                              onChange={(e) =>
                                setForm((f) => ({ ...f, degreeConversionYears: Number(e.target.value) }))
                              }
                            />
                          </Grid>
                        </>
                      )}
                      <Grid item xs={12} sm={6}>
                        <TextField
                          fullWidth
                          size="small"
                          label="Thời hạn nâng lương trước (năm)"
                          type="number"
                          inputProps={{ min: 0, step: 0.1 }}
                          value={form.priorRaiseYears ?? 0}
                          onChange={(e) => setForm((f) => ({ ...f, priorRaiseYears: Number(e.target.value) }))}
                        />
                      </Grid>
                      <Grid item xs={12} sm={6}>
                        <TextField
                          fullWidth
                          size="small"
                          label="Lương thu hút, đánh giá CM"
                          type="number"
                          inputProps={{ min: 0, step: 1000 }}
                          value={form.professionalAttractionSalary ?? 0}
                          onChange={(e) =>
                            setForm((f) => ({ ...f, professionalAttractionSalary: Number(e.target.value) }))
                          }
                        />
                      </Grid>
                      <Grid item xs={12}>
                        <TextField
                          fullWidth
                          size="small"
                          label="Trình độ / ghi chú"
                          value={form.qualificationNote ?? ''}
                          onChange={(e) => setForm((f) => ({ ...f, qualificationNote: e.target.value }))}
                        />
                      </Grid>
                    </Grid>
                  </Box>
                </Paper>
              </Grid>
            )}

            <Grid item xs={12} lg={profile.canEdit ? 5 : 12}>
              <Paper elevation={0} sx={{ ...paperSx, height: '100%' }}>
                <Box sx={{ px: 2.5, py: 2, bgcolor: alpha(theme.palette.success.main, 0.06) }}>
                  <Typography variant="subtitle1" fontWeight={700}>
                    Chi tiết lương
                  </Typography>
                </Box>
                <Divider />
                <Box sx={{ p: 2.5 }}>
                  <DetailLine
                    label="Số năm công tác"
                    value={`${salaryService.formatYears(profile.yearsOfService)} năm`}
                  />
                  <DetailLine
                    label="Thâm niên tính lương"
                    value={`${salaryService.formatYears(profile.seniorityYears)} năm`}
                  />
                  <DetailLine
                    label="Thời hạn nâng lương trước"
                    value={`${salaryService.formatYears(profile.priorRaiseYears)} năm`}
                  />
                  {category === 'EMPLOYEE' && profile.qualification && (
                    <DetailLine label="Trình độ" value={profile.qualification} />
                  )}
                  <DetailLine label="Bậc lương" value={gradeLabel} />
                  {category === 'EMPLOYEE' && grade && grade.coefficient > 0 && (
                    <DetailLine label="Hệ số" value={String(grade.coefficient)} />
                  )}
                  {category === 'EMPLOYEE' && grade && (grade.insuranceSalary > 0 || grade.productSalary > 0) && (
                    <>
                      <DetailLine label="Lương đóng BH (cơ bản)" value={salaryService.formatMoney(grade.insuranceSalary)} />
                      <DetailLine label="Lương đảm bảo sản phẩm" value={salaryService.formatMoney(grade.productSalary)} />
                    </>
                  )}
                  {category === 'DOCTOR' && grade && grade.scaleSalary > 0 && (
                    <DetailLine label="Lương theo thang bảng" value={salaryService.formatMoney(grade.scaleSalary)} />
                  )}
                  <DetailLine
                    label="Lương thu hút, đánh giá CM"
                    value={salaryService.formatMoney(profile.professionalAttractionSalary)}
                  />
                  <Box
                    sx={{
                      mt: 2,
                      p: 2,
                      borderRadius: 2,
                      bgcolor: alpha(theme.palette.primary.main, 0.08),
                      border: `1px solid ${alpha(theme.palette.primary.main, 0.15)}`,
                    }}
                  >
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="subtitle2" fontWeight={700}>
                        Tổng lương
                      </Typography>
                      <Typography variant="h5" fontWeight={800} color="primary.main">
                        {salaryService.formatMoney(profile.totalSalary)}
                      </Typography>
                    </Stack>
                  </Box>
                </Box>
              </Paper>
            </Grid>
          </Grid>
        </>
      )}

      <Paper elevation={0} sx={{ ...paperSx, mt: 2.5 }}>
        <Box sx={{ px: 2.5, py: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Typography variant="subtitle1" fontWeight={700}>
            Bảng lương theo kỳ
          </Typography>
          <Typography variant="caption" color="text.secondary">
            {pay.length} kỳ
          </Typography>
        </Box>
        <Divider />
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow sx={{ bgcolor: alpha(theme.palette.primary.main, 0.04) }}>
                <TableCell sx={{ fontWeight: 600 }}>Kỳ</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>Ngày công</TableCell>
                <TableCell sx={{ fontWeight: 600 }} align="right">
                  Gross
                </TableCell>
                <TableCell sx={{ fontWeight: 600 }} align="right">
                  Khấu trừ
                </TableCell>
                <TableCell sx={{ fontWeight: 600 }} align="right">
                  Thực lĩnh
                </TableCell>
                <TableCell sx={{ fontWeight: 600 }}>Chốt</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {pay.length === 0 && (
                <TableRow>
                  <TableCell colSpan={6} align="center" sx={{ py: 4, color: 'text.secondary' }}>
                    Chưa có bảng lương kỳ cho nhân viên này.
                  </TableCell>
                </TableRow>
              )}
              {pay.map((r) => (
                <TableRow key={String(r.id)} hover>
                  <TableCell>
                    {String(r.periodMonth)}/{String(r.periodYear)}
                  </TableCell>
                  <TableCell>{String(r.workingDays ?? '—')}</TableCell>
                  <TableCell align="right">{String(r.grossAmount)}</TableCell>
                  <TableCell align="right">{String(r.deductionAmount)}</TableCell>
                  <TableCell align="right" sx={{ fontWeight: 600 }}>
                    {String(r.netAmount)}
                  </TableCell>
                  <TableCell>
                    <Chip
                      size="small"
                      label={String(r.finalized) === 'true' ? 'Đã chốt' : 'Chưa chốt'}
                      color={String(r.finalized) === 'true' ? 'success' : 'default'}
                      variant="outlined"
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
        <Box sx={{ px: 2.5, py: 1.5, bgcolor: alpha(theme.palette.grey[500], 0.04) }}>
          <Typography variant="caption" color="text.secondary">
            Tra cứu thang bảng lương chung tại{' '}
            <MuiLink component={Link} to="/salary-scales" underline="hover">
              Thang bảng lương
            </MuiLink>
          </Typography>
        </Box>
      </Paper>

      <Snackbar
        open={Boolean(saveMsg)}
        autoHideDuration={4000}
        onClose={() => setSaveMsg(null)}
        anchorOrigin={{ vertical: 'top', horizontal: 'center' }}
      >
        <Alert severity={saveOk ? 'success' : 'error'} onClose={() => setSaveMsg(null)} sx={{ width: '100%' }}>
          {saveMsg}
        </Alert>
      </Snackbar>
    </Box>
  );
}
