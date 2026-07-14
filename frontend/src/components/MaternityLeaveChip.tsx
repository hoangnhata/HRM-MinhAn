import { Chip, type ChipProps } from '@mui/material';
import { alpha } from '@mui/material/styles';

type Props = Omit<ChipProps, 'label' | 'color' | 'variant'>;

/** Chip nghỉ thai sản — tông hồng tím, đồng bộ với cột tham gia BHXH. */
export function MaternityLeaveChip({ sx, ...rest }: Props) {
  const color = '#9d174d';
  const main = '#db2777';

  return (
    <Chip
      size="small"
      label="Nghỉ thai sản"
      variant="outlined"
      sx={{
        height: 24,
        fontSize: '0.72rem',
        fontWeight: 600,
        letterSpacing: '0.02em',
        color,
        bgcolor: alpha(main, 0.1),
        borderColor: alpha(main, 0.32),
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
