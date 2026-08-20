import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import CakeOutlinedIcon from '@mui/icons-material/CakeOutlined';
import HomeOutlinedIcon from '@mui/icons-material/HomeOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import PhoneOutlinedIcon from '@mui/icons-material/PhoneOutlined';
import SchoolOutlinedIcon from '@mui/icons-material/SchoolOutlined';
import WcOutlinedIcon from '@mui/icons-material/WcOutlined';
import { Box, CircularProgress, TextField } from '@mui/material';
import { useEffect, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import {
  FormSection,
  InfoBanner,
  ReadonlyFact,
  RequestFlowSteps,
  WorkRequestDialogShell,
  requestFieldSx,
} from './work/WorkRequestFormUi';
import * as mda from '../services/mainDutyAuthorizationService';
import * as employeeService from '../services/employeeService';
import { extractApiErrorMessage } from '../services/approvalSignatureService';
import { isNursingBlockTitle, mainDutyFlowSteps } from '../utils/nursingBlock';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  editAuthorization?: mda.MainDutyAuthorization | null;
  employee: {
    id: number;
    fullName: string;
    departmentName?: string;
    positionTitle?: string;
    dateOfBirth?: string | null;
  } | null;
};

const ACCENT = '#5b4bb4';
const fieldSx = requestFieldSx(ACCENT);

type ProfileFacts = {
  fullName: string;
  positionTitle: string;
  departmentName: string;
  dateOfBirth: string;
  phone: string;
  gender: string;
  address: string;
  degree: string;
};

function guessFormLabel(positionTitle?: string | null) {
  const p = (positionTitle || '').toLowerCase();
  if (p.includes('bác sĩ') || p.includes('bac si') || /\bbs\b/.test(p)) return 'Bác sĩ';
  if (
    p.includes('điều dưỡng') ||
    p.includes('dieu duong') ||
    p.includes('y tá') ||
    p.includes('y ta')
  ) {
    return 'Điều dưỡng';
  }
  return 'Bác sĩ / Điều dưỡng';
}

function normalizeGender(raw?: string | null) {
  if (!raw) return '';
  const g = raw.trim().toLowerCase();
  if (g === 'nam' || g === 'male' || g === 'm') return 'Nam';
  if (g === 'nữ' || g === 'nu' || g === 'female' || g === 'f') return 'Nữ';
  if (raw === 'Nam' || raw === 'Nữ') return raw;
  return raw.trim();
}

function formatDob(iso?: string | null) {
  if (!iso) return '';
  return mda.formatMainDutyDate(iso);
}

function emptyProfile(employee: NonNullable<Props['employee']>): ProfileFacts {
  return {
    fullName: employee.fullName,
    positionTitle: employee.positionTitle || '',
    departmentName: employee.departmentName || '',
    dateOfBirth: formatDob(employee.dateOfBirth),
    phone: '',
    gender: '',
    address: '',
    degree: '',
  };
}

