import AddIcon from '@mui/icons-material/Add';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import EventIcon from '@mui/icons-material/Event';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import DownloadIcon from '@mui/icons-material/Download';
import RefreshIcon from '@mui/icons-material/Refresh';
import SaveIcon from '@mui/icons-material/Save';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import MilitaryTechIcon from '@mui/icons-material/MilitaryTech';
import PaymentsIcon from '@mui/icons-material/Payments';
import LockOutlinedIcon from '@mui/icons-material/LockOutlined';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Box,
  Button,
  Checkbox,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  Grid,
  IconButton,
  MenuItem,
  Paper,
  Snackbar,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { EmployeeFilterPanel, employeeStatusQuery, formatEmployeeLabel } from '../components/EmployeeFilterPanel';
import { PageHeader } from '../components/layout/PageHeader';
import { SalaryWorkforceImportDialog } from '../components/SalaryWorkforceImportDialog';
import { DatePickerField } from '../components/ui/DateTimeFields';
import { useAuth } from '../context/AuthContext';
import * as employeeService from '../services/employeeService';
import * as salaryService from '../services/salaryService';
import { formatDateVi } from '../utils/dateFormat';

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
        p: 2.25,
        height: '100%',
        borderRadius: 3,
        position: 'relative',
        overflow: 'hidden',
        border: `1px solid ${alpha(color, 0.14)}`,
        background: `linear-gradient(145deg, ${alpha(color, 0.07)} 0%, ${alpha('#fff', 0.95)} 55%)`,
        transition: 'transform 0.2s ease, box-shadow 0.2s ease',
        '&:hover': {
          transform: 'translateY(-2px)',
          boxShadow: `0 10px 28px ${alpha(color, 0.14)}`,
        },
        '&::after': {
          content: '""',
          position: 'absolute',
          top: 0,
          left: 0,
          width: 4,
          height: '100%',
          bgcolor: color,
          opacity: 0.85,
        },
      }}
    >
      <Stack direction="row" spacing={1.75} alignItems="flex-start" sx={{ pl: 0.5 }}>
        <Box
          sx={{
            width: 44,
            height: 44,
            borderRadius: 2.5,
            display: 'grid',
            placeItems: 'center',
            bgcolor: alpha(color, 0.14),
            color,
            flexShrink: 0,
          }}
        >
          {icon}
        </Box>
        <Box sx={{ minWidth: 0 }}>
          <Typography
            variant="caption"
            color="text.secondary"
            sx={{ fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase', fontSize: '0.68rem' }}
          >
            {label}
          </Typography>
          <Typography variant="h6" fontWeight={800} sx={{ mt: 0.35, lineHeight: 1.25, letterSpacing: '-0.02em' }}>
            {value}
          </Typography>
        </Box>
      </Stack>
    </Paper>
  );
}

function DetailLine({
  label,
  value,
  emphasize,
}: {
  label: string;
  value: string;
  emphasize?: boolean;
}) {
  return (
    <Stack
      direction="row"
      justifyContent="space-between"
      alignItems="center"
      spacing={2}
      sx={{
        py: 1.35,
        px: 0.25,
        borderBottom: '1px dashed',
        borderColor: alpha('#94a3b8', 0.35),
        '&:last-of-type': { borderBottom: 'none' },
      }}
    >
      <Typography variant="body2" color="text.secondary" sx={{ fontWeight: 500, fontSize: '0.84rem' }}>
        {label}
      </Typography>
      <Typography
        variant="body2"
        fontWeight={emphasize ? 800 : 700}
        color={emphasize ? 'primary.main' : 'text.primary'}
        sx={{ textAlign: 'right', fontSize: emphasize ? '0.95rem' : '0.875rem' }}
      >
        {value}
      </Typography>
    </Stack>
  );
}

function FormSectionLabel({ children }: { children: React.ReactNode }) {
  const theme = useTheme();
  return (
    <Typography
      variant="overline"
      sx={{
        display: 'block',
        mb: 1.5,
        mt: 0.5,
        fontWeight: 800,
        letterSpacing: '0.1em',
        color: theme.palette.primary.main,
        fontSize: '0.7rem',
      }}
    >
      {children}
    </Typography>
  );
}

