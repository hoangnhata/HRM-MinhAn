import PaymentsIcon from '@mui/icons-material/Payments';
import LockOutlinedIcon from '@mui/icons-material/LockOutlined';
import {
  Alert,
  Box,
  Button,
  Checkbox,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import * as departmentService from '../services/departmentService';
import * as employeeService from '../services/employeeService';
import * as salaryService from '../services/salaryService';
import { extractApiErrorMessage } from '../services/approvalSignatureService';

const ACCENT = '#0f766e';

function toInputDate(s: string | undefined | null): string {
  if (!s) return '';
  return String(s).slice(0, 10);
}

function optNum(s: string): number | undefined {
  const n = Number(String(s).replace(/\s/g, '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : undefined;
}

type EmploymentStatus = 'ACTIVE' | 'PROBATION' | 'INTERN' | 'ON_LEAVE' | 'TERMINATED';

type WfState = {
  attendanceCode: string;
  workUnitDetail: string;
  payrollDisplayName: string;
  bankAccount: string;
  bankName: string;
  insuranceParticipation: string;
  socialInsuranceBook: string;
  idCardIssueDate: string;
  probationStartDate: string;
  officialStartDate: string;
  contractNumber: string;
  contractSignDate: string;
  contractTerm: string;
  specialty: string;
  degree: string;
  professionalDiploma: string;
  practiceScope: string;
  practiceCertNumber: string;
  practiceCertDateRaw: string;
  otherTrainingCertificates: string;
  cki: string;
  ethnicity: string;
  placeOfOrigin: string;
  maritalStatus: string;
  bloodType: string;
  emergencyContact: string;
  emergencyPhone: string;
  dependentsInfo: string;
  workforceNotes: string;
};

const EMPTY_WF: WfState = {
  attendanceCode: '',
  workUnitDetail: '',
  payrollDisplayName: '',
  bankAccount: '',
  bankName: '',
  insuranceParticipation: '',
  socialInsuranceBook: '',
  idCardIssueDate: '',
  probationStartDate: '',
  officialStartDate: '',
  contractNumber: '',
  contractSignDate: '',
  contractTerm: '',
  specialty: '',
  degree: '',
  professionalDiploma: '',
  practiceScope: '',
  practiceCertNumber: '',
  practiceCertDateRaw: '',
  otherTrainingCertificates: '',
  cki: '',
  ethnicity: '',
  placeOfOrigin: '',
  maritalStatus: '',
  bloodType: '',
  emergencyContact: '',
  emergencyPhone: '',
  dependentsInfo: '',
  workforceNotes: '',
};

type SalaryFormState = {
  enabled: boolean;
  salaryCategory: 'DOCTOR' | 'EMPLOYEE';
  employeeBlock: 'DIRECT' | 'INDIRECT';
  qualification: string;
  doctorQualificationCode: string;
  qualificationNote: string;
  degreeConversionYears: string;
  priorRaiseYears: string;
  salaryScaleStartDate: string;
  /** Thâm niên tại mốc (vd. 30/06/2026) — để trống thì tính từ ngày bắt đầu thang. */
  baseSeniorityYears: string;
  seniorityAsOfDate: string;
  ldg: boolean;
  importedInsuranceSalary: string;
  importedProductSalary: string;
};

const EMPTY_SALARY: SalaryFormState = {
  enabled: false,
  salaryCategory: 'EMPLOYEE',
  employeeBlock: 'INDIRECT',
  qualification: salaryService.EMPLOYEE_QUALIFICATIONS[0],
  doctorQualificationCode: 'CCHN',
  qualificationNote: '',
  degreeConversionYears: '0',
  priorRaiseYears: '0',
  salaryScaleStartDate: '',
  baseSeniorityYears: '',
  seniorityAsOfDate: salaryService.DEFAULT_SENIORITY_AS_OF,
  ldg: false,
  importedInsuranceSalary: '',
  importedProductSalary: '',
};

function wfFromProfile(profile: Record<string, unknown> | null | undefined): WfState {
  const g = (k: keyof WfState) => {
    const v = profile?.[k];
    return v == null ? '' : String(v);
  };
  return {
    attendanceCode: g('attendanceCode'),
    workUnitDetail: g('workUnitDetail'),
    payrollDisplayName: g('payrollDisplayName'),
    bankAccount: g('bankAccount'),
    bankName: g('bankName'),
    insuranceParticipation: g('insuranceParticipation'),
    socialInsuranceBook: g('socialInsuranceBook'),
    idCardIssueDate: toInputDate(g('idCardIssueDate')),
    probationStartDate: toInputDate(g('probationStartDate')),
    officialStartDate: toInputDate(g('officialStartDate')),
    contractNumber: g('contractNumber'),
    contractSignDate: toInputDate(g('contractSignDate')),
    contractTerm: g('contractTerm'),
    specialty: g('specialty'),
    degree: g('degree'),
    professionalDiploma: g('professionalDiploma'),
    practiceScope: g('practiceScope'),
    practiceCertNumber: g('practiceCertNumber'),
    practiceCertDateRaw: g('practiceCertDateRaw'),
    otherTrainingCertificates: g('otherTrainingCertificates'),
    cki: g('cki'),
    ethnicity: g('ethnicity'),
    placeOfOrigin: g('placeOfOrigin'),
    maritalStatus: g('maritalStatus'),
    bloodType: g('bloodType'),
    emergencyContact: g('emergencyContact'),
    emergencyPhone: g('emergencyPhone'),
    dependentsInfo: g('dependentsInfo'),
    workforceNotes: g('workforceNotes'),
  };
}

function toWorkforcePayload(wf: WfState, fullName: string): employeeService.WorkforceDetailsPayload {
  const opt = (s: string) => (s.trim() ? s.trim() : undefined);
  return {
    attendanceCode: opt(wf.attendanceCode),
    workUnitDetail: opt(wf.workUnitDetail),
    payrollDisplayName: opt(wf.payrollDisplayName) || opt(fullName),
    bankAccount: opt(wf.bankAccount),
    bankName: opt(wf.bankName),
    insuranceParticipation: opt(wf.insuranceParticipation),
    socialInsuranceBook: opt(wf.socialInsuranceBook),
    idCardIssueDate: opt(wf.idCardIssueDate),
    probationStartDate: opt(wf.probationStartDate),
    officialStartDate: opt(wf.officialStartDate),
    contractNumber: opt(wf.contractNumber),
    contractSignDate: opt(wf.contractSignDate),
    contractTerm: opt(wf.contractTerm),
    specialty: opt(wf.specialty),
    degree: opt(wf.degree),
    professionalDiploma: opt(wf.professionalDiploma),
    practiceScope: opt(wf.practiceScope),
    practiceCertNumber: opt(wf.practiceCertNumber),
    practiceCertDateRaw: opt(wf.practiceCertDateRaw),
    otherTrainingCertificates: opt(wf.otherTrainingCertificates),
    cki: opt(wf.cki),
    ethnicity: opt(wf.ethnicity),
    placeOfOrigin: opt(wf.placeOfOrigin),
    maritalStatus: opt(wf.maritalStatus),
    bloodType: opt(wf.bloodType),
    emergencyContact: opt(wf.emergencyContact),
    emergencyPhone: opt(wf.emergencyPhone),
    dependentsInfo: opt(wf.dependentsInfo),
    workforceNotes: opt(wf.workforceNotes),
  };
}

function salaryFromProfile(p: salaryService.EmployeeSalaryProfile): SalaryFormState {
  return {
    enabled: Boolean(p.salaryCategory),
    salaryCategory: p.salaryCategory === 'DOCTOR' ? 'DOCTOR' : 'EMPLOYEE',
    employeeBlock: p.employeeBlock === 'DIRECT' ? 'DIRECT' : 'INDIRECT',
    qualification: p.qualification || salaryService.EMPLOYEE_QUALIFICATIONS[0],
    doctorQualificationCode: p.doctorQualificationCode || 'CCHN',
    qualificationNote: p.qualificationNote || '',
    degreeConversionYears: String(p.degreeConversionYears ?? 0),
    priorRaiseYears: String(p.priorRaiseYears ?? 0),
    salaryScaleStartDate: toInputDate(p.salaryScaleStartDate),
    baseSeniorityYears:
      p.baseSeniorityYears != null && !Number.isNaN(Number(p.baseSeniorityYears))
        ? String(p.baseSeniorityYears)
        : '',
    seniorityAsOfDate: toInputDate(p.seniorityAsOfDate) || salaryService.DEFAULT_SENIORITY_AS_OF,
    ldg: Boolean(p.ldg),
    importedInsuranceSalary:
      p.importedInsuranceSalary != null
        ? String(p.importedInsuranceSalary)
        : p.computedGrade?.insuranceSalary
          ? String(p.computedGrade.insuranceSalary)
          : '',
    importedProductSalary:
      p.importedProductSalary != null
        ? String(p.importedProductSalary)
        : p.computedGrade?.productSalary
          ? String(p.computedGrade.productSalary)
          : '',
  };
}

function toSalaryPayload(s: SalaryFormState): salaryService.EmployeeSalaryProfileRequest {
  const base = optNum(s.baseSeniorityYears);
  const useMilestone =
    !s.ldg && salaryService.hasSeniorityMilestone(s.baseSeniorityYears, s.salaryScaleStartDate);
  return {
    salaryCategory: s.salaryCategory,
    employeeBlock: s.salaryCategory === 'EMPLOYEE' ? s.employeeBlock : null,
    qualification: s.salaryCategory === 'EMPLOYEE' ? s.qualification : null,
    doctorQualificationCode: s.salaryCategory === 'DOCTOR' ? s.doctorQualificationCode : null,
    qualificationNote: s.qualificationNote.trim() || null,
    degreeConversionYears: optNum(s.degreeConversionYears) ?? 0,
    priorRaiseYears: optNum(s.priorRaiseYears) ?? 0,
    professionalAttractionSalary: 0,
    salaryScaleStartDate: s.salaryScaleStartDate || null,
    baseSeniorityYears: useMilestone ? base ?? null : null,
    seniorityAsOfDate: useMilestone
      ? s.seniorityAsOfDate || salaryService.DEFAULT_SENIORITY_AS_OF
      : null,
    ldg: s.ldg,
    fixedGradeLabel: s.ldg ? 'LĐG' : null,
    importedInsuranceSalary: optNum(s.importedInsuranceSalary) ?? null,
    importedProductSalary: optNum(s.importedProductSalary) ?? null,
  };
}

function FormSection({
  title,
  subtitle,
  icon,
  children,
}: {
  title: string;
  subtitle?: string;
  icon?: React.ReactNode;
  children: React.ReactNode;
}) {
  const theme = useTheme();
  return (
    <Box
      sx={{
        position: 'relative',
        borderRadius: 3,
        bgcolor: '#fff',
        border: `1px solid ${alpha(theme.palette.divider, 0.55)}`,
        boxShadow: `0 1px 2px ${alpha('#0f172a', 0.03)}, 0 8px 24px ${alpha('#0f172a', 0.03)}`,
        overflow: 'hidden',
        '&::before': {
          content: '""',
          position: 'absolute',
          left: 0,
          top: 0,
          bottom: 0,
          width: 3,
          background: `linear-gradient(180deg, ${ACCENT}, ${alpha(ACCENT, 0.3)})`,
        },
      }}
    >
      <Stack direction="row" spacing={1.25} alignItems="flex-start" sx={{ px: 2.5, pt: 2, pb: subtitle ? 0.5 : 1 }}>
        {icon && (
          <Box
            sx={{
              width: 34,
              height: 34,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(ACCENT, 0.1),
              color: ACCENT,
              flexShrink: 0,
            }}
          >
            {icon}
          </Box>
        )}
        <Box sx={{ minWidth: 0 }}>
          <Typography variant="subtitle2" fontWeight={800}>
            {title}
          </Typography>
          {subtitle && (
            <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.35, lineHeight: 1.5 }}>
              {subtitle}
            </Typography>
          )}
        </Box>
      </Stack>
      <Box
        sx={{
          px: 2.5,
          pb: 2.25,
          pt: 0.5,
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
          gap: 1.75,
        }}
      >
        {children}
      </Box>
    </Box>
  );
}

const fieldSx = {
  '& .MuiOutlinedInput-root': {
    borderRadius: 2.25,
    bgcolor: '#fff',
    '&:hover .MuiOutlinedInput-notchedOutline': { borderColor: alpha(ACCENT, 0.4) },
    '&.Mui-focused': { boxShadow: `0 0 0 3px ${alpha(ACCENT, 0.1)}` },
  },
};

type Props = {
  open: boolean;
  onClose: () => void;
  mode: 'create' | 'edit';
  employeeId?: number;
  onSuccess: () => void;
  defaultStatus?: EmploymentStatus;
  allowedCreateStatuses?: EmploymentStatus[];
};

export function EmployeeFormDialog({
  open,
  onClose,
  mode,
  employeeId,
  onSuccess,
  defaultStatus = 'ACTIVE',
  allowedCreateStatuses,
}: Props) {
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [positions, setPositions] = useState<employeeService.PositionOption[]>([]);
  const [workUnits, setWorkUnits] = useState<departmentService.WorkUnitRow[]>([]);
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
  const [status, setStatus] = useState<EmploymentStatus>(defaultStatus);
  const [mainDutyAuthorized, setMainDutyAuthorized] = useState(true);
  const [employmentType, setEmploymentType] = useState<'FULL_TIME' | 'PART_TIME'>('FULL_TIME');
  const [accountRole, setAccountRole] = useState<employeeService.EmployeeAccountRole>('EMPLOYEE');
  const [wf, setWf] = useState<WfState>(EMPTY_WF);
  const [salary, setSalary] = useState<SalaryFormState>(EMPTY_SALARY);
  const [salaryScales, setSalaryScales] = useState<salaryService.AllSalaryScales | null>(null);
  const [salaryUnlocked, setSalaryUnlocked] = useState(
    () => Boolean(salaryService.getSalaryAccessToken()),
  );
  const [salaryUnlockOpen, setSalaryUnlockOpen] = useState(false);
  const [salaryUnlockPassword, setSalaryUnlockPassword] = useState('');
  const [salaryUnlockBusy, setSalaryUnlockBusy] = useState(false);
  const [salaryUnlockError, setSalaryUnlockError] = useState<string | null>(null);

  const isTrial = status === 'PROBATION' || status === 'INTERN';
  const isOfficial = status === 'ACTIVE' || status === 'ON_LEAVE';

  const createStatusOptions: { value: EmploymentStatus; label: string }[] = (
    allowedCreateStatuses ?? (['ACTIVE', 'PROBATION', 'INTERN', 'ON_LEAVE', 'TERMINATED'] as EmploymentStatus[])
  ).map((value) => ({
    value,
    label:
      value === 'ACTIVE'
        ? 'Chính thức'
        : value === 'PROBATION'
          ? 'Thử việc'
          : value === 'INTERN'
            ? 'Thực tập'
            : value === 'ON_LEAVE'
              ? 'Nghỉ phép'
              : 'Nghỉ việc',
  }));

  const setWfField = (key: keyof WfState, value: string) => {
    setWf((prev) => ({ ...prev, [key]: value }));
  };

  const setSalaryField = <K extends keyof SalaryFormState>(key: K, value: SalaryFormState[K]) => {
    setSalary((prev) => ({ ...prev, [key]: value }));
  };

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
    if (!open || !salaryUnlocked) {
      setSalaryScales(null);
      return;
    }
    salaryService.fetchSalaryScales().then(setSalaryScales).catch(() => setSalaryScales(null));
  }, [open, salaryUnlocked]);

  useEffect(() => {
    if (!salary.enabled || salary.ldg || salary.salaryCategory !== 'EMPLOYEE' || !salaryScales) {
      return;
    }
    const hasBase =
      salary.baseSeniorityYears.trim() !== '' && !Number.isNaN(Number(salary.baseSeniorityYears));
    if (!hasBase && !salary.salaryScaleStartDate) {
      return;
    }
    const years = salaryService.resolveLiveSeniorityYears({
      baseSeniorityYears: salary.baseSeniorityYears,
      seniorityAsOfDate: salary.seniorityAsOfDate,
      salaryScaleStartDate: salary.salaryScaleStartDate,
      priorRaiseYears: salary.priorRaiseYears,
      degreeConversionYears: salary.degreeConversionYears,
      ldg: salary.ldg,
    });
    const gradeLevel = Math.min(10, Math.max(1, Math.ceil(years / 2) || 1));
    const scale =
      salary.employeeBlock === 'DIRECT'
        ? salaryScales.employeeDirect
        : salaryScales.employeeIndirect;
    const tier = scale.tiers.find((item) => item.tierLabel === salary.qualification);
    const grade = tier?.grades.find((item) => item.gradeLevel === gradeLevel);
    if (!grade) return;
    setSalary((prev) => {
      const insurance = String(grade.insuranceSalary ?? 0);
      const product = String(grade.productSalary ?? 0);
      if (prev.importedInsuranceSalary === insurance && prev.importedProductSalary === product) {
        return prev;
      }
      return {
        ...prev,
        importedInsuranceSalary: insurance,
        importedProductSalary: product,
      };
    });
  }, [
    salary.enabled,
    salary.ldg,
    salary.salaryCategory,
    salary.salaryScaleStartDate,
    salary.baseSeniorityYears,
    salary.seniorityAsOfDate,
    salary.priorRaiseYears,
    salary.degreeConversionYears,
    salary.employeeBlock,
    salary.qualification,
    salaryScales,
  ]);

  useEffect(() => {
    if (!open || !departmentId) {
      setWorkUnits([]);
      return;
    }
    let active = true;
    departmentService
      .fetchWorkUnits(Number(departmentId))
      .then((rows) => {
        if (active) setWorkUnits(rows);
      })
      .catch(() => {
        if (active) setWorkUnits([]);
      });
    return () => {
      active = false;
    };
  }, [open, departmentId]);

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
      setStatus(defaultStatus);
      setMainDutyAuthorized(true);
      setEmploymentType('FULL_TIME');
      setAccountRole('EMPLOYEE');
      setWf({
        ...EMPTY_WF,
        probationStartDate:
          defaultStatus === 'PROBATION' || defaultStatus === 'INTERN'
            ? toInputDate(new Date().toISOString())
            : '',
        officialStartDate: defaultStatus === 'ACTIVE' ? toInputDate(new Date().toISOString()) : '',
      });
      setSalary({
        ...EMPTY_SALARY,
        enabled: defaultStatus === 'ACTIVE' || defaultStatus === 'ON_LEAVE',
        salaryScaleStartDate:
          defaultStatus === 'ACTIVE' || defaultStatus === 'ON_LEAVE'
            ? toInputDate(new Date().toISOString())
            : '',
      });
      setErr(null);
      return;
    }
    if (mode === 'edit' && employeeId) {
      setLoading(true);
      setErr(null);
      Promise.all([
        employeeService.fetchEmployee(employeeId),
        salaryService.getSalaryAccessToken()
          ? salaryService.fetchSalaryProfile(employeeId).catch(() => null)
          : Promise.resolve(null),
      ])
        .then(([e, salProfile]) => {
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
          setStatus(e.status as EmploymentStatus);
          setMainDutyAuthorized(e.mainDutyAuthorized !== false);
          setEmploymentType(
            e.employmentType === 'PART_TIME' ? 'PART_TIME' : 'FULL_TIME',
          );
          setAccountRole((e.role as employeeService.EmployeeAccountRole) || 'EMPLOYEE');
          setWf(wfFromProfile(e.workforceProfile as Record<string, unknown> | null));
          if (salProfile?.salaryCategory) {
            setSalary(salaryFromProfile(salProfile));
          } else {
            setSalary({
              ...EMPTY_SALARY,
              enabled: e.status === 'ACTIVE' || e.status === 'ON_LEAVE',
              salaryScaleStartDate: toInputDate(
                (e.workforceProfile as Record<string, unknown> | null)?.officialStartDate as string,
              ),
              importedInsuranceSalary: sal != null ? String(sal.baseSalary) : '',
            });
          }
        })
        .catch(() => setErr('Không tải được hồ sơ.'))
        .finally(() => setLoading(false));
    }
  }, [open, mode, employeeId, defaultStatus]);

  useEffect(() => {
    if (!open || mode !== 'create' || departments.length === 0) return;
    if (departmentId === '') setDepartmentId(departments[0].id);
  }, [open, mode, departments, departmentId]);

  useEffect(() => {
    if (!open || mode !== 'create' || positions.length === 0) return;
    if (positionId === '') setPositionId(positions[0].id);
  }, [open, mode, positions, positionId]);

  useEffect(() => {
    if (!open || mode !== 'create' || !hireDate) return;
    setWf((prev) => {
      const next = { ...prev };
      if (status === 'PROBATION' || status === 'INTERN') {
        if (!next.probationStartDate) next.probationStartDate = hireDate;
      }
      if (status === 'ACTIVE') {
        if (!next.officialStartDate) next.officialStartDate = hireDate;
      }
      return next;
    });
    if (status === 'ACTIVE' || status === 'ON_LEAVE') {
      setSalary((prev) => ({
        ...prev,
        enabled: true,
      }));
    }
  }, [open, mode, status, hireDate]);

  const workUnitOptions = useMemo(() => {
    const names = workUnits.map((w) => w.name);
    if (wf.workUnitDetail && !names.includes(wf.workUnitDetail)) {
      return [wf.workUnitDetail, ...names];
    }
    return names;
  }, [workUnits, wf.workUnitDetail]);

  const dialogTitle = useMemo(() => {
    if (mode === 'edit') return 'Sửa nhân viên';
    if (defaultStatus === 'PROBATION' || defaultStatus === 'INTERN') return 'Thêm nhân viên thử việc / thực tập';
    if (defaultStatus === 'TERMINATED') return 'Thêm nhân viên nghỉ việc';
    return 'Thêm nhân viên chính thức';
  }, [mode, defaultStatus]);

  async function saveSalaryProfile(id: number) {
    if (!isOfficial || !salary.enabled || !salaryUnlocked) return;
    try {
      await salaryService.upsertSalaryProfile(id, toSalaryPayload(salary));
    } catch {
      // Không chặn lưu hồ sơ nếu thiếu quyền bảng lương
    }
  }

  async function unlockSalarySection() {
    if (!salaryUnlockPassword) return;
    setSalaryUnlockBusy(true);
    setSalaryUnlockError(null);
    try {
      await salaryService.unlockSalaryAccess(salaryUnlockPassword);
      setSalaryUnlocked(true);
      setSalaryUnlockOpen(false);
      setSalaryUnlockPassword('');
      if (mode === 'edit' && employeeId) {
        const profile = await salaryService.fetchSalaryProfile(employeeId);
        if (profile?.salaryCategory) setSalary(salaryFromProfile(profile));
      }
    } catch {
      salaryService.clearSalaryAccess();
      setSalaryUnlocked(false);
      setSalaryUnlockPassword('');
      setSalaryUnlockError('Sai mật khẩu, vui lòng nhập lại.');
    } finally {
      setSalaryUnlockBusy(false);
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    const workforce = isTrial
      ? {
          ...(wf.attendanceCode.trim() ? { attendanceCode: wf.attendanceCode.trim() } : {}),
          ...(wf.workUnitDetail.trim() ? { workUnitDetail: wf.workUnitDetail.trim() } : {}),
          ...(wf.degree.trim() ? { degree: wf.degree.trim() } : {}),
          ...(wf.probationStartDate ? { probationStartDate: wf.probationStartDate } : {}),
          ...(wf.workforceNotes.trim() ? { workforceNotes: wf.workforceNotes.trim() } : {}),
        }
      : toWorkforcePayload(wf, fullName);

    const insuranceFromSalary = optNum(salary.importedInsuranceSalary);
    const resolvedBase =
      isOfficial && salary.enabled && insuranceFromSalary != null
        ? insuranceFromSalary
        : optNum(baseSalary) ?? 0;

    if (mode === 'create') {
      if (!fullName.trim()) {
        setErr('Nhập họ và tên.');
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
      if (departmentId === '') {
        setErr('Chọn khoa / phòng ban.');
        return;
      }
      if (!wf.attendanceCode.trim()) {
        setErr('Nhập mã chấm công.');
        return;
      }
      setSaving(true);
      try {
        const created = await employeeService.createEmployee({
          ...(email.trim() ? { email: email.trim() } : {}),
          role: accountRole as employeeService.CreatableUserRole,
          fullName: fullName.trim(),
          phone: phone.trim() || undefined,
          ...(accountRole !== 'EMPLOYEE' ? { username: username.trim(), password } : {}),
          ...(idCardNumber.trim() ? { idCardNumber: idCardNumber.trim() } : {}),
          dateOfBirth: dateOfBirth || undefined,
          address: address.trim() || undefined,
          gender: gender.trim() || undefined,
          departmentId: Number(departmentId),
          ...(positionId !== '' ? { positionId: Number(positionId) } : {}),
          hireDate: hireDate || new Date().toISOString().slice(0, 10),
          baseSalary: resolvedBase,
          employmentType,
          status,
          workforce: Object.keys(workforce).length
            ? workforce
            : { attendanceCode: wf.attendanceCode.trim() },
        });
        if (salary.enabled) {
          try {
            await saveSalaryProfile(created.id);
          } catch {
            // Hồ sơ lương có thể bổ sung sau — không chặn tạo NV
          }
        }
        onSuccess();
        onClose();
      } catch (ex) {
        setErr(extractApiErrorMessage(ex, 'Tạo nhân viên thất bại (trùng username/SĐT hoặc dữ liệu không hợp lệ).'));
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
      if (
        isOfficial &&
        salary.enabled &&
        salaryUnlocked &&
        !salary.ldg &&
        !salary.salaryScaleStartDate &&
        (salary.baseSeniorityYears.trim() === '' || Number.isNaN(Number(salary.baseSeniorityYears)))
      ) {
        setErr('Nhập thâm niên mốc 30/06 hoặc chọn ngày bắt đầu tính thang bảng lương.');
        return;
      }
      setSaving(true);
      try {
        const allowanceNum = optNum(allowance);
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
          mainDutyAuthorized,
          employmentType,
          workforce: Object.keys(workforce).length ? workforce : undefined,
          baseSalary: resolvedBase,
          ...(allowanceNum != null ? { allowance: allowanceNum } : {}),
          ...(lastRaiseDate ? { lastRaiseDate } : {}),
          ...(nextReviewDate ? { nextReviewDate } : {}),
        });
        await saveSalaryProfile(employeeId);
        onSuccess();
        onClose();
      } catch {
        setErr('Cập nhật thất bại.');
      } finally {
        setSaving(false);
      }
    }
  }

  const spanAll = { gridColumn: { sm: '1 / -1' } as const };

  return (
    <>
    <Dialog
      open={open}
      onClose={saving ? undefined : onClose}
      maxWidth={isTrial ? 'md' : 'lg'}
      fullWidth
      PaperProps={{
        sx: {
          borderRadius: 3,
          overflow: 'hidden',
          bgcolor: alpha('#f8fafc', 0.98),
        },
      }}
    >
      <DialogTitle
        sx={{
          fontWeight: 800,
          borderBottom: `1px solid ${alpha('#0f172a', 0.06)}`,
          bgcolor: '#fff',
          py: 2,
        }}
      >
        {dialogTitle}
        <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.4, fontWeight: 500 }}>
          {mode === 'create'
            ? 'Bắt buộc: họ tên, SĐT, mã chấm công, khoa/phòng — các trường khác có thể bổ sung sau'
            : isOfficial
              ? 'Đồng bộ cấu trúc Excel BVMA — hồ sơ đầy đủ + bảng lương & thâm niên'
              : 'Hồ sơ thử việc / thực tập — có thể bổ sung khi lên chính thức'}
        </Typography>
      </DialogTitle>
      <Box component="form" onSubmit={handleSubmit}>
        <DialogContent dividers sx={{ maxHeight: '78vh', bgcolor: alpha('#f1f5f9', 0.45), py: 2.5 }}>
          {err && (
            <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }}>
              {err}
            </Alert>
          )}
          {loading && mode === 'edit' ? (
            <Typography>Đang tải…</Typography>
          ) : (
            <Stack spacing={2}>
              <FormSection title="Tài khoản đăng nhập" subtitle="Thông tin đăng nhập hệ thống HRM">
                {mode === 'create' && (
                  <TextField
                    select
                    size="small"
                    label="Vai trò đăng nhập"
                    fullWidth
                    required
                    value={accountRole}
                    onChange={(e) => setAccountRole(e.target.value as employeeService.EmployeeAccountRole)}
                    sx={fieldSx}
                  >
                    <MenuItem value="EMPLOYEE">Nhân viên</MenuItem>
                    <MenuItem value="HR">HCNS 1</MenuItem>
                    <MenuItem value="HR2">HCNS 2</MenuItem>
                    <MenuItem value="HEAD_DEPARTMENT">Trưởng khoa / Điều dưỡng trưởng</MenuItem>
                    <MenuItem value="HEAD_HR">Trưởng phòng HCNS</MenuItem>
                    <MenuItem value="HEAD_NURSING">Trưởng phòng Điều dưỡng</MenuItem>
                  </TextField>
                )}
                {mode === 'edit' && (
                  <TextField
                    select
                    size="small"
                    label="Vai trò"
                    fullWidth
                    required
                    value={accountRole}
                    onChange={(e) => setAccountRole(e.target.value as employeeService.EmployeeAccountRole)}
                    sx={fieldSx}
                  >
                    <MenuItem value="ADMIN">Quản trị</MenuItem>
                    <MenuItem value="EMPLOYEE">Nhân viên</MenuItem>
                    <MenuItem value="HR">HCNS 1</MenuItem>
                    <MenuItem value="HR2">HCNS 2</MenuItem>
                    <MenuItem value="HEAD_DEPARTMENT">Trưởng khoa / Điều dưỡng trưởng</MenuItem>
                    <MenuItem value="HEAD_HR">Trưởng phòng HCNS</MenuItem>
                    <MenuItem value="HEAD_NURSING">Trưởng phòng Điều dưỡng</MenuItem>
                    <MenuItem value="DIRECTOR">Giám đốc</MenuItem>
                  </TextField>
                )}
                {mode === 'create' && accountRole !== 'EMPLOYEE' && (
                  <>
                    <TextField
                      size="small"
                      label="Tên đăng nhập"
                      fullWidth
                      required
                      value={username}
                      onChange={(e) => setUsername(e.target.value)}
                      autoComplete="off"
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Mật khẩu"
                      type="password"
                      fullWidth
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      autoComplete="new-password"
                      sx={fieldSx}
                    />
                  </>
                )}
                <TextField
                  size="small"
                  label="Email"
                  type="email"
                  fullWidth
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  helperText={
                    mode === 'create' ? 'Tuỳ chọn — trống thì tự sinh từ SĐT (@minhan.local)' : undefined
                  }
                  sx={fieldSx}
                />
                {mode === 'create' && accountRole === 'EMPLOYEE' && (
                  <TextField
                    size="small"
                    label="Số điện thoại (tên đăng nhập)"
                    fullWidth
                    required
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    helperText="Bắt buộc · Mật khẩu mặc định: 123"
                    sx={fieldSx}
                  />
                )}
              </FormSection>

              <FormSection title="Thông tin cá nhân" subtitle="Liên hệ & giấy tờ tùy thân">
                <TextField
                  size="small"
                  label="Họ và tên"
                  fullWidth
                  required
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  sx={fieldSx}
                />
                {(mode === 'edit' || accountRole !== 'EMPLOYEE') && (
                  <TextField
                    size="small"
                    label="Điện thoại"
                    fullWidth
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    sx={fieldSx}
                  />
                )}
                <TextField
                  size="small"
                  label="CCCD/CMND (= mã nhân viên)"
                  fullWidth
                  value={idCardNumber}
                  onChange={(e) => setIdCardNumber(e.target.value)}
                  helperText="Tuỳ chọn — trống thì dùng mã tạm TMP-SĐT; bổ sung sau"
                  sx={fieldSx}
                />
                <DatePickerField label="Ngày sinh" value={dateOfBirth} onChange={setDateOfBirth} sx={fieldSx} />
                <TextField
                  size="small"
                  select
                  label="Giới tính"
                  fullWidth
                  value={gender}
                  onChange={(e) => setGender(e.target.value)}
                  sx={fieldSx}
                >
                  <MenuItem value="">—</MenuItem>
                  <MenuItem value="Nam">Nam</MenuItem>
                  <MenuItem value="Nữ">Nữ</MenuItem>
                  <MenuItem value="Khác">Khác</MenuItem>
                </TextField>
                {!isTrial && (
                  <>
                    <DatePickerField
                      label="Ngày cấp CCCD/CMND"
                      value={wf.idCardIssueDate}
                      onChange={(v) => setWfField('idCardIssueDate', v)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Dân tộc"
                      fullWidth
                      value={wf.ethnicity}
                      onChange={(e) => setWfField('ethnicity', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Nguyên quán"
                      fullWidth
                      value={wf.placeOfOrigin}
                      onChange={(e) => setWfField('placeOfOrigin', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      select
                      label="Tình trạng hôn nhân"
                      fullWidth
                      value={wf.maritalStatus}
                      onChange={(e) => setWfField('maritalStatus', e.target.value)}
                      sx={fieldSx}
                    >
                      <MenuItem value="">—</MenuItem>
                      <MenuItem value="Độc thân">Độc thân</MenuItem>
                      <MenuItem value="Đã kết hôn">Đã kết hôn</MenuItem>
                      <MenuItem value="Ly hôn">Ly hôn</MenuItem>
                      <MenuItem value="Khác">Khác</MenuItem>
                    </TextField>
                    <TextField
                      size="small"
                      label="Nhóm máu"
                      fullWidth
                      value={wf.bloodType}
                      onChange={(e) => setWfField('bloodType', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Người liên hệ khẩn cấp"
                      fullWidth
                      value={wf.emergencyContact}
                      onChange={(e) => setWfField('emergencyContact', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="SĐT liên hệ khẩn cấp"
                      fullWidth
                      value={wf.emergencyPhone}
                      onChange={(e) => setWfField('emergencyPhone', e.target.value)}
                      sx={fieldSx}
                    />
                  </>
                )}
                <TextField
                  size="small"
                  label="Địa chỉ"
                  fullWidth
                  multiline
                  minRows={2}
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                  sx={{ ...fieldSx, ...spanAll }}
                />
              </FormSection>

              <FormSection title="Công việc" subtitle="Phòng ban · bộ phận · vị trí (Excel BVMA)">
                <TextField
                  size="small"
                  select
                  label="Hình thức làm việc"
                  fullWidth
                  required
                  value={employmentType}
                  onChange={(e) =>
                    setEmploymentType(e.target.value as 'FULL_TIME' | 'PART_TIME')
                  }
                  sx={fieldSx}
                >
                  <MenuItem value="FULL_TIME">Toàn thời gian (TTG)</MenuItem>
                  <MenuItem value="PART_TIME">Bán thời gian (BTG)</MenuItem>
                </TextField>
                <TextField
                  size="small"
                  select
                  label="Phòng ban"
                  fullWidth
                  required
                  value={departmentId}
                  onChange={(e) => {
                    setDepartmentId(Number(e.target.value));
                    setWfField('workUnitDetail', '');
                  }}
                  sx={fieldSx}
                >
                  {departments.map((d) => (
                    <MenuItem key={d.id} value={d.id}>
                      {d.name}
                    </MenuItem>
                  ))}
                </TextField>
                <TextField
                  size="small"
                  select
                  label="Chức vụ"
                  fullWidth
                  value={positionId}
                  onChange={(e) => setPositionId(Number(e.target.value))}
                  helperText={mode === 'create' ? 'Tuỳ chọn — trống thì gán «Nhân viên»' : undefined}
                  sx={fieldSx}
                >
                  {positions.map((p) => (
                    <MenuItem key={p.id} value={p.id}>
                      {p.title}
                    </MenuItem>
                  ))}
                </TextField>
                {workUnitOptions.length > 0 ? (
                  <TextField
                    size="small"
                    select
                    label="Bộ phận"
                    fullWidth
                    value={wf.workUnitDetail}
                    onChange={(e) => setWfField('workUnitDetail', e.target.value)}
                    sx={fieldSx}
                  >
                    <MenuItem value="">—</MenuItem>
                    {workUnitOptions.map((name) => (
                      <MenuItem key={name} value={name}>
                        {name}
                      </MenuItem>
                    ))}
                  </TextField>
                ) : (
                  <TextField
                    size="small"
                    label="Bộ phận"
                    fullWidth
                    value={wf.workUnitDetail}
                    onChange={(e) => setWfField('workUnitDetail', e.target.value)}
                    sx={fieldSx}
                    placeholder="VD: THU NGÂN"
                  />
                )}
                <TextField
                  size="small"
                  label="Mã chấm công"
                  fullWidth
                  required={mode === 'create'}
                  value={wf.attendanceCode}
                  onChange={(e) => setWfField('attendanceCode', e.target.value)}
                  sx={fieldSx}
                />
                <DatePickerField
                  label={isTrial ? 'Từ ngày (thử việc / thực tập)' : 'Ngày vào làm'}
                  value={hireDate}
                  onChange={setHireDate}
                  sx={fieldSx}
                />
                <TextField
                  size="small"
                  select
                  label="Trạng thái"
                  fullWidth
                  required
                  value={status}
                  onChange={(e) => setStatus(e.target.value as EmploymentStatus)}
                  sx={fieldSx}
                >
                  {(mode === 'create'
                    ? createStatusOptions
                    : [
                        { value: 'ACTIVE' as const, label: 'Chính thức' },
                        { value: 'PROBATION' as const, label: 'Thử việc' },
                        { value: 'INTERN' as const, label: 'Thực tập' },
                        { value: 'ON_LEAVE' as const, label: 'Nghỉ phép' },
                        { value: 'TERMINATED' as const, label: 'Nghỉ việc' },
                      ]
                  ).map((o) => (
                    <MenuItem key={o.value} value={o.value}>
                      {o.label}
                    </MenuItem>
                  ))}
                </TextField>
                {mode === 'edit' && (
                  <TextField
                    size="small"
                    select
                    label="Loại trực"
                    fullWidth
                    value={mainDutyAuthorized ? 'MAIN' : 'TK'}
                    onChange={(e) => setMainDutyAuthorized(e.target.value === 'MAIN')}
                    sx={fieldSx}
                    helperText="Trực kèm: chỉ ca TK. Trực chính: mọi loại ca."
                  >
                    <MenuItem value="TK">Trực kèm</MenuItem>
                    <MenuItem value="MAIN">Trực chính</MenuItem>
                  </TextField>
                )}
                {isOfficial && (
                  <DatePickerField
                    label="Ngày làm chính thức"
                    value={wf.officialStartDate}
                    onChange={(v) => setWfField('officialStartDate', v)}
                    sx={fieldSx}
                  />
                )}
                {isTrial && (
                  <>
                    <TextField
                      size="small"
                      label="Trình độ / bằng cấp"
                      fullWidth
                      value={wf.degree}
                      onChange={(e) => setWfField('degree', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Lương cơ bản (khởi tạo)"
                      type="number"
                      fullWidth
                      value={baseSalary}
                      onChange={(e) => setBaseSalary(e.target.value)}
                      inputProps={{ min: 0, step: 1000 }}
                      sx={fieldSx}
                    />
                  </>
                )}
              </FormSection>

              {!isTrial && (
                <>
                  <FormSection title="Chuyên môn & chứng chỉ" subtitle="Theo cột chuyên môn trên Excel nhân lực">
                    <TextField
                      size="small"
                      label="Chuyên ngành / chuyên môn"
                      fullWidth
                      value={wf.specialty}
                      onChange={(e) => setWfField('specialty', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Trình độ / bằng cấp"
                      fullWidth
                      value={wf.degree}
                      onChange={(e) => setWfField('degree', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Văn bằng chuyên môn"
                      fullWidth
                      value={wf.professionalDiploma}
                      onChange={(e) => setWfField('professionalDiploma', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Phạm vi hành nghề"
                      fullWidth
                      value={wf.practiceScope}
                      onChange={(e) => setWfField('practiceScope', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Số CCHN"
                      fullWidth
                      value={wf.practiceCertNumber}
                      onChange={(e) => setWfField('practiceCertNumber', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Ngày cấp CCHN"
                      fullWidth
                      placeholder="dd/mm/yyyy"
                      value={wf.practiceCertDateRaw}
                      onChange={(e) => setWfField('practiceCertDateRaw', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="CKI"
                      fullWidth
                      value={wf.cki}
                      onChange={(e) => setWfField('cki', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Chứng chỉ đào tạo khác"
                      fullWidth
                      multiline
                      minRows={2}
                      value={wf.otherTrainingCertificates}
                      onChange={(e) => setWfField('otherTrainingCertificates', e.target.value)}
                      sx={{ ...fieldSx, ...spanAll }}
                    />
                  </FormSection>

                  <FormSection
                    title="Bảng lương & thâm niên"
                    subtitle="Cấu hình thang bảng lương — đồng bộ với trang Lương và Excel BVMA"
                    icon={<PaymentsIcon fontSize="small" />}
                  >
                    {!salaryUnlocked ? (
                      <Box
                        sx={{
                          ...spanAll,
                          py: 3,
                          px: 2,
                          textAlign: 'center',
                          border: '1px dashed',
                          borderColor: 'divider',
                          borderRadius: 2,
                          bgcolor: 'action.hover',
                        }}
                      >
                        <LockOutlinedIcon color="action" sx={{ fontSize: 34, mb: 1 }} />
                        <Typography fontWeight={700}>Thông tin lương và thâm niên đã được khóa</Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5, mb: 2 }}>
                          Nhập mật khẩu phần lương để xem hoặc chỉnh sửa.
                        </Typography>
                        <Button
                          variant="contained"
                          startIcon={<LockOutlinedIcon />}
                          onClick={() => {
                            setSalaryUnlockError(null);
                            setSalaryUnlockOpen(true);
                          }}
                        >
                          Nhập mật khẩu
                        </Button>
                      </Box>
                    ) : (
                      <>
                    <Box sx={spanAll}>
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={salary.enabled}
                            onChange={(e) => setSalaryField('enabled', e.target.checked)}
                            sx={{ color: ACCENT, '&.Mui-checked': { color: ACCENT } }}
                          />
                        }
                        label="Thiết lập hồ sơ lương / thâm niên ngay trên form này"
                      />
                    </Box>
                    {salary.enabled && (
                      <>
                        <TextField
                          size="small"
                          select
                          label="Đối tượng lương"
                          fullWidth
                          value={salary.salaryCategory}
                          onChange={(e) =>
                            setSalaryField('salaryCategory', e.target.value as 'DOCTOR' | 'EMPLOYEE')
                          }
                          sx={fieldSx}
                        >
                          <MenuItem value="EMPLOYEE">Nhân viên</MenuItem>
                          <MenuItem value="DOCTOR">Bác sỹ</MenuItem>
                        </TextField>
                        {salary.salaryCategory === 'EMPLOYEE' ? (
                          <>
                            <TextField
                              size="small"
                              select
                              label="Khối"
                              fullWidth
                              value={salary.employeeBlock}
                              onChange={(e) =>
                                setSalaryField('employeeBlock', e.target.value as 'DIRECT' | 'INDIRECT')
                              }
                              sx={fieldSx}
                            >
                              <MenuItem value="DIRECT">Trực tiếp</MenuItem>
                              <MenuItem value="INDIRECT">Gián tiếp</MenuItem>
                            </TextField>
                            <TextField
                              size="small"
                              select
                              label="Trình độ (thang bảng lương)"
                              fullWidth
                              value={salary.qualification}
                              onChange={(e) => setSalaryField('qualification', e.target.value)}
                              sx={fieldSx}
                            >
                              {salaryService.EMPLOYEE_QUALIFICATIONS.map((q) => (
                                <MenuItem key={q} value={q}>
                                  {q}
                                </MenuItem>
                              ))}
                            </TextField>
                          </>
                        ) : (
                          <>
                            <TextField
                              size="small"
                              select
                              label="Trình độ (thang bảng BS)"
                              fullWidth
                              value={salary.doctorQualificationCode}
                              onChange={(e) => setSalaryField('doctorQualificationCode', e.target.value)}
                              sx={fieldSx}
                            >
                              {salaryService.DOCTOR_QUALIFICATIONS.map((q) => (
                                <MenuItem key={q.code} value={q.code}>
                                  {q.label}
                                </MenuItem>
                              ))}
                            </TextField>
                            <TextField
                              size="small"
                              label="Chuyển đổi bằng cấp (năm)"
                              type="number"
                              fullWidth
                              inputProps={{ min: 0, step: 0.1 }}
                              value={salary.degreeConversionYears}
                              onChange={(e) => setSalaryField('degreeConversionYears', e.target.value)}
                              sx={fieldSx}
                            />
                          </>
                        )}
                        <DatePickerField
                          label="Bắt đầu tính thang bảng lương"
                          value={salary.salaryScaleStartDate}
                          onChange={(v) => setSalaryField('salaryScaleStartDate', v)}
                          helperText="Dùng khi không có mốc thâm niên 30/06"
                          sx={fieldSx}
                        />
                        <TextField
                          size="small"
                          label="Thâm niên mốc 30/06 (năm)"
                          type="number"
                          fullWidth
                          inputProps={{ min: 0, step: 0.000001 }}
                          value={salary.baseSeniorityYears}
                          onChange={(e) => setSalaryField('baseSeniorityYears', e.target.value)}
                          helperText="Để trống (không nhập 0) nếu tính từ ngày bắt đầu thang"
                          disabled={salary.ldg}
                          sx={fieldSx}
                        />
                        <DatePickerField
                          label="Ngày chốt mốc thâm niên"
                          value={salary.seniorityAsOfDate}
                          onChange={(v) => setSalaryField('seniorityAsOfDate', v)}
                          helperText="Mặc định 30/06/2026"
                          disabled={
                            salary.ldg ||
                            !salaryService.hasSeniorityMilestone(
                              salary.baseSeniorityYears,
                              salary.salaryScaleStartDate,
                            )
                          }
                          sx={fieldSx}
                        />
                        <TextField
                          size="small"
                          label="Thâm niên hiện tại"
                          fullWidth
                          value={salaryService.formatLiveSeniorityPreview({
                            baseSeniorityYears: salary.baseSeniorityYears,
                            seniorityAsOfDate: salary.seniorityAsOfDate,
                            salaryScaleStartDate: salary.salaryScaleStartDate,
                            priorRaiseYears: salary.priorRaiseYears,
                            degreeConversionYears: salary.degreeConversionYears,
                            ldg: salary.ldg,
                          })}
                          helperText="Có mốc (>0): mốc + (hôm nay − 30/06)/365 · Không mốc/để trống/0+ngày bắt đầu: từ ngày bắt đầu thang"
                          InputProps={{ readOnly: true }}
                          sx={fieldSx}
                        />
                        <TextField
                          size="small"
                          label="Quy đổi nâng lương sớm (năm — tổng)"
                          helperText="Chi tiết theo ngày trên trang Lương"
                          type="number"
                          fullWidth
                          inputProps={{ min: 0, step: 0.1 }}
                          value={salary.priorRaiseYears}
                          onChange={(e) => setSalaryField('priorRaiseYears', e.target.value)}
                          sx={fieldSx}
                        />
                        <TextField
                          size="small"
                          label={
                            salary.salaryCategory === 'DOCTOR'
                              ? 'Lương cơ bản'
                              : 'Lương cơ bản / đóng BH'
                          }
                          type="number"
                          fullWidth
                          inputProps={{ min: 0, step: 1000 }}
                          value={salary.importedInsuranceSalary}
                          onChange={(e) => setSalaryField('importedInsuranceSalary', e.target.value)}
                          InputProps={{
                            readOnly:
                              salary.salaryCategory === 'EMPLOYEE' && !salary.ldg && Boolean(salaryScales),
                          }}
                          helperText={
                            salary.salaryCategory === 'EMPLOYEE' && !salary.ldg && salaryScales
                              ? 'Tự động theo thâm niên và bậc lương'
                              : undefined
                          }
                          sx={fieldSx}
                        />
                        <TextField
                          size="small"
                          label={
                            salary.salaryCategory === 'DOCTOR'
                              ? 'Lương đảm bảo sản phẩm'
                              : 'Lương đảm bảo SP'
                          }
                          type="number"
                          fullWidth
                          inputProps={{ min: 0, step: 1000 }}
                          value={salary.importedProductSalary}
                          onChange={(e) => setSalaryField('importedProductSalary', e.target.value)}
                          InputProps={{
                            readOnly:
                              salary.salaryCategory === 'EMPLOYEE' && !salary.ldg && Boolean(salaryScales),
                          }}
                          helperText={
                            salary.salaryCategory === 'EMPLOYEE' && !salary.ldg && salaryScales
                              ? 'Tự động theo thâm niên và bậc lương'
                              : undefined
                          }
                          sx={fieldSx}
                        />
                        <Box sx={spanAll}>
                          <FormControlLabel
                            control={
                              <Checkbox
                                checked={salary.ldg}
                                onChange={(e) => setSalaryField('ldg', e.target.checked)}
                              />
                            }
                            label="LĐG — bậc cố định, không nhảy theo thâm niên"
                          />
                        </Box>
                        <TextField
                          size="small"
                          label="Ghi chú trình độ"
                          fullWidth
                          value={salary.qualificationNote}
                          onChange={(e) => setSalaryField('qualificationNote', e.target.value)}
                          sx={{ ...fieldSx, ...spanAll }}
                        />
                      </>
                    )}
                      </>
                    )}
                  </FormSection>

                  <FormSection title="Lương & ngân hàng" subtitle="Thông tin nhận lương trên Excel">
                    <TextField
                      size="small"
                      label="Tên hiển thị bảng lương"
                      fullWidth
                      value={wf.payrollDisplayName}
                      onChange={(e) => setWfField('payrollDisplayName', e.target.value)}
                      placeholder={fullName || 'Theo họ tên'}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="STK nhận lương"
                      fullWidth
                      value={wf.bankAccount}
                      onChange={(e) => setWfField('bankAccount', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Ngân hàng nhận lương"
                      fullWidth
                      value={wf.bankName}
                      onChange={(e) => setWfField('bankName', e.target.value)}
                      sx={fieldSx}
                    />
                  </FormSection>

                  <FormSection
                    title="Bảo hiểm"
                    subtitle="Chọn «Nghỉ thai sản» để chuyển NV sang chế độ nghỉ thai sản"
                  >
                    <TextField
                      size="small"
                      select
                      label="Tham gia BHXH"
                      fullWidth
                      value={wf.insuranceParticipation}
                      onChange={(e) => setWfField('insuranceParticipation', e.target.value)}
                      sx={fieldSx}
                    >
                      <MenuItem value="">—</MenuItem>
                      <MenuItem value="Có tham gia">Có tham gia</MenuItem>
                      <MenuItem value="Không tham gia">Không tham gia</MenuItem>
                      <MenuItem value="Nghỉ thai sản">Nghỉ thai sản</MenuItem>
                    </TextField>
                    <TextField
                      size="small"
                      label="Số sổ BHXH"
                      fullWidth
                      value={wf.socialInsuranceBook}
                      onChange={(e) => setWfField('socialInsuranceBook', e.target.value)}
                      sx={fieldSx}
                    />
                  </FormSection>

                  {isOfficial && (
                    <FormSection title="Hợp đồng lao động" subtitle="Số HĐ / ngày ký / thời hạn">
                      <TextField
                        size="small"
                        label="Số hợp đồng"
                        fullWidth
                        value={wf.contractNumber}
                        onChange={(e) => setWfField('contractNumber', e.target.value)}
                        sx={fieldSx}
                      />
                      <DatePickerField
                        label="Ngày ký hợp đồng"
                        value={wf.contractSignDate}
                        onChange={(v) => setWfField('contractSignDate', v)}
                        sx={fieldSx}
                      />
                      <TextField
                        size="small"
                        label="Thời hạn hợp đồng"
                        fullWidth
                        value={wf.contractTerm}
                        onChange={(e) => setWfField('contractTerm', e.target.value)}
                        placeholder="VD: 12 tháng / Không xác định thời hạn"
                        sx={{ ...fieldSx, ...spanAll }}
                      />
                    </FormSection>
                  )}

                  <FormSection title="Thông tin bổ sung">
                    <TextField
                      size="small"
                      label="Người phụ thuộc"
                      fullWidth
                      multiline
                      minRows={2}
                      value={wf.dependentsInfo}
                      onChange={(e) => setWfField('dependentsInfo', e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      size="small"
                      label="Ghi chú"
                      fullWidth
                      multiline
                      minRows={2}
                      value={wf.workforceNotes}
                      onChange={(e) => setWfField('workforceNotes', e.target.value)}
                      sx={fieldSx}
                    />
                  </FormSection>
                </>
              )}
            </Stack>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, py: 2, bgcolor: '#fff', borderTop: `1px solid ${alpha('#0f172a', 0.06)}` }}>
          <Button type="button" onClick={onClose} disabled={saving} sx={{ borderRadius: 2 }}>
            Hủy
          </Button>
          <Button
            type="submit"
            variant="contained"
            disabled={saving || loading}
            sx={{
              borderRadius: 2,
              px: 2.5,
              fontWeight: 700,
              bgcolor: ACCENT,
              '&:hover': { bgcolor: '#0d9488' },
            }}
          >
            {mode === 'create' ? 'Tạo mới' : 'Lưu'}
          </Button>
        </DialogActions>
      </Box>
      </Dialog>
      <Dialog
        open={salaryUnlockOpen}
        onClose={() => !salaryUnlockBusy && setSalaryUnlockOpen(false)}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle>Mở khóa bảng lương & thâm niên</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Nhập mật khẩu phần lương để xem và chỉnh sửa thông tin bảo mật.
          </Typography>
          {salaryUnlockError && <Alert severity="error" sx={{ mb: 2 }}>{salaryUnlockError}</Alert>}
          <TextField
            autoFocus
            fullWidth
            type="password"
            label="Mật khẩu phần lương"
            value={salaryUnlockPassword}
            onChange={(e) => setSalaryUnlockPassword(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') void unlockSalarySection();
            }}
            disabled={salaryUnlockBusy}
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5 }}>
          <Button onClick={() => setSalaryUnlockOpen(false)} disabled={salaryUnlockBusy}>Hủy</Button>
          <Button
            variant="contained"
            onClick={() => void unlockSalarySection()}
            disabled={salaryUnlockBusy || !salaryUnlockPassword}
          >
            {salaryUnlockBusy ? 'Đang kiểm tra…' : 'Mở khóa'}
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
}

