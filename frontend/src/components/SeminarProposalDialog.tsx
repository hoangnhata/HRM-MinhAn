import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CheckBoxOutlinedIcon from '@mui/icons-material/CheckBoxOutlined';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import MenuBookOutlinedIcon from '@mui/icons-material/MenuBookOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import {
  Box,
  Checkbox,
  FormControlLabel,
  InputAdornment,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { DatePickerField } from './ui/DateTimeFields';
import {
  FormSection,
  InfoBanner,
  RequestFlowSteps,
  WorkRequestDialogShell,
} from './work/WorkRequestFormUi';
import * as sps from '../services/seminarProposalService';
import { extractApiErrorMessage } from '../services/approvalSignatureService';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  editProposal?: sps.SeminarProposal | null;
  employee: {
    id: number;
    fullName: string;
    departmentName?: string;
    positionTitle?: string;
    dateOfBirth?: string | null;
  } | null;
};

const ACCENT = '#0e7490';

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
  'Thực hiện đầy đủ chương trình hội thảo, tuân thủ quy định của Bệnh viện và đơn vị tổ chức; báo cáo kết quả sau khi hoàn thành.';

const DEPT_COMMITMENT =
  'Bố trí nhân lực trong thời gian đi hội thảo; tạo điều kiện ứng dụng kết quả hội thảo vào chuyên môn.';

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
      <Typography variant="body2" fontWeight={700} sx={{ lineHeight: 1.45, wordBreak: 'break-word' }}>
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
        p: 1.5,
        borderRadius: 2.25,
        bgcolor: checked ? alpha(ACCENT, 0.05) : alpha('#0f172a', 0.02),
        border: `1px solid ${checked ? alpha(ACCENT, 0.28) : alpha('#0f172a', 0.08)}`,
      }}
    >
      <FormControlLabel
        control={
          <Checkbox
            checked={checked}
            onChange={(_, v) => onChange(v)}
            sx={{
              color: alpha(ACCENT, 0.45),
              '&.Mui-checked': { color: ACCENT },
            }}
          />
        }
        label={
          <Box>
            <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mb: 0.35 }}>
              <CheckBoxOutlinedIcon sx={{ fontSize: 16, color: ACCENT }} />
              <Typography variant="body2" fontWeight={800}>
                {title}
              </Typography>
            </Stack>
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

