import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CheckBoxOutlinedIcon from '@mui/icons-material/CheckBoxOutlined';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import MenuBookOutlinedIcon from '@mui/icons-material/MenuBookOutlined';
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import SchoolOutlinedIcon from '@mui/icons-material/SchoolOutlined';
import {
  Box,
  Checkbox,
  FormControlLabel,
  InputAdornment,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import { FormSection, InfoBanner, RequestFlowSteps, WorkRequestDialogShell } from './work/WorkRequestFormUi';
import * as tps from '../services/trainingProposalService';
import { extractApiErrorMessage } from '../services/approvalSignatureService';

function formatPeriodLabel(fromIso: string, toIso: string) {
  return `${tps.formatTrainingDate(fromIso)} – ${tps.formatTrainingDate(toIso)}`;
}

function parsePlannedPeriod(period?: string | null): { from: string; to: string } | null {
  if (!period?.trim()) return null;
  const parts = period.split(/\s*[–-]\s*/);
  if (parts.length !== 2) return null;
  const toIso = (raw: string) => {
    const m = raw.trim().match(/^(\d{1,2})[/.](\d{1,2})[/.](\d{4})$/);
    if (!m) return '';
    return `${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`;
  };
  const from = toIso(parts[0]);
  const to = toIso(parts[1]);
  if (!from || !to) return null;
  return { from, to };
}

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  editProposal?: tps.TrainingProposal | null;
  employee: {
    id: number;
    fullName: string;
    departmentName?: string;
    positionTitle?: string;
    dateOfBirth?: string | null;
  } | null;
};

const ACCENT = '#0369a1';

const fieldSx = {
  '& .MuiOutlinedInput-root': {
    borderRadius: 2.25,
    bgcolor: '#fff',
    transition: 'border-color .18s, box-shadow .18s',
    '&:hover .MuiOutlinedInput-notchedOutline': {
      borderColor: alpha(ACCENT, 0.4),
    },
    '&.Mui-focused': {
      boxShadow: `0 0 0 3px ${alpha(ACCENT, 0.12)}`,
    },
    '&.Mui-disabled': {
      bgcolor: alpha('#0f172a', 0.02),
    },
  },
  '& .MuiInputLabel-root.Mui-focused': { color: ACCENT },
};

function adornment(icon: React.ReactNode) {
  return {
    startAdornment: (
      <InputAdornment position="start">
        <Box sx={{ display: 'flex', color: 'text.secondary', opacity: 0.72 }}>{icon}</Box>
      </InputAdornment>
    ),
  };
}

const EMP_COMMITMENT =
  'Thực hiện đầy đủ khoá học, tuân thủ quy định Bệnh viện và đơn vị đào tạo; báo cáo kết quả học tập; thực hiện nghĩa vụ làm việc sau đào tạo theo Hợp đồng đào tạo chuyên môn.';

const DEPT_COMMITMENT =
  'Bố trí, sắp xếp công việc và nhân lực trong thời gian đi học; theo dõi, giám sát và phối hợp HCNS đánh giá hiệu quả; tạo điều kiện ứng dụng kết quả đào tạo vào chuyên môn.';

function ReadonlyFact({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <Box
      sx={{
        p: 1.5,
        borderRadius: 2.25,
        bgcolor: alpha(ACCENT, 0.035),
        border: `1px solid ${alpha(ACCENT, 0.1)}`,
        height: '100%',
      }}
    >
      <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mb: 0.55 }}>
        <Box sx={{ color: ACCENT, display: 'flex', opacity: 0.85, lineHeight: 0 }}>{icon}</Box>
        <Typography
          variant="caption"
          sx={{
            fontWeight: 700,
            letterSpacing: '0.04em',
            textTransform: 'uppercase',
            fontSize: '0.65rem',
            color: 'text.secondary',
          }}
        >
          {label}
        </Typography>
      </Stack>
      <Typography variant="body2" fontWeight={750} sx={{ lineHeight: 1.45, pl: 3.1 }}>
        {value || '—'}
      </Typography>
    </Box>
  );
}

