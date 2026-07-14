import { Box, Button, Stack, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useRef, useState } from 'react';

type ClockMode = 'hour' | 'minute';

type Props = {
  value: string;
  minuteStep?: number;
  onApply: (value: string) => void;
  onCancel: () => void;
};

const CLOCK_SIZE = 220;
const CENTER = CLOCK_SIZE / 2;
const LABEL_RADIUS = 82;
const HAND_RADIUS = 68;

function parseTime(value: string): { hour: number; minute: number } {
  if (!value) return { hour: 7, minute: 0 };
  const [h, m] = value.split(':').map(Number);
  return {
    hour: Number.isFinite(h) ? Math.min(23, Math.max(0, h)) : 7,
    minute: Number.isFinite(m) ? Math.min(59, Math.max(0, m)) : 0,
  };
}

function snapMinute(minute: number, step: number) {
  const snapped = Math.round(minute / step) * step;
  return Math.min(59, Math.max(0, snapped));
}

function clampHour(h: number) {
  return Math.min(23, Math.max(0, h));
}

function clampMinute(m: number) {
  return Math.min(59, Math.max(0, m));
}

const digitInputSx = (active: boolean, primary: string) => ({
  width: 72,
  border: 'none',
  outline: 'none',
  textAlign: 'center' as const,
  fontWeight: 800,
  fontSize: '1.75rem',
  letterSpacing: '-0.03em',
  fontFamily: 'inherit',
  borderRadius: 2,
  px: 1.5,
  py: 0.75,
  bgcolor: active ? alpha(primary, 0.14) : 'transparent',
  color: active ? primary : 'inherit',
  transition: 'background-color 0.15s',
  '&:focus': {
    bgcolor: alpha(primary, 0.14),
    color: primary,
  },
  // Hide spin buttons on number inputs
  MozAppearance: 'textfield' as const,
  '&::-webkit-outer-spin-button, &::-webkit-inner-spin-button': {
    WebkitAppearance: 'none',
    margin: 0,
  },
});

function polarToXY(angleDeg: number, radius: number) {
  const rad = ((angleDeg - 90) * Math.PI) / 180;
  return {
    x: CENTER + radius * Math.cos(rad),
    y: CENTER + radius * Math.sin(rad),
  };
}

const WORK_HOURS = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17];

function hourToAngle(h: number) {
  const idx = WORK_HOURS.indexOf(h);
  if (idx >= 0) return (idx / 12) * 360;
  return (h / 24) * 360;
}
function buildHourMarkers() {
  return WORK_HOURS.map((hour, index) => {
    const angle = (index / 12) * 360;
    const pos = polarToXY(angle, LABEL_RADIUS);
    return { hour, label: String(hour), ...pos, angle };
  });
}

function buildMinuteMarkers(step: number) {
  const values: number[] = [];
  for (let m = 0; m < 60; m += step) values.push(m);
  return values.map((minute) => {
    const angle = (minute / 60) * 360;
    const pos = polarToXY(angle, LABEL_RADIUS);
    return { minute, label: String(minute).padStart(2, '0'), ...pos, angle };
  });
}

function nearestHourFromPoint(x: number, y: number) {
  const dx = x - CENTER;
  const dy = y - CENTER;
  let angle = (Math.atan2(dy, dx) * 180) / Math.PI + 90;
  if (angle < 0) angle += 360;
  const slot = Math.round((angle / 360) * 12) % 12;
  return WORK_HOURS[slot] ?? WORK_HOURS[0];
}

function nearestMinuteFromPoint(x: number, y: number, step: number) {
  const dx = x - CENTER;
  const dy = y - CENTER;
  let angle = (Math.atan2(dy, dx) * 180) / Math.PI + 90;
  if (angle < 0) angle += 360;
  const raw = Math.round((angle / 360) * 60) % 60;
  return snapMinute(raw, step);
}

