import AirlineSeatFlatOutlinedIcon from '@mui/icons-material/AirlineSeatFlatOutlined';
import CheckCircleRoundedIcon from '@mui/icons-material/CheckCircleRounded';
import EditOutlinedIcon from '@mui/icons-material/EditOutlined';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import HealthAndSafetyOutlinedIcon from '@mui/icons-material/HealthAndSafetyOutlined';
import LocalHospitalOutlinedIcon from '@mui/icons-material/LocalHospitalOutlined';
import MedicalServicesOutlinedIcon from '@mui/icons-material/MedicalServicesOutlined';
import PeopleOutlinedIcon from '@mui/icons-material/PeopleOutlined';
import UndoOutlinedIcon from '@mui/icons-material/UndoOutlined';
import WarningAmberRoundedIcon from '@mui/icons-material/WarningAmberRounded';
import { Box, Button, CircularProgress, Divider, Stack, Typography } from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useState, type ReactNode } from 'react';
import { extractApiErrorMessage } from '../../services/approvalSignatureService';
import type { NursingDailyReport } from '../../services/nursingDailyReportService';
import * as ndr from '../../services/nursingDailyReportService';
import { WorkRequestViewShell } from '../work/WorkRequestFormUi';

const ACCENT = '#0f766e';
const INK = '#0f172a';

type Props = {
  open: boolean;
  onClose: () => void;
  onEdit?: () => void;
  onRecalled?: () => void;
  report: NursingDailyReport;
};

type Row = { label: string; value: number; emphasize?: boolean; warn?: boolean };

function formatDate(iso: string) {
  const [y, m, d] = iso.split('-');
  return y && m && d ? `${d}/${m}/${y}` : iso;
}

function weekdayVi(iso: string) {
  const [y, m, d] = iso.split('-').map(Number);
  if (!y || !m || !d) return '';
  return ['Chủ nhật', 'Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy'][
    new Date(y, m - 1, d).getDay()
  ];
}

function formatStamp(raw?: string | null) {
  if (!raw) return '';
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return raw;
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yyyy = d.getFullYear();
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  return `${hh} giờ ${mi} phút · ${dd}/${mm}/${yyyy}`;
}

function Section({
  icon,
  title,
  tone = ACCENT,
  action,
  children,
}: {
  icon: ReactNode;
  title: string;
  tone?: string;
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <Box
      sx={{
        borderRadius: 2.75,
        bgcolor: '#fff',
        border: `1px solid ${alpha(INK, 0.07)}`,
        overflow: 'hidden',
        boxShadow: `0 1px 2px ${alpha(INK, 0.028)}`,
      }}
    >
      <Stack
        direction="row"
        alignItems="center"
        justifyContent="space-between"
        spacing={1}
        sx={{
          px: 2,
          py: 1.15,
          borderBottom: `1px solid ${alpha(INK, 0.06)}`,
          background: `linear-gradient(90deg, ${alpha(tone, 0.08)} 0%, transparent 70%)`,
        }}
      >
        <Stack direction="row" spacing={1.1} alignItems="center">
          <Box
            sx={{
              width: 28,
              height: 28,
              borderRadius: 1.4,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(tone, 0.14),
              color: tone,
            }}
          >
            {icon}
          </Box>
          <Typography variant="subtitle2" fontWeight={800} sx={{ letterSpacing: '-0.015em' }}>
            {title}
          </Typography>
        </Stack>
        {action}
      </Stack>
      <Box sx={{ p: { xs: 1.25, sm: 1.5 } }}>{children}</Box>
    </Box>
  );
}

