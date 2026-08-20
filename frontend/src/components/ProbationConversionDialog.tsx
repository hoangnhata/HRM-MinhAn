import HowToRegIcon from '@mui/icons-material/HowToReg';
import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import PaymentsIcon from '@mui/icons-material/Payments';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import {
  Box,
  Checkbox,
  Chip,
  CircularProgress,
  FormControlLabel,
  LinearProgress,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import {
  FormSection,
  InfoBanner,
  ReadonlyFact,
  RequestFlowSteps,
  WorkRequestDialogShell,
  requestFieldSx,
} from './work/WorkRequestFormUi';
import * as departmentService from '../services/departmentService';
import * as employeeService from '../services/employeeService';
import * as pcs from '../services/probationConversionService';
import * as salaryService from '../services/salaryService';
import { isNursingBlockTitle, probationFlowSteps } from '../utils/nursingBlock';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  editConversion?: pcs.ProbationConversion | null;
  employee: {
    id: number;
    fullName: string;
    departmentName?: string;
    positionTitle?: string;
    status?: string;
  } | null;
};

const ACCENT = '#15803d';

type OfficialFormState = {
  phone: string;
  email: string;
  gender: string;
  address: string;
  idCardNumber: string;
  dateOfBirth: string;
  departmentId: number | '';
  positionId: number | '';
  hireDate: string;
  attendanceCode: string;
  workUnitDetail: string;
  payrollDisplayName: string;
  bankAccount: string;
  bankName: string;
  insuranceParticipation: string;
  socialInsuranceBook: string;
  idCardIssueDate: string;
  probationStartDate: string;
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

const EMPTY_OFFICIAL: OfficialFormState = {
  phone: '',
  email: '',
  gender: '',
  address: '',
  idCardNumber: '',
  dateOfBirth: '',
  departmentId: '',
  positionId: '',
  hireDate: '',
  attendanceCode: '',
  workUnitDetail: '',
  payrollDisplayName: '',
  bankAccount: '',
  bankName: '',
  insuranceParticipation: '',
  socialInsuranceBook: '',
  idCardIssueDate: '',
  probationStartDate: '',
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
  priorRaiseYears: string;
  degreeConversionYears: string;
  salaryScaleStartDate: string;
  baseSeniorityYears: string;
  seniorityAsOfDate: string;
  ldg: boolean;
  importedInsuranceSalary: string;
  importedProductSalary: string;
};

const EMPTY_SALARY: SalaryFormState = {
  enabled: true,
  salaryCategory: 'EMPLOYEE',
  employeeBlock: 'INDIRECT',
  qualification: salaryService.EMPLOYEE_QUALIFICATIONS[0],
  doctorQualificationCode: 'CCHN',
  priorRaiseYears: '0',
  degreeConversionYears: '0',
  salaryScaleStartDate: '',
  baseSeniorityYears: '',
  seniorityAsOfDate: salaryService.DEFAULT_SENIORITY_AS_OF,
  ldg: false,
  importedInsuranceSalary: '',
  importedProductSalary: '',
};

function optNum(s: string): number | undefined {
  const n = Number(String(s).replace(/\s/g, '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : undefined;
}

function toInputDate(s: string | undefined | null): string {
  if (!s) return '';
  return String(s).slice(0, 10);
}

function normalizePosition(value?: string) {
  return (value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();
}

function isClinicalPosition(positionTitle?: string) {
  const title = normalizePosition(positionTitle);
  const doctor = /\b(bac\s*si|bs|doctor)\b/.test(title);
  const nurse =
    /dieu\s*duong|\bdd\b|ho\s*sinh|ky\s*thuat\s*vien|\bktv\b|y\s*ta|nurse/.test(title);
  return doctor || nurse;
}

function staffFallback(employee: NonNullable<Props['employee']>): pcs.ProbationFormTypeInfo {
  const criteria: pcs.ProbationCriterion[] = [
    {
      code: 'knowledge',
      label: 'Kiến thức chuyên môn',
      maxScore: 30,
      detail:
        'Hiểu các quy định, quy trình nội bộ liên quan đến công việc được giao; có kiến thức cơ bản về hoạt động kinh doanh dịch vụ y tế và chăm sóc khách hàng; hiểu nguyên tắc giao tiếp, tư vấn và làm việc với khách hàng/đối tác trong môi trường bệnh viện; nắm được các quy định chung về đạo đức nghề nghiệp, bảo mật thông tin và hình ảnh bệnh viện',
    },
    {
      code: 'practice',
      label: 'Kỹ năng thực hành',
      maxScore: 40,
      detail:
        'Kỹ năng giao tiếp, tư vấn dịch vụ y tế cho khách hàng/đối tác; kỹ năng xây dựng, duy trì và phát triển mối quan hệ với đối tác; thực hiện công việc đúng quy trình, đúng kế hoạch được giao; kỹ năng tin học văn phòng; phối hợp triển khai các hoạt động truyền thông - marketing bệnh viện',
    },
    {
      code: 'attitude',
      label: 'Thái độ - đạo đức',
      maxScore: 20,
      detail:
        'Thái độ chuẩn mực, lịch sự, tôn trọng người bệnh, khách hàng và đối tác; tuân thủ quy định bệnh viện, quy tắc ứng xử và bảo mật thông tin y tế; có ý thức trách nhiệm, chủ động trong công việc; giữ hình ảnh, uy tín và thương hiệu bệnh viện',
    },
    {
      code: 'teamwork',
      label: 'Phối hợp & học tập',
      maxScore: 10,
      detail:
        'Hợp tác với đồng nghiệp, hỗ trợ kịp thời; chủ động học hỏi kiến thức y tế, dịch vụ mới, chính sách mới; tiếp thu góp ý, cải thiện hiệu quả công việc; tham gia đầy đủ các chương trình đào tạo nội bộ',
    },
  ];
  return {
    employeeId: employee.id,
    employeeName: employee.fullName,
    positionTitle: employee.positionTitle,
    formType: 'STAFF',
    formTypeLabel: 'Nhân viên',
    requiresScoring: true,
    maxScore: 100,
    criteria,
  };
}

function officialFromDetail(detail: employeeService.EmployeeDetail): OfficialFormState {
  const p = (detail.workforceProfile || {}) as Record<string, unknown>;
  const g = (k: string) => (p[k] != null ? String(p[k]) : '');
  return {
    phone: detail.phone || '',
    email: detail.email || '',
    gender: detail.gender || '',
    address: detail.address || '',
    idCardNumber: detail.idCardNumber || '',
    dateOfBirth: toInputDate(detail.dateOfBirth),
    departmentId: detail.departmentId || '',
    positionId: detail.positionId || '',
    hireDate: toInputDate(detail.hireDate),
    attendanceCode: g('attendanceCode'),
    workUnitDetail: g('workUnitDetail'),
    payrollDisplayName: g('payrollDisplayName') || detail.fullName || '',
    bankAccount: g('bankAccount'),
    bankName: g('bankName'),
    insuranceParticipation: g('insuranceParticipation'),
    socialInsuranceBook: g('socialInsuranceBook'),
    idCardIssueDate: toInputDate(g('idCardIssueDate')),
    probationStartDate: toInputDate(g('probationStartDate')) || toInputDate(detail.hireDate),
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

function toWorkforcePayload(
  o: OfficialFormState,
  fullName: string,
  officialDate: string,
): employeeService.WorkforceDetailsPayload {
  const opt = (s: string) => (s.trim() ? s.trim() : undefined);
  return {
    attendanceCode: opt(o.attendanceCode),
    workUnitDetail: opt(o.workUnitDetail),
    payrollDisplayName: opt(o.payrollDisplayName) || opt(fullName),
    bankAccount: opt(o.bankAccount),
    bankName: opt(o.bankName),
    insuranceParticipation: opt(o.insuranceParticipation),
    socialInsuranceBook: opt(o.socialInsuranceBook),
    idCardIssueDate: opt(o.idCardIssueDate),
    probationStartDate: opt(o.probationStartDate),
    officialStartDate: opt(officialDate),
    contractNumber: opt(o.contractNumber),
    contractSignDate: opt(o.contractSignDate) || opt(officialDate),
    contractTerm: opt(o.contractTerm),
    specialty: opt(o.specialty),
    degree: opt(o.degree),
    professionalDiploma: opt(o.professionalDiploma),
    practiceScope: opt(o.practiceScope),
    practiceCertNumber: opt(o.practiceCertNumber),
    practiceCertDateRaw: opt(o.practiceCertDateRaw),
    otherTrainingCertificates: opt(o.otherTrainingCertificates),
    cki: opt(o.cki),
    ethnicity: opt(o.ethnicity),
    placeOfOrigin: opt(o.placeOfOrigin),
    maritalStatus: opt(o.maritalStatus),
    bloodType: opt(o.bloodType),
    emergencyContact: opt(o.emergencyContact),
    emergencyPhone: opt(o.emergencyPhone),
    dependentsInfo: opt(o.dependentsInfo),
    workforceNotes: opt(o.workforceNotes),
  };
}

export function ProbationConversionDialog({ open, onClose, onSubmitted, editConversion, employee }: Props) {
  const isEditing = Boolean(editConversion);
  const theme = useTheme();
  const fieldSx = requestFieldSx(ACCENT);
  const [officialDate, setOfficialDate] = useState('');
  const [reason, setReason] = useState('');
  const [mentorComment, setMentorComment] = useState('');
  const [headDeptComment, setHeadDeptComment] = useState('');
  const [wardNurseHeadComment, setWardNurseHeadComment] = useState('');
  const [hospitalNurseHeadComment, setHospitalNurseHeadComment] = useState('');
  const [scores, setScores] = useState<Record<string, number>>({});
  const [formInfo, setFormInfo] = useState<pcs.ProbationFormTypeInfo | null>(null);
  const [loadingMeta, setLoadingMeta] = useState(false);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [official, setOfficial] = useState<OfficialFormState>(EMPTY_OFFICIAL);
  const [salary, setSalary] = useState<SalaryFormState>(EMPTY_SALARY);
  const [salaryScales, setSalaryScales] = useState<salaryService.AllSalaryScales | null>(null);
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [positions, setPositions] = useState<employeeService.PositionOption[]>([]);
  const [workUnits, setWorkUnits] = useState<departmentService.WorkUnitRow[]>([]);

  const nursingFlow = isNursingBlockTitle(employee?.positionTitle);

  function setOfficialField<K extends keyof OfficialFormState>(key: K, value: OfficialFormState[K]) {
    setOfficial((prev) => ({ ...prev, [key]: value }));
  }

  function setSalaryField<K extends keyof SalaryFormState>(key: K, value: SalaryFormState[K]) {
    setSalary((prev) => ({ ...prev, [key]: value }));
  }

  useEffect(() => {
    if (!open || !employee) return;
    let active = true;
    setErr(null);
    if (editConversion) {
      setOfficialDate(editConversion.officialDate || '');
      setReason(editConversion.reason || '');
      setMentorComment(editConversion.mentorComment || '');
      setHeadDeptComment(editConversion.headDeptComment || '');
      setWardNurseHeadComment(editConversion.wardNurseHeadComment || '');
      setHospitalNurseHeadComment(editConversion.hospitalNurseHeadComment || '');
      setScores(pcs.parseScoresJson(editConversion.scoresJson));
    } else {
      setReason('');
      setMentorComment('');
      setHeadDeptComment('');
      setWardNurseHeadComment('');
      setHospitalNurseHeadComment('');
      setScores({});
      setOfficialDate(new Date().toISOString().slice(0, 10));
    }
    setFormInfo(null);
    if (!editConversion) {
      setOfficial(EMPTY_OFFICIAL);
      setSalary({ ...EMPTY_SALARY, salaryScaleStartDate: new Date().toISOString().slice(0, 10) });
    }
    setWorkUnits([]);
    setLoadingMeta(true);

    Promise.all([employeeService.fetchDepartments(), employeeService.fetchPositions()])
      .then(([d, p]) => {
        if (!active) return;
        setDepartments(d);
        setPositions(p);
      })
      .catch(() => {
        /* danh mục trống — vẫn cho nhập tay phần khác */
      });

    Promise.all([
      employeeService.fetchEmployee(employee.id),
      salaryService.fetchSalaryProfile(employee.id).catch(() => null),
    ])
      .then(([detail, salProfile]) => {
        if (!active || isEditing) return;
        setOfficial(officialFromDetail(detail));
        if (salProfile?.salaryCategory) {
          setSalary({
            enabled: true,
            salaryCategory: salProfile.salaryCategory === 'DOCTOR' ? 'DOCTOR' : 'EMPLOYEE',
            employeeBlock: salProfile.employeeBlock === 'DIRECT' ? 'DIRECT' : 'INDIRECT',
            qualification: salProfile.qualification || salaryService.EMPLOYEE_QUALIFICATIONS[0],
            doctorQualificationCode: salProfile.doctorQualificationCode || 'CCHN',
            priorRaiseYears: String(salProfile.priorRaiseYears ?? 0),
            degreeConversionYears: String(salProfile.degreeConversionYears ?? 0),
            salaryScaleStartDate:
              (salProfile.salaryScaleStartDate || '').slice(0, 10) ||
              new Date().toISOString().slice(0, 10),
            baseSeniorityYears:
              salProfile.baseSeniorityYears != null && !Number.isNaN(Number(salProfile.baseSeniorityYears))
                ? String(salProfile.baseSeniorityYears)
                : '',
            seniorityAsOfDate:
              (salProfile.seniorityAsOfDate || '').slice(0, 10) || salaryService.DEFAULT_SENIORITY_AS_OF,
            ldg: Boolean(salProfile.ldg),
            importedInsuranceSalary:
              salProfile.importedInsuranceSalary != null
                ? String(salProfile.importedInsuranceSalary)
                : '',
            importedProductSalary:
              salProfile.importedProductSalary != null ? String(salProfile.importedProductSalary) : '',
          });
        }
      })
      .catch(() => {
        /* giữ trống — bổ sung tay */
      });

    pcs
      .fetchConversionFormType(employee.id)
      .then((info) => {
        if (!active) return;
        setFormInfo(info);
        setErr(null);
        if (editConversion) {
          setScores(pcs.parseScoresJson(editConversion.scoresJson));
        } else {
          const init: Record<string, number> = {};
          for (const c of info.criteria || []) init[c.code] = 0;
          setScores(init);
        }
      })
      .catch(() => {
        if (!active) return;
        if (!isClinicalPosition(employee.positionTitle)) {
          const fallback = staffFallback(employee);
          setFormInfo(fallback);
          if (editConversion) {
            setScores(pcs.parseScoresJson(editConversion.scoresJson));
          } else {
            const init: Record<string, number> = {};
            for (const c of fallback.criteria) init[c.code] = 0;
            setScores(init);
          }
          setErr(null);
          return;
        }
        setErr('Không xác định được mẫu đánh giá chuyên môn. Vui lòng thử lại.');
      })
      .finally(() => {
        if (active) setLoadingMeta(false);
      });

    return () => {
      active = false;
    };
  }, [open, employee?.id, editConversion]);

  useEffect(() => {
    if (!open || !salaryService.getSalaryAccessToken()) {
      setSalaryScales(null);
      return;
    }
    salaryService.fetchSalaryScales().then(setSalaryScales).catch(() => setSalaryScales(null));
  }, [open]);

  useEffect(() => {
    const startDate = salary.salaryScaleStartDate || officialDate;
    if (!salary.enabled || salary.ldg || salary.salaryCategory !== 'EMPLOYEE' || !salaryScales) {
      return;
    }
    const hasBase =
      salary.baseSeniorityYears.trim() !== '' && !Number.isNaN(Number(salary.baseSeniorityYears));
    if (!hasBase && !startDate) {
      return;
    }
    const years = salaryService.resolveLiveSeniorityYears({
      baseSeniorityYears: salary.baseSeniorityYears,
      seniorityAsOfDate: salary.seniorityAsOfDate,
      salaryScaleStartDate: startDate,
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
    setSalary((prev) => ({
      ...prev,
      importedInsuranceSalary: String(grade.insuranceSalary ?? 0),
      importedProductSalary: String(grade.productSalary ?? 0),
    }));
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
    officialDate,
    salaryScales,
  ]);

  useEffect(() => {
    if (!open || !official.departmentId) {
      setWorkUnits([]);
      return;
    }
    let active = true;
    departmentService
      .fetchWorkUnits(Number(official.departmentId))
      .then((rows) => {
        if (active) setWorkUnits(rows);
      })
      .catch(() => {
        if (active) setWorkUnits([]);
      });
    return () => {
      active = false;
    };
  }, [open, official.departmentId]);

  const workUnitOptions = useMemo(() => {
    const names = workUnits.map((w) => w.name);
    if (official.workUnitDetail && !names.includes(official.workUnitDetail)) {
      return [official.workUnitDetail, ...names];
    }
    return names;
  }, [workUnits, official.workUnitDetail]);

  const totalScore = useMemo(() => {
    if (!formInfo?.requiresScoring) return 0;
    return Object.values(scores).reduce((a, b) => a + (Number(b) || 0), 0);
  }, [formInfo, scores]);

  const gradePreview = useMemo(() => {
    if (!formInfo?.requiresScoring) return null;
    if (formInfo.formType === 'DOCTOR') {
      if (totalScore >= 27) return 'Tốt';
      if (totalScore >= 21) return 'Khá';
      if (totalScore >= 15) return 'Đạt yêu cầu';
      return 'Không đạt';
    }
    if (totalScore >= 90) return 'Xuất sắc';
    if (totalScore >= 75) return 'Khá';
    if (totalScore >= 60) return 'Đạt yêu cầu';
    return 'Chưa đạt';
  }, [formInfo, totalScore]);

  const scorePercent = formInfo?.maxScore
    ? Math.min(100, Math.round((totalScore / formInfo.maxScore) * 100))
    : 0;
  const scoreColor =
    gradePreview === 'Tốt' || gradePreview === 'Xuất sắc'
      ? theme.palette.success.main
      : gradePreview === 'Khá' || gradePreview === 'Đạt yêu cầu'
        ? theme.palette.info.main
        : theme.palette.warning.main;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!employee || !formInfo) return;
    if (!officialDate) {
      setErr('Nhập ngày lên chính thức.');
      return;
    }
    if (!reason.trim()) {
      setErr('Nhập lý do đề nghị.');
      return;
    }
    if (formInfo.requiresScoring) {
      for (const c of formInfo.criteria) {
        const v = scores[c.code];
        if (v == null || Number.isNaN(Number(v))) {
          setErr(`Nhập điểm: ${c.label}`);
          return;
        }
      }
    }

    setLoading(true);
    setErr(null);
    try {
      const conversionPayload = {
        employeeId: employee.id,
        officialDate,
        reason: reason.trim(),
        formType: formInfo.formType,
        mentorComment: mentorComment.trim() || undefined,
        headDeptComment: headDeptComment.trim() || undefined,
        wardNurseHeadComment: wardNurseHeadComment.trim() || undefined,
        hospitalNurseHeadComment: hospitalNurseHeadComment.trim() || undefined,
        scores: formInfo.requiresScoring ? scores : undefined,
      };

      if (isEditing && editConversion) {
        await pcs.updateConversion(editConversion.id, conversionPayload);
        onSubmitted?.();
        onClose();
        return;
      }

      const workforce = toWorkforcePayload(official, employee.fullName, officialDate);
      const insurance = optNum(salary.importedInsuranceSalary);
      try {
        await employeeService.updateEmployee(employee.id, {
          email: official.email.trim() || undefined,
          phone: official.phone.trim() || undefined,
          idCardNumber: official.idCardNumber.trim() || undefined,
          dateOfBirth: official.dateOfBirth || undefined,
          address: official.address.trim() || undefined,
          gender: official.gender.trim() || undefined,
          departmentId: official.departmentId === '' ? undefined : Number(official.departmentId),
          positionId: official.positionId === '' ? undefined : Number(official.positionId),
          hireDate: official.hireDate || undefined,
          status: (employee.status as employeeService.EmployeeUpdatePayload['status']) || 'PROBATION',
          workforce,
          ...(insurance != null ? { baseSalary: insurance } : {}),
        });
      } catch {
        // Không chặn gửi đơn nếu cập nhật hồ sơ phụ thất bại
      }

      if (salary.enabled) {
        try {
          const base = optNum(salary.baseSeniorityYears);
          const startDate = salary.salaryScaleStartDate || officialDate;
          const useMilestone =
            !salary.ldg && salaryService.hasSeniorityMilestone(salary.baseSeniorityYears, startDate);
          await salaryService.upsertSalaryProfile(employee.id, {
            salaryCategory: salary.salaryCategory,
            employeeBlock: salary.salaryCategory === 'EMPLOYEE' ? salary.employeeBlock : null,
            qualification: salary.salaryCategory === 'EMPLOYEE' ? salary.qualification : null,
            doctorQualificationCode:
              salary.salaryCategory === 'DOCTOR' ? salary.doctorQualificationCode : null,
            degreeConversionYears: optNum(salary.degreeConversionYears) ?? 0,
            priorRaiseYears: optNum(salary.priorRaiseYears) ?? 0,
            professionalAttractionSalary: 0,
            salaryScaleStartDate: startDate,
            baseSeniorityYears: useMilestone ? base ?? null : null,
            seniorityAsOfDate: useMilestone
              ? salary.seniorityAsOfDate || salaryService.DEFAULT_SENIORITY_AS_OF
              : null,
            ldg: salary.ldg,
            fixedGradeLabel: salary.ldg ? 'LĐG' : null,
            importedInsuranceSalary: insurance ?? null,
            importedProductSalary: optNum(salary.importedProductSalary) ?? null,
          });
        } catch {
          // Trưởng khoa có thể không có quyền HR — HCNS cấu hình sau trên trang Lương
        }
      }

      await pcs.createConversion(conversionPayload);
      onSubmitted?.();
      onClose();
    } catch {
      setErr(
        'Gửi đơn thất bại. Kiểm tra quyền (Trưởng khoa / ĐD trưởng), điểm đánh giá hoặc đơn đang chờ duyệt.',
      );
    } finally {
      setLoading(false);
    }
  }

  const statusLabel =
    employee?.status === 'INTERN' ? 'thực tập' : employee?.status === 'PROBATION' ? 'thử việc' : 'thử việc/thực tập';

  const gridSx = {
    display: 'grid',
    gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
    gap: 2,
  } as const;

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading || loadingMeta}
      accent={ACCENT}
      icon={<HowToRegIcon />}
      overline={isEditing ? 'Chỉnh sửa đề nghị ký HĐLĐ chính thức' : 'Đề nghị ký HĐLĐ chính thức'}
      title={isEditing ? 'Chỉnh sửa đơn chuyển chính thức' : 'Lập đơn chuyển chính thức'}
      description={
        employee
          ? `${employee.fullName}${employee.departmentName ? ` · ${employee.departmentName}` : ''}`
          : 'Hoàn thiện thông tin và phiếu đánh giá trong quá trình thử việc'
      }
      formId="probation-conversion-form"
      submitLabel={
        isEditing
          ? 'Lưu thay đổi'
          : nursingFlow
            ? 'Gửi Trưởng phòng ĐD duyệt'
            : 'Gửi đơn'
      }
      error={err}
      onSubmit={submit}
      maxWidth="lg"
    >
      {loadingMeta ? (
        <Box sx={{ py: 4, textAlign: 'center' }}>
          <CircularProgress size={28} />
        </Box>
      ) : (
        <>
          <RequestFlowSteps accent={ACCENT} steps={probationFlowSteps(employee?.positionTitle)} />

          <InfoBanner>
            {nursingFlow ? (
              <>
                Nhân viên khối <strong>ĐD–KTV–HS–Thư ký</strong>: sau khi lập, đơn chuyển{' '}
                <strong>Trưởng phòng Điều dưỡng</strong> → HCNS → Giám đốc.
              </>
            ) : formInfo?.formType === 'STAFF' ? (
              <>
                Mẫu <strong>Nhân viên</strong>: Trưởng khoa/phòng lập đơn, chấm /100 theo phiếu năng lực, sau đó
                HCNS và Giám đốc duyệt.
              </>
            ) : formInfo?.formType === 'DOCTOR' ? (
              <>
                Mẫu <strong>Bác sĩ</strong>: Trưởng khoa lập đơn, chấm /30 theo phiếu năng lực, sau đó HCNS và
                Giám đốc duyệt.
              </>
            ) : (
              <>
                Mẫu <strong>Điều dưỡng</strong>: Điều dưỡng trưởng lập đơn, chấm /100 theo phiếu năng lực, sau
                đó HCNS và Giám đốc duyệt.
              </>
            )}
          </InfoBanner>

          <FormSection
            title="Thông tin đề nghị"
            subtitle="Thông tin nhân viên và ngày dự kiến ký hợp đồng chính thức"
          >
            <Box
              sx={{
                display: 'grid',
                gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
                gap: 1.25,
              }}
            >
              <ReadonlyFact
                accent={ACCENT}
                icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
            label="Nhân viên"
                value={employee?.fullName || ''}
              />
              <ReadonlyFact
                accent={ACCENT}
                icon={<BadgeOutlinedIcon sx={{ fontSize: 16 }} />}
                label="Khoa/phòng · vị trí"
            value={
              employee
                    ? `${employee.departmentName || '—'}${employee.positionTitle ? ` · ${employee.positionTitle}` : ''}`
                    : ''
                }
              />
              {formInfo && (
                <ReadonlyFact
                  accent={ACCENT}
                  label="Mẫu đánh giá"
                  value={`${formInfo.formTypeLabel} · ${statusLabel}`}
                />
              )}
          <DatePickerField
            label="Ngày lên chính thức"
            required
            value={officialDate}
            onChange={setOfficialDate}
                sx={fieldSx}
          />
            </Box>
          <TextField
            required
            fullWidth
            size="small"
            multiline
            minRows={3}
              label="Lý do đề nghị / nội dung đơn"
              placeholder="Nhập nhận xét tổng quát và lý do đề nghị ký HĐLĐ chính thức…"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
              sx={fieldSx}
            />
          </FormSection>

          <FormSection
            title="Bổ sung thông tin chính thức"
            subtitle="Đồng bộ Excel BVMA — hồ sơ đầy đủ + bảng lương & thâm niên (có thể để trống bổ sung sau)"
          >
            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
              Liên hệ & giấy tờ
            </Typography>
            <Box sx={{ ...gridSx, mb: 2.5 }}>
              <TextField
                size="small"
                label="Điện thoại"
                value={official.phone}
                onChange={(e) => setOfficialField('phone', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Email"
                value={official.email}
                onChange={(e) => setOfficialField('email', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                select
                label="Giới tính"
                value={official.gender}
                onChange={(e) => setOfficialField('gender', e.target.value)}
                fullWidth
                sx={fieldSx}
              >
                <MenuItem value="">—</MenuItem>
                <MenuItem value="Nam">Nam</MenuItem>
                <MenuItem value="Nữ">Nữ</MenuItem>
                <MenuItem value="Khác">Khác</MenuItem>
              </TextField>
              <DatePickerField
                label="Ngày sinh"
                value={official.dateOfBirth}
                onChange={(v) => setOfficialField('dateOfBirth', v)}
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="CCCD/CMND"
                value={official.idCardNumber}
                onChange={(e) => setOfficialField('idCardNumber', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <DatePickerField
                label="Ngày cấp CCCD/CMND"
                value={official.idCardIssueDate}
                onChange={(v) => setOfficialField('idCardIssueDate', v)}
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Dân tộc"
                value={official.ethnicity}
                onChange={(e) => setOfficialField('ethnicity', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Nguyên quán"
                value={official.placeOfOrigin}
                onChange={(e) => setOfficialField('placeOfOrigin', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                select
                label="Tình trạng hôn nhân"
                value={official.maritalStatus}
                onChange={(e) => setOfficialField('maritalStatus', e.target.value)}
                fullWidth
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
                value={official.bloodType}
                onChange={(e) => setOfficialField('bloodType', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Người liên hệ khẩn cấp"
                value={official.emergencyContact}
                onChange={(e) => setOfficialField('emergencyContact', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="SĐT liên hệ khẩn cấp"
                value={official.emergencyPhone}
                onChange={(e) => setOfficialField('emergencyPhone', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Địa chỉ"
                value={official.address}
                onChange={(e) => setOfficialField('address', e.target.value)}
                fullWidth
                multiline
                minRows={2}
                sx={{ ...fieldSx, gridColumn: { sm: '1 / -1' } }}
              />
            </Box>

            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
              Công việc
            </Typography>
            <Box sx={{ ...gridSx, mb: 2.5 }}>
              <TextField
                size="small"
                select
                label="Phòng ban"
                value={official.departmentId}
                onChange={(e) => {
                  const id = e.target.value === '' ? '' : Number(e.target.value);
                  setOfficial((prev) => ({ ...prev, departmentId: id, workUnitDetail: '' }));
                }}
                fullWidth
                sx={fieldSx}
              >
                <MenuItem value="">—</MenuItem>
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
                value={official.positionId}
                onChange={(e) =>
                  setOfficialField('positionId', e.target.value === '' ? '' : Number(e.target.value))
                }
                fullWidth
                sx={fieldSx}
              >
                <MenuItem value="">—</MenuItem>
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
                  value={official.workUnitDetail}
                  onChange={(e) => setOfficialField('workUnitDetail', e.target.value)}
                  fullWidth
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
                  value={official.workUnitDetail}
                  onChange={(e) => setOfficialField('workUnitDetail', e.target.value)}
                  fullWidth
                  sx={fieldSx}
                  placeholder="VD: THU NGÂN"
                />
              )}
              <TextField
                size="small"
                label="Mã chấm công"
                value={official.attendanceCode}
                onChange={(e) => setOfficialField('attendanceCode', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <DatePickerField
                label="Ngày vào làm"
                value={official.hireDate}
                onChange={(v) => setOfficialField('hireDate', v)}
                sx={fieldSx}
              />
              <DatePickerField
                label="Ngày bắt đầu thử việc"
                value={official.probationStartDate}
                onChange={(v) => setOfficialField('probationStartDate', v)}
                sx={fieldSx}
              />
            </Box>

            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
              Chuyên môn & chứng chỉ
            </Typography>
            <Box sx={{ ...gridSx, mb: 2.5 }}>
              <TextField
                size="small"
                label="Chuyên ngành / chuyên môn"
                value={official.specialty}
                onChange={(e) => setOfficialField('specialty', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Trình độ / bằng cấp"
                value={official.degree}
                onChange={(e) => setOfficialField('degree', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Văn bằng chuyên môn"
                value={official.professionalDiploma}
                onChange={(e) => setOfficialField('professionalDiploma', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Phạm vi hành nghề"
                value={official.practiceScope}
                onChange={(e) => setOfficialField('practiceScope', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Số CCHN"
                value={official.practiceCertNumber}
                onChange={(e) => setOfficialField('practiceCertNumber', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Ngày cấp CCHN"
                placeholder="dd/mm/yyyy"
                value={official.practiceCertDateRaw}
                onChange={(e) => setOfficialField('practiceCertDateRaw', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="CKI"
                value={official.cki}
                onChange={(e) => setOfficialField('cki', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Chứng chỉ đào tạo khác"
                value={official.otherTrainingCertificates}
                onChange={(e) => setOfficialField('otherTrainingCertificates', e.target.value)}
                fullWidth
                multiline
                minRows={2}
                sx={{ ...fieldSx, gridColumn: { sm: '1 / -1' } }}
              />
            </Box>

            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1, display: 'flex', alignItems: 'center', gap: 0.75 }}>
              <PaymentsIcon sx={{ fontSize: 16, color: ACCENT }} />
              Bảng lương & thâm niên
            </Typography>
            <Box sx={{ ...gridSx, mb: 2.5 }}>
              <FormControlLabel
                sx={{ gridColumn: { sm: '1 / -1' } }}
                control={
                  <Checkbox
                    checked={salary.enabled}
                    onChange={(e) => setSalaryField('enabled', e.target.checked)}
                  />
                }
                label="Thiết lập hồ sơ lương / thâm niên khi lên chính thức"
              />
              {salary.enabled && (
                <>
                  <TextField
                    size="small"
                    select
                    label="Đối tượng lương"
                    value={salary.salaryCategory}
                    onChange={(e) =>
                      setSalaryField('salaryCategory', e.target.value as 'DOCTOR' | 'EMPLOYEE')
                    }
                    fullWidth
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
                        value={salary.employeeBlock}
                        onChange={(e) =>
                          setSalaryField('employeeBlock', e.target.value as 'DIRECT' | 'INDIRECT')
                        }
                        fullWidth
                        sx={fieldSx}
                      >
                        <MenuItem value="DIRECT">Trực tiếp</MenuItem>
                        <MenuItem value="INDIRECT">Gián tiếp</MenuItem>
                      </TextField>
                      <TextField
                        size="small"
                        select
                        label="Trình độ (thang bảng lương)"
                        value={salary.qualification}
                        onChange={(e) => setSalaryField('qualification', e.target.value)}
                        fullWidth
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
                        value={salary.doctorQualificationCode}
                        onChange={(e) => setSalaryField('doctorQualificationCode', e.target.value)}
                        fullWidth
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
                        value={salary.degreeConversionYears}
                        onChange={(e) => setSalaryField('degreeConversionYears', e.target.value)}
                        fullWidth
                        sx={fieldSx}
                      />
                    </>
                  )}
                  <DatePickerField
                    label="Bắt đầu tính thang bảng lương"
                    value={salary.salaryScaleStartDate || officialDate}
                    onChange={(v) => setSalaryField('salaryScaleStartDate', v)}
                    helperText="Dùng khi không có mốc thâm niên 30/06"
                    sx={fieldSx}
                  />
                  <TextField
                    size="small"
                    label="Thâm niên mốc 30/06 (năm)"
                    type="number"
                    value={salary.baseSeniorityYears}
                    onChange={(e) => setSalaryField('baseSeniorityYears', e.target.value)}
                    fullWidth
                    inputProps={{ min: 0, step: 0.000001 }}
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
                        salary.salaryScaleStartDate || officialDate,
                      )
                    }
                    sx={fieldSx}
                  />
                  <TextField
                    size="small"
                    label="Thâm niên hiện tại"
                    value={salaryService.formatLiveSeniorityPreview({
                      baseSeniorityYears: salary.baseSeniorityYears,
                      seniorityAsOfDate: salary.seniorityAsOfDate,
                      salaryScaleStartDate: salary.salaryScaleStartDate || officialDate,
                      priorRaiseYears: salary.priorRaiseYears,
                      degreeConversionYears: salary.degreeConversionYears,
                      ldg: salary.ldg,
                    })}
                    fullWidth
                    helperText="Có mốc (>0): mốc + (hôm nay − 30/06)/365 · Không mốc: từ ngày bắt đầu thang"
                    InputProps={{ readOnly: true }}
                    sx={fieldSx}
                  />
                  <TextField
                    size="small"
                    label="Quy đổi nâng lương sớm (năm — tổng)"
                    type="number"
                    value={salary.priorRaiseYears}
                    onChange={(e) => setSalaryField('priorRaiseYears', e.target.value)}
                    fullWidth
                    helperText="Chi tiết theo ngày trên trang Lương"
                    sx={fieldSx}
                  />
                  <TextField
                    size="small"
                    label="Lương cơ bản / đóng BH"
                    type="number"
                    value={salary.importedInsuranceSalary}
                    onChange={(e) => setSalaryField('importedInsuranceSalary', e.target.value)}
                    fullWidth
                    InputProps={{
                      readOnly: salary.salaryCategory === 'EMPLOYEE' && !salary.ldg && Boolean(salaryScales),
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
                    label="Lương đảm bảo SP"
                    type="number"
                    value={salary.importedProductSalary}
                    onChange={(e) => setSalaryField('importedProductSalary', e.target.value)}
                    fullWidth
                    InputProps={{
                      readOnly: salary.salaryCategory === 'EMPLOYEE' && !salary.ldg && Boolean(salaryScales),
                    }}
                    helperText={
                      salary.salaryCategory === 'EMPLOYEE' && !salary.ldg && salaryScales
                        ? 'Tự động theo thâm niên và bậc lương'
                        : undefined
                    }
                    sx={fieldSx}
                  />
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={salary.ldg}
                        onChange={(e) => setSalaryField('ldg', e.target.checked)}
                      />
                    }
                    label="LĐG — bậc cố định"
                  />
                </>
              )}
            </Box>

            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
              Lương & ngân hàng
            </Typography>
            <Box sx={{ ...gridSx, mb: 2.5 }}>
              <TextField
                size="small"
                label="Tên hiển thị bảng lương"
                value={official.payrollDisplayName}
                onChange={(e) => setOfficialField('payrollDisplayName', e.target.value)}
                fullWidth
                sx={fieldSx}
                placeholder={employee?.fullName || 'Theo họ tên'}
              />
              <TextField
                size="small"
                label="STK nhận lương"
                value={official.bankAccount}
                onChange={(e) => setOfficialField('bankAccount', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Ngân hàng nhận lương"
                value={official.bankName}
                onChange={(e) => setOfficialField('bankName', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
            </Box>

            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
              Bảo hiểm
            </Typography>
            <Box sx={{ ...gridSx, mb: 2.5 }}>
              <TextField
                size="small"
                select
                label="Tham gia BHXH"
                value={official.insuranceParticipation}
                onChange={(e) => setOfficialField('insuranceParticipation', e.target.value)}
                fullWidth
                sx={fieldSx}
              >
                <MenuItem value="">— Để trống —</MenuItem>
                <MenuItem value="Có tham gia">Có tham gia</MenuItem>
                <MenuItem value="Không tham gia">Không tham gia</MenuItem>
                <MenuItem value="Nghỉ thai sản">Nghỉ thai sản</MenuItem>
              </TextField>
              <TextField
                size="small"
                label="Số sổ BHXH"
                value={official.socialInsuranceBook}
                onChange={(e) => setOfficialField('socialInsuranceBook', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
            </Box>

            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
              Hợp đồng lao động
            </Typography>
            <Box sx={{ ...gridSx, mb: 2.5 }}>
              <TextField
                size="small"
                label="Số hợp đồng"
                value={official.contractNumber}
                onChange={(e) => setOfficialField('contractNumber', e.target.value)}
                fullWidth
                sx={fieldSx}
              />
              <DatePickerField
                label="Ngày ký hợp đồng"
                value={official.contractSignDate}
                onChange={(v) => setOfficialField('contractSignDate', v)}
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Thời hạn hợp đồng"
                value={official.contractTerm}
                onChange={(e) => setOfficialField('contractTerm', e.target.value)}
                fullWidth
                sx={fieldSx}
                placeholder="VD: 12 tháng / Không xác định thời hạn"
              />
            </Box>

            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
              Thông tin bổ sung
            </Typography>
            <Box sx={gridSx}>
              <TextField
                size="small"
                label="Người phụ thuộc"
                value={official.dependentsInfo}
                onChange={(e) => setOfficialField('dependentsInfo', e.target.value)}
                fullWidth
                multiline
                minRows={2}
                sx={fieldSx}
              />
              <TextField
                size="small"
                label="Ghi chú"
                value={official.workforceNotes}
                onChange={(e) => setOfficialField('workforceNotes', e.target.value)}
                fullWidth
                multiline
                minRows={2}
                sx={fieldSx}
              />
            </Box>
          </FormSection>

          {formInfo?.requiresScoring && (
            <FormSection
              title="Phiếu đánh giá năng lực"
              subtitle={`Chấm từng tiêu chí theo mẫu ${formInfo.formTypeLabel.toLowerCase()} · Tổng tối đa ${formInfo.maxScore} điểm`}
            >
              {formInfo.criteria.map((c, index) => (
                <Box
                  key={c.code}
                  sx={{
                    display: 'grid',
                    gridTemplateColumns: { xs: '1fr', sm: 'minmax(0, 1fr) 112px' },
                    gap: { xs: 1.5, sm: 2.5 },
                    alignItems: 'center',
                    p: { xs: 1.75, sm: 2 },
                    border: '1px solid',
                    borderColor: alpha(theme.palette.divider, 0.9),
                    borderRadius: 2.5,
                    bgcolor: '#fff',
                    transition: 'border-color .2s, box-shadow .2s',
                    '&:focus-within': {
                      borderColor: alpha('#0f766e', 0.55),
                      boxShadow: `0 0 0 3px ${alpha('#0f766e', 0.08)}`,
                    },
                  }}
                >
                  <Stack direction="row" spacing={1.5} alignItems="flex-start">
                    <Box
                      sx={{
                        width: 32,
                        height: 32,
                        borderRadius: 2,
                        display: 'grid',
                        placeItems: 'center',
                        bgcolor: alpha('#0f766e', 0.09),
                        color: '#0f766e',
                        fontSize: '0.8rem',
                        fontWeight: 800,
                        flexShrink: 0,
                      }}
                    >
                      {String(index + 1).padStart(2, '0')}
                    </Box>
                    <Box sx={{ minWidth: 0 }}>
                      <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap" useFlexGap>
                        <Typography variant="subtitle2" fontWeight={800}>
                          {c.label}
                        </Typography>
                        <Chip
                          size="small"
                          label={`Tối đa ${c.maxScore}đ`}
                          sx={{
                            height: 21,
                            bgcolor: alpha('#0f766e', 0.07),
                            color: '#0f766e',
                            fontWeight: 700,
                            '& .MuiChip-label': { px: 0.8, fontSize: '0.68rem' },
                          }}
                        />
                      </Stack>
                      <Typography variant="body2" color="text.secondary" sx={{ mt: 0.6, lineHeight: 1.55 }}>
                        {c.detail}
                      </Typography>
                    </Box>
                  </Stack>
                  {c.maxScore <= 10 ? (
                    <TextField
                      select
                      size="small"
                      label="Điểm"
                      value={scores[c.code] ?? 0}
                      onChange={(e) =>
                        setScores((prev) => ({ ...prev, [c.code]: Number(e.target.value) }))
                      }
                      sx={{ width: { xs: '100%', sm: 112 } }}
                    >
                      {Array.from({ length: c.maxScore + 1 }, (_, i) => (
                        <MenuItem key={i} value={i}>
                          {i}
                        </MenuItem>
                      ))}
                    </TextField>
                  ) : (
                    <TextField
                      type="number"
                      size="small"
                      label="Điểm"
                      value={scores[c.code] ?? 0}
                      inputProps={{ min: 0, max: c.maxScore, step: 1 }}
                      onChange={(e) => {
                        const n = Math.max(0, Math.min(c.maxScore, Number(e.target.value) || 0));
                        setScores((prev) => ({ ...prev, [c.code]: n }));
                      }}
                      sx={{ width: { xs: '100%', sm: 112 } }}
                    />
                  )}
                </Box>
              ))}
              <Box
                sx={{
                  p: 2,
                  borderRadius: 2.5,
                  border: `1px solid ${alpha(scoreColor, 0.35)}`,
                  bgcolor: alpha(scoreColor, 0.045),
                }}
              >
                <Stack
                  direction={{ xs: 'column', sm: 'row' }}
                  justifyContent="space-between"
                  alignItems={{ xs: 'flex-start', sm: 'center' }}
                  spacing={1}
                >
                  <Stack direction="row" spacing={1} alignItems="center">
                    <CheckCircleOutlineIcon sx={{ color: scoreColor, fontSize: 21 }} />
                    <Typography variant="body2" fontWeight={700}>
                      Kết quả đánh giá
                    </Typography>
                  </Stack>
                  <Stack direction="row" spacing={1} alignItems="center">
                    <Typography variant="h6" fontWeight={900} sx={{ color: scoreColor }}>
                      {totalScore}/{formInfo.maxScore}
                    </Typography>
                    <Chip
                      size="small"
                      label={gradePreview}
                      sx={{ bgcolor: scoreColor, color: '#fff', fontWeight: 800 }}
                    />
                  </Stack>
        </Stack>
                <LinearProgress
                  variant="determinate"
                  value={scorePercent}
                  sx={{
                    mt: 1.5,
                    height: 7,
                    borderRadius: 10,
                    bgcolor: alpha(scoreColor, 0.12),
                    '& .MuiLinearProgress-bar': { bgcolor: scoreColor, borderRadius: 10 },
                  }}
                />
              </Box>
            </FormSection>
          )}

          {formInfo?.requiresScoring && (
            <FormSection
              title="Nhận xét chuyên môn"
              subtitle="Ý kiến của các cấp phụ trách trong thời gian thử việc"
            >
              <TextField
                fullWidth
                size="small"
                multiline
                minRows={2}
                label="Ý kiến của người hướng dẫn"
                placeholder="Nhận xét năng lực, thái độ và mức độ hoàn thành công việc…"
                value={mentorComment}
                onChange={(e) => setMentorComment(e.target.value)}
                sx={fieldSx}
              />
              <TextField
                fullWidth
                size="small"
                multiline
                minRows={2}
                label={
                  formInfo.formType === 'STAFF'
                    ? 'Đánh giá của Trưởng khoa/phòng'
                    : 'Đánh giá của Trưởng khoa'
                }
                placeholder={
                  formInfo.formType === 'STAFF'
                    ? 'Kết luận và đề xuất của Trưởng khoa/phòng…'
                    : 'Kết luận và đề xuất của Trưởng khoa…'
                }
                value={headDeptComment}
                onChange={(e) => setHeadDeptComment(e.target.value)}
                sx={fieldSx}
              />
              {formInfo.formType === 'NURSE' && (
                <>
                  <TextField
                    fullWidth
                    size="small"
                    multiline
                    minRows={2}
                    label="Đánh giá của Điều dưỡng trưởng khoa"
                    placeholder="Nhận xét của Điều dưỡng trưởng khoa…"
                    value={wardNurseHeadComment}
                    onChange={(e) => setWardNurseHeadComment(e.target.value)}
                    sx={fieldSx}
                  />
                  <TextField
                    fullWidth
                    size="small"
                    multiline
                    minRows={2}
                    label="Đánh giá của Điều dưỡng trưởng bệnh viện"
                    placeholder="Kết luận của Điều dưỡng trưởng bệnh viện…"
                    value={hospitalNurseHeadComment}
                    onChange={(e) => setHospitalNurseHeadComment(e.target.value)}
                    sx={fieldSx}
                  />
                </>
              )}
            </FormSection>
          )}
        </>
      )}
    </WorkRequestDialogShell>
  );
}
