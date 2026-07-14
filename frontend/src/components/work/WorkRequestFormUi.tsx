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
    <Dialog
      open={open}
      onClose={loading ? undefined : onClose}
      maxWidth={maxWidth}
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
            {icon}
          </Box>
          <Box sx={{ flex: 1, minWidth: 0, pt: 0.25 }}>
            <Typography variant="overline" sx={{ color: accent, fontWeight: 700, letterSpacing: '0.08em' }}>
              {overline}
            </Typography>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25}>
              {title}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.75 }}>
              {description}
            </Typography>
          </Box>
          <IconButton
            size="small"
            onClick={onClose}
            disabled={loading}
            sx={{ mt: -0.5, mr: -0.5, color: 'text.secondary' }}
            aria-label="Đóng"
          >
            <CloseIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Box>

      <DialogContent sx={{ px: 2.5, py: 2.5 }}>
        <Stack spacing={2.5} component="form" id={formId} onSubmit={onSubmit}>
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
          bgcolor: alpha(theme.palette.background.default, 0.5),
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
              bgcolor: accent,
              '&:hover': { bgcolor: accent, filter: 'brightness(0.92)' },
            }}
          >
            {loading ? 'Đang gửi…' : submitLabel}
          </Button>
        </Stack>
      </Box>
    </Dialog>
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
    <Dialog
      open={open}
      onClose={loading ? undefined : onClose}
      maxWidth={maxWidth}
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
            {icon}
          </Box>
          <Box sx={{ flex: 1, minWidth: 0, pt: 0.25 }}>
            <Typography variant="overline" sx={{ color: accent, fontWeight: 700, letterSpacing: '0.08em' }}>
              {overline}
            </Typography>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25}>
              {title}
            </Typography>
            {description && (
              <Typography variant="body2" color="text.secondary" sx={{ mt: 0.75 }}>
                {description}
              </Typography>
            )}
            {headerExtra && <Box sx={{ mt: 1.25 }}>{headerExtra}</Box>}
          </Box>
          <IconButton
            size="small"
            onClick={onClose}
            disabled={loading}
            sx={{ mt: -0.5, mr: -0.5, color: 'text.secondary' }}
            aria-label="Đóng"
          >
            <CloseIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Box>

      <DialogContent sx={{ px: 2.5, py: 2.5 }}>
        <Stack spacing={2.5}>{children}</Stack>
      </DialogContent>

      {footer ?? (
        <Box
          sx={{
            px: 2.5,
            py: 2,
            borderTop: `1px solid ${theme.palette.divider}`,
            bgcolor: alpha(theme.palette.background.default, 0.5),
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
  return (
    <Paper
      variant="outlined"
      sx={{
        p: 2,
        borderRadius: 2.5,
        borderColor: alpha(theme.palette.divider, 0.9),
        bgcolor: alpha(theme.palette.background.paper, 0.6),
      }}
    >
      <Typography variant="subtitle2" fontWeight={700} sx={{ mb: subtitle ? 0.25 : 1.5 }}>
        {title}
      </Typography>
      {subtitle && (
        <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1.5 }}>
          {subtitle}
        </Typography>
      )}
      <Stack spacing={1.75}>{children}</Stack>
    </Paper>
  );
}

export function InfoBanner({ children }: { children: React.ReactNode }) {
  const theme = useTheme();
  return (
    <Box
      sx={{
        display: 'flex',
        gap: 1.25,
        p: 1.5,
        borderRadius: 2,
        bgcolor: alpha(theme.palette.info.main, 0.06),
        border: `1px solid ${alpha(theme.palette.info.main, 0.18)}`,
      }}
    >
      <InfoOutlinedIcon sx={{ fontSize: 20, color: 'info.main', mt: 0.15, flexShrink: 0 }} />
      <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.55 }}>
        {children}
      </Typography>
    </Box>
  );
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
