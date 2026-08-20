import CloseIcon from '@mui/icons-material/Close';
import SaveOutlinedIcon from '@mui/icons-material/SaveOutlined';
import TimelineIcon from '@mui/icons-material/Timeline';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogContent,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import * as att from '../../services/attendanceService';
import type { ContinuousShiftDayInfo, ContinuousShiftKind, ContinuousShiftType } from '../../services/attendanceService';

type DayAssignment = {
  shiftTypeId: number;
  shiftTypeName: string;
  kind?: ContinuousShiftKind;
  continuousStart: string;
  continuousEnd: string;
};

type Props = {
  open: boolean;
  onClose: () => void;
  employeeId: number;
  employeeName: string;
  year: number;
  month: number;
  onSaved?: (dates: string[], recalculated: number, warning?: string) => void;
};

const WEEKDAYS = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

function toIso(year: number, month: number, day: number) {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function buildMonthCells(year: number, month: number) {
  const first = new Date(year, month - 1, 1);
  const daysInMonth = new Date(year, month, 0).getDate();
  const startPad = (first.getDay() + 6) % 7;
  const cells: Array<{ day: number | null; iso: string | null }> = [];
  for (let i = 0; i < startPad; i++) cells.push({ day: null, iso: null });
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push({ day: d, iso: toIso(year, month, d) });
  }
  while (cells.length % 7 !== 0) cells.push({ day: null, iso: null });
  return cells;
}

function shortTime(t?: string | null) {
  if (!t) return '';
  return t.slice(0, 5);
}

function assignmentFromType(type: ContinuousShiftType): DayAssignment {
  const split = type.kind === 'SPLIT';
  return {
    shiftTypeId: type.id,
    shiftTypeName: type.name,
    kind: type.kind === 'SPLIT' ? 'SPLIT' : 'CONTINUOUS',
    continuousStart: split ? (type.morningStart || type.startTime) : type.startTime,
    continuousEnd: split ? (type.afternoonEnd || type.endTime) : type.endTime,
  };
}

function assignmentFromDay(day: ContinuousShiftDayInfo, types: ContinuousShiftType[]): DayAssignment | null {
  if (day.shiftTypeId != null) {
    const type = types.find((t) => t.id === day.shiftTypeId);
    if (type) return assignmentFromType(type);
  }
  if (day.continuousStart && day.continuousEnd) {
    return {
      shiftTypeId: day.shiftTypeId ?? 0,
      shiftTypeName: day.shiftTypeName || 'Ca tùy chỉnh',
      kind: day.kind === 'SPLIT' ? 'SPLIT' : 'CONTINUOUS',
      continuousStart: day.continuousStart,
      continuousEnd: day.continuousEnd,
    };
  }
  return null;
}

