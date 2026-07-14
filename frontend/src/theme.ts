import { alpha, createTheme } from '@mui/material/styles';

/** Màu chủ đạo theo logo — xanh ngọc đậm */
const primary = {
  main: '#006865',
  light: '#338f8c',
  dark: '#004a48',
  contrastText: '#ffffff',
};

const accentGold = '#c9a227';

export const theme = createTheme({
  palette: {
    mode: 'light',
    primary,
    secondary: {
      main: accentGold,
      dark: '#9a7b1c',
      contrastText: '#1a1a1a',
    },
    error: {
      main: '#c62828',
    },
    success: {
      main: '#2e7d4a',
    },
    warning: {
      main: '#ed6c02',
    },
    background: {
      default: '#ecf1ef',
      paper: '#ffffff',
    },
    text: {
      primary: '#0f172a',
      secondary: '#64748b',
    },
    divider: alpha('#0f172a', 0.08),
  },
  typography: {
    fontFamily: '"Inter", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
    fontSize: 15,
    htmlFontSize: 16,
    h1: { fontWeight: 600, letterSpacing: '-0.03em', lineHeight: 1.2 },
    h2: { fontWeight: 600, letterSpacing: '-0.025em', lineHeight: 1.25 },
    h3: { fontWeight: 600, letterSpacing: '-0.02em', lineHeight: 1.3 },
    h4: {
      fontSize: '1.5rem',
      fontWeight: 700,
      letterSpacing: '-0.03em',
      lineHeight: 1.3,
    },
    h5: {
      fontSize: '1.125rem',
      fontWeight: 600,
      letterSpacing: '-0.02em',
      lineHeight: 1.4,
    },
    h6: {
      fontSize: '1rem',
      fontWeight: 600,
      letterSpacing: '-0.015em',
      lineHeight: 1.45,
    },
    subtitle1: {
      fontSize: '0.9375rem',
      fontWeight: 500,
      lineHeight: 1.5,
      letterSpacing: '-0.01em',
    },
    subtitle2: {
      fontSize: '0.8125rem',
      fontWeight: 500,
      lineHeight: 1.45,
      letterSpacing: '-0.006em',
    },
    body1: {
      fontSize: '0.9375rem',
      lineHeight: 1.65,
      letterSpacing: '-0.011em',
      fontWeight: 400,
    },
    body2: {
      fontSize: '0.8125rem',
      lineHeight: 1.55,
      letterSpacing: '-0.006em',
      fontWeight: 400,
    },
    button: {
      fontWeight: 500,
      letterSpacing: '-0.01em',
      textTransform: 'none' as const,
    },
    caption: {
      fontSize: '0.75rem',
      lineHeight: 1.5,
      letterSpacing: '0.01em',
      fontWeight: 400,
    },
    overline: {
      fontSize: '0.6875rem',
      fontWeight: 600,
      letterSpacing: '0.08em',
      lineHeight: 1.5,
      textTransform: 'uppercase' as const,
    },
  },
  shape: {
    borderRadius: 10,
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: {
          fontFeatureSettings: '"cv02", "cv03", "cv04", "cv11"',
          WebkitFontSmoothing: 'antialiased',
          MozOsxFontSmoothing: 'grayscale',
          scrollbarColor: `${alpha(primary.main, 0.28)} transparent`,
          backgroundColor: '#ecf1ef',
        },
      },
    },
    MuiButton: {
      defaultProps: {
        disableElevation: true,
      },
      styleOverrides: {
        root: {
          borderRadius: 8,
          paddingInline: 18,
          paddingBlock: 8,
          fontSize: '0.875rem',
        },
        containedPrimary: {
          boxShadow: `0 1px 2px ${alpha('#0f172a', 0.06)}, 0 2px 8px ${alpha(primary.main, 0.22)}`,
          '&:hover': {
            boxShadow: `0 2px 4px ${alpha('#0f172a', 0.08)}, 0 4px 14px ${alpha(primary.main, 0.28)}`,
          },
        },
        outlined: {
          borderColor: alpha('#0f172a', 0.12),
        },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 12,
          border: `1px solid ${alpha('#0f172a', 0.06)}`,
          boxShadow: '0 1px 3px rgba(15, 23, 42, 0.04)',
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        rounded: {
          borderRadius: 12,
        },
        elevation1: {
          boxShadow: '0 1px 3px rgba(15, 23, 42, 0.05)',
        },
      },
    },
    MuiAppBar: {
      styleOverrides: {
        colorPrimary: {
          backgroundImage: `linear-gradient(105deg, ${primary.dark} 0%, ${primary.main} 52%, #0b6d69 100%)`,
        },
      },
    },
    MuiDrawer: {
      styleOverrides: {
        paper: {
          borderRight: `1px solid ${alpha('#0f172a', 0.06)}`,
        },
      },
    },
    MuiListItemButton: {
      styleOverrides: {
        root: {
          borderRadius: 8,
          '&.Mui-selected': {
            backgroundColor: alpha(primary.main, 0.08),
            '&:hover': {
              backgroundColor: alpha(primary.main, 0.11),
            },
          },
        },
      },
    },
    MuiListItemText: {
      styleOverrides: {
        primary: {
          fontSize: '0.875rem',
          fontWeight: 500,
          letterSpacing: '-0.01em',
        },
      },
    },
    MuiListItemIcon: {
      styleOverrides: {
        root: {
          minWidth: 40,
          color: 'inherit',
          '& .MuiSvgIcon-root': {
            fontSize: '1.25rem',
          },
        },
      },
    },
    MuiTextField: {
      defaultProps: {
        variant: 'outlined',
      },
    },
    MuiOutlinedInput: {
      styleOverrides: {
        root: {
          borderRadius: 8,
          '& .MuiOutlinedInput-notchedOutline': {
            borderColor: alpha('#0f172a', 0.12),
          },
        },
      },
    },
    MuiTableHead: {
      styleOverrides: {
        root: {
          '& .MuiTableCell-head': {
            fontWeight: 700,
            fontSize: '0.8125rem',
            letterSpacing: '-0.01em',
            color: alpha('#0f172a', 0.72),
            backgroundColor: alpha(primary.main, 0.07),
            borderBottom: `1px solid ${alpha(primary.main, 0.14)}`,
          },
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          borderColor: alpha('#0f172a', 0.07),
        },
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: {
          borderRadius: 14,
          border: `1px solid ${alpha('#0f172a', 0.08)}`,
          boxShadow: '0 24px 48px rgba(15, 23, 42, 0.12)',
        },
      },
    },
    MuiTabs: {
      styleOverrides: {
        root: {
          minHeight: 48,
          '& .MuiTabs-indicator': {
            height: 3,
            borderRadius: '3px 3px 0 0',
            backgroundColor: accentGold,
          },
        },
      },
    },
    MuiTab: {
      styleOverrides: {
        root: {
          minHeight: 48,
          fontWeight: 600,
          fontSize: '0.875rem',
          textTransform: 'none',
          letterSpacing: '-0.01em',
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          fontWeight: 600,
        },
      },
    },
    MuiSnackbarContent: {
      styleOverrides: {
        root: {
          borderRadius: 10,
          boxShadow: '0 8px 24px rgba(15, 23, 42, 0.12)',
        },
      },
    },
  },
});
