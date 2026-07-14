import AccessTimeIcon from '@mui/icons-material/AccessTime';
import CloseIcon from '@mui/icons-material/Close';
import GavelIcon from '@mui/icons-material/Gavel';
import SaveOutlinedIcon from '@mui/icons-material/SaveOutlined';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogContent,
  Grid,
  IconButton,
  InputAdornment,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import * as att from '../../services/attendanceService';
import type { LatePenaltyTier } from '../../services/attendanceService';
import { dateTimeFieldSx } from '../ui/DateTimeFields';
import { FormSection, InfoBanner } from './WorkRequestFormUi';

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved?: () => void;
};

type TierRow = {
  sortOrder: number;
  minMinutes: number;
  maxMinutes: number | null;
  amount: number;
  requiresDiscipline: boolean;
  note: string;
};

const fieldSx = dateTimeFieldSx;

type TierTone = 'success' | 'warning' | 'error' | 'info';

function normalizeTier(t: LatePenaltyTier): TierRow {
  const max = t.maxMinutes === '' || t.maxMinutes == null ? null : Number(t.maxMinutes);
  return {
    sortOrder: t.sortOrder,
    minMinutes: Number(t.minMinutes),
    maxMinutes: max,
    amount: Number(t.amount),
    requiresDiscipline: Boolean(t.requiresDiscipline),
    note: t.note ?? '',
  };
}

function exemptBelow(tiers: TierRow[]) {
  const monetary = tiers.filter((t) => !t.requiresDiscipline);
  if (monetary.length === 0) return 15;
  return Math.min(...monetary.map((t) => t.minMinutes));
}

function latePenaltyPreview(totalMinutes: number, tiers: TierRow[]) {
  const below = exemptBelow(tiers);
  if (totalMinutes < below) {
    return { amount: 0, label: `Dưới ${below} phút — không phạt`, requiresDiscipline: false };
  }
  const sorted = [...tiers].sort((a, b) => a.sortOrder - b.sortOrder);
  for (const t of sorted) {
    if (totalMinutes < t.minMinutes) continue;
    if (t.maxMinutes != null && totalMinutes > t.maxMinutes) continue;
    if (t.requiresDiscipline) {
      return {
        amount: 0,
        label: t.note || `Trên ${t.minMinutes - 1} phút — kỷ luật`,
        requiresDiscipline: true,
      };
    }
    return {
      amount: t.amount,
      label: `${t.minMinutes}–${t.maxMinutes} phút/tháng`,
      requiresDiscipline: false,
    };
  }
  return { amount: 0, label: '—', requiresDiscipline: false };
}

function MoneyField({
  value,
  onChange,
  label,
  disabled,
}: {
  value: number;
  onChange: (n: number) => void;
  label: string;
  disabled?: boolean;
}) {
  return (
    <TextField
      fullWidth
      size="small"
      type="number"
      label={label}
      value={value}
      disabled={disabled}
      onChange={(e) => onChange(Math.max(0, Number(e.target.value) || 0))}
      inputProps={{ min: 0, step: 1000 }}
      InputProps={{
        endAdornment: (
          <InputAdornment position="end">
            <Typography variant="caption" color="text.secondary" fontWeight={600}>
              đ
            </Typography>
          </InputAdornment>
        ),
      }}
      helperText={att.formatMoney(value)}
      FormHelperTextProps={{ sx: { mx: 0, mt: 0.75, fontWeight: 600, color: 'text.secondary' } }}
      sx={fieldSx}
    />
  );
}

function TierCard({
  level,
  title,
  subtitle,
  tone,
  children,
}: {
  level: number;
  title: string;
  subtitle: string;
  tone: TierTone;
  children: React.ReactNode;
}) {
  const theme = useTheme();
  const palette = theme.palette[tone];

  return (
    <Box
      sx={{
        display: 'flex',
        gap: 2,
        p: 2,
        borderRadius: 2.5,
        border: `1px solid ${alpha(palette.main, 0.22)}`,
        bgcolor: alpha(palette.main, 0.04),
      }}
    >
      <Box
        sx={{
          width: 40,
          height: 40,
          borderRadius: 2,
          flexShrink: 0,
          display: 'grid',
          placeItems: 'center',
          fontWeight: 800,
          fontSize: '1.05rem',
          color: palette.dark,
          bgcolor: alpha(palette.main, 0.16),
        }}
      >
        {level}
      </Box>
      <Box sx={{ flex: 1, minWidth: 0 }}>
        <Typography variant="subtitle2" fontWeight={800} lineHeight={1.3}>
          {title}
        </Typography>
        <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1.5, mt: 0.25 }}>
          {subtitle}
        </Typography>
        {children}
      </Box>
    </Box>
  );
}

const TONE_BY_INDEX: TierTone[] = ['success', 'success', 'warning', 'warning', 'error', 'info'];