function CommitmentCard({
  checked,
  onChange,
  title,
  body,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  title: string;
  body: string;
}) {
  return (
    <Box
      sx={{
        p: 1.75,
        borderRadius: 2.5,
        bgcolor: checked ? alpha(ACCENT, 0.05) : alpha('#0f172a', 0.02),
        border: `1px solid ${checked ? alpha(ACCENT, 0.28) : alpha('#0f172a', 0.08)}`,
        transition: 'background-color .18s, border-color .18s',
      }}
    >
      <FormControlLabel
        control={
          <Checkbox
            checked={checked}
            onChange={(e) => onChange(e.target.checked)}
            sx={{
              color: alpha(ACCENT, 0.45),
              '&.Mui-checked': { color: ACCENT },
              mt: -0.25,
            }}
          />
        }
        label={
          <Box sx={{ pt: 0.35 }}>
            <Typography variant="subtitle2" fontWeight={800} sx={{ color: ACCENT, mb: 0.45 }}>
              {title}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.65 }}>
              {body}
            </Typography>
          </Box>
        }
        sx={{ alignItems: 'flex-start', ml: 0, mr: 0, width: '100%' }}
      />
    </Box>
  );
}

export function TrainingProposalDialog({ open, onClose, onSubmitted, editProposal, employee }: Props) {
  const isEditing = Boolean(editProposal);
  const [proposingDepartment, setProposingDepartment] = useState('');
  const [courseName, setCourseName] = useState('');
  const [location, setLocation] = useState('');
  const [periodFrom, setPeriodFrom] = useState('');
  const [periodTo, setPeriodTo] = useState('');
  const [tuitionFee, setTuitionFee] = useState('');
  const [trainingGoal, setTrainingGoal] = useState('');
  const [reason, setReason] = useState('');
  const [employeeAck, setEmployeeAck] = useState(false);
  const [departmentAck, setDepartmentAck] = useState(false);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    if (editProposal) {
      const period = parsePlannedPeriod(editProposal.plannedPeriod);
      setProposingDepartment(editProposal.proposingDepartment || '');
      setCourseName(editProposal.courseName || '');
      setLocation(editProposal.location || '');
      setPeriodFrom(period?.from || '');
      setPeriodTo(period?.to || '');
      setTuitionFee(editProposal.tuitionFee || '');
      setTrainingGoal(editProposal.trainingGoal || '');
      setReason(editProposal.reason || '');
      setEmployeeAck(true);
      setDepartmentAck(true);
    } else {
      setCourseName('');
      setLocation('');
      setPeriodFrom('');
      setPeriodTo('');
      setTuitionFee('');
      setTrainingGoal('');
      setReason('');
      setEmployeeAck(false);
      setDepartmentAck(false);
      setProposingDepartment(employee?.departmentName || '');
    }
  }, [open, employee?.id, employee?.departmentName, editProposal]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!employee) return;
    if (!proposingDepartment.trim()) {
      setErr('Nhập Khoa/Phòng đề xuất.');
      return;
    }
    if (!courseName.trim()) {
      setErr('Nhập tên khoá học.');
      return;
    }
    if (!location.trim()) {
      setErr('Nhập địa điểm học.');
      return;
    }
    if (!periodFrom || !periodTo) {
      setErr('Chọn thời gian dự kiến (từ ngày – đến ngày).');
      return;
    }
    if (periodTo < periodFrom) {
      setErr('Ngày kết thúc phải sau hoặc bằng ngày bắt đầu.');
      return;
    }
    if (!trainingGoal.trim()) {
      setErr('Nhập mục tiêu đào tạo.');
      return;
    }
    if (!reason.trim()) {
      setErr('Nhập lý do đề xuất.');
      return;
    }
    if (!employeeAck) {
      setErr('Cần xác nhận cam kết của nhân viên được cử đi đào tạo.');
      return;
    }
    if (!departmentAck) {
      setErr('Cần xác nhận cam kết của Khoa/Phòng đề xuất.');
      return;
    }

    setLoading(true);
    setErr(null);
    try {
      const payload = {
        employeeId: employee.id,
        proposingDepartment: proposingDepartment.trim(),
        courseName: courseName.trim(),
        location: location.trim(),
        plannedPeriod: formatPeriodLabel(periodFrom, periodTo),
        tuitionFee: tuitionFee.trim() || undefined,
        trainingGoal: trainingGoal.trim(),
        reason: reason.trim(),
        employeeCommitmentAck: true,
        departmentCommitmentAck: true,
      };
      if (isEditing && editProposal) {
        await tps.updateTrainingProposal(editProposal.id, payload);
      } else {
        await tps.createTrainingProposal(payload);
      }
      onSubmitted?.();
      onClose();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Gửi phiếu thất bại.'));
    } finally {
      setLoading(false);
    }
  }

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={ACCENT}
      icon={<SchoolOutlinedIcon />}
      overline={isEditing ? 'Chỉnh sửa phiếu · BV Đa khoa Minh An' : 'Phiếu đề xuất · BV Đa khoa Minh An'}
      title={isEditing ? 'Chỉnh sửa phiếu đào tạo, bồi dưỡng' : 'Cử CBNV đào tạo, bồi dưỡng'}
      description={
        employee
          ? `${employee.fullName}${employee.departmentName ? ` · ${employee.departmentName}` : ''}`
          : ''
      }
      formId="training-proposal-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi phiếu'}
      error={err}
      onSubmit={submit}
      maxWidth="md"
    >
      <RequestFlowSteps
        accent={ACCENT}
        steps={[
          { label: 'Lập phiếu', hint: 'Trưởng khoa / ĐD trưởng' },
          { label: 'HCNS duyệt', hint: 'Hành chính nhân sự' },
          { label: 'Giám đốc duyệt', hint: 'Ban Giám đốc' },
        ]}
      />

      <InfoBanner>
        Theo mẫu phiếu đề xuất cử CBNV tham gia đào tạo, bồi dưỡng. Sau khi gửi, phiếu chuyển HCNS rồi
        Ban Giám đốc trước khi ký quyết định chính thức.
      </InfoBanner>

      <FormSection
        title="Thông tin nhân viên được đề xuất"
        subtitle="Thông tin lấy từ hồ sơ — chỉ cần bổ sung Khoa/Phòng đề xuất nếu khác."
      >
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
            gap: 1.25,
          }}
        >
          <ReadonlyFact
            icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
            label="Họ tên"
            value={employee?.fullName || ''}
          />
          <ReadonlyFact
            icon={<BadgeOutlinedIcon sx={{ fontSize: 16 }} />}
            label="Vị trí"
            value={employee?.positionTitle || ''}
          />
          <ReadonlyFact
            icon={<CalendarMonthOutlinedIcon sx={{ fontSize: 16 }} />}
            label="Ngày sinh"
            value={employee?.dateOfBirth ? tps.formatTrainingDate(employee.dateOfBirth) : ''}
          />
          <ReadonlyFact
            icon={<LocationOnOutlinedIcon sx={{ fontSize: 16 }} />}
            label="Khoa/Phòng hiện tại"
            value={employee?.departmentName || ''}
          />
        </Box>
        <TextField
          required
          label="Khoa/Phòng đề xuất"
          value={proposingDepartment}
          onChange={(e) => setProposingDepartment(e.target.value)}
          fullWidth
          size="small"
          sx={fieldSx}
          helperText="Thường trùng khoa của nhân viên; có thể chỉnh nếu đơn vị đề xuất khác."
        />
      </FormSection>

      <FormSection title="Nội dung đào tạo" subtitle="Thông tin khoá học theo mẫu phiếu của Bệnh viện.">
        <TextField
          required
          label="Tên khoá học"
          value={courseName}
          onChange={(e) => setCourseName(e.target.value)}
          fullWidth
          size="small"
          sx={fieldSx}
          InputProps={adornment(<MenuBookOutlinedIcon sx={{ fontSize: 18 }} />)}
        />
        <TextField
          required
          label="Địa điểm học"
          value={location}
          onChange={(e) => setLocation(e.target.value)}
          fullWidth
          size="small"
          sx={fieldSx}
          InputProps={adornment(<LocationOnOutlinedIcon sx={{ fontSize: 18 }} />)}
        />
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.75}>
          <DatePickerField
            required
            fullWidth
            size="small"
            label="Từ ngày"
            value={periodFrom}
            onChange={(v) => {
              setPeriodFrom(v);
              if (periodTo && periodTo < v) setPeriodTo(v);
            }}
            sx={fieldSx}
          />
          <DatePickerField
            required
            fullWidth
            size="small"
            label="Đến ngày"
            value={periodTo}
            onChange={setPeriodTo}
            sx={fieldSx}
            helperText={
              periodFrom && periodTo && periodTo >= periodFrom
                ? `Thời gian: ${formatPeriodLabel(periodFrom, periodTo)}`
                : undefined
            }
          />
        </Stack>
        <TextField
          label="Học phí khóa học"
          placeholder="Tuỳ chọn — ghi rõ đơn vị (VNĐ) nếu có"
          value={tuitionFee}
          onChange={(e) => setTuitionFee(e.target.value)}
          fullWidth
          size="small"
          sx={fieldSx}
          InputProps={adornment(<PaymentsOutlinedIcon sx={{ fontSize: 18 }} />)}
        />
        <TextField
          required
          label="Mục tiêu đào tạo"
          value={trainingGoal}
          onChange={(e) => setTrainingGoal(e.target.value)}
          fullWidth
          size="small"
          multiline
          minRows={2}
          sx={fieldSx}
          placeholder="Năng lực / kỹ năng cần đạt sau khoá học…"
        />
      </FormSection>

      <FormSection title="Lý do đề xuất" subtitle="Nêu rõ nhu cầu chuyên môn và lợi ích cho Khoa/Phòng.">
        <TextField
          required
          label="Lý do"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          fullWidth
          size="small"
          multiline
          minRows={3}
          sx={fieldSx}
          placeholder="Lý do đề cử nhân viên tham gia khoá đào tạo…"
        />
      </FormSection>

      <FormSection
        title="Cam kết"
        subtitle="Bắt buộc xác nhận đủ hai cam kết trước khi gửi phiếu."
      >
        <Stack spacing={1.35}>
          <CommitmentCard
            checked={employeeAck}
            onChange={setEmployeeAck}
            title="Cam kết của nhân viên được cử đi đào tạo"
            body={EMP_COMMITMENT}
          />
          <CommitmentCard
            checked={departmentAck}
            onChange={setDepartmentAck}
            title="Cam kết của Khoa/Phòng đề xuất"
            body={DEPT_COMMITMENT}
          />
        </Stack>
        {(employeeAck || departmentAck) && (
          <Stack direction="row" spacing={0.75} alignItems="center" sx={{ color: ACCENT, pt: 0.5 }}>
            <CheckBoxOutlinedIcon sx={{ fontSize: 18 }} />
            <Typography variant="caption" fontWeight={700}>
              {employeeAck && departmentAck
                ? 'Đã xác nhận đủ cam kết — có thể gửi phiếu.'
                : 'Còn thiếu một cam kết chưa xác nhận.'}
            </Typography>
          </Stack>
        )}
      </FormSection>
    </WorkRequestDialogShell>
  );
}
