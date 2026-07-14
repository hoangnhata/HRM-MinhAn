import CalendarMonthOutlinedIcon from '@mui/icons-material/CalendarMonthOutlined';
import CloseIcon from '@mui/icons-material/Close';
import HowToRegOutlinedIcon from '@mui/icons-material/HowToRegOutlined';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import PersonOutlineIcon from '@mui/icons-material/PersonOutline';
import PlaylistAddIcon from '@mui/icons-material/PlaylistAdd';
import {
  Box,
  Chip,
  Dialog,
  DialogContent,
  IconButton,
  Stack,
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { CongHoSupplementForm } from './CongHoSupplementForm';
import { DutyShiftDialog } from './DutyShiftDialog';
import { QuangTrungSupplementForm } from './QuangTrungSupplementForm';
import type { DutyShiftEntry } from '../../services/attendanceService';
import * as att from '../../services/attendanceService';

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved?: () => void;
  employeeId: number;
  employeeName: string;
  workDate: string;
  existingDuty?: DutyShiftEntry | null;
  attendanceRow?: Record<string, unknown> | null;
  /** 0 = trực, 1 = QT, 2 = công hộ */
  initialTab?: 0 | 1 | 2;
};

const ACCENT = '#5b4bb4';

export function WorkSupplementDialog({
  open,
  onClose,
  onSaved,
  employeeId,
  employeeName,
  workDate,
  existingDuty,
  attendanceRow,
  initialTab,
}: Props) {
  const hasQuangTrung = att.isQuangTrungRow(attendanceRow);
  const hasCongHo = att.isCongHoRow(attendanceRow);
  const [tab, setTab] = useState(0);

  useEffect(() => {
    if (!open) return;
    if (initialTab != null) {
      setTab(initialTab);
    } else if (hasCongHo && !existingDuty && !hasQuangTrung) {
      setTab(2);
    } else if (hasQuangTrung && !existingDuty) {
      setTab(1);
    } else {
      setTab(0);
    }
  }, [open, workDate, hasQuangTrung, hasCongHo, existingDuty, initialTab]);

  const dateLabel = (() => {
    const d = new Date(`${workDate}T12:00:00`);
    return Number.isNaN(d.getTime())
      ? workDate
      : d.toLocaleDateString('vi-VN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  })();

  function handleSaved() {
    onSaved?.();
    onClose();
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="md"
      fullWidth
      PaperProps={{
        sx: {
          borderRadius: 3,
          overflow: 'hidden',
          boxShadow: `0 24px 48px ${alpha('#0f172a', 0.14)}`,
        },
      }}
    >
      <Box
        sx={{
          px: 2.5,
          pt: 2.5,
          pb: 1.5,
          background: `linear-gradient(135deg, ${alpha(ACCENT, 0.16)} 0%, ${alpha(ACCENT, 0.04)} 100%)`,
          borderBottom: `1px solid ${alpha(ACCENT, 0.12)}`,
        }}
      >
        <Stack direction="row" spacing={2} alignItems="flex-start">
          <Box
            sx={{
              width: 48,
              height: 48,
              borderRadius: 2.5,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(ACCENT, 0.14),
              color: ACCENT,
              flexShrink: 0,
            }}
          >
            <PlaylistAddIcon />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0, pt: 0.25 }}>
            <Typography variant="overline" sx={{ color: ACCENT, fontWeight: 700, letterSpacing: '0.08em' }}>
              Bổ sung công
            </Typography>
            <Typography variant="h6" fontWeight={800} lineHeight={1.25}>
              Công trực · Quang Trung · Công hộ
            </Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mt: 1.25 }}>
              <Chip
                size="small"
                icon={<PersonOutlineIcon sx={{ fontSize: '16px !important' }} />}
                label={employeeName}
                sx={{ bgcolor: alpha('#fff', 0.72), fontWeight: 600 }}
              />
              <Chip
                size="small"
                icon={<CalendarMonthOutlinedIcon sx={{ fontSize: '16px !important' }} />}
                label={dateLabel}
                sx={{ bgcolor: alpha('#fff', 0.72), fontWeight: 500 }}
              />
              {existingDuty && (
                <Chip size="small" label="Có ca trực" color="secondary" variant="outlined" />
              )}
              {hasQuangTrung && (
                <Chip size="small" label="Có công QT" color="success" variant="outlined" />
              )}
              {hasCongHo && (
                <Chip size="small" label="Có công hộ" color="info" variant="outlined" />
              )}
            </Stack>
          </Box>
          <IconButton
            size="small"
            onClick={onClose}
            sx={{ mt: -0.5, mr: -0.5, color: 'text.secondary' }}
            aria-label="Đóng"
          >
            <CloseIcon fontSize="small" />
          </IconButton>
        </Stack>

        <Tabs
          value={tab}
          onChange={(_, v) => setTab(v)}
          variant="scrollable"
          scrollButtons="auto"
          sx={{
            mt: 2,
            minHeight: 40,
            '& .MuiTab-root': { minHeight: 40, textTransform: 'none', fontWeight: 600 },
          }}
        >
          <Tab icon={<NightsStayIcon sx={{ fontSize: 18 }} />} iconPosition="start" label="Công trực" />
          <Tab
            icon={<LocationOnOutlinedIcon sx={{ fontSize: 18 }} />}
            iconPosition="start"
            label={hasQuangTrung ? 'Công Quang Trung (sửa)' : 'Công Quang Trung'}
          />
          <Tab
            icon={<HowToRegOutlinedIcon sx={{ fontSize: 18 }} />}
            iconPosition="start"
            label={hasCongHo ? 'Công hộ (sửa)' : 'Công hộ'}
          />
        </Tabs>
      </Box>

      <DialogContent sx={{ px: 2.5, py: 2.5 }}>
        {tab === 0 ? (
          <DutyShiftDialog
            embedded
            open={open}
            onClose={onClose}
            onSaved={handleSaved}
            employeeId={employeeId}
            employeeName={employeeName}
            workDate={workDate}
            existing={existingDuty ?? null}
          />
        ) : tab === 1 ? (
          <QuangTrungSupplementForm
            open={open}
            employeeId={employeeId}
            employeeName={employeeName}
            workDate={workDate}
            onClose={onClose}
            onSaved={handleSaved}
          />
        ) : (
          <CongHoSupplementForm
            open={open}
            employeeId={employeeId}
            employeeName={employeeName}
            workDate={workDate}
            onClose={onClose}
            onSaved={handleSaved}
          />
        )}
      </DialogContent>
    </Dialog>
  );
}