export function ClockTimePickerPanel({ value, minuteStep = 5, onApply, onCancel }: Props) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;
  const parsed = parseTime(value);

  const [hour, setHour] = useState(parsed.hour);
  const [minute, setMinute] = useState(clampMinute(parsed.minute));
  const [mode, setMode] = useState<ClockMode>('hour');
  const [hourDraft, setHourDraft] = useState('');
  const [minuteDraft, setMinuteDraft] = useState('');
  const hourRef = useRef<HTMLInputElement>(null);
  const minuteRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const p = parseTime(value);
    setHour(p.hour);
    setMinute(clampMinute(p.minute));
    setHourDraft('');
    setMinuteDraft('');
    setMode('hour');
  }, [value, minuteStep]);

  useEffect(() => {
    if (mode === 'hour') hourRef.current?.focus();
    else minuteRef.current?.focus();
  }, [mode]);

  const hourShown = hourDraft !== '' ? hourDraft : String(hour).padStart(2, '0');
  const minuteShown = minuteDraft !== '' ? minuteDraft : String(minute).padStart(2, '0');

  function clearDrafts() {
    setHourDraft('');
    setMinuteDraft('');
  }

  function selectHourFromClock(h: number) {
    setHour(h);
    clearDrafts();
    setMode('minute');
  }

  function selectMinuteFromClock(m: number) {
    setMinute(m);
    setMinuteDraft('');
  }

  const hourMarkers = useMemo(() => buildHourMarkers(), []);
  const minuteMarkers = useMemo(() => buildMinuteMarkers(minuteStep), [minuteStep]);

  const activeAngle = mode === 'hour' ? hourToAngle(hour) : (minute / 60) * 360;
  const handEnd = polarToXY(activeAngle, HAND_RADIUS);

  function handleClockClick(e: React.MouseEvent<SVGElement>) {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * CLOCK_SIZE;
    const y = ((e.clientY - rect.top) / rect.height) * CLOCK_SIZE;
    if (mode === 'hour') {
      selectHourFromClock(nearestHourFromPoint(x, y));
    } else {
      selectMinuteFromClock(nearestMinuteFromPoint(x, y, minuteStep));
    }
  }

  function apply() {
    onApply(`${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`);
  }

  function handleHourKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key >= '0' && e.key <= '9') {
      e.preventDefault();
      const d = e.key;
      if (hourDraft.length === 0) {
        const n = Number(d);
        if (n >= 3) {
          setHour(clampHour(n));
          clearDrafts();
          setMode('minute');
          return;
        }
        setHourDraft(d);
        setHour(n);
        return;
      }
      const h = clampHour(Number(hourDraft + d));
      setHour(h);
      clearDrafts();
      setMode('minute');
      return;
    }
    if (e.key === 'Backspace') {
      e.preventDefault();
      if (hourDraft.length > 0) {
        setHourDraft('');
        setHour(0);
      }
      return;
    }
    if (e.key === 'Enter') {
      e.preventDefault();
      if (hourDraft.length === 1) setHour(clampHour(Number(hourDraft)));
      clearDrafts();
      setMode('minute');
      return;
    }
    if (e.key === 'ArrowRight' || e.key === ':') {
      e.preventDefault();
      if (hourDraft.length === 1) setHour(clampHour(Number(hourDraft)));
      clearDrafts();
      setMode('minute');
    }
  }

  function handleMinuteKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key >= '0' && e.key <= '9') {
      e.preventDefault();
      const d = e.key;
      if (minuteDraft.length === 0) {
        const n = Number(d);
        if (n >= 6) {
          setMinute(clampMinute(n));
          setMinuteDraft('');
          return;
        }
        setMinuteDraft(d);
        setMinute(n);
        return;
      }
      const m = clampMinute(Number(minuteDraft + d));
      setMinute(m);
      setMinuteDraft('');
      return;
    }
    if (e.key === 'Backspace') {
      e.preventDefault();
      if (minuteDraft.length > 0) {
        setMinuteDraft('');
        setMinute(0);
      }
      return;
    }
    if (e.key === 'Enter') {
      e.preventDefault();
      if (minuteDraft.length === 1) {
        setMinute(clampMinute(Number(minuteDraft)));
      }
      setMinuteDraft('');
      apply();
      return;
    }
    if (e.key === 'ArrowLeft') {
      e.preventDefault();
      if (minuteDraft.length === 1) {
        setMinute(clampMinute(Number(minuteDraft)));
      }
      setMinuteDraft('');
      setMode('hour');
    }
  }

  const markers = mode === 'hour' ? hourMarkers : minuteMarkers;

  return (
    <Box sx={{ width: 280, p: 2 }}>
      <Typography variant="caption" color="text.secondary" fontWeight={600} sx={{ mb: 1.25, display: 'block' }}>
        Chọn giờ
      </Typography>

      <Stack direction="row" alignItems="center" justifyContent="center" spacing={0.75} sx={{ mb: 1.5 }}>
        <Box
          component="input"
          ref={hourRef}
          type="text"
          inputMode="numeric"
          readOnly={false}
          aria-label="Giờ"
          value={hourShown}
          onFocus={(e) => {
            setMode('hour');
            setHourDraft('');
            e.target.select();
          }}
          onClick={() => {
            setMode('hour');
            hourRef.current?.select();
          }}
          onKeyDown={handleHourKeyDown}
          onChange={() => {}}
          sx={digitInputSx(mode === 'hour', primary)}
        />
        <Typography variant="h4" fontWeight={300} color="text.secondary">
          :
        </Typography>
        <Box
          component="input"
          ref={minuteRef}
          type="text"
          inputMode="numeric"
          readOnly={false}
          aria-label="Phút"
          value={minuteShown}
          onFocus={(e) => {
            setMode('minute');
            setMinuteDraft('');
            e.target.select();
          }}
          onClick={() => {
            setMode('minute');
            minuteRef.current?.select();
          }}
          onKeyDown={handleMinuteKeyDown}
          onChange={() => {}}
          sx={digitInputSx(mode === 'minute', primary)}
        />
      </Stack>

      <Box sx={{ display: 'flex', justifyContent: 'center' }}>
        <Box
          component="svg"
          viewBox={`0 0 ${CLOCK_SIZE} ${CLOCK_SIZE}`}
          onClick={handleClockClick}
          sx={{
            width: CLOCK_SIZE,
            height: CLOCK_SIZE,
            cursor: 'pointer',
            userSelect: 'none',
          }}
        >
          <circle
            cx={CENTER}
            cy={CENTER}
            r={CLOCK_SIZE / 2 - 4}
            fill={alpha(primary, 0.05)}
            stroke={alpha(primary, 0.12)}
            strokeWidth={1}
          />
          <line
            x1={CENTER}
            y1={CENTER}
            x2={handEnd.x}
            y2={handEnd.y}
            stroke={primary}
            strokeWidth={2}
            strokeLinecap="round"
          />
          <circle cx={CENTER} cy={CENTER} r={4} fill={primary} />
          <circle cx={handEnd.x} cy={handEnd.y} r={14} fill={primary} />

          {markers.map((m) => {
            const isHour = mode === 'hour';
            const selected = isHour
              ? (m as { hour: number }).hour === hour
              : snapMinute((m as { minute: number }).minute, minuteStep) === snapMinute(minute, minuteStep);
            const label = m.label;
            const onMarkerClick = (e: React.MouseEvent) => {
              e.stopPropagation();
              if (isHour) {
                selectHourFromClock((m as { hour: number }).hour);
              } else {
                selectMinuteFromClock((m as { minute: number }).minute);
              }
            };
            return (
              <g key={label} onClick={onMarkerClick} style={{ cursor: 'pointer' }}>
                <circle
                  cx={m.x}
                  cy={m.y}
                  r={selected ? 16 : 13}
                  fill={selected ? primary : alpha('#fff', 0.95)}
                  stroke={selected ? primary : alpha(primary, 0.15)}
                  strokeWidth={1}
                />
                <text
                  x={m.x}
                  y={m.y}
                  textAnchor="middle"
                  dominantBaseline="central"
                  fontSize={isHour ? 11 : 12}
                  fontWeight={selected ? 700 : 600}
                  fill={selected ? '#fff' : theme.palette.text.primary}
                  style={{ pointerEvents: 'none' }}
                >
                  {isHour ? Number(label) : label}
                </text>
              </g>
            );
          })}
        </Box>
      </Box>

      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', textAlign: 'center', mt: 1 }}>
        {mode === 'hour'
          ? 'Bấm vào số giờ rồi gõ trên bàn phím, hoặc chọn trên đồng hồ'
          : `Gõ phút bất kỳ (0–59) hoặc chọn trên đồng hồ (bước ${minuteStep} phút)`}
      </Typography>

      <Stack direction="row" justifyContent="flex-end" spacing={1} sx={{ mt: 1.75 }}>
        <Button size="small" color="inherit" onClick={onCancel}>
          Hủy
        </Button>
        <Button size="small" variant="contained" onClick={apply}>
          OK
        </Button>
      </Stack>
    </Box>
  );
}
