import AirlineSeatFlatOutlinedIcon from '@mui/icons-material/AirlineSeatFlatOutlined';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import HealthAndSafetyOutlinedIcon from '@mui/icons-material/HealthAndSafetyOutlined';
import LocalHospitalOutlinedIcon from '@mui/icons-material/LocalHospitalOutlined';
import MedicalServicesOutlinedIcon from '@mui/icons-material/MedicalServicesOutlined';
import PeopleOutlinedIcon from '@mui/icons-material/PeopleOutlined';
import { Alert, Box, Chip, Stack, Typography } from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { extractApiErrorMessage } from '../../services/approvalSignatureService';
import * as ndr from '../../services/nursingDailyReportService';
import { WorkRequestDialogShell } from '../work/WorkRequestFormUi';
import { InpatientCareLevelAccordion } from './InpatientCareLevelAccordion';
import { IntegerStepperField } from './IntegerStepperField';

const ACCENT = '#0f766e';

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved?: () => void;
  departmentId: number;
  departmentName: string;
  reportDate: string;
  existing?: ndr.NursingDailyReport | null;
};

type FieldKey = Exclude<keyof ndr.NursingDailyReportPayload, 'departmentId' | 'reportDate'>;

const STAFF_FIELDS: { key: FieldKey; label: string }[] = [
  { key: 'totalStaff', label: 'Tổng số nhân viên khoa' },
  { key: 'workingStaff', label: 'Số nhân viên đi làm' },
  { key: 'plannedLeave', label: 'Nghỉ theo kế hoạch' },
  { key: 'unplannedLeave', label: 'Nghỉ đột xuất' },
  { key: 'maternityLeave', label: 'Nghỉ thai sản' },
  { key: 'longLeave', label: 'Nghỉ phép / NKL dài ngày' },
  { key: 'dutyAfternoonOff', label: 'Nghỉ trực / nghỉ buổi chiều' },
  { key: 'externalMission', label: 'Công tác ngoại viện' },
];

const PATIENT_FIELDS: { key: FieldKey; label: string }[] = [
  { key: 'outpatients', label: 'Người bệnh ngoại trú' },
  { key: 'paraclinical', label: 'Người bệnh CLS' },
  { key: 'surgery', label: 'Người bệnh phẫu thuật' },
  { key: 'dischargedYesterday', label: 'Ra viện hôm qua' },
];

const BED_FIELDS: { key: FieldKey; label: string }[] = [
  { key: 'actualBeds', label: 'Giường thực kê' },
  { key: 'plannedBeds', label: 'Giường kế hoạch' },
];

const TREATMENT_FIELDS: { key: FieldKey; label: string }[] = [
  {
    key: 'inpatientTreatmentDays',
    label: 'Ngày ĐT nội trú (BN ra viện ngày qua)',
  },
];

const SAFETY_FIELDS: { key: FieldKey; label: string }[] = [
  { key: 'falls', label: 'Ca té ngã ngày qua' },
  { key: 'newPressureUlcers', label: 'Ca loét tì đè mới' },
  { key: 'idMixups', label: 'Nhầm lẫn xác định NB' },
  { key: 'medicationErrors', label: 'Sai sót dùng thuốc' },
];

function ReportSection({
  icon,
  title,
  subtitle,
  accent = ACCENT,
  children,
}: {
  icon: ReactNode;
  title: string;
  subtitle?: string;
  accent?: string;
  children: ReactNode;
}) {
  return (
    <Box
      sx={{
        borderRadius: 2.5,
        bgcolor: '#fff',
        border: `1px solid ${alpha('#0f172a', 0.07)}`,
        overflow: 'hidden',
        boxShadow: `0 1px 2px ${alpha('#0f172a', 0.03)}`,
      }}
    >
      <Stack
        direction="row"
        spacing={1.25}
        alignItems="center"
        sx={{
          px: 1.75,
          py: 1.25,
          bgcolor: alpha(accent, 0.05),
          borderBottom: `1px solid ${alpha(accent, 0.1)}`,
        }}
      >
        <Box
          sx={{
            width: 30,
            height: 30,
            borderRadius: 1.5,
            display: 'grid',
            placeItems: 'center',
            bgcolor: alpha(accent, 0.12),
            color: accent,
            flexShrink: 0,
          }}
        >
          {icon}
        </Box>
        <Box sx={{ minWidth: 0, flex: 1 }}>
          <Typography variant="subtitle2" fontWeight={800} sx={{ letterSpacing: '-0.01em', lineHeight: 1.2 }}>
            {title}
          </Typography>
          {subtitle ? (
            <Typography variant="caption" color="text.secondary" sx={{ lineHeight: 1.35 }}>
              {subtitle}
            </Typography>
          ) : null}
        </Box>
      </Stack>
      <Box sx={{ p: 1.35 }}>{children}</Box>
    </Box>
  );
}

