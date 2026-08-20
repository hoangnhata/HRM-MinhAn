import { alpha, createTheme } from '@mui/material/styles';

/**
 * Design tokens chung cho HRM Minh An.
 * Bảng màu giữ nhận diện xanh ngọc / vàng của bệnh viện, nhưng giảm độ chói để
 * phù hợp với các màn hình nghiệp vụ cần làm việc liên tục.
 */
const primary = {
  main: '#087A75',
  light: '#4BA9A2',
  dark: '#045B57',
  contrastText: '#ffffff',
};

const accentGold = '#B98716';
const ink = '#172033';
const mutedInk = '#5C697C';
const canvas = '#F5F8F8';
const surface = '#FFFFFF';
const subtleBorder = alpha(ink, 0.09);

export const theme = createTheme({
  spacing: 8,
  palette: {
    mode: 'light',
    primary,
    secondary: {
      main: accentGold,
      light: '#E6C76E',
      dark: '#89630D',
      contrastText: '#251B05',
    },
    error: {
      main: '#C33B4A',
      light: '#FDEBED',
      dark: '#952D39',
      contrastText: '#FFFFFF',
    },
    success: {
      main: '#17835F',
      light: '#E4F7EF',
      dark: '#0F6247',
      contrastText: '#FFFFFF',
    },
    warning: {
      main: '#B96B00',
      light: '#FFF3DE',
      dark: '#8D5100',
      contrastText: '#FFFFFF',
    },
    info: {
      main: '#2574C8',
      light: '#E8F2FF',
      dark: '#15549A',
      contrastText: '#FFFFFF',
    },
    background: {
      default: canvas,
      paper: surface,
    },
    text: {
      primary: ink,
      secondary: mutedInk,
    },
    divider: subtleBorder,
    action: {
      hover: alpha(primary.main, 0.055),
      selected: alpha(primary.main, 0.105),
      focus: alpha(primary.main, 0.15),
      disabled: alpha(ink, 0.28),
      disabledBackground: alpha(ink, 0.08),
    },
  },
  typography: {
    fontFamily: '"Inter", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
    fontSize: 15,
    htmlFontSize: 16,
    h1: { fontWeight: 750, letterSpacing: '-0.035em', lineHeight: 1.15 },
    h2: { fontWeight: 750, letterSpacing: '-0.03em', lineHeight: 1.2 },
    h3: { fontWeight: 700, letterSpacing: '-0.025em', lineHeight: 1.25 },
    h4: {
      fontSize: '1.625rem',
      fontWeight: 750,
      letterSpacing: '-0.03em',
      lineHeight: 1.25,
    },
    h5: {
      fontSize: '1.125rem',
      fontWeight: 700,
      letterSpacing: '-0.02em',
      lineHeight: 1.35,
    },
    h6: {
      fontSize: '1rem',
      fontWeight: 700,
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
      fontWeight: 650,
      letterSpacing: '-0.012em',
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
    borderRadius: 12,
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        ':root': {
          colorScheme: 'light',
        },
        '*': {
          boxSizing: 'border-box',
        },
        body: {
          fontFeatureSettings: '"cv02", "cv03", "cv04", "cv11"',
          WebkitFontSmoothing: 'antialiased',
          MozOsxFontSmoothing: 'grayscale',
          scrollbarColor: `${alpha(primary.main, 0.28)} transparent`,
          backgroundColor: canvas,
          color: ink,
        },
        '::selection': {
          backgroundColor: alpha(primary.main, 0.2),
          color: primary.dark,
        },
        '::-webkit-scrollbar': {
          width: 10,
          height: 10,
        },
        '::-webkit-scrollbar-thumb': {
          backgroundColor: alpha(primary.main, 0.24),
          border: '3px solid transparent',
          borderRadius: 999,
          backgroundClip: 'padding-box',
        },
        '::-webkit-scrollbar-thumb:hover': {
          backgroundColor: alpha(primary.main, 0.38),
        },
      },
    },
    MuiButton: {
      defaultProps: {
        disableElevation: true,
      },
      styleOverrides: {
        root: {
          minHeight: 38,
          borderRadius: 10,
          paddingInline: 18,
          paddingBlock: 8,
          fontSize: '0.875rem',
          lineHeight: 1.35,
          transition: 'background-color 160ms ease, border-color 160ms ease, box-shadow 160ms ease, transform 160ms ease',
          '&:focus-visible': {
            outline: `3px solid ${alpha(primary.main, 0.28)}`,
            outlineOffset: 2,
          },
          '&.Mui-disabled': {
            color: alpha(ink, 0.35),
          },
        },
        sizeSmall: {
          minHeight: 32,
          borderRadius: 8,
          paddingInline: 12,
          paddingBlock: 5,
          fontSize: '0.8125rem',
        },
        containedPrimary: {
          boxShadow: `0 2px 4px ${alpha(primary.dark, 0.16)}, 0 7px 16px ${alpha(primary.main, 0.2)}`,
          '&:hover': {
            backgroundColor: primary.dark,
            boxShadow: `0 3px 6px ${alpha(primary.dark, 0.18)}, 0 10px 22px ${alpha(primary.main, 0.25)}`,
            transform: 'translateY(-1px)',
          },
          '&:active': {
            boxShadow: `0 1px 3px ${alpha(primary.dark, 0.18)}`,
            transform: 'translateY(0)',
          },
        },
        outlined: {
          borderColor: alpha(ink, 0.16),
          '&:hover': {
            borderColor: alpha(primary.main, 0.55),
            backgroundColor: alpha(primary.main, 0.045),
          },
        },
        text: {
          '&:hover': {
            backgroundColor: alpha(primary.main, 0.065),
          },
        },
      },
    },
    MuiIconButton: {
      styleOverrides: {
        root: {
          borderRadius: 10,
          transition: 'background-color 160ms ease, color 160ms ease, transform 160ms ease',
          '&:focus-visible': {
            outline: `3px solid ${alpha(primary.main, 0.28)}`,
            outlineOffset: 2,
          },
        },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 16,
          border: `1px solid ${subtleBorder}`,
          boxShadow: '0 1px 2px rgba(23, 32, 51, 0.03), 0 8px 24px rgba(23, 32, 51, 0.035)',
          backgroundImage: 'none',
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        rounded: {
          borderRadius: 14,
        },
        elevation1: {
          boxShadow: '0 1px 2px rgba(23, 32, 51, 0.04), 0 6px 18px rgba(23, 32, 51, 0.04)',
        },
      },
    },
    MuiAppBar: {
      styleOverrides: {
        colorPrimary: {
          backgroundImage: `linear-gradient(108deg, ${primary.dark} 0%, ${primary.main} 58%, #10918A 100%)`,
          boxShadow: `0 1px 0 ${alpha('#FFFFFF', 0.12)} inset, 0 4px 14px ${alpha(primary.dark, 0.15)}`,
        },
      },
    },
    MuiDrawer: {
      styleOverrides: {
        paper: {
          borderRight: `1px solid ${subtleBorder}`,
          backgroundColor: '#FBFCFC',
        },
      },
    },
    MuiListItemButton: {
      styleOverrides: {
        root: {
          minHeight: 40,
          marginInline: 4,
          borderRadius: 10,
          transition: 'background-color 150ms ease, color 150ms ease',
          '&:hover': {
            backgroundColor: alpha(primary.main, 0.055),
          },
          '&.Mui-selected': {
            color: primary.dark,
            backgroundColor: alpha(primary.main, 0.105),
            boxShadow: `inset 3px 0 0 ${primary.main}`,
            '&:hover': {
              backgroundColor: alpha(primary.main, 0.14),
            },
          },
        },
      },
    },
    MuiListItemText: {
      styleOverrides: {
        primary: {
          fontSize: '0.875rem',
          fontWeight: 600,
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
          borderRadius: 10,
          backgroundColor: surface,
          transition: 'border-color 150ms ease, box-shadow 150ms ease, background-color 150ms ease',
          '& .MuiOutlinedInput-notchedOutline': {
            borderColor: alpha(ink, 0.15),
          },
          '&:hover .MuiOutlinedInput-notchedOutline': {
            borderColor: alpha(primary.main, 0.52),
          },
          '&.Mui-focused': {
            boxShadow: `0 0 0 3px ${alpha(primary.main, 0.12)}`,
          },
          '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
            borderColor: primary.main,
            borderWidth: 2,
          },
          '&.Mui-error .MuiOutlinedInput-notchedOutline': {
            borderColor: '#C33B4A',
          },
          '&.Mui-disabled': {
            backgroundColor: alpha(ink, 0.035),
          },
        },
      },
    },
    MuiInputLabel: {
      styleOverrides: {
        root: {
          fontWeight: 500,
          '&.Mui-focused': {
            color: primary.dark,
          },
        },
      },
    },
    MuiFormHelperText: {
      styleOverrides: {
        root: {
          marginInline: 2,
          lineHeight: 1.45,
        },
      },
    },
    MuiTableHead: {
      styleOverrides: {
        root: {
          '& .MuiTableCell-head': {
            fontWeight: 700,
            fontSize: '0.8125rem',
            letterSpacing: '0.005em',
            color: alpha(ink, 0.76),
            backgroundColor: alpha(primary.main, 0.065),
            borderBottom: `1px solid ${alpha(primary.main, 0.16)}`,
            whiteSpace: 'nowrap',
          },
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          paddingBlock: 12,
          borderColor: alpha(ink, 0.075),
        },
      },
    },
    MuiTableRow: {
      styleOverrides: {
        root: {
          '&.MuiTableRow-hover:hover': {
            backgroundColor: alpha(primary.main, 0.035),
          },
        },
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: {
          borderRadius: 18,
          border: `1px solid ${alpha(ink, 0.1)}`,
          boxShadow: '0 24px 56px rgba(23, 32, 51, 0.16)',
        },
      },
    },
    MuiDialogTitle: {
      styleOverrides: {
        root: {
          padding: '20px 24px 12px',
          fontWeight: 750,
          letterSpacing: '-0.02em',
        },
      },
    },
    MuiMenu: {
      styleOverrides: {
        paper: {
          marginTop: 6,
          border: `1px solid ${alpha(ink, 0.09)}`,
          borderRadius: 12,
          boxShadow: '0 12px 30px rgba(23, 32, 51, 0.13)',
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
            backgroundColor: primary.main,
          },
        },
      },
    },
    MuiTab: {
      styleOverrides: {
        root: {
          minHeight: 48,
          fontWeight: 650,
          fontSize: '0.875rem',
          textTransform: 'none',
          letterSpacing: '-0.01em',
          color: mutedInk,
          '&.Mui-selected': {
            color: primary.dark,
          },
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          height: 28,
          borderRadius: 8,
          fontWeight: 600,
          letterSpacing: '-0.005em',
        },
        outlined: {
          borderColor: alpha(ink, 0.14),
          backgroundColor: alpha(surface, 0.72),
        },
        sizeSmall: {
          height: 24,
          borderRadius: 7,
          fontSize: '0.75rem',
        },
      },
    },
    MuiAlert: {
      styleOverrides: {
        root: {
          borderRadius: 12,
          alignItems: 'center',
          border: '1px solid transparent',
        },
        standardSuccess: {
          color: '#0F6247',
          backgroundColor: '#E4F7EF',
          borderColor: alpha('#17835F', 0.18),
        },
        standardWarning: {
          color: '#744200',
          backgroundColor: '#FFF3DE',
          borderColor: alpha('#B96B00', 0.18),
        },
        standardError: {
          color: '#8C2A36',
          backgroundColor: '#FDEBED',
          borderColor: alpha('#C33B4A', 0.18),
        },
        standardInfo: {
          color: '#15549A',
          backgroundColor: '#E8F2FF',
          borderColor: alpha('#2574C8', 0.18),
        },
      },
    },
    MuiTooltip: {
      styleOverrides: {
        tooltip: {
          padding: '7px 10px',
          borderRadius: 8,
          backgroundColor: '#263244',
          fontSize: '0.75rem',
          boxShadow: '0 8px 20px rgba(23, 32, 51, 0.18)',
        },
        arrow: {
          color: '#263244',
        },
      },
    },
    MuiLinearProgress: {
      styleOverrides: {
        root: {
          height: 7,
          borderRadius: 99,
          backgroundColor: alpha(primary.main, 0.12),
        },
        bar: {
          borderRadius: 99,
        },
      },
    },
    MuiPaginationItem: {
      styleOverrides: {
        root: {
          minWidth: 34,
          height: 34,
          borderRadius: 9,
          '&.Mui-selected': {
            backgroundColor: alpha(primary.main, 0.12),
            color: primary.dark,
            fontWeight: 700,
          },
        },
      },
    },
    MuiSnackbarContent: {
      styleOverrides: {
        root: {
          borderRadius: 12,
          boxShadow: '0 12px 30px rgba(23, 32, 51, 0.16)',
        },
      },
    },
  },
});
