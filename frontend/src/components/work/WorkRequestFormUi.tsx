import CloseIcon from '@mui/icons-material/Close';
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';
import SendIcon from '@mui/icons-material/Send';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogContent,
  IconButton,
  Paper,
  Stack,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { createContext, useContext } from 'react';

const RequestAccentContext = createContext<string | null>(null);

export function useRequestAccent(fallback?: string) {
  const theme = useTheme();
  const ctx = useContext(RequestAccentContext);
  return ctx || fallback || theme.palette.primary.main;
}

/** Chip header thống nhất trên dialog chi tiết đơn. */
export const detailHeaderChipSx = {
  filled: { fontWeight: 700, borderRadius: 1.5 },
  outlined: { fontWeight: 600, borderRadius: 1.5, bgcolor: alpha('#fff', 0.55) },
} as const;

type DialogShellProps = {
  open: boolean;
  onClose: () => void;
  loading?: boolean;
  accent: string;
  icon: React.ReactNode;
  overline: string;
  title: string;
  description: string;
  formId: string;
  submitLabel: string;
  children: React.ReactNode;
  error?: string | null;
  onSubmit?: (e: React.FormEvent) => void;
  maxWidth?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
};

export function WorkRequestDialogShell({
  open,
  onClose,
  loading,
  accent,
  icon,
  overline,
  title,
  description,
  formId,
  submitLabel,
  children,
  error,
  onSubmit,
  maxWidth = 'md',
}: DialogShellProps) {
  const theme = useTheme();

  return (
    <RequestAccentContext.Provider value={accent}>
    <Dialog
      open={open}
      onClose={loading ? undefined : onClose}
      maxWidth={maxWidth}
      fullWidth
      PaperProps={{
        sx: {
          borderRadius: { xs: 0, sm: 3.5 },
          overflow: 'hidden',
          maxHeight: { xs: '100dvh', sm: '92dvh' },
          bgcolor: '#f4f7fb',
          border: { sm: `1px solid ${alpha(theme.palette.divider, 0.7)}` },
          boxShadow: `0 28px 80px ${alpha('#0f172a', 0.16)}`,
        },
      }}
    >
      <Box
        sx={{
          px: { xs: 2, sm: 3 },
          pt: { xs: 2, sm: 2.75 },
          pb: { xs: 1.75, sm: 2.5 },
          background: `linear-gradient(145deg, ${alpha(accent, 0.16)} 0%, ${alpha(accent, 0.04)} 42%, #fff 100%)`,
          borderBottom: `1px solid ${alpha(accent, 0.1)}`,
        }}
      >
        <Stack direction="row" spacing={2} alignItems="flex-start">
          <Box
            sx={{
              width: { xs: 46, sm: 52 },
              height: { xs: 46, sm: 52 },
              borderRadius: 2.75,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(accent, 0.12),
              color: accent,
              flexShrink: 0,
              boxShadow: `0 8px 20px ${alpha(accent, 0.16)}, inset 0 1px 0 ${alpha('#fff', 0.55)}`,
              border: `1px solid ${alpha(accent, 0.18)}`,
            }}
          >
            {icon}
          </Box>
          <Box sx={{ flex: 1, minWidth: 0, pt: 0.25 }}>
            <Typography
              variant="overline"
              sx={{ color: accent, fontWeight: 800, letterSpacing: '0.1em', fontSize: '0.68rem' }}
            >
              {overline}
            </Typography>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25} sx={{ letterSpacing: '-0.01em' }}>
              {title}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.65, lineHeight: 1.5 }}>
              {description}
            </Typography>
          </Box>
          <IconButton
            size="small"
            onClick={onClose}
            disabled={loading}
            sx={{
              mt: -0.5,
              mr: -0.5,
              color: 'text.secondary',
              bgcolor: alpha(theme.palette.grey[500], 0.06),
              '&:hover': { bgcolor: alpha(theme.palette.grey[500], 0.12) },
            }}
            aria-label="Đóng"
          >
            <CloseIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Box>

      <DialogContent sx={{ px: { xs: 2, sm: 3 }, py: { xs: 2, sm: 2.75 }, bgcolor: '#f4f7fb' }}>
        <Stack spacing={2.25} component="form" id={formId} onSubmit={onSubmit}>
          {children}
          {error && (
            <Alert severity="error" variant="outlined" sx={{ borderRadius: 2 }}>
              {error}
            </Alert>
          )}
        </Stack>
      </DialogContent>

      <Box
        sx={{
          px: 2.5,
          py: 2,
          borderTop: `1px solid ${theme.palette.divider}`,
          bgcolor: '#fff',
        }}
      >
        <Stack direction="row" spacing={1.5} justifyContent="flex-end">
          <Button onClick={onClose} disabled={loading} variant="outlined" color="inherit" sx={{ borderRadius: 2 }}>
            Hủy
          </Button>
          <Button
            type="submit"
            form={formId}
            variant="contained"
            disabled={loading}
            startIcon={loading ? <CircularProgress size={18} color="inherit" /> : <SendIcon />}
            sx={{
              borderRadius: 2,
              px: 2.5,
              fontWeight: 700,
              bgcolor: accent,
              '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
            }}
          >
            {loading ? 'Đang gửi…' : submitLabel}
          </Button>
        </Stack>
      </Box>
    </Dialog>
    </RequestAccentContext.Provider>
  );
}