function MetricRows({ rows, columns = 2 }: { rows: Row[]; columns?: 1 | 2 }) {
  return (
    <Box
      sx={{
        display: 'grid',
        gridTemplateColumns: {
          xs: '1fr',
          sm: columns === 1 ? '1fr' : '1fr 1fr',
        },
        columnGap: 0,
        rowGap: 0,
        borderRadius: 2,
        border: `1px solid ${alpha(INK, 0.07)}`,
        overflow: 'hidden',
        bgcolor: '#fff',
      }}
    >
      {rows.map((r, i) => {
        const color = r.warn && r.value > 0 ? '#be123c' : r.emphasize ? ACCENT : INK;
        const isLeft = columns === 2 && i % 2 === 0;
        return (
          <Stack
            key={r.label}
            direction="row"
            alignItems="center"
            justifyContent="space-between"
            spacing={1.5}
            sx={{
              px: 1.5,
              py: 1.05,
              minHeight: 48,
              bgcolor: Math.floor(i / columns) % 2 === 0 ? alpha(INK, 0.018) : '#fff',
              borderRight: isLeft ? { sm: `1px solid ${alpha(INK, 0.06)}` } : undefined,
              borderTop: i >= columns ? `1px solid ${alpha(INK, 0.05)}` : undefined,
            }}
          >
            <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.35, pr: 1 }}>
              {r.label}
            </Typography>
            <Typography
              fontWeight={800}
              sx={{
                fontSize: '1.05rem',
                letterSpacing: '-0.03em',
                color,
                fontVariantNumeric: 'tabular-nums',
                flexShrink: 0,
              }}
            >
              {r.value}
            </Typography>
          </Stack>
        );
      })}
    </Box>
  );
}

function KpiCard({
  label,
  value,
  hint,
  icon,
  tone = ACCENT,
  alert,
}: {
  label: string;
  value: string;
  hint?: string;
  icon: ReactNode;
  tone?: string;
  alert?: boolean;
}) {
  const color = alert ? '#be123c' : tone;
  return (
    <Box
      sx={{
        position: 'relative',
        px: 1.75,
        py: 1.6,
        pl: 1.85,
        borderRadius: 2.75,
        overflow: 'hidden',
        minHeight: 118,
        bgcolor: '#fff',
        border: `1px solid ${alpha(color, 0.14)}`,
        backgroundImage: `linear-gradient(145deg, ${alpha(color, 0.09)} 0%, ${alpha(color, 0.02)} 42%, #fff 100%)`,
        boxShadow: `0 1px 2px ${alpha(INK, 0.03)}, 0 10px 28px ${alpha(INK, 0.045)}`,
        transition: 'transform 0.15s ease, box-shadow 0.15s ease',
        '&:hover': {
          transform: 'translateY(-2px)',
          boxShadow: `0 12px 32px ${alpha(color, 0.14)}`,
        },
        '&::after': {
          content: '""',
          position: 'absolute',
          right: -18,
          top: -18,
          width: 72,
          height: 72,
          borderRadius: '50%',
          bgcolor: alpha(color, 0.07),
        },
      }}
    >
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
        <Typography
          variant="caption"
          fontWeight={800}
          sx={{
            color: alpha(color, 0.85),
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            fontSize: '0.66rem',
            lineHeight: 1.3,
          }}
        >
          {label}
        </Typography>
        <Box
          sx={{
            width: 34,
            height: 34,
            borderRadius: 1.75,
            display: 'grid',
            placeItems: 'center',
            flexShrink: 0,
            bgcolor: alpha(color, 0.14),
            color,
            border: `1px solid ${alpha(color, 0.16)}`,
            boxShadow: `inset 0 1px 0 ${alpha('#fff', 0.65)}`,
            zIndex: 1,
          }}
        >
          {icon}
        </Box>
      </Stack>

      <Typography
        fontWeight={850}
        sx={{
          mt: 1.05,
          fontSize: { xs: '1.65rem', sm: '1.85rem' },
          lineHeight: 1,
          letterSpacing: '-0.05em',
          color,
          fontVariantNumeric: 'tabular-nums',
          zIndex: 1,
          position: 'relative',
        }}
      >
        {value}
      </Typography>

      {hint ? (
        <Typography
          variant="caption"
          sx={{
            mt: 0.85,
            display: 'block',
            lineHeight: 1.4,
            color: alpha(INK, 0.52),
            position: 'relative',
            zIndex: 1,
            pr: 0.5,
          }}
        >
          {hint}
        </Typography>
      ) : null}
    </Box>
  );
}

