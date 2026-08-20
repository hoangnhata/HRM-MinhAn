import SyncOutlinedIcon from '@mui/icons-material/SyncOutlined';
import SwapHorizOutlinedIcon from '@mui/icons-material/SwapHorizOutlined';
import EventNoteOutlinedIcon from '@mui/icons-material/EventNoteOutlined';
import { Box, Chip, Stack, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import {
  attendanceNoteKindLabel,
  parseAttendanceNotes,
  type AttendanceNoteKind,
  type ParsedAttendanceNote,
} from '../../utils/attendanceNotes';

function kindAccent(kind: AttendanceNoteKind, primary: string, info: string, warning: string, success: string) {
  switch (kind) {
    case 'deployment_ot':
    case 'deployment_inside':
      return '#0f766e';
    case 'sync':
      return info;
    case 'leave':
    case 'unpaid':
    case 'business_trip':
      return warning;
    case 'explanation':
    case 'update':
      return primary;
    default:
      return success;
  }
}

function KindIcon({ kind }: { kind: AttendanceNoteKind }) {
  const sx = { fontSize: 16 };
  if (kind === 'sync') return <SyncOutlinedIcon sx={sx} />;
  if (kind === 'deployment_ot' || kind === 'deployment_inside') return <SwapHorizOutlinedIcon sx={sx} />;
  return <EventNoteOutlinedIcon sx={sx} />;
}

function NoteItem({ item }: { item: ParsedAttendanceNote }) {
  const theme = useTheme();
  const accent = kindAccent(
    item.kind,
    theme.palette.primary.main,
    theme.palette.info.main,
    theme.palette.warning.dark,
    theme.palette.success.main,
  );

  return (
    <Box
      sx={{
        p: 1.25,
        borderRadius: 2,
        bgcolor: alpha(accent, 0.05),
        border: `1px solid ${alpha(accent, 0.16)}`,
      }}
    >
      <Stack direction="row" spacing={1} alignItems="flex-start">
        <Box
          sx={{
            mt: 0.15,
            width: 26,
            height: 26,
            borderRadius: 1.25,
            display: 'grid',
            placeItems: 'center',
            bgcolor: alpha(accent, 0.12),
            color: accent,
            flexShrink: 0,
          }}
        >
          <KindIcon kind={item.kind} />
        </Box>
        <Box sx={{ minWidth: 0, flex: 1 }}>
          <Stack direction="row" spacing={0.75} alignItems="center" flexWrap="wrap" useFlexGap sx={{ mb: 0.35 }}>
            <Typography variant="body2" fontWeight={800} color={accent} sx={{ lineHeight: 1.3 }}>
              {item.title}
            </Typography>
            <Chip
              size="small"
              label={attendanceNoteKindLabel(item.kind)}
              sx={{
                height: 20,
                fontSize: '0.65rem',
                fontWeight: 700,
                bgcolor: alpha(accent, 0.1),
                color: accent,
                '& .MuiChip-label': { px: 0.75 },
              }}
            />
            {item.ref && (
              <Chip
                size="small"
                variant="outlined"
                label={item.ref}
                sx={{
                  height: 20,
                  fontSize: '0.65rem',
                  fontWeight: 700,
                  borderColor: alpha(accent, 0.28),
                  color: 'text.secondary',
                  '& .MuiChip-label': { px: 0.75 },
                }}
              />
            )}
            {(item.kind === 'deployment_ot' || item.kind === 'deployment_inside') && !item.approved && (
              <Chip
                size="small"
                label="Không tính công"
                sx={{
                  height: 20,
                  fontSize: '0.65rem',
                  fontWeight: 700,
                  bgcolor: alpha(theme.palette.warning.main, 0.12),
                  color: theme.palette.warning.dark,
                  '& .MuiChip-label': { px: 0.75 },
                }}
              />
            )}
          </Stack>

          {(item.timeRange || item.hoursLine) && (
            <Typography variant="body2" fontWeight={700} sx={{ lineHeight: 1.45, mb: item.breakdown || item.reason ? 0.35 : 0 }}>
              {[item.timeRange, item.hoursLine].filter(Boolean).join(' · ')}
            </Typography>
          )}

          {item.breakdown && (
            <Typography variant="caption" color="text.secondary" display="block" sx={{ lineHeight: 1.4, mb: item.reason ? 0.35 : 0 }}>
              {item.breakdown}
            </Typography>
          )}

          {item.reason && (
            <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.45 }}>
              {item.reason}
            </Typography>
          )}
        </Box>
      </Stack>
    </Box>
  );
}

/** Khối ghi chú ngày công — tách từng mục, bố cục chuẩn. */
export function AttendanceNoteBlock({ note }: { note?: string | null }) {
  const items = parseAttendanceNotes(note);
  if (!items.length) return null;

  return (
    <Box sx={{ width: '100%', mt: 0.5 }}>
      <Typography variant="body2" color="text.secondary" fontWeight={700} sx={{ mb: 0.85 }}>
        Ghi chú
      </Typography>
      <Stack spacing={0.85}>
        {items.map((item, i) => (
          <NoteItem key={`${item.kind}-${i}-${item.ref || item.title}`} item={item} />
        ))}
      </Stack>
    </Box>
  );
}

/** Phiên bản gọn cho ô bảng — mỗi mục một dòng. */
export function AttendanceNoteCompact({ note }: { note?: string | null }) {
  const items = parseAttendanceNotes(note);
  if (!items.length) {
    return (
      <Typography variant="body2" color="text.secondary">
        —
      </Typography>
    );
  }
  return (
    <Stack spacing={0.35} sx={{ minWidth: 160, maxWidth: 320 }}>
      {items.map((item, i) => (
        <Typography
          key={`${item.kind}-${i}`}
          variant="caption"
          title={item.raw}
          sx={{
            display: 'block',
            lineHeight: 1.35,
            color: 'text.primary',
            whiteSpace: 'normal',
          }}
        >
          <Box component="span" fontWeight={700}>
            {item.title}
          </Box>
          {item.timeRange ? ` · ${item.timeRange}` : ''}
          {item.reason ? ` — ${item.reason}` : ''}
          {item.ref ? ` [${item.ref}]` : ''}
        </Typography>
      ))}
    </Stack>
  );
}
