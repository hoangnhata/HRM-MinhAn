import BeachAccessOutlinedIcon from '@mui/icons-material/BeachAccessOutlined';
import BusinessCenterOutlinedIcon from '@mui/icons-material/BusinessCenterOutlined';
import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import DescriptionOutlinedIcon from '@mui/icons-material/DescriptionOutlined';
import EditCalendarOutlinedIcon from '@mui/icons-material/EditCalendarOutlined';
import PlaceOutlinedIcon from '@mui/icons-material/PlaceOutlined';
import SwapHorizOutlinedIcon from '@mui/icons-material/SwapHorizOutlined';
import { Box, Chip, Paper, Stack, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import * as att from '../../services/attendanceService';

type Props = {
  request: att.WorkRequest;
  onClick: () => void;
  showEmployee?: boolean;
};

function requestAccent(type: att.WorkRequest['requestType'], theme: ReturnType<typeof useTheme>) {
  if (type === 'EXPLANATION') return theme.palette.info.main;
  if (type === 'LEAVE') return theme.palette.secondary.main;
  if (type === 'BUSINESS_TRIP') return theme.palette.warning.dark;
  if (type === 'DEPLOYMENT') return '#0f766e';
  return theme.palette.primary.main;
}

export function WorkRequestListCard({ request, onClick, showEmployee = false }: Props) {
  const theme = useTheme();
  const accent = requestAccent(request.requestType, theme);
  const isRanged = request.requestType === 'LEAVE' || request.requestType === 'BUSINESS_TRIP';
  const times =
    request.requestType === 'UPDATE'
      ? att.formatRequestedTimes(request)
      : request.requestType === 'DEPLOYMENT' && request.requestedStart && request.requestedEnd
        ? `${request.requestedStart.slice(0, 5)}–${request.requestedEnd.slice(0, 5)}`
        : isRanged
          ? att.formatLeaveRange(request)
          : att.formatExplanationTimes(request);
  const dayCount =
    request.requestType === 'LEAVE'
      ? (request.leaveDays ?? 1)
      : request.requestType === 'BUSINESS_TRIP'
        ? (request.tripDays ?? 1)
        : null;

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
      <Stack direction="row" alignItems="stretch" spacing={0} sx={{ height: '100%' }}>
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
            {request.requestType === 'EXPLANATION' ? (
              <DescriptionOutlinedIcon sx={{ fontSize: 20 }} />
            ) : request.requestType === 'LEAVE' ? (
              <BeachAccessOutlinedIcon sx={{ fontSize: 20 }} />
            ) : request.requestType === 'BUSINESS_TRIP' ? (
              <BusinessCenterOutlinedIcon sx={{ fontSize: 20 }} />
            ) : request.requestType === 'DEPLOYMENT' ? (
              <SwapHorizOutlinedIcon sx={{ fontSize: 20 }} />
            ) : (
              <EditCalendarOutlinedIcon sx={{ fontSize: 20 }} />
            )}
          </Box>

          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Stack direction="row" alignItems="flex-start" justifyContent="space-between" spacing={1}>
              <Box sx={{ minWidth: 0 }}>
                <Typography variant="body2" fontWeight={800} noWrap>
                  {att.requestTypeLabel(request.requestType)}
                  {showEmployee
                    ? ` · ${request.employeeName}`
                    : dayCount != null
                      ? ` · ${dayCount} ngày`
                      : ` · ${att.formatWorkDate(request.workDate)}`}
                </Typography>
                <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.25 }}>
                  {request.department}
                </Typography>
              </Box>
              <Chip
                size="small"
                label={att.requestStatusLabel(request.status, request.requestType)}
                color={att.requestStatusColor(request.status)}
                variant="outlined"
                sx={{ height: 24, flexShrink: 0, fontWeight: 600, '& .MuiChip-label': { px: 0.85, fontSize: '0.7rem' } }}
              />
            </Stack>

            <Stack direction="row" spacing={0.75} alignItems="center" flexWrap="wrap" useFlexGap sx={{ mt: 1 }}>
              {request.requestType === 'UPDATE' && request.updateKind && (
                <Chip
                  size="small"
                  label={att.updateKindLabel(request.updateKind)}
                  sx={{ height: 22, bgcolor: alpha(accent, 0.08), '& .MuiChip-label': { px: 0.85, fontSize: '0.68rem' } }}
                />
              )}
              {isRanged && (
                <Chip
                  size="small"
                  label={att.formatLeaveRange(request) || att.formatWorkDate(request.workDate)}
                  sx={{ height: 22, bgcolor: alpha(accent, 0.08), '& .MuiChip-label': { px: 0.85, fontSize: '0.68rem' } }}
                />
              )}
              {request.requestType === 'BUSINESS_TRIP' && request.location && (
                <Chip
                  size="small"
                  icon={<PlaceOutlinedIcon sx={{ fontSize: '14px !important' }} />}
                  label={request.location}
                  sx={{
                    height: 22,
                    maxWidth: '100%',
                    bgcolor: alpha(accent, 0.08),
                    '& .MuiChip-label': { px: 0.85, fontSize: '0.68rem' },
                    '& .MuiChip-icon': { ml: 0.5, color: accent },
                  }}
                />
              )}
              {request.requestType === 'DEPLOYMENT' && (
                <Chip
                  size="small"
                  label={
                    request.deploymentCreditedHours != null
                      ? `×1,5 · ${request.deploymentCreditedHours}h công`
                      : times || 'Điều động'
                  }
                  sx={{ height: 22, bgcolor: alpha(accent, 0.08), '& .MuiChip-label': { px: 0.85, fontSize: '0.68rem' } }}
                />
              )}
            </Stack>

            <Typography
              variant="body2"
              sx={{
                mt: 1,
                color: 'text.primary',
                display: '-webkit-box',
                WebkitLineClamp: 2,
                WebkitBoxOrient: 'vertical',
                overflow: 'hidden',
                lineHeight: 1.5,
              }}
            >
              {request.reason}
            </Typography>

            {times && !isRanged && request.requestType !== 'DEPLOYMENT' && (
              <Typography variant="caption" color="text.secondary" display="block" noWrap sx={{ mt: 0.75 }}>
                {times}
              </Typography>
            )}

            <Typography
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
