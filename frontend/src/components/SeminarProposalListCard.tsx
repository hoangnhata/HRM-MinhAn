import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import { Box, Chip, Paper, Stack, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import * as sps from '../services/seminarProposalService';

type Props = {
  proposal: sps.SeminarProposal;
  onClick: () => void;
};

export function SeminarProposalListCard({ proposal, onClick }: Props) {
  const theme = useTheme();
  const accent = '#0e7490';
  const payLabel =
    proposal.withPay != null
      ? proposal.withPay
        ? ' · Có công'
        : ' · Không công'
      : '';

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
            <GroupsOutlinedIcon sx={{ fontSize: 20 }} />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Stack direction="row" alignItems="flex-start" justifyContent="space-between" spacing={1}>
              <Box sx={{ minWidth: 0 }}>
                <Typography variant="body2" fontWeight={800} noWrap>
                  Hội thảo · {proposal.employeeName}
                </Typography>
                <Typography variant="caption" color="text.secondary" display="block" noWrap sx={{ mt: 0.25 }}>
                  {proposal.employeeCode || '—'} · {proposal.proposingDepartment || '—'}
                </Typography>
              </Box>
              <Chip
                size="small"
                label={`${sps.SEMINAR_STATUS_LABEL[proposal.status] || proposal.status}${payLabel}`}
                color={sps.seminarStatusColor(proposal.status)}
                variant="outlined"
                sx={{
                  height: 24,
                  flexShrink: 0,
                  fontWeight: 600,
                  '& .MuiChip-label': { px: 0.85, fontSize: '0.7rem' },
                }}
              />
            </Stack>
            <Typography variant="body2" noWrap title={proposal.seminarName} sx={{ mt: 1, fontWeight: 700 }}>
              {proposal.seminarName}
            </Typography>
            <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.5 }}>
              {proposal.location} · {proposal.plannedPeriod || sps.formatSeminarDate(proposal.startDate)}
            </Typography>
          </Box>
          <ChevronRightIcon sx={{ alignSelf: 'center', color: 'text.disabled', flexShrink: 0 }} />
        </Stack>
      </Stack>
    </Paper>
  );
}