export function MainDutyAuthorizationDialog({ open, onClose, onSubmitted, editAuthorization, employee }: Props) {
  const isEditing = Boolean(editAuthorization);
  const [accompanyingFrom, setAccompanyingFrom] = useState('');
  const [accompanyingTo, setAccompanyingTo] = useState('');
  const [effectiveFrom, setEffectiveFrom] = useState('');
  const [reason, setReason] = useState('');
  const [profile, setProfile] = useState<ProfileFacts | null>(null);
  const [profileLoading, setProfileLoading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const formLabel = guessFormLabel(employee?.positionTitle || profile?.positionTitle);
  const nursingFlow = isNursingBlockTitle(employee?.positionTitle || profile?.positionTitle);

  useEffect(() => {
    if (!open || !employee) return;
    let active = true;
    setErr(null);
    if (editAuthorization) {
      setAccompanyingFrom(editAuthorization.accompanyingFrom || '');
      setAccompanyingTo(editAuthorization.accompanyingTo || '');
      setEffectiveFrom(editAuthorization.effectiveFrom || '');
      setReason(editAuthorization.reason || '');
    } else {
      setAccompanyingFrom('');
      setAccompanyingTo('');
      setEffectiveFrom('');
      setReason('');
    }
    setProfile(emptyProfile(employee));
    setProfileLoading(true);

    employeeService
      .fetchEmployee(employee.id)
      .then((detail) => {
        if (!active) return;
        const p = (detail.workforceProfile || {}) as Record<string, unknown>;
        setProfile({
          fullName: detail.fullName || employee.fullName,
          positionTitle: detail.positionTitle || employee.positionTitle || '',
          departmentName: detail.departmentName || employee.departmentName || '',
          dateOfBirth: formatDob(detail.dateOfBirth || employee.dateOfBirth),
          phone: editAuthorization?.phone?.trim() || (detail.phone || '').trim(),
          gender: normalizeGender(editAuthorization?.gender || detail.gender),
          address: editAuthorization?.address?.trim() || (detail.address || '').trim(),
          degree:
            editAuthorization?.degree?.trim()
            || (p.degree != null ? String(p.degree).trim() : ''),
        });
      })
      .catch(() => {
        /* giữ thông tin tối thiểu từ props */
      })
      .finally(() => {
        if (active) setProfileLoading(false);
      });

    return () => {
      active = false;
    };
  }, [open, employee, editAuthorization]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!employee || !profile) return;
    if (!accompanyingFrom || !accompanyingTo || !effectiveFrom) {
      setErr('Nhập đủ thời gian trực kèm và ngày hiệu lực trực chính.');
      return;
    }
    setLoading(true);
    setErr(null);
    try {
      const payload = {
        employeeId: employee.id,
        accompanyingFrom,
        accompanyingTo,
        effectiveFrom,
        phone: profile.phone || undefined,
        address: profile.address || undefined,
        gender: profile.gender || undefined,
        degree: profile.degree || undefined,
        reason: reason.trim() || undefined,
      };
      if (isEditing && editAuthorization) {
        await mda.updateMainDutyAuthorization(editAuthorization.id, payload);
      } else {
        await mda.createMainDutyAuthorization(payload);
      }
      onSubmitted?.();
      onClose();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Gửi đơn thất bại.'));
    } finally {
      setLoading(false);
    }
  }

  if (!employee) return null;

  const facts = profile ?? emptyProfile(employee);

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={ACCENT}
      icon={<NightsStayIcon />}
      overline={
        isEditing
          ? `Chỉnh sửa đơn trực chính · ${formLabel}`
          : `Đơn được trực chính · ${formLabel}`
      }
      title={
        isEditing
          ? 'Chỉnh sửa đề nghị trực chính'
          : 'Đề nghị chuyển từ trực kèm lên trực chính'
      }
      description="Sau khi Giám đốc duyệt, nhân viên được chọn các loại ca trực chính (1, 3, 5) ngoài Trực kèm."
      formId="main-duty-auth-form"
      submitLabel={
        loading
          ? 'Đang gửi…'
          : isEditing
            ? 'Lưu thay đổi'
            : nursingFlow
              ? 'Gửi Trưởng phòng ĐD duyệt'
              : 'Gửi đơn'
      }
      error={err}
      onSubmit={handleSubmit}
      maxWidth="md"
    >
      <RequestFlowSteps
        accent={ACCENT}
        steps={mainDutyFlowSteps(employee?.positionTitle || profile?.positionTitle)}
      />

      <InfoBanner>
        {nursingFlow ? (
          <>
            Mẫu <strong>{formLabel}</strong> — khối ĐD–KTV–HS–Thư ký: sau khi lập, đơn chuyển{' '}
            <strong>Trưởng phòng Điều dưỡng</strong> rồi Giám đốc. Trước khi duyệt, chỉ được nhập ca{' '}
            <strong>Trực kèm (TK)</strong>.
          </>
        ) : (
          <>
            Mẫu <strong>{formLabel}</strong> — hệ thống tự xác định loại đơn theo chức danh. Trước khi
            duyệt, chỉ được nhập ca <strong>Trực kèm (TK)</strong>.
          </>
        )}
      </InfoBanner>

      <FormSection
        title="Thông tin nhân viên"
        subtitle="Lấy từ hồ sơ — không cần nhập lại"
      >
        {profileLoading ? (
          <Box sx={{ py: 2.5, textAlign: 'center' }}>
            <CircularProgress size={24} sx={{ color: ACCENT }} />
          </Box>
        ) : (
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
              label="Họ và tên"
              value={facts.fullName}
            />
            <ReadonlyFact
              accent={ACCENT}
              icon={<BadgeOutlinedIcon sx={{ fontSize: 16 }} />}
              label="Chức danh"
              value={facts.positionTitle}
            />
            <ReadonlyFact
              accent={ACCENT}
              icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
              label="Khoa / phòng"
              value={facts.departmentName}
            />
            <ReadonlyFact
              accent={ACCENT}
              icon={<CakeOutlinedIcon sx={{ fontSize: 16 }} />}
              label="Ngày sinh"
              value={facts.dateOfBirth}
            />
            <ReadonlyFact
              accent={ACCENT}
              icon={<PhoneOutlinedIcon sx={{ fontSize: 16 }} />}
              label="Điện thoại"
              value={facts.phone}
            />
            <ReadonlyFact
              accent={ACCENT}
              icon={<WcOutlinedIcon sx={{ fontSize: 16 }} />}
              label="Giới tính"
              value={facts.gender}
            />
            <ReadonlyFact
              accent={ACCENT}
              icon={<HomeOutlinedIcon sx={{ fontSize: 16 }} />}
              label="Địa chỉ"
              value={facts.address}
            />
            <ReadonlyFact
              accent={ACCENT}
              icon={<SchoolOutlinedIcon sx={{ fontSize: 16 }} />}
              label="Bằng cấp / trình độ"
              value={facts.degree}
            />
          </Box>
        )}
      </FormSection>

      <FormSection
        title="Thời gian & hiệu lực"
        subtitle="Thời gian đã trực kèm và ngày bắt đầu được trực chính"
      >
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
            gap: 1.75,
          }}
        >
          <DatePickerField
            label="Trực kèm từ ngày"
            required
            fullWidth
            size="small"
            value={accompanyingFrom}
            onChange={setAccompanyingFrom}
            sx={fieldSx}
          />
          <DatePickerField
            label="Trực kèm đến ngày"
            required
            fullWidth
            size="small"
            value={accompanyingTo}
            onChange={setAccompanyingTo}
            sx={fieldSx}
          />
          <Box sx={{ gridColumn: { xs: '1', sm: '1 / -1' }, maxWidth: { sm: 'calc(50% - 0.875rem)' } }}>
            <DatePickerField
              label="Hiệu lực trực chính từ"
              required
              fullWidth
              size="small"
              value={effectiveFrom}
              onChange={setEffectiveFrom}
              sx={fieldSx}
            />
          </Box>
        </Box>
      </FormSection>

      <FormSection title="Lý do / đề nghị" subtitle="Tuỳ chọn — theo mẫu đơn giấy">
        <TextField
          label="Nội dung đề nghị"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          fullWidth
          size="small"
          multiline
          minRows={3}
          placeholder="Đề nghị chuyển từ trực kèm lên trực chính…"
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
