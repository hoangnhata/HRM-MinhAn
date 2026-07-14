import CloseIcon from '@mui/icons-material/Close';
import EventAvailableIcon from '@mui/icons-material/EventAvailable';
import SaveOutlinedIcon from '@mui/icons-material/SaveOutlined';
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
import { MonthPickerField } from '../ui/DateTimeFields';

type Props = {
  open: boolean;
  onClose: () => void;
  /** Tháng đang xem trên trang công — mở dialog sẽ load tháng này */
  initialYear: number;
  initialMonth: number;
  onSaved?: (year: number, month: number, dates: string[]) => void;
};

const WEEKDAYS = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

function toIso(year: number, month: number, day: number) {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function buildMonthCells(year: number, month: number) {
  const first = new Date(year, month - 1, 1);
  const daysInMonth = new Date(year, month, 0).getDate();
  // JS: 0=CN … 6=T7 → chuyển sang T2=0 … CN=6
  const startPad = (first.getDay() + 6) % 7;
  const cells: Array<{ day: number | null; iso: string | null }> = [];
  for (let i = 0; i < startPad; i++) cells.push({ day: null, iso: null });
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push({ day: d, iso: toIso(year, month, d) });
  }
  while (cells.length % 7 !== 0) cells.push({ day: null, iso: null });
  return cells;
}

export function HolidayWorkConfigDialog({
  open,
  onClose,
  initialYear,
  initialMonth,
  onSaved,
}: Props) {
  const theme = useTheme();
  const accent = theme.palette.warning.main;
  const [year, setYear] = useState(initialYear);
  const [month, setMonth] = useState(initialMonth);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setYear(initialYear);
    setMonth(initialMonth);
    setErr(null);
  }, [open, initialYear, initialMonth]);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    setLoading(true);
    setErr(null);
    att
      .fetchHolidayWorkDays(year, month)
      .then((r) => {
        if (cancelled) return;
        setSelected(new Set(r.dates));
      })
      .catch(() => {
        if (!cancelled) setErr('Không tải được danh sách ngày lễ.');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, year, month]);

  const cells = useMemo(() => buildMonthCells(year, month), [year, month]);

  function toggleDay(iso: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(iso)) next.delete(iso);
      else next.add(iso);
      return next;
    });
  }

  async function save() {
    setSaving(true);
    setErr(null);
    try {
      const dates = [...selected].sort();
      await att.updateHolidayWorkDays(year, month, dates);
      onSaved?.(year, month, dates);
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
          <EventAvailableIcon />
        </Box>
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <Typography variant="overline" sx={{ color: accent, fontWeight: 700, letterSpacing: '0.08em' }}>
            Vận hành
          </Typography>
          <Typography variant="h6" fontWeight={800} lineHeight={1.25}>
            Cấu hình công lễ
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
            Chọn ngày lễ trong tháng — đi làm được tính <strong>2 công</strong> (thay vì 1).
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

        <MonthPickerField
          label="Tháng cấu hình"
          value={`${year}-${String(month).padStart(2, '0')}`}
          onChange={(v) => {
            if (!v) return;
            const [y, m] = v.split('-').map(Number);
            if (y && m) {
              setYear(y);
              setMonth(m);
            }
          }}
          sx={{ mb: 2, maxWidth: 280 }}
        />

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
            <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}>
              {cells.map((c, idx) => {
                if (!c.iso || c.day == null) {
                  return <Box key={`e-${idx}`} sx={{ minHeight: 48 }} />;
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
                      borderRight: (idx + 1) % 7 === 0 ? 'none' : `1px solid ${alpha(theme.palette.divider, 0.5)}`,
                      borderBottom: `1px solid ${alpha(theme.palette.divider, 0.5)}`,
                      bgcolor: active ? alpha(accent, 0.16) : 'transparent',
                      cursor: 'pointer',
                      fontFamily: 'inherit',
                      transition: 'background-color 0.12s',
                      '&:hover': { bgcolor: active ? alpha(accent, 0.22) : alpha(theme.palette.primary.main, 0.04) },
                    }}
                  >
                    <Typography
                      variant="body2"
                      sx={{
                        fontWeight: active ? 800 : 500,
                        color: active ? theme.palette.warning.dark : 'text.primary',
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
          Đã chọn <strong>{selected.size}</strong> ngày lễ. Nhấn lại ngày để bỏ chọn.
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
          bgcolor: alpha(theme.palette.warning.main, 0.03),
        }}
      >
        <Button onClick={onClose} color="inherit" disabled={saving}>
          Hủy
        </Button>
        <Button
          variant="contained"
          startIcon={saving ? <CircularProgress size={16} color="inherit" /> : <SaveOutlinedIcon />}
          onClick={save}
          disabled={saving || loading}
          color="warning"
        >
          Lưu
        </Button>
      </Stack>
    </Dialog>
  );
}
