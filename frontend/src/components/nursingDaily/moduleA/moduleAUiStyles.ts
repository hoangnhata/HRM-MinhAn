import { alpha, type SxProps, type Theme } from '@mui/material/styles';

export const MODULE_A_ACCENT = '#0f766e';

/** Pill-style tabs — ẩn indicator, tab active có nền trắng */
export function pillTabsSx(compact = false): SxProps<Theme> {
  return {
    minHeight: compact ? 40 : 44,
    p: 0.5,
    bgcolor: alpha('#0f172a', 0.035),
    borderRadius: compact ? 2.5 : 3,
    border: `1px solid ${alpha('#64748b', 0.1)}`,
    '& .MuiTabs-flexContainer': { gap: 0.5 },
    '& .MuiTab-root': {
      minHeight: compact ? 34 : 38,
      py: compact ? 0.65 : 0.75,
      px: compact ? 1.15 : 1.5,
      borderRadius: compact ? 2 : 2.25,
      textTransform: 'none',
      fontWeight: 700,
      fontSize: compact ? '0.8125rem' : '0.875rem',
      letterSpacing: '-0.01em',
      color: 'text.secondary',
      transition: 'background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease',
      '&.Mui-selected': {
        color: MODULE_A_ACCENT,
        bgcolor: '#fff',
        boxShadow: `0 1px 4px ${alpha('#0f172a', 0.08)}`,
      },
      '&:hover:not(.Mui-selected)': {
        bgcolor: alpha('#fff', 0.55),
        color: 'text.primary',
      },
    },
    '& .MuiTabs-indicator': { display: 'none' },
    '& .MuiTab-iconWrapper': { marginRight: 6, marginBottom: '0 !important' },
  };
}

/** Tab cấp trang — segmented pill giống Module A TabBar */
export function pageTabsSx(): SxProps<Theme> {
  return {
    minHeight: 44,
    p: 0.65,
    width: 'fit-content',
    maxWidth: '100%',
    bgcolor: alpha('#f8fafc', 0.95),
    borderRadius: 2.75,
    border: `1px solid ${alpha('#64748b', 0.12)}`,
    boxShadow: `inset 0 1px 0 ${alpha('#fff', 0.9)}`,
    '& .MuiTabs-scroller': { overflow: 'visible !important' },
    '& .MuiTabs-flexContainer': {
      gap: 0.35,
      width: 'fit-content',
    },
    '& .MuiTab-root': {
      minHeight: 38,
      minWidth: 'auto',
      maxWidth: 'none',
      width: 'auto',
      flex: '0 0 auto',
      py: 0.75,
      px: { xs: 1.15, sm: 1.35 },
      borderRadius: 2,
      textTransform: 'none',
      fontWeight: 700,
      fontSize: { xs: '0.8125rem', sm: '0.875rem' },
      letterSpacing: '-0.015em',
      color: 'text.secondary',
      border: '1px solid transparent',
      display: 'inline-flex',
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 0.75,
      transition: 'background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease',
      '&.Mui-selected': {
        color: MODULE_A_ACCENT,
        bgcolor: '#fff',
        border: `1px solid ${alpha(MODULE_A_ACCENT, 0.22)}`,
        boxShadow: `0 2px 10px ${alpha(MODULE_A_ACCENT, 0.1)}, inset 0 1px 0 ${alpha('#fff', 0.95)}`,
      },
      '&:hover:not(.Mui-selected)': {
        bgcolor: alpha('#fff', 0.65),
        color: 'text.primary',
      },
    },
    '& .MuiTabs-indicator': { display: 'none' },
    '& .MuiTab-iconWrapper': {
      margin: '0 !important',
      flexShrink: 0,
      width: 28,
      height: 28,
      borderRadius: 1.5,
      display: 'inline-grid',
      placeItems: 'center',
      bgcolor: alpha('#0f172a', 0.04),
      border: `1px solid ${alpha('#64748b', 0.08)}`,
      color: alpha('#475569', 0.9),
      '& .MuiSvgIcon-root': { fontSize: 17 },
    },
    '& .Mui-selected .MuiTab-iconWrapper': {
      bgcolor: alpha(MODULE_A_ACCENT, 0.1),
      border: `1px solid ${alpha(MODULE_A_ACCENT, 0.16)}`,
      color: MODULE_A_ACCENT,
    },
  };
}

export function panelPaperSx(): SxProps<Theme> {
  return {
    borderRadius: 3,
    border: `1px solid ${alpha('#64748b', 0.12)}`,
    bgcolor: '#fff',
    overflow: 'hidden',
    boxShadow: `0 1px 3px ${alpha('#0f172a', 0.04)}`,
  };
}

export function panelHeaderBandSx(): SxProps<Theme> {
  return {
    px: { xs: 1.5, sm: 2 },
    py: { xs: 1.35, sm: 1.65 },
    borderBottom: `1px solid ${alpha('#64748b', 0.1)}`,
    background: `linear-gradient(135deg, ${alpha(MODULE_A_ACCENT, 0.07)} 0%, ${alpha('#fff', 0.95)} 55%, ${alpha('#f0fdfa', 0.5)} 100%)`,
  };
}

export function filterBarSx(): SxProps<Theme> {
  return {
    p: { xs: 1.25, sm: 1.5 },
    mb: 2,
    borderRadius: 2.5,
    border: `1px solid ${alpha(MODULE_A_ACCENT, 0.12)}`,
    bgcolor: alpha('#f0fdfa', 0.35),
    boxShadow: `inset 0 1px 0 ${alpha('#fff', 0.8)}`,
  };
}
