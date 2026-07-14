import CalendarMonthOutlinedIcon from "@mui/icons-material/CalendarMonthOutlined";
import CloseIcon from "@mui/icons-material/Close";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutline";
import EventAvailableOutlinedIcon from "@mui/icons-material/EventAvailableOutlined";
import LocalHospitalOutlinedIcon from "@mui/icons-material/LocalHospitalOutlined";
import NightsStayIcon from "@mui/icons-material/NightsStay";
import PersonOutlineIcon from "@mui/icons-material/PersonOutline";
import SaveOutlinedIcon from "@mui/icons-material/SaveOutlined";
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogContent,
  Grid,
  IconButton,
  Skeleton,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import { alpha, useTheme } from "@mui/material/styles";
import { useEffect, useMemo, useState } from "react";
import { dateTimeFieldSx } from "../ui/DateTimeFields";
import { FormSection, InfoBanner } from "./WorkRequestFormUi";
import * as attSvc from "../../services/attendanceService";
import { formatWorkUnits } from "../../utils/shiftSchedule";

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved?: () => void;
  employeeId: number;
  employeeName: string;
  workDate: string;
  existing?: attSvc.DutyShiftEntry | null;
  /** Nhúng trong dialog tab — ẩn header/dialog shell */
  embedded?: boolean;
};

const ACCENT = "#5b4bb4";

function shiftTypeBadge(type: attSvc.DutyShiftTypeOption) {
  return type.grantsWorkUnits ? "+0,33 công" : "50% · không công";
}

function shiftTypeBadgeColor(
  type: attSvc.DutyShiftTypeOption,
): "primary" | "secondary" {
  return type.grantsWorkUnits ? "primary" : "secondary";
}

