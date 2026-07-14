import WbSunnyIcon from "@mui/icons-material/WbSunny";
import AcUnitIcon from "@mui/icons-material/AcUnit";
import WbTwilightIcon from "@mui/icons-material/WbTwilight";
import NightsStayIcon from "@mui/icons-material/NightsStay";
import TimelineIcon from "@mui/icons-material/Timeline";
import ChildCareIcon from "@mui/icons-material/ChildCare";
import EditIcon from "@mui/icons-material/Edit";
import {
  Box,
  Button,
  Chip,
  Paper,
  Stack,
  Switch,
  Typography,
} from "@mui/material";
import { alpha, useTheme } from "@mui/material/styles";
import {
  continuousShiftHours,
  formatShiftTime,
  scheduleForDate,
  type ShiftScheduleInfo,
} from "../../utils/shiftSchedule";

type Props = {
  schedule?: ShiftScheduleInfo;
  date?: Date;
  canEdit?: boolean;
  onEdit?: () => void;
  /** HR/Admin: quản lý ca thông tầm / nuôi con nhỏ cho nhân viên đang chọn */
  canManageContinuous?: boolean;
  employeeName?: string;
  continuousShift?: boolean;
  continuousSaving?: boolean;
  onContinuousShiftChange?: (checked: boolean) => void;
  youngChild?: boolean;
  youngChildSaving?: boolean;
  onYoungChildChange?: (checked: boolean) => void;
  /** Nhãn tháng đang xem, ví dụ "tháng 7/2026" */
  periodLabel?: string;
};

function ShiftBlock({
  icon,
  title,
  hours,
  units,
  start,
  end,
  accent,
}: {
  icon: React.ReactNode;
  title: string;
  hours: number;
  units: string;
  start: string;
  end: string;
  accent: string;
}) {
  const theme = useTheme();
  return (
    <Paper
      elevation={0}
      sx={{
        flex: 1,
        minWidth: 200,
        p: 2.25,
        borderRadius: 3,
        border: `1px solid ${alpha(accent, 0.18)}`,
        bgcolor: alpha(accent, 0.04),
        transition: "transform 0.2s, box-shadow 0.2s",
        "&:hover": {
          transform: "translateY(-1px)",
          boxShadow: `0 8px 24px ${alpha(accent, 0.1)}`,
        },
      }}
    >
      <Stack direction="row" spacing={1.75} alignItems="flex-start">
        <Box
          sx={{
            width: 44,
            height: 44,
            borderRadius: 2.5,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            bgcolor: alpha(accent, 0.14),
            color: accent,
            flexShrink: 0,
          }}
        >
          {icon}
        </Box>
        <Box sx={{ minWidth: 0 }}>
          <Typography
            variant="subtitle2"
            fontWeight={700}
            sx={{ letterSpacing: "-0.01em" }}
          >
            {title}
          </Typography>
          <Typography
            variant="caption"
            color="text.secondary"
            display="block"
            sx={{ mt: 0.25 }}
          >
            {hours} giờ · {units}
          </Typography>
          <Typography
            variant="h6"
            fontWeight={700}
            sx={{
              mt: 1,
              letterSpacing: "-0.02em",
              color: theme.palette.text.primary,
              fontSize: "1.05rem",
            }}
          >
            {formatShiftTime(start)}
            <Typography
              component="span"
              variant="body2"
              color="text.secondary"
              sx={{ mx: 0.75, fontWeight: 500 }}
            >
              →
            </Typography>
            {formatShiftTime(end)}
          </Typography>
        </Box>
      </Stack>
    </Paper>
  );
}

function ContinuousShiftBlock({ schedule }: { schedule: ShiftScheduleInfo }) {
  const theme = useTheme();
  const totalHours = schedule.effectiveDayHours ?? continuousShiftHours(schedule);
  const totalUnits = schedule.morningUnits + schedule.afternoonUnits;
  const unitsLabel = `${Number(totalUnits).toFixed(2).replace(".", ",")} công`;
  return (
    <ShiftBlock
      icon={<TimelineIcon />}
      title={schedule.youngChild ? "Ca thông tầm · nuôi con nhỏ" : "Ca thông tầm"}
      hours={totalHours}
      units={`${unitsLabel} · không nghỉ trưa`}
      start={schedule.morningStart}
      end={schedule.afternoonEnd}
      accent={theme.palette.success.main}
    />
  );
}