export function SeminarProposalDialog({ open, onClose, onSubmitted, editProposal, employee }: Props) {
  const isEditing = Boolean(editProposal);
  const [proposingDepartment, setProposingDepartment] = useState('');
  const [seminarName, setSeminarName] = useState('');
  const [location, setLocation] = useState('');
  const [periodFrom, setPeriodFrom] = useState('');
  const [periodTo, setPeriodTo] = useState('');
  const [periodMode, setPeriodMode] = useState<'SINGLE_DAY' | 'MULTI_DAY'>('SINGLE_DAY');
  const [attendanceScope, setAttendanceScope] = useState<'MORNING' | 'AFTERNOON' | 'FULL_DAY'>('FULL_DAY');
  const [reason, setReason] = useState('');
  const [employeeAck, setEmployeeAck] = useState(false);
  const [departmentAck, setDepartmentAck] = useState(false);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [existingProposals, setExistingProposals] = useState<sps.SeminarProposal[]>([]);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    if (editProposal) {
      const sameDay = editProposal.startDate === editProposal.endDate;
      setProposingDepartment(editProposal.proposingDepartment || '');
      setSeminarName(editProposal.seminarName || '');
      setLocation(editProposal.location || '');
      setPeriodFrom(editProposal.startDate || '');
      setPeriodTo(editProposal.endDate || '');
      setPeriodMode(sameDay ? 'SINGLE_DAY' : 'MULTI_DAY');
      setAttendanceScope(editProposal.attendanceScope || 'FULL_DAY');
      setReason(editProposal.reason || '');
      setEmployeeAck(true);
      setDepartmentAck(true);
    } else {
      setSeminarName('');
      setLocation('');
      setPeriodFrom('');
      setPeriodTo('');
      setPeriodMode('SINGLE_DAY');
      setAttendanceScope('FULL_DAY');
      setReason('');
      setEmployeeAck(false);
      setDepartmentAck(false);
      setProposingDepartment(employee?.departmentName || '');
    }
    if (employee?.id) {
      sps.fetchSeminarProposalsByEmployee(employee.id)
        .then(setExistingProposals)
        .catch(() => setExistingProposals([]));
    } else {
      setExistingProposals([]);
    }
  }, [open, employee?.id, employee?.departmentName, editProposal]);

  const effectiveTo = periodMode === 'SINGLE_DAY' ? periodFrom : periodTo;
  const overlapWarning = useMemo(() => {
    if (!periodFrom || !effectiveTo || effectiveTo < periodFrom) return null;
    const hit = sps.findSeminarDateOverlap(
      existingProposals,
      periodFrom,
      effectiveTo,
      editProposal?.id,
    );
    if (!hit) return null;
    return `Khoảng ngày trùng với phiếu «${hit.seminarName}» (${sps.formatSeminarDate(hit.startDate)} → ${sps.formatSeminarDate(hit.endDate)}).`;
  }, [existingProposals, periodFrom, effectiveTo, editProposal?.id]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!employee) return;
    if (!proposingDepartment.trim()) {
      setErr('Nhập Khoa/Phòng đề xuất.');
      return;
    }
    if (!seminarName.trim()) {
      setErr('Nhập tên hội thảo.');
      return;
    }
    if (!location.trim()) {
      setErr('Nhập địa điểm.');
      return;
    }
    const effectiveTo = periodMode === 'SINGLE_DAY' ? periodFrom : periodTo;
    if (!periodFrom || !effectiveTo) {
      setErr(periodMode === 'SINGLE_DAY' ? 'Chọn ngày hội thảo.' : 'Chọn thời gian từ ngày – đến ngày.');
      return;
    }
    if (effectiveTo < periodFrom) {
      setErr('Ngày kết thúc phải sau hoặc bằng ngày bắt đầu.');
      return;
    }
    if (!reason.trim()) {
      setErr('Nhập lý do đề xuất.');
      return;
    }
    if (!employeeAck) {
      setErr('Cần xác nhận cam kết của nhân viên được cử đi hội thảo.');
      return;
    }
    if (!departmentAck) {
      setErr('Cần xác nhận cam kết của Khoa/Phòng đề xuất.');
      return;
    }
    if (overlapWarning) {
      setErr(overlapWarning);
      return;
    }

    setLoading(true);
    setErr(null);
    try {
      const payload = {
        employeeId: employee.id,
        proposingDepartment: proposingDepartment.trim(),
        seminarName: seminarName.trim(),
        location: location.trim(),
        startDate: periodFrom,
        endDate: effectiveTo,
        attendanceScope: periodMode === 'MULTI_DAY' ? 'FULL_DAY' : attendanceScope,
        reason: reason.trim(),
        employeeCommitmentAck: true,
        departmentCommitmentAck: true,
      };
      if (isEditing && editProposal) {
        await sps.updateSeminarProposal(editProposal.id, payload);
      } else {
        await sps.createSeminarProposal(payload);
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
      icon={<GroupsOutlinedIcon />}
      overline={isEditing ? 'Chỉnh sửa phiếu · BV Đa khoa Minh An' : 'Phiếu đề xuất · BV Đa khoa Minh An'}
      title={isEditing ? 'Chỉnh sửa phiếu hội thảo / công tác' : 'Cử CBNV tham gia hội thảo / công tác'}
      description={
        employee
          ? `${employee.fullName}${employee.departmentName ? ` · ${employee.departmentName}` : ''}`
          : ''
      }
      formId="seminar-proposal-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi phiếu'}
      error={err}
      onSubmit={submit}
      maxWidth="md"
    >
      <RequestFlowSteps
        accent={ACCENT}
        steps={[
          { label: 'Lập phiếu', hint: 'Trưởng khoa / ĐD trưởng' },
          { label: 'Giám đốc duyệt', hint: 'Có/không công · tiền hỗ trợ' },
        ]}
      />

      <InfoBanner>
        Phiếu này dùng chung cho nhu cầu <strong>hội thảo hoặc công tác</strong>. Có thể lập{' '}
        <strong>nhiều phiếu</strong> cho các ngày không liên tiếp (ví dụ ngày 16 và 18), nhưng{' '}
        <strong>không được trùng khoảng thời gian</strong> với phiếu khác đang chờ hoặc đã duyệt.
        Phiếu gửi thẳng <strong>Giám đốc</strong> duyệt (có công / không công, tuỳ chọn cấp tiền hỗ trợ)
        trước khi áp dụng bảng công (trạng thái <strong>Hội thảo</strong>).
      </InfoBanner>

      <FormSection
        title="Thông tin nhân viên được đề xuất"
        subtitle="Thông tin lấy từ hồ sơ — bổ sung Khoa/Phòng đề xuất nếu khác."
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
            value={employee?.dateOfBirth ? sps.formatSeminarDate(employee.dateOfBirth) : ''}
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
        />
      </FormSection>

      <FormSection title="Nội dung hội thảo / công tác" subtitle="Thông tin theo mẫu phiếu của Bệnh viện.">
        <TextField
          required
          label="Tên hội thảo"
          value={seminarName}
          onChange={(e) => setSeminarName(e.target.value)}
          fullWidth
          size="small"
          sx={fieldSx}
          InputProps={adornment(<MenuBookOutlinedIcon sx={{ fontSize: 18 }} />)}
        />
        <TextField
          required
          label="Địa điểm"
          value={location}
          onChange={(e) => setLocation(e.target.value)}
          fullWidth
          size="small"
          sx={fieldSx}
          InputProps={adornment(<LocationOnOutlinedIcon sx={{ fontSize: 18 }} />)}
        />
        <TextField
          select
          required
          label="Thời gian tham gia"
          value={periodMode}
          onChange={(e) => {
            const next = e.target.value as 'SINGLE_DAY' | 'MULTI_DAY';
            setPeriodMode(next);
            if (next === 'MULTI_DAY') setAttendanceScope('FULL_DAY');
          }}
          fullWidth
          size="small"
          sx={fieldSx}
        >
          <MenuItem value="SINGLE_DAY">Trong một ngày</MenuItem>
          <MenuItem value="MULTI_DAY">Nhiều ngày</MenuItem>
        </TextField>

        {periodMode === 'SINGLE_DAY' ? (
          <DatePickerField
            required
            fullWidth
            size="small"
            label="Ngày hội thảo"
            value={periodFrom}
            onChange={setPeriodFrom}
            sx={fieldSx}
          />
        ) : (
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
            />
          </Stack>
        )}

        {periodMode === 'SINGLE_DAY' && (
          <TextField
            select
            required
            label="Buổi được tính hội thảo"
            value={attendanceScope}
            onChange={(e) => setAttendanceScope(e.target.value as typeof attendanceScope)}
            fullWidth
            size="small"
            sx={fieldSx}
            helperText="Buổi không chọn chỉ có công khi nhân viên chấm công và đi làm bình thường."
          >
            <MenuItem value="MORNING">Buổi sáng</MenuItem>
            <MenuItem value="AFTERNOON">Buổi chiều</MenuItem>
            <MenuItem value="FULL_DAY">Cả ngày</MenuItem>
          </TextField>
        )}

        {overlapWarning && (
          <Typography variant="body2" color="error.main" sx={{ mt: 1, lineHeight: 1.55 }}>
            {overlapWarning}
          </Typography>
        )}
      </FormSection>

      <FormSection title="Lý do đề xuất">
        <TextField
          required
          label="Lý do đề xuất"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          fullWidth
          size="small"
          multiline
          minRows={3}
          sx={fieldSx}
        />
      </FormSection>

      <FormSection title="Cam kết" subtitle="Bắt buộc xác nhận trước khi gửi.">
        <Stack spacing={1.35}>
          <CommitmentCard
            checked={employeeAck}
            onChange={setEmployeeAck}
            title="Cam kết của nhân viên được cử đi hội thảo"
            body={EMP_COMMITMENT}
          />
          <CommitmentCard
            checked={departmentAck}
            onChange={setDepartmentAck}
            title="Cam kết của Khoa/Phòng đề xuất"
            body={DEPT_COMMITMENT}
          />
        </Stack>
      </FormSection>
    </WorkRequestDialogShell>
  );
}
