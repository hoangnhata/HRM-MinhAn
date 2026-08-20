import { Chip, type ChipProps } from '@mui/material';
import { alpha } from '@mui/material/styles';

type Props = Omit<ChipProps, 'label' | 'color' | 'variant'>;

/** Chip đang đi đào tạo / bồi dưỡng — nền vàng. */
export function TrainingOnChip({ sx, ...rest }: Props) {
  const color = '#a16207';
  const main = '#eab308';

  return (
    <Chip
      size="small"
      label="Đang đào tạo"
      variant="outlined"
      sx={{
        height: 24,
        fontSize: '0.72rem',
        fontWeight: 600,
        letterSpacing: '0.02em',
        color,
        bgcolor: alpha(main, 0.18),
        borderColor: alpha(main, 0.45),
        borderRadius: '6px',
        boxShadow: 'none',
        '& .MuiChip-label': {
          px: 1.1,
          py: 0,
        },
        ...sx,
      }}
      {...rest}
    />
  );
}