export default function SalaryPage() {
  const theme = useTheme();
  const { user } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const employeeIdFromUrl = searchParams.get('employeeId');
  const [employees, setEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [selected, setSelected] = useState<number | ''>('');
  const [qInput, setQInput] = useState('');
  const [q, setQ] = useState('');
  const [filterDept, setFilterDept] = useState<number | ''>('');
  const [filterStatus, setFilterStatus] = useState('WORKING');
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [profile, setProfile] = useState<salaryService.EmployeeSalaryProfile | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);
  const [saveOk, setSaveOk] = useState(true);
  const [saving, setSaving] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [salaryUnlocked, setSalaryUnlocked] = useState(() => Boolean(salaryService.getSalaryAccessToken()));
  const [unlockPassword, setUnlockPassword] = useState('');
  const [unlockBusy, setUnlockBusy] = useState(false);
  const [unlockError, setUnlockError] = useState<string | null>(null);

  const selfOnly = location.pathname === '/salary/me';
  const isAdmin = user?.role === 'ADMIN' || user?.role === 'HR';
  const canBrowseSalaries = isAdmin && !selfOnly && salaryUnlocked;
  const shouldUseOwnSalary = selfOnly || !isAdmin;
  const canViewOwnSalary = user?.canViewSalary !== false;
  const salaryBlocked = !canBrowseSalaries && !canViewOwnSalary;

  async function handleUnlock() {
    if (!unlockPassword) return;
    setUnlockBusy(true);
    setUnlockError(null);
    try {
      await salaryService.unlockSalaryAccess(unlockPassword);
      setSalaryUnlocked(true);
      setUnlockPassword('');
    } catch {
      salaryService.clearSalaryAccess();
      setUnlockPassword('');
      setUnlockError('Sai mật khẩu, vui lòng nhập lại.');
    } finally {
      setUnlockBusy(false);
    }
  }

  const [form, setForm] = useState<salaryService.EmployeeSalaryProfileRequest>({
    salaryCategory: 'EMPLOYEE',
    employeeBlock: 'DIRECT',
    qualification: salaryService.EMPLOYEE_QUALIFICATIONS[2],
    tierGroup: 3,
    doctorQualificationCode: 'CCHN',
    qualificationNote: '',
    degreeConversionYears: 0,
    priorRaiseYears: 0,
    earlyRaiseConversions: [],
    salaryScaleStartDate: null,
    baseSeniorityYears: null,
    seniorityAsOfDate: salaryService.DEFAULT_SENIORITY_AS_OF,
  });
  const [earlyRaiseDate, setEarlyRaiseDate] = useState('');
  const [earlyRaiseYears, setEarlyRaiseYears] = useState('0');

  function syncFormFromProfile(p: salaryService.EmployeeSalaryProfile) {
    if (!p.salaryCategory) return;
    const conversions = (p.earlyRaiseConversions ?? [])
      .map((e) => ({
        raiseDate: normalizeRaiseDate(e.raiseDate),
        years: Number(e.years) || 0,
      }))
      .filter((e) => e.raiseDate);
    const total =
      conversions.length > 0
        ? conversions.reduce((s, e) => s + e.years, 0)
        : Number(p.priorRaiseYears) || 0;
    setForm({
      salaryCategory: p.salaryCategory,
      employeeBlock: p.employeeBlock,
      qualification: p.qualification ?? salaryService.EMPLOYEE_QUALIFICATIONS[2],
      tierGroup: p.tierGroup,
      doctorQualificationCode: p.doctorQualificationCode,
      qualificationNote: p.qualificationNote ?? '',
      degreeConversionYears: p.degreeConversionYears,
      priorRaiseYears: total,
      earlyRaiseConversions: conversions,
      salaryScaleStartDate: p.salaryScaleStartDate ?? null,
      baseSeniorityYears: p.baseSeniorityYears ?? null,
      seniorityAsOfDate: p.seniorityAsOfDate ?? salaryService.DEFAULT_SENIORITY_AS_OF,
      ldg: Boolean(p.ldg),
    });
    setEarlyRaiseDate('');
    setEarlyRaiseYears('0');
  }

  function normalizeRaiseDate(raw?: string | null): string {
    if (!raw) return '';
    if (typeof raw === 'string') {
      const m = raw.match(/^(\d{4}-\d{2}-\d{2})/);
      return m ? m[1] : raw.slice(0, 10);
    }
    return '';
  }

  function formatScaleStart(iso?: string | null): string {
    return formatDateVi(iso);
  }

  function salaryObjectLabel(p: salaryService.EmployeeSalaryProfile): string {
    if (p.salaryCategory === 'DOCTOR') return 'Bác sĩ';
    if (p.salaryCategory === 'EMPLOYEE') {
      if (p.employeeBlock === 'INDIRECT') return 'Gián tiếp';
      if (p.employeeBlock === 'DIRECT') return 'Trực tiếp';
      return 'Nhân viên';
    }
    return '—';
  }

  function addEarlyRaiseEntry() {
    if (!earlyRaiseDate) return;
    const years = Number(earlyRaiseYears);
    if (Number.isNaN(years) || years < 0) return;
    setForm((f) => {
      const next = [
        ...(f.earlyRaiseConversions ?? []),
        { raiseDate: earlyRaiseDate, years },
      ].sort((a, b) => String(a.raiseDate).localeCompare(String(b.raiseDate)));
      const total = next.reduce((s, e) => s + (Number(e.years) || 0), 0);
      return { ...f, earlyRaiseConversions: next, priorRaiseYears: total };
    });
    setEarlyRaiseDate('');
    setEarlyRaiseYears('0');
  }

  function removeEarlyRaiseEntry(index: number) {
    setForm((f) => {
      const next = (f.earlyRaiseConversions ?? []).filter((_, i) => i !== index);
      const total = next.reduce((s, e) => s + (Number(e.years) || 0), 0);
      return { ...f, earlyRaiseConversions: next, priorRaiseYears: total };
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
    if (canBrowseSalaries) {
      employeeService.fetchDepartments().then(setDepartments).catch(() => {});
    }
  }, [canBrowseSalaries]);

  useEffect(() => {
    if (!canBrowseSalaries) return;
    let cancelled = false;
    (async () => {
      const p = await employeeService.fetchEmployees({
        page: 0,
        size: 1000,
        q: q.trim() || undefined,
        departmentId: filterDept === '' ? undefined : filterDept,
        ...employeeStatusQuery(filterStatus),
      });
      if (cancelled) return;
      setEmployees(p.content);
      if (p.content.length === 0) {
        setSelected('');
        return;
      }
      const urlId = employeeIdFromUrl ? Number(employeeIdFromUrl) : NaN;
      if (!Number.isNaN(urlId) && urlId > 0) {
        setSelected(urlId);
        return;
      }
      setSelected(p.content[0].id);
    })();
    return () => {
      cancelled = true;
    };
  }, [canBrowseSalaries, q, filterDept, filterStatus, employeeIdFromUrl]);

  useEffect(() => {
    if (!shouldUseOwnSalary) {
      setSelected('');
      setProfile(null);
      return;
    }
    if (user?.employeeId) setSelected(user.employeeId);
  }, [user?.employeeId, shouldUseOwnSalary]);

  useEffect(() => {
    if (!shouldUseOwnSalary) return;
    const urlId = employeeIdFromUrl ? Number(employeeIdFromUrl) : NaN;
    if (!Number.isNaN(urlId) && urlId > 0 && urlId === user?.employeeId) {
      setSelected(urlId);
    }
  }, [employeeIdFromUrl, shouldUseOwnSalary, user?.employeeId]);

  useEffect(() => {
    if (selected === '' || salaryBlocked) return;
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
  }, [selected, salaryBlocked]);

  async function saveProfile() {
    if (selected === '' || !profile?.canEdit) return;
    const hasBase = salaryService.hasSeniorityMilestone(
      form.baseSeniorityYears,
      form.salaryScaleStartDate,
    );
    if (!form.ldg && !form.salaryScaleStartDate && !hasBase) {
      setSaveOk(false);
      setSaveMsg('Nhập thâm niên mốc 30/06 hoặc chọn ngày bắt đầu tính thang bảng lương.');
      return;
    }
    setSaving(true);
    try {
      const payload: salaryService.EmployeeSalaryProfileRequest = {
        ...form,
        earlyRaiseConversions: (form.earlyRaiseConversions ?? []).map((e) => ({
          raiseDate: normalizeRaiseDate(e.raiseDate),
          years: Number(e.years) || 0,
        })),
        priorRaiseYears: (form.earlyRaiseConversions ?? []).reduce(
          (s, e) => s + (Number(e.years) || 0),
          0,
        ),
        baseSeniorityYears: form.ldg || !hasBase ? null : Number(form.baseSeniorityYears),
        seniorityAsOfDate:
          form.ldg || !hasBase
            ? null
            : form.seniorityAsOfDate || salaryService.DEFAULT_SENIORITY_AS_OF,
      };
      const updated = await salaryService.upsertSalaryProfile(Number(selected), payload);
      setProfile(updated);
      syncFormFromProfile(updated);
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

  const gradeLabel = (() => {
    if (!grade || grade.gradeLabel === '—') {
      return isConfigured ? '—' : 'Chưa cấu hình';
    }
    const band = grade.yearsRange && grade.yearsRange !== '—' ? grade.yearsRange : '';
    // Bác sỹ: gradeLabel = yearsRange = «0-2 năm» → không ghép trùng.
    if (!band || band === grade.gradeLabel) {
      return grade.gradeLabel;
    }
    return `${grade.gradeLabel} · ${band}`;
  })();

  return (
    <Box>
      <PageHeader
        overline="Lương"
        title={selfOnly ? 'Thông tin lương của tôi' : 'Thông tin lương'}
        description={
          selfOnly
            ? 'Thông tin lương, thâm niên và bậc lương cá nhân.'
            : 'Thâm niên: mốc 30/06 + (hôm nay − 30/06)/365; không có mốc thì tính từ ngày bắt đầu thang bảng.'
        }
        actions={
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            {canBrowseSalaries && (
              <>
                <Button variant="outlined" startIcon={<CloudUploadIcon />} onClick={() => setImportOpen(true)}>
                  Import bảng lương
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
            {!salaryBlocked && (
              <Button
                component={Link}
                to={selfOnly ? '/salary-scales/me' : '/salary-scales'}
                variant="outlined"
                endIcon={<OpenInNewIcon />}
              >
                {selfOnly ? 'Thang bảng lương của tôi' : 'Thang bảng lương'}
              </Button>
            )}
          </Stack>
        }
      />

      <Dialog
        open={isAdmin && !selfOnly && !salaryUnlocked}
        onClose={() => !unlockBusy && navigate('/')}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <LockOutlinedIcon color="primary" />
          Mở khóa phần lương
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Vì lý do bảo mật, ADMIN/HCNS 1 cần nhập mật khẩu riêng để xem và chỉnh sửa lương của toàn bộ nhân viên.
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
          <Button onClick={() => navigate('/')} disabled={unlockBusy}>
            Hủy
          </Button>
          <Button
            variant="contained"
            onClick={() => void handleUnlock()}
            disabled={unlockBusy || !unlockPassword}
          >
            {unlockBusy ? 'Đang kiểm tra…' : 'Mở khóa'}
          </Button>
        </DialogActions>
      </Dialog>

      {salaryBlocked && (
        <Alert severity="info" sx={{ mb: 2, borderRadius: 2 }}>
          Bạn đang trong thời gian thử việc/thực tập và chưa có <strong>ngày vào làm chính thức</strong> — hiện chỉ
          xem được phần <strong>Công</strong>. Bảng lương sẽ mở sau khi HCNS cập nhật ngày chính thức hoặc chuyển
          trạng thái nhân viên.
        </Alert>
      )}

      <SalaryWorkforceImportDialog
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

      {canBrowseSalaries && (
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

      {err && !salaryBlocked && (
        <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }}>
          {err}
        </Alert>
      )}

      {profile && !salaryBlocked && (
        <>
          {!isConfigured && profile.canEdit && (
            <Alert severity="info" sx={{ mb: 2, borderRadius: 2 }}>
              Chưa lưu hồ sơ lương. Chọn đối tượng bên dưới rồi bấm <strong>Lưu cấu hình</strong> để tính bậc.
            </Alert>
          )}

          <Grid container spacing={2} sx={{ mb: 2.5 }}>
            <Grid item xs={6} md={3}>
              <StatCard
                icon={<EventIcon fontSize="small" />}
                label="Bắt đầu thang bảng lương"
                value={formatScaleStart(profile.salaryScaleStartDate)}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <StatCard
                icon={<TrendingUpIcon fontSize="small" />}
                label={
                  profile.baseSeniorityYears != null && profile.seniorityAsOfDate
                    ? `Thâm niên (mốc ${formatScaleStart(profile.seniorityAsOfDate)})`
                    : 'Thâm niên tính lương'
                }
                value={
                  profile.ldg
                    ? 'LĐG'
                    : `${salaryService.formatYears(profile.seniorityYears)} năm`
                }
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
                <Paper
                  elevation={0}
                  sx={{
                    ...paperSx,
                    borderRadius: 3,
                    boxShadow: `0 8px 32px ${alpha('#0f172a', 0.06)}`,
                  }}
                >
                  <Box
                    sx={{
                      px: 2.75,
                      py: 2.25,
                      background: `linear-gradient(120deg, ${alpha(theme.palette.primary.main, 0.1)} 0%, ${alpha(theme.palette.primary.light, 0.04)} 100%)`,
                      borderBottom: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
                    }}
                  >
                    <Stack
                      direction={{ xs: 'column', sm: 'row' }}
                      alignItems={{ xs: 'stretch', sm: 'center' }}
                      justifyContent="space-between"
                      spacing={2}
                    >
                      <Box>
                        <Typography variant="h6" fontWeight={800} sx={{ letterSpacing: '-0.02em' }}>
                          Cấu hình hồ sơ lương
                        </Typography>
                        {selectedEmployee && canBrowseSalaries && (
                          <Chip
                            size="small"
                            label={formatEmployeeLabel(selectedEmployee)}
                            sx={{
                              mt: 1,
                              fontWeight: 600,
                              bgcolor: alpha(theme.palette.primary.main, 0.1),
                              color: theme.palette.primary.dark,
                            }}
                          />
                        )}
                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
                          Chỉnh xong bấm lưu để tính lại bậc và tổng lương.
                        </Typography>
                      </Box>
                      <Button
                        variant="contained"
                        startIcon={<SaveIcon />}
                        onClick={saveProfile}
                        disabled={saving}
                        sx={{
                          flexShrink: 0,
                          borderRadius: 2.5,
                          px: 2.5,
                          py: 1.1,
                          fontWeight: 700,
                          boxShadow: `0 6px 18px ${alpha(theme.palette.primary.main, 0.35)}`,
                          alignSelf: { xs: 'stretch', sm: 'center' },
                        }}
                      >
                        {saving ? 'Đang lưu…' : 'Lưu cấu hình'}
                      </Button>
                    </Stack>
                  </Box>

                  <Box sx={{ p: 2.75 }}>
                    <FormSectionLabel>Thông tin cơ bản</FormSectionLabel>
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
                        <DatePickerField
                          fullWidth
                          size="small"
                          label="Bắt đầu tính thang bảng lương"
                          value={form.salaryScaleStartDate?.slice(0, 10) ?? ''}
                          onChange={(v) => setForm((f) => ({ ...f, salaryScaleStartDate: v || null }))}
                          helperText="Dùng khi không có mốc thâm niên 30/06"
                        />
                      </Grid>
                      <Grid item xs={12} sm={6}>
                        <TextField
                          fullWidth
                          size="small"
                          label="Thâm niên mốc 30/06 (năm)"
                          type="number"
                          inputProps={{ min: 0, step: 0.000001 }}
                          value={form.baseSeniorityYears ?? ''}
                          onChange={(e) =>
                            setForm((f) => ({
                              ...f,
                              baseSeniorityYears:
                                e.target.value === '' ? null : Number(e.target.value),
                            }))
                          }
                          helperText="Để trống (không nhập 0) nếu tính từ ngày bắt đầu thang"
                          disabled={Boolean(form.ldg)}
                        />
                      </Grid>
                      <Grid item xs={12} sm={6}>
                        <DatePickerField
                          fullWidth
                          size="small"
                          label="Ngày chốt mốc thâm niên"
                          value={form.seniorityAsOfDate?.slice(0, 10) ?? ''}
                          onChange={(v) => setForm((f) => ({ ...f, seniorityAsOfDate: v || null }))}
                          helperText="Mặc định 30/06/2026"
                          disabled={
                            Boolean(form.ldg) ||
                            !salaryService.hasSeniorityMilestone(
                              form.baseSeniorityYears,
                              form.salaryScaleStartDate,
                            )
                          }
                        />
                      </Grid>
                      <Grid item xs={12} sm={6}>
                        <TextField
                          fullWidth
                          size="small"
                          label="Thâm niên hiện tại (xem trước)"
                          value={salaryService.formatLiveSeniorityPreview({
                            baseSeniorityYears: form.baseSeniorityYears,
                            seniorityAsOfDate: form.seniorityAsOfDate,
                            salaryScaleStartDate: form.salaryScaleStartDate,
                            priorRaiseYears: form.priorRaiseYears,
                            degreeConversionYears: form.degreeConversionYears,
                            ldg: Boolean(form.ldg),
                          })}
                          helperText="Có mốc: mốc + (hôm nay − 30/06)/365 · Không mốc: từ ngày bắt đầu thang"
                          InputProps={{ readOnly: true }}
                        />
                      </Grid>
                      <Grid item xs={12}>
                        <FormControlLabel
                          control={
                            <Checkbox
                              checked={Boolean(form.ldg)}
                              onChange={(e) => setForm((f) => ({ ...f, ldg: e.target.checked }))}
                            />
                          }
                          label="LĐG — bậc cố định, không nhảy theo thâm niên"
                        />
                      </Grid>
                    </Grid>

                    <Box
                      sx={{
                        mt: 3,
                        p: 2,
                        borderRadius: 2.5,
                        border: `1px solid ${alpha(theme.palette.info.main, 0.2)}`,
                        bgcolor: alpha(theme.palette.info.main, 0.04),
                      }}
                    >
                      <FormSectionLabel>Quy đổi nâng lương sớm</FormSectionLabel>
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.75, mt: -0.5 }}>
                        Chọn ngày → nhập hệ số năm → Thêm. Tổng cộng vào thâm niên tính lương.
                      </Typography>
                      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ sm: 'flex-start' }}>
                        <DatePickerField
                          fullWidth
                          size="small"
                          label="Ngày nâng lương sớm"
                          value={earlyRaiseDate}
                          onChange={setEarlyRaiseDate}
                        />
                        <TextField
                          size="small"
                          label="Hệ số năm"
                          type="number"
                          inputProps={{ min: 0, step: 0.1 }}
                          value={earlyRaiseYears}
                          onChange={(e) => setEarlyRaiseYears(e.target.value)}
                          sx={{ minWidth: { sm: 130 }, width: { xs: '100%', sm: 'auto' } }}
                        />
                        <Button
                          variant="contained"
                          color="info"
                          startIcon={<AddIcon />}
                          onClick={addEarlyRaiseEntry}
                          disabled={!earlyRaiseDate}
                          sx={{ flexShrink: 0, height: 40, borderRadius: 2, fontWeight: 700, boxShadow: 'none' }}
                        >
                          Thêm
                        </Button>
                      </Stack>
                      {(form.earlyRaiseConversions?.length ?? 0) > 0 ? (
                        <Stack spacing={1} sx={{ mt: 2 }}>
                          {(form.earlyRaiseConversions ?? []).map((e, idx) => (
                            <Stack
                              key={`${e.raiseDate}-${idx}`}
                              direction="row"
                              alignItems="center"
                              justifyContent="space-between"
                              sx={{
                                py: 1,
                                px: 1.5,
                                borderRadius: 2,
                                bgcolor: 'background.paper',
                                border: `1px solid ${theme.palette.divider}`,
                              }}
                            >
                              <Stack direction="row" spacing={1} alignItems="center">
                                <Chip
                                  size="small"
                                  icon={<EventIcon sx={{ fontSize: '0.9rem !important' }} />}
                                  label={formatScaleStart(e.raiseDate)}
                                  variant="outlined"
                                  sx={{ fontWeight: 600 }}
                                />
                                <Typography variant="body2" fontWeight={700} color="info.dark">
                                  +{salaryService.formatYears(e.years)} năm
                                </Typography>
                              </Stack>
                              <IconButton
                                size="small"
                                onClick={() => removeEarlyRaiseEntry(idx)}
                                sx={{
                                  color: 'error.main',
                                  bgcolor: alpha(theme.palette.error.main, 0.06),
                                  '&:hover': { bgcolor: alpha(theme.palette.error.main, 0.12) },
                                }}
                              >
                                <DeleteOutlineIcon fontSize="small" />
                              </IconButton>
                            </Stack>
                          ))}
                          <Box
                            sx={{
                              mt: 0.5,
                              px: 1.5,
                              py: 1,
                              borderRadius: 2,
                              bgcolor: alpha(theme.palette.info.main, 0.1),
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                            }}
                          >
                            <Typography variant="caption" fontWeight={700} color="text.secondary">
                              Tổng quy đổi
                            </Typography>
                            <Typography variant="body2" fontWeight={800} color="info.dark">
                              {salaryService.formatYears(form.priorRaiseYears ?? 0)} năm
                            </Typography>
                          </Box>
                        </Stack>
                      ) : (
                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1.5 }}>
                          Chưa có lần quy đổi nào.
                        </Typography>
                      )}
                    </Box>

                    <Box sx={{ mt: 3 }}>
                      <FormSectionLabel>Ghi chú</FormSectionLabel>
                      <TextField
                        fullWidth
                        size="small"
                        label="Trình độ / ghi chú thêm"
                        value={form.qualificationNote ?? ''}
                        onChange={(e) => setForm((f) => ({ ...f, qualificationNote: e.target.value }))}
                        multiline
                        minRows={2}
                      />
                    </Box>
                  </Box>
                </Paper>
              </Grid>
            )}

            <Grid item xs={12} lg={profile.canEdit ? 5 : 12}>
              <Paper
                elevation={0}
                sx={{
                  ...paperSx,
                  height: '100%',
                  borderRadius: 3,
                  display: 'flex',
                  flexDirection: 'column',
                  boxShadow: `0 8px 32px ${alpha('#0f172a', 0.06)}`,
                  overflow: 'hidden',
                }}
              >
                <Box
                  sx={{
                    px: 2.75,
                    py: 2.25,
                    background: `linear-gradient(120deg, ${alpha(theme.palette.success.main, 0.12)} 0%, ${alpha(theme.palette.primary.main, 0.06)} 100%)`,
                    borderBottom: `1px solid ${alpha(theme.palette.success.main, 0.15)}`,
                  }}
                >
                  <Typography variant="h6" fontWeight={800} sx={{ letterSpacing: '-0.02em' }}>
                    Chi tiết lương
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    Kết quả tính theo cấu hình hiện tại
                  </Typography>
                </Box>
                <Box sx={{ p: 2.5, flex: 1 }}>
                  <Box
                    sx={{
                      mb: 2,
                      px: 1.75,
                      py: 1.25,
                      borderRadius: 2,
                      bgcolor: alpha(theme.palette.primary.main, 0.06),
                      border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
                    }}
                  >
                    <Typography variant="caption" color="text.secondary" fontWeight={700}>
                      Đối tượng lương
                    </Typography>
                    <Typography variant="subtitle1" fontWeight={800} color="primary.dark">
                      {salaryObjectLabel(profile)}
                    </Typography>
                  </Box>

                  <DetailLine
                    label="Bắt đầu thang bảng lương"
                    value={formatScaleStart(profile.salaryScaleStartDate)}
                  />
                  <DetailLine
                    label="Thâm niên tính lương"
                    value={
                      profile.ldg ? 'LĐG' : `${salaryService.formatYears(profile.seniorityYears)} năm`
                    }
                    emphasize
                  />
                  <DetailLine
                    label="Quy đổi nâng lương sớm"
                    value={`${salaryService.formatYears(profile.priorRaiseYears)} năm`}
                  />
                  {(profile.earlyRaiseConversions?.length ?? 0) > 0 && (
                    <Accordion
                      disableGutters
                      elevation={0}
                      sx={{
                        my: 1.25,
                        border: `1px solid ${alpha(theme.palette.info.main, 0.25)}`,
                        borderRadius: '12px !important',
                        bgcolor: alpha(theme.palette.info.main, 0.03),
                        '&:before': { display: 'none' },
                        overflow: 'hidden',
                      }}
                    >
                      <AccordionSummary expandIcon={<ExpandMoreIcon />} sx={{ minHeight: 44, px: 1.5 }}>
                        <Typography variant="body2" fontWeight={700} color="info.dark">
                          Chi tiết {profile.earlyRaiseConversions!.length} lần nâng sớm
                        </Typography>
                      </AccordionSummary>
                      <AccordionDetails sx={{ pt: 0, px: 1.5, pb: 1.5 }}>
                        {profile.earlyRaiseConversions!.map((e, idx) => (
                          <Stack
                            key={`${e.raiseDate ?? 'x'}-${idx}`}
                            direction="row"
                            justifyContent="space-between"
                            sx={{
                              py: 0.85,
                              borderBottom:
                                idx < profile.earlyRaiseConversions!.length - 1
                                  ? `1px dashed ${alpha('#94a3b8', 0.4)}`
                                  : 0,
                            }}
                          >
                            <Typography variant="body2" color="text.secondary">
                              {e.raiseDate ? formatScaleStart(e.raiseDate) : 'Không có ngày'}
                            </Typography>
                            <Typography variant="body2" fontWeight={800}>
                              +{salaryService.formatYears(e.years)} năm
                            </Typography>
                          </Stack>
                        ))}
                      </AccordionDetails>
                    </Accordion>
                  )}
                  {category === 'EMPLOYEE' && profile.qualification && (
                    <DetailLine label="Trình độ" value={profile.qualification} />
                  )}
                  <DetailLine label="Bậc lương" value={gradeLabel} emphasize />
                  {category === 'EMPLOYEE' && grade && grade.coefficient > 0 && (
                    <DetailLine label="Hệ số" value={String(grade.coefficient)} />
                  )}
                  {category === 'EMPLOYEE' && grade && (grade.insuranceSalary > 0 || grade.productSalary > 0) && (
                    <>
                      <DetailLine
                        label="Lương đóng BH (cơ bản)"
                        value={salaryService.formatMoney(grade.insuranceSalary)}
                      />
                      <DetailLine
                        label="Lương đảm bảo sản phẩm"
                        value={salaryService.formatMoney(grade.productSalary)}
                      />
                    </>
                  )}
                  {category === 'DOCTOR' && grade && (
                    <>
                      {(grade.insuranceSalary > 0 || grade.productSalary > 0) && (
                        <>
                          <DetailLine
                            label="Lương cơ bản"
                            value={salaryService.formatMoney(grade.insuranceSalary)}
                          />
                          <DetailLine
                            label="Lương đảm bảo sản phẩm"
                            value={salaryService.formatMoney(grade.productSalary)}
                          />
                        </>
                      )}
                      {grade.scaleSalary > 0 && (
                        <DetailLine
                          label="Tổng theo thang bảng BS"
                          value={salaryService.formatMoney(grade.scaleSalary)}
                        />
                      )}
                    </>
                  )}
                </Box>
                <Box
                  sx={{
                    mx: 2,
                    mb: 2,
                    p: 2.25,
                    borderRadius: 2.5,
                    background: `linear-gradient(135deg, ${theme.palette.primary.main} 0%, ${theme.palette.primary.dark} 100%)`,
                    color: '#fff',
                    boxShadow: `0 10px 28px ${alpha(theme.palette.primary.main, 0.35)}`,
                  }}
                >
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Box>
                      <Typography variant="caption" sx={{ opacity: 0.85, fontWeight: 700, letterSpacing: '0.06em' }}>
                        TỔNG LƯƠNG
                      </Typography>
                      <Typography variant="h5" fontWeight={900} sx={{ letterSpacing: '-0.03em', mt: 0.25 }}>
                        {salaryService.formatMoney(profile.totalSalary)}
                      </Typography>
                    </Box>
                    <PaymentsIcon sx={{ fontSize: 36, opacity: 0.35 }} />
                  </Stack>
                </Box>
              </Paper>
            </Grid>
          </Grid>

        </>
      )}

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
