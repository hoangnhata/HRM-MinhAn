import NightsStayIcon from '@mui/icons-material/NightsStay';
import { Chip, Paper, Stack, Typography } from '@mui/material';
import { alpha } from '@mui/material/styles';
import * as mda from '../services/mainDutyAuthorizationService';

type Props = {
  row: mda.MainDutyAuthorization;
  onClick?: () => void;
};

export function MainDutyAuthorizationListCard({ row, onClick }: Props) {
  const accent = '#5b4bb4';

  return (
    <Paper
      elevation={0}
      onClick={onClick}
      sx={{
        p: 2,
        borderRadius: 2.5,
        cursor: onClick ? 'pointer' : 'default',
        border: `1px solid ${alpha(accent, 0.14)}`,
        bgcolor: alpha(accent, 0.03),
        transition: 'transform 0.16s, box-shadow 0.16s',
        '&:hover': onClick
          ? {
              transform: 'translateY(-1px)',
              boxShadow: `0 8px 22px ${alpha(accent, 0.12)}`,
            }
          : undefined,
      }}
    >
      <Stack direction="row" spacing={1.5} alignItems="flex-start">
        <Stack
          sx={{
            width: 40,
            height: 40,
            borderRadius: 2,
            bgcolor: alpha(accent, 0.12),
            color: accent,
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <NightsStayIcon fontSize="small" />
        </Stack>
        <Stack spacing={0.75} sx={{ flex: 1, minWidth: 0 }}>
          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
            <Typography variant="subtitle2" fontWeight={800}>
              {row.employeeName}
            </Typography>
            <Chip
              size="small"
              label={row.formTypeLabel}
              sx={{ height: 22, fontSize: '0.7rem', fontWeight: 700 }}
            />
            <Chip
              size="small"
              color={mda.mainDutyStatusColor(row.status)}
              label={mda.MAIN_DUTY_STATUS_LABEL[row.status] ?? row.status}
              sx={{ height: 22, fontSize: '0.7rem', fontWeight: 700 }}
            />
          </Stack>
          <Typography variant="body2" color="text.secondary">
            Trực kèm: {row.accompanyingPeriod || `${mda.formatMainDutyDate(row.accompanyingFrom)} – ${mda.formatMainDutyDate(row.accompanyingTo)}`}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            Hiệu lực trực chính từ {mda.formatMainDutyDate(row.effectiveFrom)}
            {row.departmentName ? ` · ${row.departmentName}` : ''}
          </Typography>
        </Stack>
      </Stack>
    </Paper>
  );
}
