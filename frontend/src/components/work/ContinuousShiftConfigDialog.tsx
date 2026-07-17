import CloseIcon from '@mui/icons-material/Close';
import SaveOutlinedIcon from '@mui/icons-material/SaveOutlined';
import TimelineIcon from '@mui/icons-material/Timeline';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogContent,
  IconButton,
  Stack,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import * as att from '../../services/attendanceService';

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
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    setLoading(true);
    setErr(null);
    att
      .fetchEmployeeContinuousShiftDays(employeeId, year, month)
      .then((r) => {
        if (!cancelled) setSelected(new Set(r.dates ?? []));
      })
      .catch(() => {
        if (!cancelled) setErr('Không tải được danh sách ngày ca thông tầm.');
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

  function toggleDay(iso: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(iso)) next.delete(iso);
      else next.add(iso);
      return next;
    });
  }

  function selectAll() {
    setSelected(new Set(cells.filter((c) => c.iso).map((c) => c.iso!)));
  }

  function clearAll() {
    setSelected(new Set());
  }

  async function save() {
    setSaving(true);
    setErr(null);
    try {
      const dates = [...selected].sort();
      const result = await att.setEmployeeContinuousShiftDays(employeeId, year, month, dates);
      onSaved?.(result.dates ?? dates, result.recalculated ?? 0, result.recalculateWarning);
      onClose();
    } catch {
      setErr('Không lưu được. Thử lại.');
    } finally {
      setSaving(false);
    }
  }

  return (
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
            Ca thông tầm theo ngày
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
            {employeeName} · {periodLabel} — chọn ngày thông tầm; ngày còn lại theo ca sáng/chiều thường.
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

        <Stack direction="row" spacing={1} sx={{ mb: 1.5 }}>
          <Button size="small" onClick={selectAll} disabled={loading || saving} sx={{ borderRadius: 2 }}>
            Chọn cả tháng
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
                  return (
                    <Box
                      key={`e-${idx}`}
                      sx={{ minHeight: 48, bgcolor: 'background.paper' }}
                    />
                  );
                }
                const active = selected.has(c.iso);
                return (
                  <Box
                    key={c.iso}
                    component="button"
                    type="button"
                    onClick={() => toggleDay(c.iso!)}
                    sx={{
                      minHeight: 48,
                      border: 'none',
                      bgcolor: active ? accent : 'background.paper',
                      color: active ? '#fff' : 'inherit',
                      cursor: 'pointer',
                      fontFamily: 'inherit',
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
                      }}
                    >
                      {c.day}
                    </Typography>
                  </Box>
                );
              })}
            </Box>
          </Box>
        )}

        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1.5 }}>
          Đã chọn <strong>{selected.size}</strong> ngày thông tầm. Ngày không chọn = ca bình thường.
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
  );
}
