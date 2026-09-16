import { Box, Card, CardContent, Stack, Typography } from '@mui/material';
import { alpha } from '@mui/material/styles';
import type { ReactNode } from 'react';

const INK = '#0f172a';

export const MODULE_A_METRIC_TONES = {
  falls: '#0f766e',
  'pressure-ulcers': '#0369a1',
  'nurse-bed': '#0e7490',
  'id-mixup': '#7c3aed',
  medication: '#b45309',
  default: '#0f766e',
} as const;

type Props = {
  title: string;
  primary?: string | number | null;
  secondary?: string | null;
  icon?: ReactNode;
  tone?: string;
  compact?: boolean;
};

export function ModuleAStatCard({
  title,
  primary,
  secondary,
  icon,
  tone = MODULE_A_METRIC_TONES.default,
  compact = false,
}: Props) {
  return (
    <Card
      elevation={0}
      sx={{
        position: 'relative',
        height: '100%',
        borderRadius: compact ? 2.25 : 2.75,
        overflow: 'hidden',
        border: `1px solid ${alpha(tone, 0.16)}`,
        background: `linear-gradient(155deg, ${alpha(tone, 0.1)} 0%, ${alpha(tone, 0.02)} 42%, #fff 100%)`,
        boxShadow: `0 1px 2px ${alpha(INK, 0.03)}, 0 8px 22px ${alpha(INK, 0.04)}`,
        transition: 'transform 0.15s ease, box-shadow 0.15s ease',
        '&:hover': {
          transform: 'translateY(-2px)',
          boxShadow: `0 4px 16px ${alpha(tone, 0.14)}`,
        },
        '&::before': {
          content: '""',
          position: 'absolute',
          left: 0,
          top: 0,
          bottom: 0,
          width: 3.5,
          bgcolor: tone,
        },
      }}
    >
      <CardContent
        sx={{
          py: compact ? 1.2 : 1.5,
          px: compact ? 1.35 : 1.6,
          pl: compact ? 1.6 : 1.85,
          '&:last-child': { pb: compact ? 1.2 : 1.5 },
        }}
      >
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
          <Typography
            variant="caption"
            fontWeight={800}
            sx={{
              color: alpha(INK, 0.55),
              textTransform: 'uppercase',
              letterSpacing: '0.06em',
              fontSize: compact ? '0.65rem' : '0.68rem',
              lineHeight: 1.3,
            }}
          >
            {title}
          </Typography>
          {icon ? (
            <Box
              sx={{
                width: compact ? 28 : 32,
                height: compact ? 28 : 32,
                borderRadius: 1.75,
                display: 'grid',
                placeItems: 'center',
                flexShrink: 0,
                bgcolor: alpha(tone, 0.12),
                color: tone,
                border: `1px solid ${alpha(tone, 0.16)}`,
                '& .MuiSvgIcon-root': { fontSize: compact ? 16 : 18 },
              }}
            >
              {icon}
            </Box>
          ) : null}
        </Stack>
        <Typography
          variant="h6"
          fontWeight={850}
          sx={{
            color: tone,
            lineHeight: 1.25,
            mt: 0.85,
            letterSpacing: '-0.03em',
            fontSize: compact
              ? { xs: '0.98rem', md: '1.05rem' }
              : { xs: '1.05rem', md: '1.15rem' },
          }}
        >
          {primary ?? '—'}
        </Typography>
        {secondary ? (
          <Typography
            variant="caption"
            fontWeight={650}
            sx={{
              display: 'block',
              mt: 0.55,
              color: alpha(INK, 0.58),
              lineHeight: 1.4,
            }}
          >
            {secondary}
          </Typography>
        ) : icon ? (
          <Typography variant="caption" sx={{ display: 'block', mt: 0.55, visibility: 'hidden' }}>
            —
          </Typography>
        ) : null}
      </CardContent>
    </Card>
  );
}
