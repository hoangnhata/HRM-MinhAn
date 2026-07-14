import CloseIcon from '@mui/icons-material/Close';
import SaveOutlinedIcon from '@mui/icons-material/SaveOutlined';
import SavingsOutlinedIcon from '@mui/icons-material/SavingsOutlined';
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
import { dateTimeFieldSx } from '../ui/DateTimeFields';
import { FormSection, InfoBanner } from './WorkRequestFormUi';

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved?: () => void;
};

const fieldSx = dateTimeFieldSx;

type TierTone = 'success' | 'warning' | 'error';

/** Mức / lần theo tổng số lần quên trong tháng. */
function rateForMonthlyCount(
  count: number,
  tier1: number,
  tier2Max: number,
  tier2: number,
  tier3: number,
) {
  if (count <= 1) return tier1;
  if (count <= tier2Max) return tier2;
  return tier3;
}

function totalForgotPenalty(
  count: number,
  tier1: number,
  _tier2Min: number,
  tier2Max: number,
  tier2: number,
  tier3: number,
) {
  if (count <= 0) return 0;
  return count * rateForMonthlyCount(count, tier1, tier2Max, tier2, tier3);
}

function MoneyField({
  value,
  onChange,
  label,
}: {
  value: number;
  onChange: (n: number) => void;
  label: string;
}) {
  return (
    <TextField
      fullWidth
      size="small"
      type="number"
      label={label}
      value={value}
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
        transition: 'border-color 0.2s, box-shadow 0.2s',
        '&:hover': {
          borderColor: alpha(palette.main, 0.35),
          boxShadow: `0 4px 16px ${alpha(palette.main, 0.08)}`,
        },
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

export function ForgotPenaltyConfigDialog({ open, onClose, onSaved }: Props) {
  const theme = useTheme();
  const accent = theme.palette.secondary.main;
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [tier1Amount, setTier1Amount] = useState(10000);
  const [tier2Min, setTier2Min] = useState(2);
  const [tier2Max, setTier2Max] = useState(4);
  const [tier2Amount, setTier2Amount] = useState(50000);
  const [tier3Amount, setTier3Amount] = useState(100000);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setLoading(true);
    att
      .fetchForgotPenaltyConfig()
      .then((cfg) => {
        setTier1Amount(Number(cfg.tier1Amount));
        setTier2Min(cfg.tier2Min);
        setTier2Max(cfg.tier2Max);
        setTier2Amount(Number(cfg.tier2Amount));
        setTier3Amount(Number(cfg.tier3Amount));
      })
      .catch(() => setErr('Không tải được cấu hình phạt quên chấm.'))
      .finally(() => setLoading(false));
  }, [open]);

  const previewRows = useMemo(() => {
    const counts = [1, 2, 3, 4, 5, 6];
    return counts.map((count) => ({
      count,
      total: totalForgotPenalty(count, tier1Amount, tier2Min, tier2Max, tier2Amount, tier3Amount),
    }));
  }, [tier1Amount, tier2Min, tier2Max, tier2Amount, tier3Amount]);

  async function save() {
    if (tier2Max < tier2Min) {
      setErr('Mức giữa: số lần tối đa phải ≥ số lần tối thiểu.');
      return;
    }
    setSaving(true);
    setErr(null);
    try {
      await att.updateForgotPenaltyConfig({
        tier1Amount,
        tier2Min,
        tier2Max,
        tier2Amount,
        tier3Amount,
      });
      onSaved?.();
      onClose();
    } catch {
      setErr('Lưu cấu hình thất bại.');
    } finally {
      setSaving(false);
    }
  }

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
          background: `linear-gradient(135deg, ${alpha(accent, 0.14)} 0%, ${alpha(accent, 0.04)} 100%)`,
          borderBottom: `1px solid ${alpha(accent, 0.12)}`,
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
              bgcolor: alpha(accent, 0.14),
              color: accent,
              flexShrink: 0,
            }}
          >
            <SavingsOutlinedIcon />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0, pt: 0.25 }}>
            <Typography variant="overline" sx={{ color: accent, fontWeight: 700, letterSpacing: '0.08em' }}>
              Cấu hình bảng công
            </Typography>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25}>
              Phạt quên chấm công
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.75 }}>
              Thiết lập mức phạt theo số lần quên chấm tích lũy trong tháng.
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
              Tính theo <strong>tổng số lần quên</strong> trong tháng: 1 lần = 10k; 2–4 lần = 50k × số lần;
              từ 5 lần = 100k × số lần. Đơn cập nhật: <strong>1 ca = 2 lần</strong>,{' '}
              <strong>cả ngày = 4 lần</strong>.
            </InfoBanner>

            <FormSection title="Ba mức phạt" subtitle="Mức / lần được xác định theo tổng số lần quên trong tháng">
              <Stack spacing={1.75}>
                <TierCard
                  level={1}
                  tone="success"
                  title="Lần đầu tiên"
                  subtitle="Khi tổng số lần quên trong tháng = 1"
                >
                  <MoneyField value={tier1Amount} onChange={setTier1Amount} label="Số tiền / lần" />
                </TierCard>

                <TierCard
                  level={2}
                  tone="warning"
                  title={`Từ lần thứ ${tier2Min} đến ${tier2Max}`}
                  subtitle={`Khi tổng số lần quên trong tháng từ ${tier2Min} đến ${tier2Max} — nhân với số lần`}
                >
                  <Grid container spacing={2}>
                    <Grid item xs={12} sm={6} md={4}>
                      <TextField
                        fullWidth
                        size="small"
                        type="number"
                        label="Từ lần thứ"
                        value={tier2Min}
                        onChange={(e) => setTier2Min(Math.max(2, Number(e.target.value) || 2))}
                        inputProps={{ min: 2, max: 31 }}
                        sx={fieldSx}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6} md={4}>
                      <TextField
                        fullWidth
                        size="small"
                        type="number"
                        label="Đến lần thứ"
                        value={tier2Max}
                        onChange={(e) => setTier2Max(Math.max(tier2Min, Number(e.target.value) || tier2Min))}
                        inputProps={{ min: tier2Min, max: 31 }}
                        sx={fieldSx}
                      />
                    </Grid>
                    <Grid item xs={12} md={4}>
                      <MoneyField value={tier2Amount} onChange={setTier2Amount} label="Số tiền / lần" />
                    </Grid>
                  </Grid>
                </TierCard>

                <TierCard
                  level={3}
                  tone="error"
                  title={`Từ lần thứ ${tier2Max + 1} trở đi`}
                  subtitle={`Khi tổng số lần quên trong tháng ≥ ${tier2Max + 1} — nhân với số lần`}
                >
                  <MoneyField value={tier3Amount} onChange={setTier3Amount} label="Số tiền / lần" />
                </TierCard>
              </Stack>
            </FormSection>

            <FormSection title="Xem trước tổng phạt" subtitle="Tổng tiền phạt theo tổng số lần quên trong tháng">
              <Box
                sx={{
                  borderRadius: 2,
                  border: `1px solid ${theme.palette.divider}`,
                  overflow: 'hidden',
                }}
              >
                <Table size="small">
                  <TableHead>
                    <TableRow sx={{ bgcolor: alpha(theme.palette.grey[500], 0.06) }}>
                      <TableCell sx={{ fontWeight: 700, py: 1.25 }}>Số lần trong tháng</TableCell>
                      <TableCell align="right" sx={{ fontWeight: 700, py: 1.25 }}>
                        Tổng phạt tích lũy
                      </TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {previewRows.map((row) => (
                      <TableRow key={row.count} hover>
                        <TableCell sx={{ py: 1.25 }}>
                          <Typography variant="body2" fontWeight={600}>
                            {row.count} lần
                          </Typography>
                        </TableCell>
                        <TableCell align="right" sx={{ py: 1.25 }}>
                          <Typography variant="body2" fontWeight={700} color="secondary.dark">
                            {att.formatMoney(row.total)}
                          </Typography>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </Box>
              <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 1.25 }}>
                Ví dụ: 1 đơn cập nhật cả ngày (4 lần) với cấu hình mặc định →{' '}
                {att.formatMoney(totalForgotPenalty(4, tier1Amount, tier2Min, tier2Max, tier2Amount, tier3Amount))}.
              </Typography>
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
