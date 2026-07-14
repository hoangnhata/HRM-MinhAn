import AccessTimeIcon from "@mui/icons-material/AccessTime";
import NightsStayIcon from "@mui/icons-material/NightsStay";
import TimelineIcon from "@mui/icons-material/Timeline";
import WbTwilightIcon from "@mui/icons-material/WbTwilight";
import {
  Box,
  Chip,
  Dialog,
  DialogContent,
  DialogTitle,
  Divider,
  Grid,
  Paper,
  Stack,
  Typography,
} from "@mui/material";
import { alpha, useTheme } from "@mui/material/styles";
import * as attSvc from "../../services/attendanceService";
import type { AttendanceRow } from "./AttendanceRowActions";
import {
  continuousShiftHours,
  formatPunchTime,
  formatShiftTime,
  formatWorkedHours,
  formatWorkUnits,
  parseLocalDate,
  scheduleForDate,
  displayHoursFromUnits,
  type ShiftScheduleInfo,
} from "../../utils/shiftSchedule";

type Props = {
  open: boolean;
  onClose: () => void;
  workDate: string;
  row: AttendanceRow | null;
  employeeName?: string;
  monthSummary?: attSvc.MonthSummary | null;
  schedule?: ShiftScheduleInfo;
  continuousShift?: boolean;
};

function DetailRow({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <Stack
      direction="row"
      justifyContent="space-between"
      spacing={2}
      sx={{ py: 0.75 }}
    >
      <Typography variant="body2" color="text.secondary">
        {label}
      </Typography>
      <Typography variant="body2" fontWeight={600} textAlign="right">
        {value}
      </Typography>
    </Stack>
  );
}

function ShiftCard({
  title,
  icon,
  accent,
  checkIn,
  checkOut,
  hours,
  units,
  scheduleLine,
}: {
  title: string;
  icon: React.ReactNode;
  accent: string;
  checkIn: string;
  checkOut: string;
  hours: string;
  units: string;
  scheduleLine: string;
}) {
  return (
    <Paper
      variant="outlined"
      sx={{
        p: 2,
        borderRadius: 2.5,
        borderColor: alpha(accent, 0.25),
        bgcolor: alpha(accent, 0.04),
      }}
    >
      <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 1.5 }}>
        <Box sx={{ color: accent }}>{icon}</Box>
        <Typography variant="subtitle2" fontWeight={700}>
          {title}
        </Typography>
      </Stack>
      <Typography
        variant="caption"
        color="text.secondary"
        display="block"
        sx={{ mb: 1.5 }}
      >
        Lịch ca: {scheduleLine}
      </Typography>
      <DetailRow label="Giờ vào" value={checkIn} />
      <DetailRow label="Giờ ra" value={checkOut} />
      <Divider sx={{ my: 1 }} />
      <DetailRow label="Số giờ làm" value={hours} />
      <DetailRow label="Công ca" value={units} />
    </Paper>
  );
}