export function NursingDailyReportViewDialog({ open, onClose, onEdit, onRecalled, report }: Props) {
  const [recalling, setRecalling] = useState(false);
  const [recallErr, setRecallErr] = useState<string | null>(null);
  const canEdit = report.canEdit === true;
  const canRecall = report.canRecall === true;
  const dateLabel = formatDate(report.reportDate);
  const weekday = weekdayVi(report.reportDate);
  const safetyTotal =
    report.falls + report.newPressureUlcers + report.idMixups + report.medicationErrors;
  const leaveTotal =
    report.plannedLeave +
    report.unplannedLeave +
    report.maternityLeave +
    report.longLeave +
    report.dutyAfternoonOff +
    report.externalMission;
  const occupancy =
    report.plannedBeds > 0
      ? Math.round((report.actualBeds / report.plannedBeds) * 100)
      : null;

  async function handleRecall() {
    if (!canRecall || recalling) return;
    const ok = window.confirm(
      'Thu hồi báo cáo đã gửi về trạng thái nháp để chỉnh sửa?\nTrưởng khoa chỉ thu hồi được trong vòng 1 ngày kể từ lúc gửi.',
    );
    if (!ok) return;
    setRecalling(true);
    setRecallErr(null);
    try {
      await ndr.recallNursingDailyReport(report.id);
      onRecalled?.();
      onClose();
    } catch (ex) {
      setRecallErr(extractApiErrorMessage(ex, 'Không thu hồi được báo cáo.'));
    } finally {
      setRecalling(false);
    }
  }

  return (
    <WorkRequestViewShell
      open={open}
      onClose={onClose}
      accent={ACCENT}
      icon={<LocalHospitalOutlinedIcon />}
      overline="Báo cáo điều dưỡng hằng ngày"
      title={report.departmentName}
      description={`${weekday} · ${dateLabel}`}
      maxWidth={false}
      paperSx={{
        width: { xs: '100%', sm: 'min(1320px, 96vw)' },
        maxWidth: { xs: '100%', sm: '96vw' },
        m: { xs: 0, sm: 1.25 },
        bgcolor: '#eef2f6',
      }}
      headerExtra={
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap alignItems="center">
          <Box
            sx={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 0.6,
              px: 1.1,
              py: 0.45,
              borderRadius: 99,
              bgcolor: alpha('#15803d', 0.1),
              color: '#15803d',
              border: `1px solid ${alpha('#15803d', 0.18)}`,
            }}
          >
            <CheckCircleRoundedIcon sx={{ fontSize: 15 }} />
            <Typography variant="caption" fontWeight={800}>
              Đã nộp
            </Typography>
          </Box>
          <Box
            sx={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 0.6,
              px: 1.1,
              py: 0.45,
              borderRadius: 99,
              bgcolor: safetyTotal > 0 ? alpha('#be123c', 0.1) : alpha(ACCENT, 0.1),
              color: safetyTotal > 0 ? '#be123c' : ACCENT,
              border: `1px solid ${
                safetyTotal > 0 ? alpha('#be123c', 0.2) : alpha(ACCENT, 0.18)
              }`,
            }}
          >
            {safetyTotal > 0 ? (
              <WarningAmberRoundedIcon sx={{ fontSize: 15 }} />
            ) : (
              <HealthAndSafetyOutlinedIcon sx={{ fontSize: 15 }} />
            )}
            <Typography variant="caption" fontWeight={800}>
              {safetyTotal > 0 ? `${safetyTotal} sự cố an toàn` : 'An toàn — không sự cố'}
            </Typography>
          </Box>
        </Stack>
      }
      footer={
        <Box
          sx={{
            px: { xs: 2, sm: 3 },
            py: 1.65,
            borderTop: `1px solid ${alpha(INK, 0.08)}`,
            bgcolor: '#fff',
          }}
        >
          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            spacing={1.25}
            justifyContent="space-between"
            alignItems={{ sm: 'center' }}
          >
            <Typography variant="caption" color="text.secondary" sx={{ lineHeight: 1.45 }}>
              {recallErr ? (
                <Box component="span" sx={{ color: 'error.main', fontWeight: 700 }}>
                  {recallErr}
                </Box>
              ) : report.updatedByUsername ? (
                `Cập nhật bởi ${report.updatedByUsername}`
              ) : report.createdByUsername ? (
                `Tạo bởi ${report.createdByUsername}`
              ) : (
                'Phiếu đã lưu'
              )}
              {!recallErr && (report.updatedAt || report.createdAt)
                ? ` · ${formatStamp(report.updatedAt || report.createdAt)}`
                : ''}
            </Typography>
            <Stack direction="row" spacing={1.25} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
              <Button onClick={onClose} variant="outlined" color="inherit" sx={{ borderRadius: 2, px: 2 }}>
                Đóng
              </Button>
              {canRecall && (
                <Button
                  onClick={() => void handleRecall()}
                  variant="outlined"
                  color="warning"
                  disabled={recalling}
                  startIcon={recalling ? <CircularProgress size={14} /> : <UndoOutlinedIcon />}
                  sx={{ borderRadius: 2, px: 2, fontWeight: 750 }}
                >
                  Thu hồi
                </Button>
              )}
              {canEdit && onEdit && (
                <Button
                  onClick={onEdit}
                  variant="contained"
                  startIcon={<EditOutlinedIcon />}
                  sx={{
                    borderRadius: 2,
                    px: 2.25,
                    fontWeight: 750,
                    bgcolor: ACCENT,
                    boxShadow: `0 8px 18px ${alpha(ACCENT, 0.28)}`,
                    '&:hover': { bgcolor: ACCENT, filter: 'brightness(0.93)' },
                  }}
                >
                  Chỉnh sửa
                </Button>
              )}
            </Stack>
          </Stack>
        </Box>
      }
    >
      {/* KPI overview */}
      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr 1fr', lg: 'repeat(4, 1fr)' },
          gap: 1.25,
        }}
      >
        <KpiCard
          label="Nhân lực"
          value={`${report.workingStaff}/${report.totalStaff}`}
          hint={`${leaveTotal} NV không đi làm / nghỉ / công tác`}
          icon={<GroupsOutlinedIcon sx={{ fontSize: 18 }} />}
        />
        <KpiCard
          label="Nội trú"
          value={String(report.inpatients)}
          hint={`Ngoại trú ${report.outpatients} · CLS ${report.paraclinical}`}
          tone="#0369a1"
          icon={<PeopleOutlinedIcon sx={{ fontSize: 18 }} />}
        />
        <KpiCard
          label="Giường"
          value={`${report.actualBeds}/${report.plannedBeds}`}
          hint={occupancy != null ? `Tỷ lệ thực kê ${occupancy}% kế hoạch` : 'Chưa có giường kế hoạch'}
          tone="#0e7490"
          icon={<AirlineSeatFlatOutlinedIcon sx={{ fontSize: 18 }} />}
        />
        <KpiCard
          label="An toàn"
          value={String(safetyTotal)}
          hint={safetyTotal > 0 ? 'Cần theo dõi sự cố ngày qua' : 'Không ghi nhận sự cố'}
          alert={safetyTotal > 0}
          icon={
            safetyTotal > 0 ? (
              <WarningAmberRoundedIcon sx={{ fontSize: 18 }} />
            ) : (
              <HealthAndSafetyOutlinedIcon sx={{ fontSize: 18 }} />
            )
          }
        />
      </Box>

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', lg: '1.35fr 1fr' },
          gap: 1.35,
          alignItems: 'start',
        }}
      >
        <Stack spacing={1.35}>
          <Section icon={<GroupsOutlinedIcon sx={{ fontSize: 17 }} />} title="Nhân lực trong ngày">
            <MetricRows
              rows={[
                { label: 'Tổng số nhân viên khoa', value: report.totalStaff, emphasize: true },
                { label: 'Số nhân viên đi làm', value: report.workingStaff, emphasize: true },
                { label: 'Nghỉ theo kế hoạch', value: report.plannedLeave },
                { label: 'Nghỉ đột xuất', value: report.unplannedLeave },
                { label: 'Nghỉ thai sản', value: report.maternityLeave },
                { label: 'Nghỉ phép / NKL dài ngày', value: report.longLeave },
                { label: 'Nghỉ trực / nghỉ buổi chiều', value: report.dutyAfternoonOff },
                { label: 'Công tác ngoại viện', value: report.externalMission },
              ]}
            />
          </Section>

          <Section
            icon={<PeopleOutlinedIcon sx={{ fontSize: 17 }} />}
            title="Người bệnh"
            tone="#0369a1"
          >
            <MetricRows
              rows={[
                { label: 'Nội trú', value: report.inpatients, emphasize: true },
                { label: 'Ngoại trú', value: report.outpatients },
                { label: 'CLS', value: report.paraclinical },
                { label: 'Phẫu thuật', value: report.surgery },
                { label: 'Ra viện hôm qua', value: report.dischargedYesterday },
              ]}
            />
          </Section>
        </Stack>

        <Stack spacing={1.35}>
          <Section
            icon={<AirlineSeatFlatOutlinedIcon sx={{ fontSize: 17 }} />}
            title="Giường bệnh"
            tone="#0e7490"
          >
            <MetricRows
              columns={1}
              rows={[
                { label: 'Giường thực kê', value: report.actualBeds, emphasize: true },
                { label: 'Giường kế hoạch', value: report.plannedBeds },
              ]}
            />
            {occupancy != null && (
              <Box sx={{ mt: 1.25 }}>
                <Stack direction="row" justifyContent="space-between" sx={{ mb: 0.6 }}>
                  <Typography variant="caption" color="text.secondary" fontWeight={650}>
                    Thực kê / kế hoạch
                  </Typography>
                  <Typography variant="caption" fontWeight={800} sx={{ color: '#0e7490' }}>
                    {occupancy}%
                  </Typography>
                </Stack>
                <Box
                  sx={{
                    height: 8,
                    borderRadius: 99,
                    bgcolor: alpha('#0e7490', 0.12),
                    overflow: 'hidden',
                  }}
                >
                  <Box
                    sx={{
                      width: `${Math.min(100, occupancy)}%`,
                      height: '100%',
                      bgcolor: '#0e7490',
                      borderRadius: 99,
                    }}
                  />
                </Box>
              </Box>
            )}
          </Section>

          <Section
            icon={<MedicalServicesOutlinedIcon sx={{ fontSize: 17 }} />}
            title="Hoạt động điều trị"
            tone="#b45309"
          >
            <MetricRows
              columns={1}
              rows={[
                {
                  label: 'Ngày ĐT nội trú (BN ra viện ngày qua)',
                  value: report.inpatientTreatmentDays,
                  emphasize: true,
                },
              ]}
            />
          </Section>

          <Section
            icon={<HealthAndSafetyOutlinedIcon sx={{ fontSize: 17 }} />}
            title="An toàn người bệnh"
            tone="#be123c"
            action={
              <Typography
                variant="caption"
                fontWeight={800}
                sx={{ color: safetyTotal > 0 ? '#be123c' : ACCENT }}
              >
                {safetyTotal > 0 ? `${safetyTotal} sự cố` : 'An toàn'}
              </Typography>
            }
          >
            {safetyTotal === 0 ? (
              <Stack
                direction="row"
                spacing={1.1}
                alignItems="center"
                sx={{
                  px: 1.5,
                  py: 1.35,
                  borderRadius: 2,
                  bgcolor: alpha(ACCENT, 0.06),
                  border: `1px solid ${alpha(ACCENT, 0.14)}`,
                }}
              >
                <CheckCircleRoundedIcon sx={{ color: ACCENT, fontSize: 22 }} />
                <Box>
                  <Typography variant="body2" fontWeight={750}>
                    Không ghi nhận sự cố
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    Té ngã, loét tì đè, nhầm NB, sai sót thuốc đều = 0
                  </Typography>
                </Box>
              </Stack>
            ) : (
              <MetricRows
                columns={1}
                rows={[
                  { label: 'Ca té ngã ngày qua', value: report.falls, warn: true },
                  { label: 'Ca loét tì đè mới', value: report.newPressureUlcers, warn: true },
                  { label: 'Nhầm lẫn xác định NB', value: report.idMixups, warn: true },
                  { label: 'Sai sót dùng thuốc', value: report.medicationErrors, warn: true },
                ]}
              />
            )}
          </Section>
        </Stack>
      </Box>

      <Divider sx={{ borderColor: alpha(INK, 0.06) }} />
      <Typography variant="caption" color="text.secondary" sx={{ textAlign: 'center', display: 'block' }}>
        Báo cáo điều dưỡng · 1 phiếu / khoa / ngày · Có thể chỉnh sửa sau khi nộp
      </Typography>
    </WorkRequestViewShell>
  );
}