type ViewShellProps = {
  open: boolean;
  onClose: () => void;
  loading?: boolean;
  accent: string;
  icon: React.ReactNode;
  overline: string;
  title: string;
  description?: string;
  headerExtra?: React.ReactNode;
  children: React.ReactNode;
  footer?: React.ReactNode;
  maxWidth?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
};

/** Shell xem chi tiết / duyệt đơn — cùng phong cách với form gửi đơn. */
export function WorkRequestViewShell({
  open,
  onClose,
  loading,
  accent,
  icon,
  overline,
  title,
  description,
  headerExtra,
  children,
  footer,
  maxWidth = 'md',
}: ViewShellProps) {
  const theme = useTheme();

  return (
    <RequestAccentContext.Provider value={accent}>
    <Dialog
      open={open}
      onClose={loading ? undefined : onClose}
      maxWidth={maxWidth}
      fullWidth
      PaperProps={{
        sx: {
          borderRadius: { xs: 0, sm: 3.5 },
          overflow: 'hidden',
          maxHeight: { xs: '100dvh', sm: '92dvh' },
          bgcolor: '#f4f7fb',
          border: { sm: `1px solid ${alpha(theme.palette.divider, 0.7)}` },
          boxShadow: `0 28px 80px ${alpha('#0f172a', 0.16)}`,
        },
      }}
    >
      <Box
        sx={{
          px: { xs: 2, sm: 3 },
          pt: { xs: 2, sm: 2.75 },
          pb: { xs: 1.75, sm: 2.5 },
          background: `linear-gradient(145deg, ${alpha(accent, 0.16)} 0%, ${alpha(accent, 0.04)} 42%, #fff 100%)`,
          borderBottom: `1px solid ${alpha(accent, 0.1)}`,
        }}
      >
        <Stack direction="row" spacing={2} alignItems="flex-start">
          <Box
            sx={{
              width: { xs: 46, sm: 52 },
              height: { xs: 46, sm: 52 },
              borderRadius: 2.75,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(accent, 0.12),
              color: accent,
              flexShrink: 0,
              boxShadow: `0 8px 20px ${alpha(accent, 0.16)}, inset 0 1px 0 ${alpha('#fff', 0.55)}`,
              border: `1px solid ${alpha(accent, 0.18)}`,
            }}
          >
            {icon}
          </Box>
          <Box sx={{ flex: 1, minWidth: 0, pt: 0.25 }}>
            <Typography
              variant="overline"
              sx={{ color: accent, fontWeight: 800, letterSpacing: '0.1em', fontSize: '0.68rem' }}
            >
              {overline}
            </Typography>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25} sx={{ letterSpacing: '-0.01em' }}>
              {title}
            </Typography>
            {description && (
              <Typography variant="body2" color="text.secondary" sx={{ mt: 0.65, lineHeight: 1.5 }}>
                {description}
              </Typography>
            )}
            {headerExtra && <Box sx={{ mt: 1.35 }}>{headerExtra}</Box>}
          </Box>
          <IconButton
            size="small"
            onClick={onClose}
            disabled={loading}
            sx={{
              mt: -0.5,
              mr: -0.5,
              color: 'text.secondary',
              bgcolor: alpha(theme.palette.grey[500], 0.06),
              '&:hover': { bgcolor: alpha(theme.palette.grey[500], 0.12) },
            }}
            aria-label="Đóng"
          >
            <CloseIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Box>

      <DialogContent
        sx={{
          px: { xs: 2, sm: 3 },
          py: { xs: 2, sm: 2.75 },
          bgcolor: '#f4f7fb',
        }}
      >
        <Stack spacing={2.25}>{children}</Stack>
      </DialogContent>

      {footer ?? (
        <Box
          sx={{
            px: { xs: 2, sm: 3 },
            py: 1.75,
            borderTop: `1px solid ${theme.palette.divider}`,
            bgcolor: '#fff',
          }}
        >
          <Stack direction="row" spacing={1.5} justifyContent="flex-end">
            <Button onClick={onClose} disabled={loading} variant="outlined" color="inherit" sx={{ borderRadius: 2 }}>
              Đóng
            </Button>
          </Stack>
        </Box>
      )}
    </Dialog>
    </RequestAccentContext.Provider>
  );
}