export function LatePenaltyConfigDialog({ open, onClose, onSaved }: Props) {
  const theme = useTheme();
  const accent = theme.palette.warning.main;
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [tiers, setTiers] = useState<TierRow[]>([]);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setLoading(true);
    att
      .fetchLatePenaltyConfig()
      .then((cfg) => setTiers(cfg.tiers.map(normalizeTier)))
      .catch(() => setErr('Không tải được cấu hình phạt đi muộn / về sớm.'))
      .finally(() => setLoading(false));
  }, [open]);

  const previewRows = useMemo(() => {
    const below = exemptBelow(tiers);
    const samples = [below - 1, below, 30, 50, 60, 100, 200, 201].filter((m) => m >= 0);
    const unique = [...new Set(samples)].sort((a, b) => a - b);
    return unique.map((minutes) => ({ minutes, ...latePenaltyPreview(minutes, tiers) }));
  }, [tiers]);

  function updateTier(sortOrder: number, patch: Partial<TierRow>) {
    setTiers((prev) => prev.map((t) => (t.sortOrder === sortOrder ? { ...t, ...patch } : t)));
  }

  async function save() {
    const monetary = tiers.filter((t) => !t.requiresDiscipline);
    for (const t of monetary) {
      if (t.maxMinutes == null || t.maxMinutes < t.minMinutes) {
        setErr(`Mức ${t.sortOrder}: phút tối đa phải ≥ phút tối thiểu.`);
        return;
      }
    }
    setSaving(true);
    setErr(null);
    try {
      await att.updateLatePenaltyConfig({
        tiers: tiers.map((t) => ({
          sortOrder: t.sortOrder,
          minMinutes: t.minMinutes,
          maxMinutes: t.requiresDiscipline ? null : t.maxMinutes,
          amount: t.amount,
          requiresDiscipline: t.requiresDiscipline,
          note: t.note || null,
        })),
      });
      onSaved?.();
      onClose();
    } catch {
      setErr('Lưu cấu hình thất bại. Kiểm tra các mức phải liên tiếp.');
    } finally {
      setSaving(false);
    }
  }

  const exemptMin = exemptBelow(tiers);

  return (
    <Dialog
      open={open}
      onClose={saving ? undefined : onClose}
      maxWidth="md"
      fullWidth
      PaperProps={{
        sx: {
          borderRadius: 3,
          overflow: 'hidden',
          boxShadow: `0 24px 48px ${alpha('#0f172a', 0.14)}`,
        },
      }}
    >
      <Box
        sx={{
          px: 2.5,
          pt: 2.5,
          pb: 2,
          background: `linear-gradient(135deg, ${alpha(accent, 0.16)} 0%, ${alpha(accent, 0.04)} 100%)`,
          borderBottom: `1px solid ${alpha(accent, 0.14)}`,
        }}
      >
        <Stack direction="row" spacing={2} alignItems="flex-start">
          <Box
            sx={{
              width: 48,
              height: 48,
              borderRadius: 2.5,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(accent, 0.16),
              color: accent,
              flexShrink: 0,
            }}
          >
            <AccessTimeIcon />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0, pt: 0.25 }}>
            <Typography variant="overline" sx={{ color: accent, fontWeight: 700, letterSpacing: '0.08em' }}>
              Cấu hình bảng công
            </Typography>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25}>
              Phạt đi muộn / về sớm
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.75 }}>
              Một mức phạt cố định cho cả tháng, theo tổng số phút đi muộn và về sớm.
            </Typography>
          </Box>
          <IconButton
            size="small"
            onClick={onClose}
            disabled={saving}
            sx={{ mt: -0.5, mr: -0.5, color: 'text.secondary' }}
            aria-label="Đóng"
          >
            <CloseIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Box>

      <DialogContent sx={{ px: 2.5, py: 2.5 }}>
        {loading ? (
          <Stack alignItems="center" py={5}>
            <CircularProgress size={28} />
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1.5 }}>
              Đang tải cấu hình…
            </Typography>
          </Stack>
        ) : (
          <Stack spacing={2.5}>
            {err && (
              <Alert severity="error" variant="outlined" sx={{ borderRadius: 2 }}>
                {err}
              </Alert>
            )}

            <InfoBanner>
              Tính theo <strong>tổng phút</strong> đi muộn / về sớm trong tháng (không miễn trừ). Dưới{' '}
              <strong>{exemptMin} phút</strong> không phạt tiền.
            </InfoBanner>

            <FormSection
              title="Các mức phạt theo phút"
              subtitle="Mỗi mức áp dụng khi tổng phút tháng nằm trong khoảng tương ứng"
            >
              <Stack spacing={1.75}>
                {tiers.map((tier, idx) => {
                  const tone = TONE_BY_INDEX[idx] ?? 'info';
                  if (tier.requiresDiscipline) {
                    return (
                      <TierCard
                        key={tier.sortOrder}
                        level={tier.sortOrder}
                        tone={tone}
                        title={`Từ ${tier.minMinutes} phút trở lên`}
                        subtitle="Vượt ngưỡng — không phạt tiền, xử lý kỷ luật"
                      >
                        <Stack spacing={1.5}>
                          <Grid container spacing={1.5}>
                            <Grid item xs={12} sm={6}>
                              <TextField
                                fullWidth
                                size="small"
                                type="number"
                                label="Từ phút thứ"
                                value={tier.minMinutes}
                                onChange={(e) =>
                                  updateTier(tier.sortOrder, {
                                    minMinutes: Math.max(1, Number(e.target.value) || 1),
                                  })
                                }
                                inputProps={{ min: 1 }}
                                sx={fieldSx}
                              />
                            </Grid>
                          </Grid>
                          <TextField
                            fullWidth
                            size="small"
                            label="Ghi chú xử lý"
                            value={tier.note}
                            onChange={(e) => updateTier(tier.sortOrder, { note: e.target.value })}
                            placeholder="Yêu cầu làm bản tự kiểm điểm và xem xét kỷ luật"
                            sx={fieldSx}
                            InputProps={{
                              startAdornment: (
                                <InputAdornment position="start">
                                  <GavelIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                                </InputAdornment>
                              ),
                            }}
                          />
                        </Stack>
                      </TierCard>
                    );
                  }

                  return (
                    <TierCard
                      key={tier.sortOrder}
                      level={tier.sortOrder}
                      tone={tone}
                      title={`${tier.minMinutes}–${tier.maxMinutes ?? '…'} phút/tháng`}
                      subtitle="Mức phạt tiền cố định cho cả tháng"
                    >
                      <Grid container spacing={2}>
                        <Grid item xs={12} sm={6} md={4}>
                          <TextField
                            fullWidth
                            size="small"
                            type="number"
                            label="Từ phút"
                            value={tier.minMinutes}
                            onChange={(e) =>
                              updateTier(tier.sortOrder, {
                                minMinutes: Math.max(0, Number(e.target.value) || 0),
                              })
                            }
                            inputProps={{ min: 0 }}
                            sx={fieldSx}
                          />
                        </Grid>
                        <Grid item xs={12} sm={6} md={4}>
                          <TextField
                            fullWidth
                            size="small"
                            type="number"
                            label="Đến phút"
                            value={tier.maxMinutes ?? ''}
                            onChange={(e) =>
                              updateTier(tier.sortOrder, {
                                maxMinutes: Math.max(tier.minMinutes, Number(e.target.value) || tier.minMinutes),
                              })
                            }
                            inputProps={{ min: tier.minMinutes }}
                            sx={fieldSx}
                          />
                        </Grid>
                        <Grid item xs={12} md={4}>
                          <MoneyField
                            value={tier.amount}
                            onChange={(n) => updateTier(tier.sortOrder, { amount: n })}
                            label="Số tiền phạt"
                          />
                        </Grid>
                      </Grid>
                    </TierCard>
                  );
                })}
              </Stack>
            </FormSection>

            <FormSection title="Xem trước" subtitle="Mức phạt áp dụng theo tổng phút trong tháng">
              <Box sx={{ borderRadius: 2, border: `1px solid ${theme.palette.divider}`, overflow: 'hidden' }}>
                <Table size="small">
                  <TableHead>
                    <TableRow sx={{ bgcolor: alpha(theme.palette.grey[500], 0.06) }}>
                      <TableCell sx={{ fontWeight: 700, py: 1.25 }}>Tổng phút/tháng</TableCell>
                      <TableCell sx={{ fontWeight: 700, py: 1.25 }}>Mức áp dụng</TableCell>
                      <TableCell align="right" sx={{ fontWeight: 700, py: 1.25 }}>
                        Số tiền
                      </TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {previewRows.map((row) => (
                      <TableRow key={row.minutes} hover>
                        <TableCell sx={{ py: 1.25 }}>
                          <Typography variant="body2" fontWeight={600}>
                            {row.minutes} phút
                          </Typography>
                        </TableCell>
                        <TableCell sx={{ py: 1.25 }}>
                          <Typography variant="body2" color="text.secondary">
                            {row.label}
                          </Typography>
                        </TableCell>
                        <TableCell align="right" sx={{ py: 1.25 }}>
                          {row.requiresDiscipline ? (
                            <Typography variant="body2" fontWeight={700} color="error.main">
                              Kỷ luật
                            </Typography>
                          ) : (
                            <Typography variant="body2" fontWeight={700} color="warning.dark">
                              {att.formatMoney(row.amount)}
                            </Typography>
                          )}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </Box>
            </FormSection>
          </Stack>
        )}
      </DialogContent>

      <Box
        sx={{
          px: 2.5,
          py: 2,
          borderTop: `1px solid ${theme.palette.divider}`,
          bgcolor: alpha(theme.palette.background.default, 0.5),
        }}
      >
        <Stack direction="row" justifyContent="flex-end" spacing={1.5}>
          <Button onClick={onClose} disabled={saving} variant="outlined" color="inherit" sx={{ borderRadius: 2 }}>
            Hủy
          </Button>
          <Button
            variant="contained"
            disabled={saving || loading}
            onClick={save}
            startIcon={saving ? <CircularProgress size={16} color="inherit" /> : <SaveOutlinedIcon />}
            sx={{
              borderRadius: 2,
              px: 2.5,
              bgcolor: accent,
              color: theme.palette.getContrastText(accent),
              '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
            }}
          >
            {saving ? 'Đang lưu…' : 'Lưu cấu hình'}
          </Button>
        </Stack>
      </Box>
    </Dialog>
  );
}
