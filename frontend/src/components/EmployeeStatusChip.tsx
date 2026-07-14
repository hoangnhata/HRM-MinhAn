import { Chip, type ChipProps } from '@mui/material';
import { alpha, useTheme, type Theme } from '@mui/material/styles';
import { EMPLOYMENT_STATUS_LABEL } from '../services/employeeService';

type StatusKey = keyof typeof EMPLOYMENT_STATUS_LABEL;

function statusPalette(status: string, theme: Theme) {
  const p = theme.palette;
  switch (status) {
    case 'ACTIVE':
      return {
        color: p.success.dark,
        bg: alpha(p.success.main, 0.1),
        border: alpha(p.success.main, 0.28),
      };
    case 'PROBATION':
      return {
        color: '#b45309',
        bg: alpha('#f59e0b', 0.12),
        border: alpha('#f59e0b', 0.35),
      };
    case 'INTERN':
      return {
        color: p.info.dark,
        bg: alpha(p.info.main, 0.1),
        border: alpha(p.info.main, 0.28),
      };
    case 'ON_LEAVE':
      return {
        color: '#6d28d9',
        bg: alpha('#8b5cf6', 0.1),
        border: alpha('#8b5cf6', 0.28),
      };
    case 'TERMINATED':
      return {
        color: p.text.secondary,
        bg: alpha(p.text.primary, 0.05),
        border: alpha(p.divider, 0.9),
      };
    default:
      return {
        color: p.text.secondary,
        bg: alpha(p.text.primary, 0.04),
        border: alpha(p.divider, 0.8),
      };
  }
}

type Props = {
  status: string;
} & Omit<ChipProps, 'label' | 'color' | 'variant'>;

/** Chip trạng thái nhân viên — nền nhạt, viền mảnh, chữ gọn. */
export function EmployeeStatusChip({ status, sx, ...rest }: Props) {
  const theme = useTheme();
  const palette = statusPalette(status, theme);
  const label = EMPLOYMENT_STATUS_LABEL[status as StatusKey] ?? status;

  return (
    <Chip
      size="small"
      label={label}
      variant="outlined"
      sx={{
        height: 24,
        minWidth: 72,
        fontSize: '0.72rem',
        fontWeight: 600,
        letterSpacing: '0.02em',
        lineHeight: 1.2,
        bgcolor: palette.bg,
        color: palette.color,
        borderColor: palette.border,
        borderRadius: '6px',
        boxShadow: 'none',
        '& .MuiChip-label': {
          px: 1.15,
          py: 0,
        },
        ...sx,
      }}
      {...rest}
    />
  );
}
