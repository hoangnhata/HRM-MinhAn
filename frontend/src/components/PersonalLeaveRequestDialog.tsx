import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined';
import CheckCircleRoundedIcon from '@mui/icons-material/CheckCircleRounded';
import FavoriteBorderRoundedIcon from '@mui/icons-material/FavoriteBorderRounded';
import LocalFloristOutlinedIcon from '@mui/icons-material/LocalFloristOutlined';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import VolunteerActivismOutlinedIcon from '@mui/icons-material/VolunteerActivismOutlined';
import { Box, Chip, Stack, TextField, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as att from '../services/attendanceService';
import * as employeeService from '../services/employeeService';
import { DatePickerField } from './ui/DateTimeFields';
import {
  FormSection,
  InfoBanner,
  ReadonlyFact,
  RequestFlowSteps,
  WorkRequestDialogShell,
  requestFieldSx,
} from './work/WorkRequestFormUi';

type Props = {
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  defaultFrom?: string;
  editRequest?: att.WorkRequest | null;
};

type KindOption = {
  kind: att.PersonalLeaveKind;
  title: string;
  hint: string;
  icon: React.ReactNode;
};

const KIND_OPTIONS: KindOption[] = [
  {
    kind: 'MARRIAGE',
    title: 'Người lao động kết hôn',
    hint: 'Bản thân nhân viên đăng ký kết hôn',
    icon: <FavoriteBorderRoundedIcon />,
  },
  {
    kind: 'BEREAVEMENT',
    title: 'Người thân NLĐ mất',
    hint: 'Bố, mẹ, vợ, chồng, con hoặc bố mẹ bên vợ/chồng',
    icon: <LocalFloristOutlinedIcon />,
  },
];

function daysInclusive(from: string, to: string): number {
  const a = new Date(`${from}T12:00:00`);
  const b = new Date(`${to}T12:00:00`);
  if (Number.isNaN(a.getTime()) || Number.isNaN(b.getTime()) || b < a) return 0;
  return Math.round((b.getTime() - a.getTime()) / 86400000) + 1;
}

function addDays(iso: string, days: number): string {
  const d = new Date(`${iso}T12:00:00`);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

/**
 * Đơn nghỉ chế độ (Điều 115 BLLĐ 2019): kết hôn hoặc người thân mất, tối đa 3 ngày.
 * Nhân viên chính thức hưởng lương cơ bản và không trừ phép năm; nhân viên thử việc
 * hoặc thực tập nghỉ không lương. Chế độ hưởng lương do backend chốt theo hồ sơ.
 */
export function PersonalLeaveRequestDialog({
  open,
  onClose,
  onSubmitted,
  defaultFrom,
  editRequest,
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const accent = '#7c3aed';
  const fieldSx = requestFieldSx(accent);
  const today = new Date().toISOString().slice(0, 10);
  const isEditing = Boolean(editRequest);

  const [kind, setKind] = useState<att.PersonalLeaveKind | null>(null);
  const [fromDate, setFromDate] = useState(defaultFrom ?? today);
  const [toDate, setToDate] = useState(defaultFrom ?? today);
  const [reason, setReason] = useState('');
  const [departmentName, setDepartmentName] = useState('');
  const [employeeStatus, setEmployeeStatus] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const leaveDays = useMemo(() => daysInclusive(fromDate, toDate), [fromDate, toDate]);
  const overMax = leaveDays > att.PERSONAL_LEAVE_MAX_DAYS;
  const isOfficial = employeeStatus === 'ACTIVE';
  const statusKnown = employeeStatus !== '';

  useEffect(() => {
    if (!open) return;
    const d = defaultFrom ?? new Date().toISOString().slice(0, 10);
    if (editRequest) {
      setKind(editRequest.personalLeaveKind ?? null);
      setFromDate(editRequest.workDate || d);
      setToDate(editRequest.endDate || editRequest.workDate || d);
      setReason(editRequest.reason || '');
    } else {
      setKind(null);
      setFromDate(d);
      // Mặc định trọn 3 ngày chế độ, người dùng có thể rút ngắn.
      setToDate(addDays(d, att.PERSONAL_LEAVE_MAX_DAYS - 1));
      setReason('');
    }
    setErr(null);
    employeeService
      .fetchMe()
      .then((me) => {
        setDepartmentName(me.departmentName ?? '');
        setEmployeeStatus(String(me.status ?? ''));
      })
      .catch(() => {
        setDepartmentName('');
        setEmployeeStatus('');
      });
  }, [open, defaultFrom, editRequest]);

  function handleFromChange(value: string) {
    setFromDate(value);
    // Giữ độ dài kỳ nghỉ khi đổi ngày bắt đầu, nhưng không vượt 3 ngày.
    const span = Math.min(Math.max(leaveDays, 1), att.PERSONAL_LEAVE_MAX_DAYS);
    setToDate(addDays(value, span - 1));
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!kind) {
      setErr('Chọn chế độ nghỉ: NLĐ kết hôn hoặc người thân NLĐ mất.');
      return;
    }
    if (!reason.trim()) {
      setErr('Nhập lý do / thông tin sự việc.');
      return;
    }
    if (toDate < fromDate) {
      setErr('Ngày kết thúc phải sau hoặc bằng ngày bắt đầu.');
      return;
    }
    if (overMax) {
      setErr(
        `Nghỉ chế độ tối đa ${att.PERSONAL_LEAVE_MAX_DAYS} ngày, đơn đang xin ${leaveDays} ngày.`,
      );
      return;
    }
    setLoading(true);
    try {
      const payload: att.SubmitWorkRequest = {
        requestType: 'PERSONAL_LEAVE',
        personalLeaveKind: kind,
        workDate: fromDate,
        endDate: toDate,
        shiftScope: 'FULL_DAY',
        reason: reason.trim(),
      };
      if (isEditing && editRequest) {
        await att.updateWorkRequest(editRequest.id, payload);
      } else {
        await att.submitWorkRequest(payload);
      }
      onSubmitted?.();
      onClose();
    } catch (ex: unknown) {
      const msg =
        ex && typeof ex === 'object' && 'response' in ex
          ? String(
              (ex as { response?: { data?: { message?: string } } }).response?.data?.message ?? '',
            )
          : '';
      setErr(msg || 'Gửi đơn thất bại. Kiểm tra khoảng ngày trùng đơn nghỉ khác.');
    } finally {
      setLoading(false);
    }
  }

  const regimeChip = !statusKnown ? null : isOfficial ? (
    <Chip
      size="small"
      icon={<CheckCircleRoundedIcon sx={{ fontSize: '16px !important' }} />}
      label="Nhân viên chính thức · hưởng lương cơ bản, không trừ phép năm"
      sx={{
        fontWeight: 700,
        bgcolor: alpha(theme.palette.success.main, 0.1),
        color: theme.palette.success.dark,
        '& .MuiChip-icon': { color: theme.palette.success.dark },
      }}
    />
  ) : (
    <Chip
      size="small"
      label="Nhân viên thử việc / thực tập · nghỉ không lương"
      sx={{
        fontWeight: 700,
        bgcolor: alpha(theme.palette.warning.main, 0.12),
        color: theme.palette.warning.dark,
      }}
    />
  );

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={accent}
      maxWidth="md"
      icon={<VolunteerActivismOutlinedIcon />}
      overline={isEditing ? 'Chỉnh sửa đơn' : 'Đề nghị nghỉ chế độ'}
      title={isEditing ? 'Chỉnh sửa đơn nghỉ chế độ' : 'Đơn nghỉ chế độ'}
      description="Nghỉ việc riêng theo Điều 115 Bộ luật Lao động: kết hôn hoặc người thân mất, tối đa 3 ngày. Quy trình duyệt giống nghỉ phép."
      formId="personal-leave-request-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi đơn nghỉ chế độ'}
      error={err}
      onSubmit={submit}
    >
      <RequestFlowSteps
        accent={accent}
        steps={[
          { label: 'Gửi đơn', hint: 'Nhân viên' },
          { label: 'Lãnh đạo duyệt', hint: 'Trưởng khoa / ĐD trưởng' },
          { label: 'HCNS duyệt', hint: 'Hành chính nhân sự' },
          { label: 'Giám đốc duyệt', hint: 'Duyệt cuối' },
        ]}
      />

      <InfoBanner>
        Nhân viên <strong>chính thức</strong> được nghỉ <strong>3 ngày hưởng lương cơ bản</strong>,
        không trừ vào phép năm. Nhân viên <strong>thử việc</strong> nghỉ 3 ngày{' '}
        <strong>không lương</strong>. Chế độ hưởng lương được xác định theo hồ sơ tại thời điểm gửi
        đơn.
      </InfoBanner>

      <FormSection title="Chế độ nghỉ" subtitle="Chọn một trường hợp">
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 1.25 }}>
          {KIND_OPTIONS.map((opt) => {
            const selected = kind === opt.kind;
            return (
              <Box
                key={opt.kind}
                component="button"
                type="button"
                onClick={() => setKind(opt.kind)}
                disabled={isEditing}
                sx={{
                  all: 'unset',
                  boxSizing: 'border-box',
                  cursor: isEditing ? 'default' : 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 1.5,
                  p: 1.5,
                  borderRadius: 2.5,
                  border: `1.5px solid ${selected ? accent : alpha('#0f172a', 0.12)}`,
                  bgcolor: selected ? alpha(accent, 0.06) : '#fff',
                  boxShadow: selected ? `0 0 0 3px ${alpha(accent, 0.12)}` : 'none',
                  transition: 'all .15s ease',
                  '&:hover': isEditing
                    ? undefined
                    : { borderColor: accent, bgcolor: alpha(accent, 0.04) },
                }}
              >
                <Box
                  sx={{
                    width: 42,
                    height: 42,
                    borderRadius: 2,
                    display: 'grid',
                    placeItems: 'center',
                    bgcolor: alpha(accent, selected ? 0.16 : 0.08),
                    color: accent,
                    flexShrink: 0,
                  }}
                >
                  {opt.icon}
                </Box>
                <Box sx={{ minWidth: 0, flex: 1 }}>
                  <Typography variant="subtitle2" fontWeight={800} sx={{ lineHeight: 1.25 }}>
                    {opt.title}
                  </Typography>
                  <Typography
                    variant="caption"
                    color="text.secondary"
                    sx={{ display: 'block', mt: 0.25 }}
                  >
                    {opt.hint}
                  </Typography>
                </Box>
                {selected && <CheckCircleRoundedIcon sx={{ color: accent, fontSize: 22 }} />}
              </Box>
            );
          })}
        </Box>
      </FormSection>

      <FormSection title="Người nộp đơn">
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 1.25 }}>
          <ReadonlyFact
            accent={accent}
            icon={<PersonOutlineIcon sx={{ fontSize: 16 }} />}
            label="Họ và tên"
            value={user?.fullName ?? ''}
          />
          <ReadonlyFact
            accent={accent}
            icon={<BusinessOutlinedIcon sx={{ fontSize: 16 }} />}
            label="Phòng ban"
            value={departmentName}
          />
        </Box>
        {regimeChip && (
          <Stack direction="row" sx={{ mt: 1.25 }}>
            {regimeChip}
          </Stack>
        )}
      </FormSection>

      <FormSection
        title="Thời gian nghỉ"
        subtitle={
          leaveDays > 0
            ? `Số ngày xin: ${leaveDays} / ${att.PERSONAL_LEAVE_MAX_DAYS} ngày`
            : 'Chọn khoảng ngày nghỉ'
        }
      >
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 1.75 }}>
          <DatePickerField
            label="Từ ngày"
            required
            value={fromDate}
            onChange={handleFromChange}
            sx={fieldSx}
          />
          <DatePickerField
            label="Đến ngày"
            required
            value={toDate}
            onChange={setToDate}
            sx={fieldSx}
          />
        </Box>
        <Typography
          variant="body2"
          sx={{
            color: overMax ? theme.palette.error.main : 'text.secondary',
            fontWeight: overMax ? 700 : 400,
          }}
        >
          {overMax
            ? `Vượt quy định: nghỉ chế độ tối đa ${att.PERSONAL_LEAVE_MAX_DAYS} ngày.`
            : isOfficial
              ? 'Các ngày này ghi đủ công hưởng lương cơ bản, không trừ ngày phép năm.'
              : statusKnown
                ? 'Các ngày này ghi 0 công (nghỉ không lương) khi đơn được duyệt.'
                : 'Tính cả ngày theo lịch, tối đa 3 ngày liên tục.'}
        </Typography>
      </FormSection>

      <FormSection title="Lý do / thông tin sự việc">
        <TextField
          fullWidth
          size="small"
          required
          multiline
          minRows={3}
          placeholder={
            kind === 'BEREAVEMENT'
              ? 'Ví dụ: Bố đẻ mất ngày 12/09, lo hậu sự tại quê…'
              : 'Ví dụ: Đăng ký kết hôn ngày 20/09, tổ chức lễ cưới tại quê…'
          }
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