export function AttendanceScheduleBanner({
  schedule: scheduleProp,
  date,
  canEdit,
  onEdit,
  canManageContinuous,
  employeeName,
  continuousShift,
  continuousSaving,
  onContinuousShiftChange,
  youngChild,
  youngChildSaving,
  onYoungChildChange,
  periodLabel,
}: Props) {
  const theme = useTheme();
  const schedule = scheduleProp ?? scheduleForDate(date ?? new Date());
  const seasonColor = schedule.summer
    ? theme.palette.warning.main
    : theme.palette.info.main;
  const SeasonIcon = schedule.summer ? WbSunnyIcon : AcUnitIcon;
  const continuous = schedule.continuousShift ?? continuousShift;
  const hasYoungChild = schedule.youngChild ?? youngChild;
  const dayHours =
    schedule.effectiveDayHours ??
    (continuous
      ? continuousShiftHours(schedule)
      : (schedule.morningHours ?? 0) + (schedule.afternoonHours ?? 0));

  return (
    <Paper
      elevation={0}
      sx={{
        mb: 2.5,
        borderRadius: 3.5,
        border: `1px solid ${alpha(seasonColor, 0.2)}`,
        background: `linear-gradient(135deg, ${alpha(seasonColor, 0.11)} 0%, ${alpha("#fff", 0.98)} 42%, ${alpha(theme.palette.primary.main, 0.05)} 100%)`,
        boxShadow: `0 10px 36px ${alpha("#0f172a", 0.06)}`,
        overflow: "hidden",
      }}
    >
      <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
        <Stack
          direction={{ xs: "column", sm: "row" }}
          alignItems={{ sm: "center" }}
          justifyContent="space-between"
          spacing={2}
          sx={{ mb: 2.25 }}
        >
          <Stack direction="row" spacing={1.75} alignItems="center">
            <Box
              sx={{
                width: 48,
                height: 48,
                borderRadius: 3,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                bgcolor: alpha(seasonColor, 0.16),
                color: seasonColor,
                boxShadow: `inset 0 0 0 1px ${alpha(seasonColor, 0.2)}`,
              }}
            >
              <SeasonIcon />
            </Box>
            <Box>
              <Typography
                variant="overline"
                sx={{
                  color: "text.secondary",
                  fontWeight: 700,
                  letterSpacing: "0.1em",
                  lineHeight: 1.2,
                }}
              >
                Lịch làm việc hiện tại
              </Typography>
              <Typography
                variant="h6"
                fontWeight={800}
                sx={{ letterSpacing: "-0.025em", mt: 0.25 }}
              >
                {schedule.seasonLabel}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Áp dụng {schedule.periodLabel}
                {schedule.referenceDate
                  ? ` · tham chiếu ${schedule.referenceDate}`
                  : ""}
                {hasYoungChild ? ` · ${dayHours}h = 1 công` : ""}
              </Typography>
            </Box>
          </Stack>
          <Stack
            direction="row"
            spacing={1}
            alignItems="center"
            flexWrap="wrap"
            useFlexGap
          >
            {continuous && (
              <Chip
                icon={<TimelineIcon sx={{ fontSize: "18px !important" }} />}
                label="Thông tầm"
                size="small"
                sx={{
                  fontWeight: 700,
                  bgcolor: alpha(theme.palette.success.main, 0.12),
                  color: theme.palette.success.dark,
                  border: `1px solid ${alpha(theme.palette.success.main, 0.28)}`,
                }}
              />
            )}
            {hasYoungChild && (
              <Chip
                icon={<ChildCareIcon sx={{ fontSize: "18px !important" }} />}
                label="Nuôi con nhỏ (−1h)"
                size="small"
                sx={{
                  fontWeight: 700,
                  bgcolor: alpha(theme.palette.secondary.main, 0.12),
                  color: theme.palette.secondary.dark,
                  border: `1px solid ${alpha(theme.palette.secondary.main, 0.28)}`,
                }}
              />
            )}
            <Chip
              icon={<SeasonIcon sx={{ fontSize: "18px !important" }} />}
              label={schedule.summer ? "Ca hè" : "Ca đông"}
              size="small"
              sx={{
                fontWeight: 700,
                bgcolor: alpha(seasonColor, 0.12),
                color: seasonColor,
                border: `1px solid ${alpha(seasonColor, 0.28)}`,
              }}
            />
            {canEdit && onEdit && (
              <Button
                size="small"
                variant="outlined"
                startIcon={<EditIcon />}
                onClick={onEdit}
                sx={{
                  fontWeight: 700,
                  borderRadius: 2,
                  bgcolor: alpha("#fff", 0.7),
                  borderColor: alpha(theme.palette.primary.main, 0.25),
                }}
              >
                Chỉnh sửa lịch
              </Button>
            )}
          </Stack>
        </Stack>

        <Stack direction={{ xs: "column", md: "row" }} spacing={2}>
          {continuous ? (
            <ContinuousShiftBlock schedule={schedule} />
          ) : (
            <>
              <ShiftBlock
                icon={<WbTwilightIcon />}
                title="Ca sáng"
                hours={schedule.morningHours}
                units={schedule.morningUnitsLabel ?? "0,67 công"}
                start={schedule.morningStart}
                end={schedule.morningEnd}
                accent={theme.palette.primary.main}
              />
              <ShiftBlock
                icon={<NightsStayIcon />}
                title="Ca chiều"
                hours={schedule.afternoonHours}
                units={schedule.afternoonUnitsLabel ?? "0,33 công"}
                start={schedule.afternoonStart}
                end={schedule.afternoonEnd}
                accent={theme.palette.secondary.main}
              />
            </>
          )}
        </Stack>
      </Box>

      {canManageContinuous && employeeName && (onContinuousShiftChange || onYoungChildChange) && (
        <Box
          sx={{
            px: { xs: 2, sm: 2.5 },
            py: 1.75,
            borderTop: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
            bgcolor: alpha(theme.palette.primary.main, 0.03),
          }}
        >
          <Stack spacing={1.75}>
            {onContinuousShiftChange && (
              <Stack
                direction={{ xs: "column", sm: "row" }}
                alignItems={{ xs: "flex-start", sm: "center" }}
                justifyContent="space-between"
                spacing={1.5}
              >
                <Box sx={{ flex: 1, minWidth: 0 }}>
                  <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 0.35 }}>
                    <TimelineIcon sx={{ fontSize: 18, color: theme.palette.success.main }} />
                    <Typography variant="body2" fontWeight={700}>
                      Ca thông tầm · {employeeName}
                      {periodLabel ? ` · ${periodLabel}` : ""}
                    </Typography>
                  </Stack>
                  <Typography variant="caption" color="text.secondary" sx={{ display: "block", pl: 3.5 }}>
                    Bật/tắt theo từng tháng — khi bật chỉ cần giờ vào đầu ngày và giờ ra cuối ngày, không nghỉ trưa.
                  </Typography>
                </Box>
                <Stack direction="row" spacing={1} alignItems="center">
                  <Typography variant="caption" color="text.secondary" fontWeight={600}>
                    {continuousShift ? "Đang bật" : "Tắt"}
                  </Typography>
                  <Switch
                    checked={Boolean(continuousShift)}
                    disabled={continuousSaving}
                    onChange={(_, checked) => onContinuousShiftChange(checked)}
                    color="success"
                  />
                </Stack>
              </Stack>
            )}

            {onYoungChildChange && (
              <Stack
                direction={{ xs: "column", sm: "row" }}
                alignItems={{ xs: "flex-start", sm: "center" }}
                justifyContent="space-between"
                spacing={1.5}
              >
                <Box sx={{ flex: 1, minWidth: 0 }}>
                  <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 0.35 }}>
                    <ChildCareIcon sx={{ fontSize: 18, color: theme.palette.secondary.main }} />
                    <Typography variant="body2" fontWeight={700}>
                      Nuôi con nhỏ · {employeeName}
                      {periodLabel ? ` · ${periodLabel}` : ""}
                    </Typography>
                  </Stack>
                  <Typography variant="caption" color="text.secondary" sx={{ display: "block", pl: 3.5 }}>
                    Giảm 1 giờ/ngày (về sớm 1 giờ không bị trừ) — tối thiểu <strong>7 giờ = 1 công</strong>.
                  </Typography>
                </Box>
                <Stack direction="row" spacing={1} alignItems="center">
                  <Typography variant="caption" color="text.secondary" fontWeight={600}>
                    {youngChild ? "Đang bật" : "Tắt"}
                  </Typography>
                  <Switch
                    checked={Boolean(youngChild)}
                    disabled={youngChildSaving}
                    onChange={(_, checked) => onYoungChildChange(checked)}
                    color="secondary"
                  />
                </Stack>
              </Stack>
            )}
          </Stack>
        </Box>
      )}
    </Paper>
  );
}