export function DutyShiftDialog({
  open,
  onClose,
  onSaved,
  employeeId,
  employeeName,
  workDate,
  existing,
  embedded = false,
}: Props) {
  const theme = useTheme();
  const [types, setTypes] = useState<attSvc.DutyShiftTypeOption[]>([]);
  const [typesLoading, setTypesLoading] = useState(false);
  const [shiftTypeCode, setShiftTypeCode] = useState("");
  const [roleTierCode, setRoleTierCode] = useState("");
  const [note, setNote] = useState("");
  const [preview, setPreview] = useState<attSvc.DutyShiftPreview | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const selectedType = useMemo(
    () => types.find((t) => t.code === shiftTypeCode) ?? null,
    [types, shiftTypeCode],
  );

  const roleTiers = selectedType?.roleTiers ?? [];

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setTypesLoading(true);
    attSvc
      .fetchDutyShiftTypes()
      .then(setTypes)
      .catch(() => setTypes([]))
      .finally(() => setTypesLoading(false));
  }, [open]);

  useEffect(() => {
    if (!open) return;
    if (existing) {
      setShiftTypeCode(existing.shiftTypeCode);
      setRoleTierCode(existing.roleTier);
      setNote(existing.note ?? "");
      return;
    }
    setShiftTypeCode("");
    setRoleTierCode("");
    setNote("");
    setPreview(null);
  }, [open, existing]);

  useEffect(() => {
    if (!open || !shiftTypeCode) {
      setPreview(null);
      setPreviewLoading(false);
      return;
    }
    let cancelled = false;
    setPreviewLoading(true);
    attSvc
      .previewDutyShift(
        employeeId,
        workDate,
        shiftTypeCode,
        roleTierCode || undefined,
      )
      .then((p) => {
        if (cancelled) return;
        setPreview(p);
        if (!roleTierCode && p.suggestedRoleTier) {
          setRoleTierCode(p.suggestedRoleTier);
        }
      })
      .catch(() => {
        if (!cancelled) setPreview(null);
      })
      .finally(() => {
        if (!cancelled) setPreviewLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, employeeId, workDate, shiftTypeCode, roleTierCode]);

  async function handleSave() {
    if (!shiftTypeCode) {
      setErr("Chọn loại ca trực.");
      return;
    }
    setLoading(true);
    setErr(null);
    try {
      await attSvc.upsertDutyShift(employeeId, {
        workDate,
        shiftTypeCode,
        roleTierCode: roleTierCode || undefined,
        note: note.trim() || undefined,
      });
      onSaved?.();
      onClose();
    } catch {
      setErr(
        "Không lưu được ca trực. Kiểm tra quyền trưởng phòng và dữ liệu nhân viên.",
      );
    } finally {
      setLoading(false);
    }
  }

  async function handleDelete() {
    if (!existing) return;
    setLoading(true);
    setErr(null);
    try {
      await attSvc.deleteDutyShift(employeeId, workDate);
      onSaved?.();
      onClose();
    } catch {
      setErr("Không xóa được ca trực.");
    } finally {
      setLoading(false);
    }
  }

  const dateLabel = (() => {
    const d = new Date(`${workDate}T12:00:00`);
    return Number.isNaN(d.getTime())
      ? workDate
      : d.toLocaleDateString("vi-VN", {
          weekday: "long",
          day: "numeric",
          month: "long",
          year: "numeric",
        });
  })();

  const shortDate = (() => {
    const d = new Date(`${workDate}T12:00:00`);
    return Number.isNaN(d.getTime())
      ? workDate
      : d.toLocaleDateString("vi-VN", {
          day: "2-digit",
          month: "2-digit",
          year: "numeric",
        });
  })();

  const formBody = (
    <Stack spacing={2.5}>
      <InfoBanner>
        Ca trực mục <strong>1, 3, 5</strong>: thưởng theo vị trí +{" "}
        <strong>0,33 công</strong>. Ca <strong>Trực kèm (TK)</strong>:{" "}
        <strong>50%</strong> mức trực chính, không cộng 0,33 công.
      </InfoBanner>

      <FormSection
        title="Loại ca trực"
        subtitle="Chọn một loại ca theo biểu mẫu quy định"
      >
        {typesLoading ? (
          <Stack spacing={1.25}>
            {[1, 2, 3].map((i) => (
              <Skeleton
                key={i}
                variant="rounded"
                height={56}
                sx={{ borderRadius: 2 }}
              />
            ))}
          </Stack>
        ) : types.length === 0 ? (
          <Alert severity="warning" variant="outlined" sx={{ borderRadius: 2 }}>
            Không tải được danh mục ca trực. Kiểm tra kết nối backend.
          </Alert>
        ) : (
          <Grid container spacing={1.25}>
            {types.map((t) => {
              const selected = shiftTypeCode === t.code;
              return (
                <Grid item xs={12} sm={6} key={t.code}>
                  <Box
                    component="button"
                    type="button"
                    onClick={() => {
                      setShiftTypeCode(t.code);
                      setRoleTierCode("");
                    }}
                    sx={{
                      border: "none",
                      cursor: "pointer",
                      font: "inherit",
                      textAlign: "left",
                      width: "100%",
                      p: 1.75,
                      borderRadius: 2.5,
                      transition: "all 0.18s ease",
                      bgcolor: selected
                        ? alpha(ACCENT, 0.1)
                        : alpha(theme.palette.grey[500], 0.04),
                      outline: selected
                        ? `2px solid ${ACCENT}`
                        : `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                      "&:hover": {
                        bgcolor: selected
                          ? alpha(ACCENT, 0.14)
                          : alpha(theme.palette.grey[500], 0.08),
                      },
                    }}
                  >
                    <Stack spacing={0.75}>
                      <Typography
                        variant="body2"
                        fontWeight={selected ? 700 : 600}
                        lineHeight={1.35}
                      >
                        {t.label}
                      </Typography>
                      <Chip
                        size="small"
                        label={shiftTypeBadge(t)}
                        color={shiftTypeBadgeColor(t)}
                        variant={selected ? "filled" : "outlined"}
                        sx={{
                          width: "fit-content",
                          height: 22,
                          fontSize: "0.7rem",
                        }}
                      />
                    </Stack>
                  </Box>
                </Grid>
              );
            })}
          </Grid>
        )}
      </FormSection>

      {shiftTypeCode && roleTiers.length > 0 && (
        <FormSection
          title="Vị trí / mức thưởng"
          subtitle="Hệ thống gợi ý theo chức danh — có thể đổi nếu cần"
        >
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            {roleTiers.map((r) => {
              const selected = roleTierCode === r.code;
              return (
                <Chip
                  key={r.code}
                  label={r.label}
                  clickable
                  onClick={() => setRoleTierCode(r.code)}
                  color={selected ? "primary" : "default"}
                  variant={selected ? "filled" : "outlined"}
                  sx={{
                    fontWeight: selected ? 700 : 500,
                    borderRadius: 2,
                    px: 0.5,
                    height: 34,
                  }}
                />
              );
            })}
          </Stack>
        </FormSection>
      )}

      {(previewLoading || preview) && (
        <FormSection title="Dự kiến chi trả" subtitle={`Ngày ${shortDate}`}>
          {previewLoading ? (
            <Grid container spacing={1.5}>
              {[1, 2].map((i) => (
                <Grid item xs={12} sm={4} key={i}>
                  <Skeleton
                    variant="rounded"
                    height={88}
                    sx={{ borderRadius: 2.5 }}
                  />
                </Grid>
              ))}
            </Grid>
          ) : preview ? (
            <Grid container spacing={1.5}>
              <Grid
                item
                xs={12}
                sm={preview && Number(preview.workUnits) > 0 ? 6 : 12}
              >
                <PreviewMetricCard
                  icon={<LocalHospitalOutlinedIcon fontSize="small" />}
                  label="Tiền thưởng trực"
                  value={attSvc.formatMoney(preview.bonusAmount)}
                  accent={theme.palette.info.main}
                />
              </Grid>
              {Number(preview.workUnits) > 0 ? (
                <Grid item xs={12} sm={6}>
                  <PreviewMetricCard
                    icon={<EventAvailableOutlinedIcon fontSize="small" />}
                    label="Công sau trực"
                    value={`+${formatWorkUnits(preview.workUnits)}`}
                    accent={theme.palette.success.main}
                  />
                </Grid>
              ) : (
                <Grid item xs={12} sm={8}>
                  <Box
                    sx={{
                      p: 1.75,
                      borderRadius: 2.5,
                      height: "100%",
                      display: "flex",
                      alignItems: "center",
                      bgcolor: alpha(theme.palette.warning.main, 0.06),
                      border: `1px dashed ${alpha(theme.palette.warning.main, 0.35)}`,
                    }}
                  >
                    <Typography variant="body2" color="text.secondary">
                      Trực kèm (TK): chỉ nhận 50% tiền thưởng,{" "}
                      <strong>không</strong> cộng 0,33 công.
                    </Typography>
                  </Box>
                </Grid>
              )}
            </Grid>
          ) : null}
        </FormSection>
      )}

      <FormSection
        title="Ghi chú"
        subtitle="Tuỳ chọn — lý do hoặc chi tiết bổ sung"
      >
        <TextField
          placeholder="Ví dụ: Trực cấp cứu đêm, thay ca đồng nghiệp nghỉ…"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          multiline
          minRows={3}
          fullWidth
          sx={dateTimeFieldSx}
        />
      </FormSection>

      {err && (
        <Alert
          severity="error"
          variant="outlined"
          onClose={() => setErr(null)}
          sx={{ borderRadius: 2 }}
        >
          {err}
        </Alert>
      )}
    </Stack>
  );

  const formFooter = (
    <Stack direction="row" spacing={1.5} alignItems="center">
      {existing ? (
        <Button
          color="error"
          variant="outlined"
          onClick={handleDelete}
          disabled={loading}
          startIcon={<DeleteOutlineIcon />}
          sx={{ borderRadius: 2, mr: "auto" }}
        >
          Xóa ca trực
        </Button>
      ) : (
        <Box sx={{ mr: "auto" }} />
      )}
      {!embedded && (
        <Button
          onClick={onClose}
          disabled={loading}
          variant="outlined"
          color="inherit"
          sx={{ borderRadius: 2 }}
        >
          Hủy
        </Button>
      )}
      <Button
        variant="contained"
        onClick={handleSave}
        disabled={loading || !shiftTypeCode}
        startIcon={
          loading ? (
            <CircularProgress size={18} color="inherit" />
          ) : (
            <SaveOutlinedIcon />
          )
        }
        sx={{
          borderRadius: 2,
          px: 2.5,
          bgcolor: ACCENT,
          "&:hover": { bgcolor: ACCENT, filter: "brightness(0.92)" },
        }}
      >
        {loading ? "Đang lưu…" : "Lưu ca trực"}
      </Button>
    </Stack>
  );

  if (embedded) {
    if (!open) return null;
    return (
      <Box>
        {formBody}
        <Box sx={{ pt: 2 }}>{formFooter}</Box>
      </Box>
    );
  }

  return (
    <Dialog
      open={open}
      onClose={loading ? undefined : onClose}
      maxWidth="md"
      fullWidth
      PaperProps={{
        sx: {
          borderRadius: 3,
          overflow: "hidden",
          boxShadow: `0 24px 48px ${alpha("#0f172a", 0.14)}`,
        },
      }}
    >
      <Box
        sx={{
          px: 2.5,
          pt: 2.5,
          pb: 2,
          background: `linear-gradient(135deg, ${alpha(ACCENT, 0.16)} 0%, ${alpha(ACCENT, 0.04)} 100%)`,
          borderBottom: `1px solid ${alpha(ACCENT, 0.12)}`,
        }}
      >
        <Stack direction="row" spacing={2} alignItems="flex-start">
          <Box
            sx={{
              width: 48,
              height: 48,
              borderRadius: 2.5,
              display: "grid",
              placeItems: "center",
              bgcolor: alpha(ACCENT, 0.14),
              color: ACCENT,
              flexShrink: 0,
            }}
          >
            <NightsStayIcon />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0, pt: 0.25 }}>
            <Typography
              variant="overline"
              sx={{ color: ACCENT, fontWeight: 700, letterSpacing: "0.08em" }}
            >
              Ca trực
            </Typography>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25}>
              Bổ sung ca trực
            </Typography>
            <Stack
              direction="row"
              spacing={1}
              flexWrap="wrap"
              useFlexGap
              sx={{ mt: 1.25 }}
            >
              <Chip
                size="small"
                icon={
                  <PersonOutlineIcon sx={{ fontSize: "16px !important" }} />
                }
                label={employeeName}
                sx={{ bgcolor: alpha("#fff", 0.72), fontWeight: 600 }}
              />
              <Chip
                size="small"
                icon={
                  <CalendarMonthOutlinedIcon
                    sx={{ fontSize: "16px !important" }}
                  />
                }
                label={dateLabel}
                sx={{ bgcolor: alpha("#fff", 0.72), fontWeight: 500 }}
              />
              {existing && (
                <Chip
                  size="small"
                  label="Đang chỉnh sửa"
                  color="warning"
                  variant="outlined"
                />
              )}
            </Stack>
          </Box>
          <IconButton
            size="small"
            onClick={onClose}
            disabled={loading}
            sx={{ mt: -0.5, mr: -0.5, color: "text.secondary" }}
            aria-label="Đóng"
          >
            <CloseIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Box>

      <DialogContent sx={{ px: 2.5, py: 2.5 }}>{formBody}</DialogContent>

      <Box
        sx={{
          px: 2.5,
          py: 2,
          borderTop: `1px solid ${theme.palette.divider}`,
          bgcolor: alpha(theme.palette.background.default, 0.5),
        }}
      >
        {formFooter}
      </Box>
    </Dialog>
  );
}

function PreviewMetricCard({
  icon,
  label,
  value,
  accent,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  accent: string;
}) {
  return (
    <Box
      sx={{
        p: 1.75,
        borderRadius: 2.5,
        height: "100%",
        bgcolor: alpha(accent, 0.06),
        border: `1px solid ${alpha(accent, 0.16)}`,
      }}
    >
      <Stack
        direction="row"
        spacing={0.75}
        alignItems="center"
        sx={{ mb: 0.75, color: accent }}
      >
        {icon}
        <Typography variant="caption" fontWeight={600} color="text.secondary">
          {label}
        </Typography>
      </Stack>
      <Typography
        variant="h6"
        fontWeight={800}
        sx={{ color: accent, lineHeight: 1.2 }}
      >
        {value}
      </Typography>
    </Box>
  );
}
