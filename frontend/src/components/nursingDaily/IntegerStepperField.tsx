import AddIcon from '@mui/icons-material/Add';
import RemoveIcon from '@mui/icons-material/Remove';
import { Box, IconButton, Stack, TextField, Typography } from '@mui/material';
import { alpha } from '@mui/material/styles';

type Props = {
  label: string;
  value: number;
  onChange: (value: number) => void;
  accent?: string;
  hint?: string;
  disabled?: boolean;
};

/** Ô số tự nhiên gọn — nhãn trên, [−] số [+] dưới. */
export function IntegerStepperField({
  label,
  value,
  onChange,
  accent = '#0f766e',
  hint,
  disabled = false,
}: Props) {
  const safe = Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0;
  const hasValue = safe > 0;

  function set(next: number) {
    onChange(Math.max(0, Math.floor(next)));
  }

  return (
    <Box
      sx={{
        px: 1.35,
        py: 1.1,
        borderRadius: 2,
        bgcolor: hasValue ? alpha(accent, 0.045) : '#fafbfc',
        border: `1px solid ${hasValue ? alpha(accent, 0.22) : alpha('#0f172a', 0.07)}`,
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        gap: 0.75,
        transition: 'border-color 0.15s ease, background-color 0.15s ease, box-shadow 0.15s ease',
        '&:focus-within': {
          borderColor: alpha(accent, 0.45),
          bgcolor: '#fff',
          boxShadow: `0 0 0 3px ${alpha(accent, 0.1)}`,
        },
      }}
    >
      <Typography
        variant="caption"
        fontWeight={700}
        sx={{
          lineHeight: 1.35,
          color: 'text.secondary',
          letterSpacing: '0.01em',
          minHeight: 34,
          display: '-webkit-box',
          WebkitLineClamp: 2,
          WebkitBoxOrient: 'vertical',
          overflow: 'hidden',
        }}
      >
        {label}
      </Typography>
      <Stack direction="row" spacing={0.5} alignItems="center">
        <IconButton
          size="small"
          disabled={disabled || safe <= 0}
          onClick={() => set(safe - 1)}
          aria-label={`Giảm ${label}`}
          sx={{
            width: 30,
            height: 30,
            borderRadius: '50%',
            color: accent,
            bgcolor: '#fff',
            border: `1px solid ${alpha(accent, 0.2)}`,
            '&:hover': { bgcolor: alpha(accent, 0.08) },
            '&.Mui-disabled': { borderColor: alpha('#0f172a', 0.08) },
          }}
        >
          <RemoveIcon sx={{ fontSize: 16 }} />
        </IconButton>
        <TextField
          size="small"
          value={String(safe)}
          disabled={disabled}
          inputProps={{
            inputMode: 'numeric',
            pattern: '[0-9]*',
            style: {
              textAlign: 'center',
              fontWeight: 800,
              fontSize: '1.125rem',
              letterSpacing: '-0.03em',
              color: hasValue ? accent : undefined,
            },
            'aria-label': label,
          }}
          onChange={(e) => {
            const raw = e.target.value.replace(/\D/g, '');
            if (raw === '') {
              set(0);
              return;
            }
            set(Number(raw));
          }}
          sx={{
            flex: 1,
            '& .MuiOutlinedInput-root': {
              height: 34,
              borderRadius: 1.5,
              bgcolor: '#fff',
            },
            '& .MuiOutlinedInput-notchedOutline': {
              borderColor: alpha('#0f172a', 0.08),
            },
            '& .Mui-focused .MuiOutlinedInput-notchedOutline': {
              borderColor: alpha(accent, 0.45),
              borderWidth: 1,
            },
          }}
        />
        <IconButton
          size="small"
          disabled={disabled}
          onClick={() => set(safe + 1)}
          aria-label={`Tăng ${label}`}
          sx={{
            width: 30,
            height: 30,
            borderRadius: '50%',
            color: '#fff',
            bgcolor: accent,
            boxShadow: `0 2px 6px ${alpha(accent, 0.28)}`,
            '&:hover': { bgcolor: accent, filter: 'brightness(0.94)' },
          }}
        >
          <AddIcon sx={{ fontSize: 16 }} />
        </IconButton>
      </Stack>
      {hint ? (
        <Typography variant="caption" color="text.secondary" sx={{ lineHeight: 1.35 }}>
          {hint}
        </Typography>
      ) : null}
    </Box>
  );
}
