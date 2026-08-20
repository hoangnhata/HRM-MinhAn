import AccessTimeIcon from '@mui/icons-material/AccessTime';
import AcUnitIcon from '@mui/icons-material/AcUnit';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import WbSunnyIcon from '@mui/icons-material/WbSunny';
import { Box, TextField, Typography } from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useEffect, useState, type ReactNode } from 'react';
import { fetchEmployeeShiftConfigAdmin } from '../services/attendanceService';
import * as scc from '../services/shiftConfigChangeRequestService';
import type { ShiftScheduleInfo, ShiftSeasonConfig } from '../utils/shiftSchedule';
import { TimePickerField } from './ui/DateTimeFields';
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
  editRequest?: scc.ShiftConfigChangeRequest | null;
  employeeId: number;
  employeeName: string;
  departmentName?: string;
  /** Prefill từ lịch hiện tại của NV (mùa đang xem) */
  schedule?: ShiftScheduleInfo | null;
};

type SeasonTimes = {
  morningStart: string;
  morningEnd: string;
  afternoonStart: string;
  afternoonEnd: string;
};

const ACCENT = '#0369a1';
const SUMMER_COLOR = '#ea580c';
const WINTER_COLOR = '#0284c7';

const DEFAULT_SUMMER: SeasonTimes = {
  morningStart: '06:45',
  morningEnd: '11:45',
  afternoonStart: '14:00',
  afternoonEnd: '17:00',
};

const DEFAULT_WINTER: SeasonTimes = {
  morningStart: '07:00',
  morningEnd: '12:00',
  afternoonStart: '13:30',
  afternoonEnd: '17:00',
};

function toHhMm(value?: string | null) {
  if (!value) return '';
  return String(value).slice(0, 5);
}

function fromSeasonConfig(cfg: ShiftSeasonConfig | null | undefined, fallback: SeasonTimes): SeasonTimes {
  if (!cfg) return { ...fallback };
  return {
    morningStart: toHhMm(cfg.morningStart) || fallback.morningStart,
    morningEnd: toHhMm(cfg.morningEnd) || fallback.morningEnd,
    afternoonStart: toHhMm(cfg.afternoonStart) || fallback.afternoonStart,
    afternoonEnd: toHhMm(cfg.afternoonEnd) || fallback.afternoonEnd,
  };
}

function validateSeason(times: SeasonTimes, label: string): string | null {
  if (!times.morningStart || !times.morningEnd || times.morningStart >= times.morningEnd) {
    return `Giờ ca sáng ${label} không hợp lệ.`;
  }
  if (!times.afternoonStart || !times.afternoonEnd || times.afternoonStart >= times.afternoonEnd) {
    return `Giờ ca chiều ${label} không hợp lệ.`;
  }
  return null;
}

function toApiTime(hhMm: string) {
  return `${hhMm}:00`.slice(0, 8);
}

function SeasonSelectCard({
  selected,
  onToggle,
  color,
  icon,
  title,
  subtitle,
}: {
  selected: boolean;
  onToggle: () => void;
  color: string;
  icon: ReactNode;
  title: string;
  subtitle: string;
}) {
  return (
    <Box
      component="button"
      type="button"
      onClick={onToggle}
      sx={{
        all: 'unset',
        cursor: 'pointer',
        boxSizing: 'border-box',
        display: 'flex',
        alignItems: 'center',
        gap: 1.5,
        width: '100%',
        px: 2,
        py: 1.75,
        borderRadius: 2.5,
        border: `1.5px solid ${selected ? color : alpha(color, 0.22)}`,
        bgcolor: selected ? alpha(color, 0.08) : alpha(color, 0.02),
        boxShadow: selected ? `0 6px 18px ${alpha(color, 0.14)}` : 'none',
        transition: 'border-color 0.15s ease, background-color 0.15s ease, box-shadow 0.15s ease',
        '&:hover': {
          borderColor: color,
          bgcolor: alpha(color, selected ? 0.1 : 0.05),
        },
      }}
    >
      <Box
        sx={{
          width: 40,
          height: 40,
          borderRadius: 2,
          display: 'grid',
          placeItems: 'center',
          flexShrink: 0,
          bgcolor: alpha(color, selected ? 0.18 : 0.1),
          color,
        }}
      >
        {icon}
      </Box>
      <Box sx={{ flex: 1, minWidth: 0 }}>
        <Typography variant="body2" fontWeight={800} sx={{ color: selected ? color : 'text.primary' }}>
          {title}
        </Typography>
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.15 }}>
          {subtitle}
        </Typography>
      </Box>
      <CheckCircleIcon
        sx={{
          fontSize: 22,
          color: selected ? color : alpha(color, 0.22),
          flexShrink: 0,
        }}
      />
    </Box>
  );
}