export function AttendanceDayDetailDialog({
  open,
  onClose,
  workDate,
  row,
  employeeName,
  monthSummary,
  schedule: scheduleProp,
  continuousShift,
}: Props) {
  const theme = useTheme();
  const parsed = parseLocalDate(workDate);
  const sch = scheduleProp ?? scheduleForDate(workDate);
  const continuous = continuousShift ?? sch.continuousShift;
  const dateLabel = parsed
    ? parsed.toLocaleDateString("vi-VN", {
        weekday: "long",
        day: "numeric",
        month: "long",
        year: "numeric",
      })
    : workDate || "—";

  const morningUnits = row ? Number(row.morningWorkUnits ?? 0) : 0;
  const afternoonUnits = row ? Number(row.afternoonWorkUnits ?? 0) : 0;
  const overtimeUnits = row ? Number(row.overtimeWorkUnits ?? 0) : 0;
  const dayHours = continuous
    ? continuousShiftHours(sch)
    : (sch.morningHours ?? 0) + (sch.afternoonHours ?? 0) || 8;
  const totalUnits = morningUnits + afternoonUnits;
  const totalShiftUnits = sch.morningUnits + sch.afternoonUnits;
  const continuousH = displayHoursFromUnits(
    totalUnits,
    totalShiftUnits,
    dayHours,
    dayHours,
    {
      hasPunch: Boolean(row?.morningCheckIn || row?.afternoonCheckOut),
    },
  );
  const morningH = displayHoursFromUnits(
    morningUnits,
    sch.morningUnits,
    sch.morningHours,
    dayHours,
    { hasPunch: Boolean(row?.morningCheckIn || row?.morningCheckOut) },
  );
  const afternoonH = displayHoursFromUnits(
    afternoonUnits,
    sch.afternoonUnits,
    sch.afternoonHours,
    dayHours,
    { hasPunch: Boolean(row?.afternoonCheckIn || row?.afternoonCheckOut) },
  );
  const overtimeH = overtimeUnits > 0 ? overtimeUnits * dayHours : 0;
  const status = row ? String(row.status ?? "") : "";
  const partialLabels =
    status === "PARTIAL" && row ? attSvc.partialStatusLabels(row) : [];
  const lateMin = row ? Number(row.lateMinutes ?? 0) : 0;
  const lateExempt = Boolean(row?.lateMinutesExempt);
  const dayPenalty = attSvc.dayLatePenalty(lateMin, lateExempt, monthSummary);
  const punchTimes = Array.isArray(row?.punchTimes)
    ? (row.punchTimes as string[])
    : [];
  const isDeployment = attSvc.isDeploymentRow(row);

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle sx={{ pb: 1 }}>
        <Typography variant="overline" color="text.secondary" display="block">
          Chi tiết chấm công
        </Typography>
        <Typography variant="h6" fontWeight={700}>
          {dateLabel}
        </Typography>
        {employeeName && (
          <Typography variant="body2" color="text.secondary">
            {employeeName}
          </Typography>
        )}
      </DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pb: 1 }}>
          <Paper variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
            <Stack
              direction="row"
              spacing={1}
              flexWrap="wrap"
              useFlexGap
              alignItems="center"
            >
              <Chip
                size="small"
                label={sch.seasonLabel}
                color={sch.summer ? "warning" : "info"}
                variant="outlined"
              />
              {status === "PARTIAL" ? (
                <>
                  {partialLabels.map((label) => (
                    <Chip
                      key={label}
                      size="small"
                      label={label}
                      color={label === "Ngoài giờ" ? "info" : "warning"}
                      variant="outlined"
                    />
                  ))}
                  {partialLabels.length === 0 && (
                    <Chip
                      size="small"
                      label="Thiếu ca"
                      color="warning"
                      variant="outlined"
                    />
                  )}
                </>
              ) : (
                <Chip
                  size="small"
                  label={attSvc.attendanceStatusLabel(row)}
                  color={
                    status === "PRESENT"
                      ? "success"
                      : status === "LEAVE"
                        ? "info"
                        : status === "BUSINESS_TRIP"
                          ? "warning"
                          : status === "DEPLOYMENT"
                            ? "info"
                            : "default"
                  }
                  variant="outlined"
                />
              )}
              {isDeployment && (
                <Chip
                  size="small"
                  label="Điều động"
                  color="info"
                  sx={{ fontWeight: 700 }}
                />
              )}
              {row?.lateMinutesExempt ? (
                <Chip
                  size="small"
                  label="Miễn phạt muộn"
                  color="success"
                  variant="outlined"
                />
              ) : lateMin > 0 ? (
                <Chip
                  size="small"
                  icon={<AccessTimeIcon />}
                  label={`${lateMin} phút muộn/về sớm`}
                  color="warning"
                />
              ) : null}
            </Stack>
          </Paper>

          {continuous ? (
            <ShiftCard
              title="Ca thông tầm"
              icon={<TimelineIcon />}
              accent={theme.palette.success.main}
              checkIn={formatPunchTime(row?.morningCheckIn as string)}
              checkOut={formatPunchTime(row?.afternoonCheckOut as string)}
              hours={formatWorkedHours(continuousH)}
              units={
                totalUnits > 0
                  ? formatWorkUnits(totalUnits, { suffix: true })
                  : "—"
              }
              scheduleLine={`${formatShiftTime(sch.morningStart)} – ${formatShiftTime(sch.afternoonEnd)} (${dayHours}h, không nghỉ trưa)`}
            />
          ) : (
            <Grid container spacing={2}>
              <Grid item xs={12} sm={6}>
                <ShiftCard
                  title="Ca sáng"
                  icon={<WbTwilightIcon />}
                  accent={theme.palette.primary.main}
                  checkIn={formatPunchTime(row?.morningCheckIn as string)}
                  checkOut={formatPunchTime(row?.morningCheckOut as string)}
                  hours={formatWorkedHours(morningH)}
                  units={
                    morningUnits > 0
                      ? formatWorkUnits(morningUnits, { suffix: true })
                      : "—"
                  }
                  scheduleLine={`${formatShiftTime(sch.morningStart)} – ${formatShiftTime(sch.morningEnd)} (${sch.morningHours}h)`}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <ShiftCard
                  title="Ca chiều"
                  icon={<NightsStayIcon />}
                  accent={theme.palette.secondary.main}
                  checkIn={formatPunchTime(row?.afternoonCheckIn as string)}
                  checkOut={formatPunchTime(row?.afternoonCheckOut as string)}
                  hours={formatWorkedHours(afternoonH)}
                  units={
                    afternoonUnits > 0
                      ? formatWorkUnits(afternoonUnits, { suffix: true })
                      : "—"
                  }
                  scheduleLine={`${formatShiftTime(sch.afternoonStart)} – ${formatShiftTime(sch.afternoonEnd)} (${sch.afternoonHours}h)`}
                />
              </Grid>
            </Grid>
          )}

          {punchTimes.length > 0 && (
            <Paper
              variant="outlined"
              sx={{
                p: 2,
                borderRadius: 2.5,
                bgcolor: alpha(theme.palette.grey[500], 0.04),
              }}
            >
              <Typography variant="subtitle2" fontWeight={700} sx={{ mb: 1 }}>
                Log máy chấm ({punchTimes.length} lần)
              </Typography>
              <Stack direction="row" spacing={0.75} flexWrap="wrap" useFlexGap>
                {punchTimes.map((t) => (
                  <Chip
                    key={t}
                    size="small"
                    label={formatPunchTime(t)}
                    variant="outlined"
                    sx={{ fontWeight: 600 }}
                  />
                ))}
              </Stack>
              <Typography
                variant="caption"
                color="text.secondary"
                display="block"
                sx={{ mt: 1.25 }}
              >
                Giờ ca sáng/chiều được suy ra từ các lần quẹt trên theo lịch ca
                và cửa sổ chấm công.
              </Typography>
            </Paper>
          )}

          <Paper variant="outlined" sx={{ p: 2, borderRadius: 2.5 }}>
            <Typography variant="subtitle2" fontWeight={700} sx={{ mb: 1 }}>
              Tổng hợp ngày
            </Typography>
            <DetailRow
              label="Tổng công"
              value={
                row
                  ? formatWorkUnits(
                      Number(
                        row.totalWorkUnits ??
                          morningUnits + afternoonUnits + overtimeUnits,
                      ),
                    )
                  : "—"
              }
            />
            <DetailRow
              label="Tổng giờ làm"
              value={formatWorkedHours(
                continuous
                  ? continuousH + overtimeH
                  : morningH + afternoonH + overtimeH,
              )}
            />
            {overtimeUnits > 0 && (
              <DetailRow
                label="Ngoài giờ (điều động)"
                value={`${formatWorkedHours(overtimeH)} · ${formatWorkUnits(overtimeUnits, { suffix: true })}`}
              />
            )}
            {row && lateMin > 0 && (
              <DetailRow
                label="Muộn / về sớm"
                value={lateExempt ? "Miễn phạt" : `${lateMin} phút`}
              />
            )}
            {row && (lateMin > 0 || dayPenalty.display !== "—") && (
              <DetailRow
                label="Phạt muộn/sớm (ngày)"
                value={
                  lateExempt ? (
                    "—"
                  ) : dayPenalty.display === "Kiểm điểm" ? (
                    <Typography
                      component="span"
                      color="error.main"
                      fontWeight={600}
                    >
                      Cần tự kiểm điểm
                    </Typography>
                  ) : (
                    dayPenalty.display
                  )
                }
              />
            )}
            {row?.forgotShifts ? (
              <DetailRow
                label="Thiếu ca chấm"
                value={String(row.forgotShifts)}
              />
            ) : null}
            {row?.note ? (
              <DetailRow label="Ghi chú" value={String(row.note)} />
            ) : null}
            {!row && (
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                Chưa có bản ghi chấm công cho ngày này.
              </Typography>
            )}
          </Paper>
        </Stack>
      </DialogContent>
    </Dialog>
  );
}
