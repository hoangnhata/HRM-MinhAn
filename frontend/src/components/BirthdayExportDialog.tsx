import CakeOutlinedIcon from '@mui/icons-material/CakeOutlined';
import CheckCircleRoundedIcon from '@mui/icons-material/CheckCircleRounded';
import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import * as importService from '../services/importService';

type Props = {
  open: boolean;
  onClose: () => void;
  onDone?: (message: string) => void;
};

const MONTHS = Array.from({ length: 12 }, (_, i) => i + 1);

/** Chọn một hoặc nhiều tháng rồi xuất Excel danh sách sinh nhật toàn viện. */
export function BirthdayExportDialog({ open, onClose, onDone }: Props) {
  const theme = useTheme();
  const accent = theme.palette.primary.main;
  const now = new Date();
  const currentMonth = now.getMonth() + 1;
  const year = now.getFullYear();
  const [selected, setSelected] = useState<Set<number>>(new Set([currentMonth]));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setSelected(new Set([currentMonth]));
      setError(null);
    }
  }, [open, currentMonth]);

  const toggle = (m: number) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(m)) next.delete(m);
      else next.add(m);
      return next;
    });

  const quarterStart = Math.floor((currentMonth - 1) / 3) * 3 + 1;
  const presets: Array<{ label: string; months: number[] }> = [
    { label: 'Tháng này', months: [currentMonth] },
    { label: 'Tháng sau', months: [(currentMonth % 12) + 1] },
    { label: 'Quý này', months: [quarterStart, quarterStart + 1, quarterStart + 2] },
    { label: 'Cả năm', months: MONTHS },
  ];
  const sorted = [...selected].sort((a, b) => a - b);
  const samePreset = (months: number[]) =>
    months.length === sorted.length && months.every((m) => selected.has(m));

  async function submit() {
    if (sorted.length === 0) return;
    setBusy(true);
    setError(null);
    try {
      await importService.downloadBirthdayExcel(sorted);
      onDone?.(`Đã xuất danh sách sinh nhật tháng ${sorted.join(', ')}/${year}.`);
      onClose();
    } catch {
      setError('Xuất Excel thất bại. Kiểm tra quyền hoặc thử lại sau.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open={open} onClose={() => !busy && onClose()} maxWidth="sm" fullWidth>
      <DialogTitle sx={{ pb: 1 }}>
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Box
            sx={{
              width: 42,
              height: 42,
              borderRadius: '12px',
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(accent, 0.12),
              color: accent,
              flexShrink: 0,
            }}
          >
            <CakeOutlinedIcon />
          </Box>
          <Box>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25}>
              Xuất danh sách sinh nhật
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Toàn viện · nhân viên chính thức, thử việc, thực tập · năm {year}
            </Typography>
          </Box>
        </Stack>
      </DialogTitle>
      <DialogContent>
        <Typography variant="body2" fontWeight={700} sx={{ mb: 1 }}>
          Chọn tháng sinh (có thể chọn nhiều tháng)
        </Typography>
        <Stack direction="row" spacing={0.75} flexWrap="wrap" useFlexGap sx={{ mb: 1.75 }}>
          {presets.map((p) => {
            const active = samePreset(p.months);
            return (
              <Chip
                key={p.label}
                label={p.label}
                size="small"
                clickable
                color={active ? 'primary' : 'default'}
                variant={active ? 'filled' : 'outlined'}
                onClick={() => setSelected(new Set(p.months))}
                sx={{ fontWeight: 700 }}
              />
            );
          })}
          <Chip
            label="Bỏ chọn"
            size="small"
            variant="outlined"
            onClick={() => setSelected(new Set())}
            disabled={selected.size === 0}
            sx={{ fontWeight: 600 }}
          />
        </Stack>

        <Box
          role="group"
          aria-label="Tháng sinh"
          sx={{ display: 'grid', gap: 1, gridTemplateColumns: { xs: 'repeat(3, 1fr)', sm: 'repeat(4, 1fr)' } }}
        >
          {MONTHS.map((m) => {
            const active = selected.has(m);
            const current = m === currentMonth;
            return (
              <Box
                key={m}
                component="button"
                type="button"
                aria-pressed={active}
                onClick={() => toggle(m)}
                sx={{
                  position: 'relative',
                  font: 'inherit',
                  cursor: 'pointer',
                  py: 1.4,
                  borderRadius: '10px',
                  border: `1.5px solid ${active ? accent : theme.palette.divider}`,
                  bgcolor: active ? alpha(accent, 0.09) : 'background.paper',
                  color: active ? accent : 'text.primary',
                  fontWeight: active ? 800 : 600,
                  fontSize: 14,
                  transition: 'all .15s',
                  '&:hover': { borderColor: accent, bgcolor: alpha(accent, active ? 0.12 : 0.04) },
                  '&:focus-visible': { outline: `3px solid ${alpha(accent, 0.3)}`, outlineOffset: 1 },
                }}
              >
                Tháng {m}
                {active && (
                  <CheckCircleRoundedIcon
                    sx={{ position: 'absolute', top: 5, right: 5, fontSize: 15, color: accent }}
                  />
                )}
                {current && (
                  <Typography
                    component="span"
                    sx={{ display: 'block', fontSize: 10.5, fontWeight: 700, color: 'text.secondary', mt: 0.25 }}
                  >
                    Tháng hiện tại
                  </Typography>
                )}
              </Box>
            );
          })}
        </Box>

        <Typography variant="body2" color="text.secondary" sx={{ mt: 1.75 }}>
          {sorted.length === 0
            ? 'Chưa chọn tháng nào.'
            : `Đã chọn: ${sorted.map((m) => `Tháng ${m}`).join(', ')} — mỗi tháng là một nhóm trong file, sắp xếp theo ngày sinh nhật.`}
        </Typography>

        {error && (
          <Alert severity="error" sx={{ mt: 1.5, borderRadius: '10px' }}>
            {error}
          </Alert>
        )}
      </DialogContent>
      <DialogActions sx={{ px: 3, pb: 2.5 }}>
        <Button onClick={onClose} disabled={busy}>
          Hủy
        </Button>
        <Button
          variant="contained"
          onClick={() => void submit()}
          disabled={busy || sorted.length === 0}
          startIcon={busy ? <CircularProgress size={16} color="inherit" /> : <FileDownloadOutlinedIcon />}
          sx={{ fontWeight: 800 }}
        >
          {busy ? 'Đang xuất…' : `Xuất Excel${sorted.length ? ` (${sorted.length} tháng)` : ''}`}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
