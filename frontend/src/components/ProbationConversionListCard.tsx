import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import HowToRegIcon from '@mui/icons-material/HowToReg';
import { Box, Chip, Paper, Stack, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import * as pcs from '../services/probationConversionService';

type Props = {
  conversion: pcs.ProbationConversion;
  onClick: () => void;
};

export function ProbationConversionListCard({ conversion, onClick }: Props) {
  const theme = useTheme();
  const accent = '#15803d';

  return (
    <Paper
      variant="outlined"
      onClick={onClick}
      sx={{
        height: '100%',
        borderRadius: 2.5,
        cursor: 'pointer',
        overflow: 'hidden',
        borderColor: alpha(theme.palette.divider, 0.95),
        transition: 'border-color 0.18s, box-shadow 0.18s, transform 0.18s',
        '&:hover': {
          borderColor: alpha(accent, 0.45),
          boxShadow: `0 10px 28px ${alpha('#0f172a', 0.08)}`,
          transform: 'translateY(-2px)',
        },
      }}
    >
      <Stack direction="row" alignItems="stretch" sx={{ height: '100%' }}>
        <Box sx={{ width: 4, bgcolor: accent, flexShrink: 0 }} />
        <Stack direction="row" spacing={1.5} sx={{ p: 1.75, flex: 1, minWidth: 0 }}>
          <Box
            sx={{
              width: 42,
              height: 42,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(accent, 0.1),
              color: accent,
              flexShrink: 0,
            }}
          >
            <HowToRegIcon sx={{ fontSize: 20 }} />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Stack direction="row" alignItems="flex-start" justifyContent="space-between" spacing={1}>
              <Box sx={{ minWidth: 0 }}>
                <Typography variant="body2" fontWeight={800} noWrap>
                  Chính thức · {conversion.employeeName}
                </Typography>
                <Typography variant="caption" color="text.secondary" display="block" noWrap sx={{ mt: 0.25 }}>
                  {conversion.employeeCode || '—'} · {conversion.departmentName || '—'} · Người lập:{' '}
                  {conversion.requestedByUsername || '—'}
                </Typography>
              </Box>
              <Chip
                size="small"
                label={pcs.CONVERSION_STATUS_LABEL[conversion.status] || conversion.status}
                color={pcs.conversionStatusColor(conversion.status)}
                variant="outlined"
                sx={{
                  height: 24,
                  flexShrink: 0,
                  fontWeight: 600,
                  '& .MuiChip-label': { px: 0.85, fontSize: '0.7rem' },
                }}
              />
            </Stack>

            <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 1 }}>
              Ngày lên chính thức {pcs.formatConversionDate(conversion.officialDate)}
            </Typography>

            <Typography variant="body2" noWrap title={conversion.reason} sx={{ mt: 0.75 }}>
              {conversion.reason}
            </Typography>

            <Typography
              component="span"
              variant="caption"
              sx={{
                mt: 1.25,
                color: accent,
                fontWeight: 700,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 0.25,
              }}
            >
              Xem chi tiết
              <ChevronRightIcon sx={{ fontSize: 16 }} />
            </Typography>
          </Box>
        </Stack>
      </Stack>
    </Paper>
  );
}