export function FormSection({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}) {
  const theme = useTheme();
  const accent = useRequestAccent();
  return (
    <Box
      sx={{
        position: 'relative',
        borderRadius: 3,
        bgcolor: '#fff',
        border: `1px solid ${alpha(theme.palette.divider, 0.5)}`,
        boxShadow: `0 1px 2px ${alpha('#0f172a', 0.03)}, 0 10px 28px ${alpha('#0f172a', 0.035)}`,
        overflow: 'hidden',
        '&::before': {
          content: '""',
          position: 'absolute',
          left: 0,
          top: 0,
          bottom: 0,
          width: 3,
          background: `linear-gradient(180deg, ${accent}, ${alpha(accent, 0.35)})`,
        },
      }}
    >
      <Box sx={{ px: { xs: 2.25, sm: 2.75 }, pt: 2, pb: subtitle ? 0.65 : 1 }}>
        <Typography
          variant="subtitle2"
          fontWeight={800}
          sx={{
            letterSpacing: '0.01em',
            color: 'text.primary',
          }}
        >
          {title}
        </Typography>
        {subtitle && (
          <Typography
            variant="caption"
            color="text.secondary"
            display="block"
            sx={{ mt: 0.4, lineHeight: 1.55, maxWidth: 560 }}
          >
            {subtitle}
          </Typography>
        )}
      </Box>
      <Stack spacing={1.75} sx={{ px: { xs: 2.25, sm: 2.75 }, pb: 2.25, pt: 0.25 }}>
        {children}
      </Stack>
    </Box>
  );
}

/** Lưới nhãn / giá trị cho dialog xem chi tiết đơn. */
export function DetailFields({ children }: { children: React.ReactNode }) {
  return (
    <Box
      sx={{
        display: 'grid',
        gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
        gap: { xs: 1.25, sm: 1.35 },
      }}
    >
      {children}
    </Box>
  );
}

export function DetailField({
  label,
  value,
  icon,
  wide,
}: {
  label: string;
  value: React.ReactNode;
  icon?: React.ReactNode;
  /** Chiếm cả hàng (lý do, ghi chú dài…) */
  wide?: boolean;
}) {
  const theme = useTheme();
  const accent = useRequestAccent();
  const empty =
    value == null || value === '' || (typeof value === 'string' && !value.trim());
  return (
    <Box
      sx={{
        minWidth: 0,
        gridColumn: wide ? '1 / -1' : undefined,
        p: { xs: 1.35, sm: 1.5 },
        borderRadius: 2,
        bgcolor: '#fff',
        border: `1px solid ${alpha(theme.palette.divider, 0.4)}`,
        boxShadow: `0 1px 2px ${alpha('#0f172a', 0.02)}`,
        transition: 'border-color .18s ease, box-shadow .18s ease',
        '&:hover': {
          borderColor: alpha(accent, 0.28),
          boxShadow: `0 4px 14px ${alpha(accent, 0.06)}`,
        },
      }}
    >
      <Typography
        variant="caption"
        sx={{
          display: 'flex',
          alignItems: 'center',
          gap: 0.85,
          fontWeight: 700,
          mb: 0.65,
          letterSpacing: '0.04em',
          textTransform: 'uppercase',
          fontSize: '0.68rem',
          color: alpha(theme.palette.text.secondary, 0.92),
        }}
      >
        {icon && (
          <Box
            component="span"
            sx={{
              width: 22,
              height: 22,
              borderRadius: 1.25,
              display: 'inline-grid',
              placeItems: 'center',
              bgcolor: alpha(accent, 0.1),
              color: accent,
              lineHeight: 0,
              flexShrink: 0,
              '& .MuiSvgIcon-root': { fontSize: 14 },
            }}
          >
            {icon}
          </Box>
        )}
        {label}
      </Typography>
      <Typography
        variant="body2"
        component="div"
        sx={{
          fontWeight: 700,
          lineHeight: 1.55,
          fontSize: wide ? '0.95rem' : '0.9375rem',
          color: empty ? 'text.disabled' : 'text.primary',
          wordBreak: 'break-word',
          whiteSpace: typeof value === 'string' ? 'pre-wrap' : undefined,
          pl: icon ? 3.85 : 0,
        }}
      >
        {empty ? '—' : value}
      </Typography>
    </Box>
  );
}