export function ShiftConfigChangeProposeDialog({
  open,
  onClose,
  onSubmitted,
  editRequest,
  employeeId,
  employeeName,
  departmentName,
  schedule,
}: Props) {
  const isEditing = Boolean(editRequest);
  const fieldSx = requestFieldSx(ACCENT);
  const [includeSummer, setIncludeSummer] = useState(true);
  const [includeWinter, setIncludeWinter] = useState(true);
  const [summer, setSummer] = useState<SeasonTimes>({ ...DEFAULT_SUMMER });
  const [winter, setWinter] = useState<SeasonTimes>({ ...DEFAULT_WINTER });
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setErr(null);

    if (editRequest) {
      const season = editRequest.season;
      setIncludeSummer(season === 'SUMMER' || season === 'BOTH');
      setIncludeWinter(season === 'WINTER' || season === 'BOTH');
      setSummer({
        morningStart: toHhMm(editRequest.morningStart) || DEFAULT_SUMMER.morningStart,
        morningEnd: toHhMm(editRequest.morningEnd) || DEFAULT_SUMMER.morningEnd,
        afternoonStart: toHhMm(editRequest.afternoonStart) || DEFAULT_SUMMER.afternoonStart,
        afternoonEnd: toHhMm(editRequest.afternoonEnd) || DEFAULT_SUMMER.afternoonEnd,
      });
      setWinter({
        morningStart: toHhMm(editRequest.winterMorningStart || editRequest.morningStart) || DEFAULT_WINTER.morningStart,
        morningEnd: toHhMm(editRequest.winterMorningEnd || editRequest.morningEnd) || DEFAULT_WINTER.morningEnd,
        afternoonStart: toHhMm(editRequest.winterAfternoonStart || editRequest.afternoonStart) || DEFAULT_WINTER.afternoonStart,
        afternoonEnd: toHhMm(editRequest.winterAfternoonEnd || editRequest.afternoonEnd) || DEFAULT_WINTER.afternoonEnd,
      });
      setReason(editRequest.reason || '');
      return;
    }

    setReason('');
    setIncludeSummer(true);
    setIncludeWinter(true);

    const fromSchedule: SeasonTimes = {
      morningStart: toHhMm(schedule?.morningStart) || DEFAULT_SUMMER.morningStart,
      morningEnd: toHhMm(schedule?.morningEnd) || DEFAULT_SUMMER.morningEnd,
      afternoonStart: toHhMm(schedule?.afternoonStart) || DEFAULT_SUMMER.afternoonStart,
      afternoonEnd: toHhMm(schedule?.afternoonEnd) || DEFAULT_SUMMER.afternoonEnd,
    };
    if (schedule?.summer === false) {
      setWinter(fromSchedule);
      setSummer({ ...DEFAULT_SUMMER });
    } else {
      setSummer(fromSchedule);
      setWinter({ ...DEFAULT_WINTER });
    }

    let cancelled = false;
    fetchEmployeeShiftConfigAdmin(employeeId)
      .then((cfg) => {
        if (cancelled) return;
        setSummer(
          fromSeasonConfig(cfg.summer, fromSchedule.morningStart ? fromSchedule : DEFAULT_SUMMER),
        );
        setWinter(fromSeasonConfig(cfg.winter, DEFAULT_WINTER));
      })
      .catch(() => {
        /* giữ prefill từ schedule */
      });
    return () => {
      cancelled = true;
    };
  }, [open, employeeId, schedule, editRequest]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!includeSummer && !includeWinter) {
      setErr('Chọn ít nhất một mùa để đề xuất thay đổi.');
      return;
    }
    if (!reason.trim()) {
      setErr('Nhập lý do đề xuất.');
      return;
    }
    if (includeSummer) {
      const summerErr = validateSeason(summer, 'mùa hè');
      if (summerErr) {
        setErr(summerErr);
        return;
      }
    }
    if (includeWinter) {
      const winterErr = validateSeason(winter, 'mùa đông');
      if (winterErr) {
        setErr(winterErr);
        return;
      }
    }

    const season: 'SUMMER' | 'WINTER' | 'BOTH' =
      includeSummer && includeWinter ? 'BOTH' : includeSummer ? 'SUMMER' : 'WINTER';
    const primary = season === 'WINTER' ? winter : summer;

    setLoading(true);
    try {
      const payload = {
        employeeId,
        season,
        morningStart: toApiTime(primary.morningStart),
        morningEnd: toApiTime(primary.morningEnd),
        afternoonStart: toApiTime(primary.afternoonStart),
        afternoonEnd: toApiTime(primary.afternoonEnd),
        ...(season === 'BOTH'
          ? {
              winterMorningStart: toApiTime(winter.morningStart),
              winterMorningEnd: toApiTime(winter.morningEnd),
              winterAfternoonStart: toApiTime(winter.afternoonStart),
              winterAfternoonEnd: toApiTime(winter.afternoonEnd),
            }
          : {}),
        reason: reason.trim(),
      };
      if (isEditing && editRequest) {
        await scc.updateShiftConfigChangeRequest(editRequest.id, payload);
      } else {
        await scc.createShiftConfigChangeRequest(payload);
      }
      onSubmitted?.();
      onClose();
    } catch {
      setErr('Không gửi được đề xuất. Kiểm tra quyền hoặc đã có đơn chờ duyệt cùng mùa.');
    } finally {
      setLoading(false);
    }
  }

  function SeasonTimeFields({
    title,
    subtitle,
    accent,
    value,
    onChange,
  }: {
    title: string;
    subtitle: string;
    accent: string;
    value: SeasonTimes;
    onChange: (next: SeasonTimes) => void;
  }) {
    return (
      <FormSection title={title} subtitle={subtitle}>
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 1.25 }}>
          <TimePickerField
            required
            fullWidth
            size="small"
            label="Vào ca sáng"
            value={value.morningStart}
            onChange={(v) => onChange({ ...value, morningStart: v })}
            sx={requestFieldSx(accent)}
          />
          <TimePickerField
            required
            fullWidth
            size="small"
            label="Ra ca sáng"
            value={value.morningEnd}
            onChange={(v) => onChange({ ...value, morningEnd: v })}
            sx={requestFieldSx(accent)}
          />
          <TimePickerField
            required
            fullWidth
            size="small"
            label="Vào ca chiều"
            value={value.afternoonStart}
            onChange={(v) => onChange({ ...value, afternoonStart: v })}
            sx={requestFieldSx(accent)}
          />
          <TimePickerField
            required
            fullWidth
            size="small"
            label="Ra ca chiều"
            value={value.afternoonEnd}
            onChange={(v) => onChange({ ...value, afternoonEnd: v })}
            sx={requestFieldSx(accent)}
          />
        </Box>
        <Typography
          variant="caption"
          color="text.secondary"
          sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mt: 1 }}
        >
          <AccessTimeIcon sx={{ fontSize: 14 }} />
          Công mặc định ~0,67 sáng / 0,33 chiều (giống cấu hình viện).
        </Typography>
      </FormSection>
    );
  }

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={ACCENT}
      maxWidth="md"
      icon={<WbSunnyIcon />}
      overline={isEditing ? 'Chỉnh sửa đề xuất thay đổi ca' : 'Đề xuất thay đổi ca'}
      title={isEditing ? 'Chỉnh sửa ca sáng / chiều' : 'Đề xuất thay đổi ca sáng / chiều'}
      description="Có thể đề xuất một hoặc cả hai mùa trong cùng một đơn · HCNS duyệt rồi ghi vào hồ sơ ca"
      formId="shift-config-change-propose-form"
      submitLabel={isEditing ? 'Lưu thay đổi' : 'Gửi đề xuất'}
      error={err}
      onSubmit={submit}
    >
      <RequestFlowSteps
        accent={ACCENT}
        steps={[
          { label: 'Đề xuất', hint: 'Trưởng khoa' },
          { label: 'HCNS duyệt', hint: 'Áp dụng cấu hình' },
        ]}
      />

      <InfoBanner>
        Sau khi HCNS duyệt, cấu hình ca sáng/chiều theo mùa đã chọn được ghi cho nhân viên và giữ đến
        khi có đơn hoặc HCNS chỉnh lại. Ca thông tầm và cửa sổ quẹt giữ nguyên.
      </InfoBanner>

      <FormSection title="Nhân viên">
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
            value={employeeName}
          />
          <ReadonlyFact accent={ACCENT} label="Khoa/phòng" value={departmentName || '—'} />
        </Box>
      </FormSection>

      <FormSection title="Mùa áp dụng" subtitle="Chọn một hoặc cả hai mùa — gửi trong một đơn duy nhất">
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
            gap: 1.25,
            width: '100%',
          }}
        >
          <SeasonSelectCard
            selected={includeSummer}
            onToggle={() => setIncludeSummer((v) => !v)}
            color={SUMMER_COLOR}
            icon={<WbSunnyIcon />}
            title="Mùa hè"
            subtitle="Áp dụng 15/4 – 15/10"
          />
          <SeasonSelectCard
            selected={includeWinter}
            onToggle={() => setIncludeWinter((v) => !v)}
            color={WINTER_COLOR}
            icon={<AcUnitIcon />}
            title="Mùa đông"
            subtitle="Ngoài khoảng mùa hè"
          />
        </Box>
      </FormSection>

      {includeSummer && (
        <SeasonTimeFields
          title="Giờ ca mùa hè"
          subtitle="Vào / ra buổi sáng và chiều"
          accent={SUMMER_COLOR}
          value={summer}
          onChange={setSummer}
        />
      )}

      {includeWinter && (
        <SeasonTimeFields
          title="Giờ ca mùa đông"
          subtitle="Vào / ra buổi sáng và chiều"
          accent={WINTER_COLOR}
          value={winter}
          onChange={setWinter}
        />
      )}

      <FormSection title="Nội dung đề xuất">
        <TextField
          required
          fullWidth
          size="small"
          multiline
          minRows={3}
          label="Lý do đề xuất"
          placeholder="Ví dụ: điều chỉnh giờ theo yêu cầu chuyên môn / lịch khám…"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>
    </WorkRequestDialogShell>
  );
}