export function ContinuousShiftConfigDialog({
  open,
  onClose,
  employeeId,
  employeeName,
  year,
  month,
  onSaved,
}: Props) {
  const theme = useTheme();
  const accent = theme.palette.success.main;
  const [selected, setSelected] = useState<Map<string, DayAssignment>>(new Map());
  const [types, setTypes] = useState<ContinuousShiftType[]>([]);
  const [brushTypeId, setBrushTypeId] = useState<number | ''>('');
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    setLoading(true);
    setErr(null);
    Promise.all([
      att.fetchContinuousShiftTypes(true),
      att.fetchEmployeeContinuousShiftDays(employeeId, year, month),
    ])
      .then(([typeList, dayRes]) => {
        if (cancelled) return;
        setTypes(typeList);
        const map = new Map<string, DayAssignment>();
        for (const day of dayRes.days ?? []) {
          const a = assignmentFromDay(day, typeList);
          if (a) map.set(day.date, a);
          else if (typeList[0]) map.set(day.date, assignmentFromType(typeList[0]));
          else {
            map.set(day.date, {
              shiftTypeId: 0,
              shiftTypeName: 'Theo cấu hình mùa',
              continuousStart: '',
              continuousEnd: '',
            });
          }
        }
        // ngày cũ không có giờ: gán ca brush mặc định khi lưu nếu user không đổi
        setSelected(map);
        setBrushTypeId(typeList[0]?.id ?? '');
      })
      .catch(() => {
        if (!cancelled) setErr('Không tải được danh sách ngày / khung ca.');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, employeeId, year, month]);

  const cells = useMemo(() => buildMonthCells(year, month), [year, month]);
  const periodLabel = `tháng ${month}/${year}`;
  const brushType = types.find((t) => t.id === brushTypeId) ?? null;

  function requireBrush(): ContinuousShiftType | null {
    if (!brushType) {
      setErr('Hãy tạo hoặc chọn một khung ca trước khi chọn ngày.');
      return null;
    }
    return brushType;
  }

  function toggleDay(iso: string) {
    setSelected((prev) => {
      const next = new Map(prev);
      if (next.has(iso)) {
        next.delete(iso);
        return next;
      }
      const type = brushType ?? types[0];
      if (!type) {
        setErr('Hãy tạo khung ca trước khi chọn ngày.');
        return prev;
      }
      next.set(iso, assignmentFromType(type));
      return next;
    });
  }

  function selectAll() {
    const type = requireBrush();
    if (!type) return;
    const a = assignmentFromType(type);
    setSelected(new Map(cells.filter((c) => c.iso).map((c) => [c.iso!, a])));
  }

  function clearAll() {
    setSelected(new Map());
  }

  async function save() {
    if (selected.size > 0 && [...selected.values()].some((a) => !a.shiftTypeId && !a.continuousStart)) {
      setErr('Mỗi ngày cần gắn một khung ca (thông tầm hoặc sáng–chiều).');
      return;
    }
    setSaving(true);
    setErr(null);
    try {
      const days = [...selected.entries()]
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([date, a]) => ({
          date,
          shiftTypeId: a.shiftTypeId || null,
          continuousStart: a.continuousStart || null,
          continuousEnd: a.continuousEnd || null,
        }));
      const result = await att.setEmployeeContinuousShiftDays(employeeId, year, month, days);
      onSaved?.(result.dates ?? days.map((d) => d.date), result.recalculated ?? 0, result.recalculateWarning);
      onClose();
    } catch (e: unknown) {
      const msg =
        (e as { response?: { data?: { message?: string } } })?.response?.data?.message ||
        'Không lưu được. Thử lại.';
      setErr(msg);
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth scroll="paper">
        <Box
          sx={{
            px: 3,
            pt: 2.5,
            pb: 1.5,
            display: 'flex',
            alignItems: 'flex-start',
            gap: 1.5,
            borderBottom: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
          }}
        >
          <Box
            sx={{
              width: 44,
              height: 44,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(accent, 0.12),
              color: accent,
              flexShrink: 0,
            }}
          >
            <TimelineIcon />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography variant="overline" sx={{ color: accent, fontWeight: 700, letterSpacing: '0.08em' }}>
              Ca làm việc
            </Typography>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25}>
              Xếp ca theo ngày
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
              {employeeName} · {periodLabel} — chọn khung ca (thông tầm hoặc sáng–chiều) rồi gắn từng ngày.
            </Typography>
          </Box>
          <IconButton onClick={onClose} size="small" aria-label="Đóng">
            <CloseIcon />
          </IconButton>
        </Box>

        <DialogContent sx={{ px: 3, py: 2.5 }}>
          {err && (
            <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }} onClose={() => setErr(null)}>
              {err}
            </Alert>
          )}

          <Stack spacing={1.25} sx={{ mb: 2 }}>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
              <FormControl size="small" sx={{ minWidth: 220, flex: 1 }} disabled={loading || saving || types.length === 0}>
                <InputLabel id="brush-type-label">Ca đang chọn</InputLabel>
                <Select
                  labelId="brush-type-label"
                  label="Ca đang chọn"
                  value={brushTypeId}
                  onChange={(e) => setBrushTypeId(e.target.value as number)}
                >
                  {types.map((t) => (
                    <MenuItem key={t.id} value={t.id}>
                      {t.kind === 'SPLIT'
                        ? `${t.name} · sáng–chiều (${shortTime(t.morningStart || t.startTime)}–${shortTime(t.morningEnd)} / ${shortTime(t.afternoonStart)}–${shortTime(t.afternoonEnd || t.endTime)})`
                        : `${t.name} · thông tầm (${shortTime(t.startTime)}–${shortTime(t.endTime)})`}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Stack>
            {brushType && (
              <Typography variant="caption" color="text.secondary">
                Click ngày để gắn/bỏ ca <strong>{brushType.name}</strong>
                {brushType.kind === 'SPLIT'
                  ? ` (sáng–chiều ${shortTime(brushType.morningStart || brushType.startTime)}–${shortTime(brushType.morningEnd)} / ${shortTime(brushType.afternoonStart)}–${shortTime(brushType.afternoonEnd || brushType.endTime)})`
                  : ` (thông tầm ${shortTime(brushType.startTime)}–${shortTime(brushType.endTime)})`}
                . Đổi ca ở trên rồi click lại ngày đã chọn để đổi khung giờ.
              </Typography>
            )}
            {types.length === 0 && !loading && (
              <Alert severity="info" sx={{ borderRadius: 2 }}>
                Chưa có khung ca. Vui lòng liên hệ ADMIN/HCNS để cấu hình danh mục ca (thông tầm hoặc sáng–chiều) trước khi xếp.
              </Alert>
            )}
          </Stack>

          <Stack direction="row" spacing={1} sx={{ mb: 1.5 }}>
            <Button size="small" onClick={selectAll} disabled={loading || saving || !brushType} sx={{ borderRadius: 2 }}>
              Gắn cả tháng theo ca đang chọn
            </Button>
            <Button size="small" onClick={clearAll} disabled={loading || saving} sx={{ borderRadius: 2 }}>
              Bỏ chọn
            </Button>
          </Stack>

          {loading ? (
            <Box sx={{ py: 6, display: 'grid', placeItems: 'center' }}>
              <CircularProgress size={28} />
            </Box>
          ) : (
            <Box
              sx={{
                borderRadius: 2.5,
                border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                overflow: 'hidden',
                bgcolor: 'background.paper',
              }}
            >
              <Box
                sx={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(7, 1fr)',
                  bgcolor: alpha(accent, 0.06),
                  borderBottom: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
                }}
              >
                {WEEKDAYS.map((w) => (
                  <Typography
                    key={w}
                    variant="caption"
                    align="center"
                    sx={{ py: 1, fontWeight: 700, color: 'text.secondary' }}
                  >
                    {w}
                  </Typography>
                ))}
              </Box>
              <Box
                sx={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(7, 1fr)',
                  gap: '1px',
                  bgcolor: alpha(theme.palette.divider, 0.85),
                  borderTop: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
                }}
              >
                {cells.map((c, idx) => {
                  if (!c.iso || c.day == null) {
                    return <Box key={`e-${idx}`} sx={{ minHeight: 64, bgcolor: 'background.paper' }} />;
                  }
                  const a = selected.get(c.iso);
                  const active = !!a;
                  return (
                    <Box
                      key={c.iso}
                      component="button"
                      type="button"
                      onClick={() => {
                        if (active && brushType && a.shiftTypeId !== brushType.id) {
                          setSelected((prev) => {
                            const next = new Map(prev);
                            next.set(c.iso!, assignmentFromType(brushType));
                            return next;
                          });
                          return;
                        }
                        toggleDay(c.iso!);
                      }}
                      sx={{
                        minHeight: 64,
                        border: 'none',
                        bgcolor: active ? accent : 'background.paper',
                        color: active ? '#fff' : 'inherit',
                        cursor: 'pointer',
                        fontFamily: 'inherit',
                        px: 0.5,
                        py: 0.75,
                        transition: 'background-color 0.12s, box-shadow 0.12s',
                        boxShadow: active ? `inset 0 0 0 2px ${alpha('#000', 0.12)}` : 'none',
                        '&:hover': {
                          bgcolor: active ? accent : alpha(theme.palette.primary.main, 0.04),
                          filter: active ? 'brightness(0.92)' : 'none',
                        },
                      }}
                    >
                      <Typography
                        variant="body2"
                        sx={{
                          fontWeight: active ? 800 : 500,
                          color: active ? '#fff' : 'text.primary',
                          lineHeight: 1.1,
                        }}
                      >
                        {c.day}
                      </Typography>
                      {active && (
                        <Typography
                          variant="caption"
                          sx={{
                            display: 'block',
                            mt: 0.35,
                            fontSize: '0.58rem',
                            lineHeight: 1.15,
                            color: alpha('#fff', 0.92),
                            fontWeight: 600,
                          }}
                        >
                          {a.kind === 'SPLIT'
                            ? `${shortTime(a.continuousStart)}…${shortTime(a.continuousEnd)} · SC`
                            : `${shortTime(a.continuousStart) || '—'}–${shortTime(a.continuousEnd) || '—'} · TT`}
                        </Typography>
                      )}
                    </Box>
                  );
                })}
              </Box>
            </Box>
          )}

          <Stack direction="row" flexWrap="wrap" gap={0.75} sx={{ mt: 1.5 }}>
            {[...selected.values()]
              .reduce<ContinuousShiftType[]>((acc, a) => {
                if (!a.shiftTypeId || acc.some((t) => t.id === a.shiftTypeId)) return acc;
                const t = types.find((x) => x.id === a.shiftTypeId);
                if (t) acc.push(t);
                return acc;
              }, [])
              .map((t) => (
                <Chip
                  key={t.id}
                  size="small"
                  color={t.kind === 'SPLIT' ? 'primary' : 'success'}
                  variant="outlined"
                  label={
                    t.kind === 'SPLIT'
                      ? `${t.name}: ${shortTime(t.morningStart || t.startTime)}–${shortTime(t.morningEnd)} / ${shortTime(t.afternoonStart)}–${shortTime(t.afternoonEnd || t.endTime)}`
                      : `${t.name}: ${shortTime(t.startTime)}–${shortTime(t.endTime)}`
                  }
                />
              ))}
          </Stack>

          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1.5 }}>
            Đã chọn <strong>{selected.size}</strong> ngày xếp ca (thông tầm hoặc sáng–chiều). Ngày không chọn = ca
            bình thường theo mùa.
          </Typography>
        </DialogContent>

        <Stack
          direction="row"
          spacing={1.25}
          justifyContent="flex-end"
          sx={{
            px: 3,
            py: 2,
            borderTop: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
            bgcolor: alpha(accent, 0.03),
          }}
        >
          <Button onClick={onClose} color="inherit" disabled={saving}>
            Hủy
          </Button>
          <Button
            variant="contained"
            color="success"
            startIcon={saving ? <CircularProgress size={16} color="inherit" /> : <SaveOutlinedIcon />}
            onClick={save}
            disabled={saving || loading}
          >
            Lưu
          </Button>
        </Stack>
      </Dialog>

    </>
  );
}