export function InfoBanner({ children }: { children: React.ReactNode }) {
  const theme = useTheme();
  return (
    <Box
      sx={{
        display: 'flex',
        gap: 1.35,
        p: 1.65,
        borderRadius: 2.5,
        bgcolor: alpha(theme.palette.info.main, 0.07),
        border: `1px solid ${alpha(theme.palette.info.main, 0.16)}`,
        boxShadow: `inset 0 1px 0 ${alpha('#fff', 0.55)}`,
      }}
    >
      <InfoOutlinedIcon sx={{ fontSize: 20, color: 'info.main', mt: 0.1, flexShrink: 0 }} />
      <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.6 }}>
        {children}
      </Typography>
    </Box>
  );
}

/** Thanh bước duyệt trên form lập đơn. */
export function RequestFlowSteps({
  accent,
  steps,
  activeIndex = 0,
}: {
  accent: string;
  steps: { label: string; hint?: string }[];
  activeIndex?: number;
}) {
  return (
    <Box
      sx={{
        display: 'grid',
        gridTemplateColumns: `repeat(${steps.length}, minmax(0, 1fr))`,
        gap: { xs: 0.5, sm: 1 },
        p: { xs: 1, sm: 1.25 },
        borderRadius: 2.5,
        bgcolor: '#fff',
        border: `1px solid ${alpha(accent, 0.12)}`,
        boxShadow: `0 4px 16px ${alpha('#0f172a', 0.03)}`,
        overflow: 'hidden',
      }}
    >
      {steps.map((s, i) => (
        <Stack
          key={`${s.label}-${i}`}
          direction="row"
          spacing={{ xs: 0.75, sm: 1 }}
          alignItems="center"
          sx={{
            p: { xs: 0.6, sm: 1 },
            borderRadius: 2,
            bgcolor: i === activeIndex ? alpha(accent, 0.07) : i < activeIndex ? alpha(accent, 0.035) : 'transparent',
            minWidth: 0,
          }}
        >
          <Box
            sx={{
              width: 26,
              height: 26,
              borderRadius: '50%',
              display: 'grid',
              placeItems: 'center',
              bgcolor: i <= activeIndex ? accent : alpha(accent, 0.12),
              color: i <= activeIndex ? '#fff' : accent,
              fontSize: '0.72rem',
              fontWeight: 800,
              flexShrink: 0,
            }}
          >
            {i + 1}
          </Box>
          <Box sx={{ minWidth: 0 }}>
            <Typography
              variant="body2"
              fontWeight={800}
              noWrap
              sx={{ fontSize: { xs: '0.78rem', sm: '0.875rem' } }}
            >
              {s.label}
            </Typography>
            {s.hint && (
              <Typography
                variant="caption"
                color="text.secondary"
                sx={{
                  display: 'block',
                  fontSize: { xs: '0.65rem', sm: '0.75rem' },
                  whiteSpace: 'normal',
                  wordBreak: 'keep-all',
                  overflowWrap: 'break-word',
                  lineHeight: 1.25,
                }}
              >
                {s.hint}
              </Typography>
            )}
          </Box>
        </Stack>
      ))}
    </Box>
  );
}

/** Ô thông tin chỉ đọc trên form lập đơn. */
export function ReadonlyFact({
  accent,
  icon,
  label,
  value,
}: {
  accent: string;
  icon?: React.ReactNode;
  label: string;
  value: React.ReactNode;
}) {
  return (
    <Box
      sx={{
        p: 1.5,
        borderRadius: 2.25,
        bgcolor: alpha(accent, 0.035),
        border: `1px solid ${alpha(accent, 0.1)}`,
        height: '100%',
      }}
    >
      <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mb: 0.55 }}>
        {icon && (
          <Box sx={{ color: accent, display: 'flex', opacity: 0.85, lineHeight: 0 }}>{icon}</Box>
        )}
        <Typography
          variant="caption"
          sx={{
            fontWeight: 700,
            letterSpacing: '0.04em',
            textTransform: 'uppercase',
            fontSize: '0.65rem',
            color: 'text.secondary',
          }}
        >
          {label}
        </Typography>
      </Stack>
      <Typography
        variant="body2"
        fontWeight={750}
        sx={{ lineHeight: 1.45, pl: icon ? 3.1 : 0, wordBreak: 'break-word' }}
      >
        {value || '—'}
      </Typography>
    </Box>
  );
}