function FieldGrid({
  fields,
  values,
  onChange,
  accent,
  columns,
}: {
  fields: { key: FieldKey; label: string }[];
  values: ndr.NursingDailyReportPayload;
  onChange: (key: FieldKey, value: number) => void;
  accent?: string;
  columns?: string | Record<string, string>;
}) {
  return (
    <Box
      sx={{
        display: 'grid',
        gridTemplateColumns: columns ?? {
          xs: '1fr',
          sm: 'repeat(2, 1fr)',
          md: 'repeat(3, 1fr)',
          lg: 'repeat(4, 1fr)',
        },
        gap: 1,
      }}
    >
      {fields.map((f) => (
        <IntegerStepperField
          key={f.key}
          label={f.label}
          value={values[f.key]}
          onChange={(v) => onChange(f.key, v)}
          accent={accent ?? ACCENT}
        />
      ))}
    </Box>
  );
}

export function NursingDailyReportDialog({
  open,
  onClose,
  onSaved,
  departmentId,
  departmentName,
  reportDate,
  existing,
}: Props) {
  const [form, setForm] = useState<ndr.NursingDailyReportPayload>(
    ndr.emptyNursingDailyPayload(departmentId, reportDate),
  );
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setForm(
      existing
        ? ndr.payloadFromReport(existing)
        : ndr.emptyNursingDailyPayload(departmentId, reportDate),
    );
  }, [open, departmentId, reportDate, existing]);

  const staffSumHint = useMemo(() => {
    const accounted =
      form.workingStaff +
      form.plannedLeave +
      form.unplannedLeave +
      form.maternityLeave +
      form.longLeave +
      form.dutyAfternoonOff +
      form.externalMission;
    if (form.totalStaff === 0 && accounted === 0) return null;
    if (accounted === form.totalStaff) return null;
    return `Gợi ý: đi làm + các loại nghỉ (${accounted}) khác tổng NV khoa (${form.totalStaff}). Có thể vẫn lưu nếu đúng thực tế.`;
  }, [form]);

  function setField(key: FieldKey, value: number) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  function setInpatientLevels(next: { level1: number; level2: number; level3: number }) {
    const total = next.level1 + next.level2 + next.level3;
    setForm((prev) => ({
      ...prev,
      inpatientsCareLevel1: next.level1,
      inpatientsCareLevel2: next.level2,
      inpatientsCareLevel3: next.level3,
      inpatients: total,
    }));
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setErr(null);
    try {
      const body = { ...form, submit: true };
      if (existing?.id) {
        await ndr.updateNursingDailyReport(existing.id, body);
      } else {
        await ndr.createNursingDailyReport(body);
      }
      onSaved?.();
      onClose();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Không lưu được báo cáo.'));
    } finally {
      setLoading(false);
    }
  }

  const dateLabel = (() => {
    const [y, m, d] = reportDate.split('-');
    return y && m && d ? `${d}/${m}/${y}` : reportDate;
  })();

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={ACCENT}
      icon={<LocalHospitalOutlinedIcon />}
      overline="Báo cáo điều dưỡng hằng ngày"
      title={existing ? 'Cập nhật báo cáo' : 'Nhập báo cáo mới'}
      description={`${departmentName} · Ngày ${dateLabel}`}
      formId="nursing-daily-report-form"
      submitLabel={existing ? 'Gửi báo cáo' : 'Gửi báo cáo'}
      error={err}
      onSubmit={submit}
      maxWidth={false}
      paperSx={{
        width: { xs: '100%', sm: 'min(1480px, 97vw)' },
        maxWidth: { xs: '100%', sm: '97vw' },
        m: { xs: 0, sm: 1.25 },
      }}
    >
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={1}
        alignItems={{ sm: 'center' }}
        justifyContent="space-between"
        sx={{
          px: 1.5,
          py: 1.15,
          borderRadius: 2,
          bgcolor: alpha(ACCENT, 0.04),
          border: `1px solid ${alpha(ACCENT, 0.12)}`,
        }}
      >
        <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.5 }}>
          Nhập số tự nhiên bằng nút <strong>− / +</strong>. Không phát sinh thì để{' '}
          <strong>0</strong>. Mỗi khoa chỉ có một phiếu / ngày.
        </Typography>
        <Stack direction="row" spacing={0.75} flexShrink={0}>
          <Chip
            size="small"
            label={departmentName}
            sx={{
              fontWeight: 700,
              maxWidth: 280,
              bgcolor: '#fff',
              border: `1px solid ${alpha(ACCENT, 0.18)}`,
              color: ACCENT,
              '& .MuiChip-label': { overflow: 'hidden', textOverflow: 'ellipsis' },
            }}
          />
          <Chip
            size="small"
            label={dateLabel}
            sx={{
              fontWeight: 700,
              bgcolor: '#fff',
              border: `1px solid ${alpha('#0f172a', 0.1)}`,
            }}
          />
        </Stack>
      </Stack>

      {staffSumHint && (
        <Alert severity="info" variant="outlined" sx={{ borderRadius: 2, py: 0.5 }}>
          {staffSumHint}
        </Alert>
      )}

      <ReportSection
        icon={<GroupsOutlinedIcon sx={{ fontSize: 18 }} />}
        title="Nhân lực"
        subtitle="Tình hình nhân sự trong ngày"
      >
        <FieldGrid fields={STAFF_FIELDS} values={form} onChange={setField} />
      </ReportSection>

      <ReportSection
        icon={<PeopleOutlinedIcon sx={{ fontSize: 18 }} />}
        title="Người bệnh"
        subtitle="Nội trú theo cấp chăm sóc · ngoại trú · CLS · phẫu thuật"
        accent="#0369a1"
      >
        <Stack spacing={1.15}>
          <InpatientCareLevelAccordion
            level1={form.inpatientsCareLevel1}
            level2={form.inpatientsCareLevel2}
            level3={form.inpatientsCareLevel3}
            onChange={setInpatientLevels}
            accent="#0369a1"
            defaultExpanded
          />
          <FieldGrid
            fields={PATIENT_FIELDS}
            values={form}
            onChange={setField}
            accent="#0369a1"
            columns={{
              xs: '1fr',
              sm: 'repeat(2, 1fr)',
              md: 'repeat(2, 1fr)',
              lg: 'repeat(4, 1fr)',
            }}
          />
        </Stack>
      </ReportSection>

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', md: '1.1fr 0.9fr' },
          gap: 1.5,
        }}
      >
        <ReportSection
          icon={<AirlineSeatFlatOutlinedIcon sx={{ fontSize: 18 }} />}
          title="Giường bệnh"
          accent="#0e7490"
        >
          <FieldGrid
            fields={BED_FIELDS}
            values={form}
            onChange={setField}
            accent="#0e7490"
            columns={{ xs: '1fr', sm: '1fr 1fr' }}
          />
        </ReportSection>

        <ReportSection
          icon={<MedicalServicesOutlinedIcon sx={{ fontSize: 18 }} />}
          title="Hoạt động điều trị"
          accent="#b45309"
        >
          <FieldGrid
            fields={TREATMENT_FIELDS}
            values={form}
            onChange={setField}
            accent="#b45309"
            columns={{ xs: '1fr' }}
          />
        </ReportSection>
      </Box>

      <ReportSection
        icon={<HealthAndSafetyOutlinedIcon sx={{ fontSize: 18 }} />}
        title="An toàn người bệnh"
        subtitle="Sự cố ngày qua — không có thì để 0"
        accent="#be123c"
      >
        <FieldGrid
          fields={SAFETY_FIELDS}
          values={form}
          onChange={setField}
          accent="#be123c"
        />
      </ReportSection>
    </WorkRequestDialogShell>
  );
}