/** Style TextField đồng bộ theo accent của loại đơn. */
export function requestFieldSx(accent: string) {
  return {
    '& .MuiOutlinedInput-root': {
      borderRadius: 2.25,
      bgcolor: '#fff',
      transition: 'border-color .18s, box-shadow .18s',
      '&:hover .MuiOutlinedInput-notchedOutline': {
        borderColor: alpha(accent, 0.4),
      },
      '&.Mui-focused': {
        boxShadow: `0 0 0 3px ${alpha(accent, 0.12)}`,
      },
      '&.Mui-disabled': {
        bgcolor: alpha('#0f172a', 0.02),
      },
    },
    '& .MuiInputLabel-root.Mui-focused': { color: accent },
  };
}

export function SelectableChip({
  selected,
  label,
  onClick,
}: {
  selected: boolean;
  label: string;
  onClick: () => void;
}) {
  const theme = useTheme();
  const accent = theme.palette.primary.main;
  return (
    <Box
      component="button"
      type="button"
      onClick={onClick}
      sx={{
        border: 'none',
        cursor: 'pointer',
        font: 'inherit',
        textAlign: 'left',
        width: '100%',
        p: 1.5,
        borderRadius: 2,
        transition: 'all 0.18s ease',
        bgcolor: selected ? alpha(accent, 0.1) : alpha(theme.palette.grey[500], 0.04),
        outline: selected ? `2px solid ${accent}` : `1px solid ${alpha(theme.palette.divider, 0.9)}`,
        '&:hover': {
          bgcolor: selected ? alpha(accent, 0.14) : alpha(theme.palette.grey[500], 0.08),
        },
      }}
    >
      <Typography variant="body2" fontWeight={selected ? 700 : 500}>
        {label}
      </Typography>
    </Box>
  );
}

export function ExplainToggleCard({
  selected,
  title,
  subtitle,
  icon,
  accent,
  onToggle,
  children,
}: {
  selected: boolean;
  title: string;
  subtitle: string;
  icon: React.ReactNode;
  accent: string;
  onToggle: () => void;
  children?: React.ReactNode;
}) {
  const theme = useTheme();
  return (
    <Paper
      variant="outlined"
      sx={{
        borderRadius: 2.5,
        overflow: 'hidden',
        borderColor: selected ? alpha(accent, 0.45) : alpha(theme.palette.divider, 0.9),
        bgcolor: selected ? alpha(accent, 0.05) : 'transparent',
        transition: 'border-color 0.2s, background-color 0.2s',
      }}
    >
      <Box
        component="button"
        type="button"
        onClick={onToggle}
        sx={{
          width: '100%',
          border: 'none',
          cursor: 'pointer',
          bgcolor: 'transparent',
          textAlign: 'left',
          p: 1.75,
          display: 'flex',
          gap: 1.5,
          alignItems: 'flex-start',
        }}
      >
        <Box
          sx={{
            width: 40,
            height: 40,
            borderRadius: 2,
            display: 'grid',
            placeItems: 'center',
            bgcolor: selected ? alpha(accent, 0.14) : alpha(theme.palette.grey[500], 0.08),
            color: selected ? accent : 'text.secondary',
            flexShrink: 0,
          }}
        >
          {icon}
        </Box>
        <Box sx={{ flex: 1 }}>
          <Stack direction="row" alignItems="center" spacing={1}>
            <Typography variant="subtitle2" fontWeight={700}>
              {title}
            </Typography>
            <Box
              sx={{
                width: 18,
                height: 18,
                borderRadius: '50%',
                border: `2px solid ${selected ? accent : theme.palette.grey[400]}`,
                bgcolor: selected ? accent : 'transparent',
                display: 'grid',
                placeItems: 'center',
                flexShrink: 0,
              }}
            >
              {selected && (
                <Box sx={{ width: 6, height: 6, borderRadius: '50%', bgcolor: '#fff' }} />
              )}
            </Box>
          </Stack>
          <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.35 }}>
            {subtitle}
          </Typography>
        </Box>
      </Box>
      {selected && children && (
        <Box sx={{ px: 1.75, pb: 1.75, pt: 0 }}>
          {children}
        </Box>
      )}
    </Paper>
  );
}
