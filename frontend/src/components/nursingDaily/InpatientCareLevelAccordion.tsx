import ExpandLessRoundedIcon from '@mui/icons-material/ExpandLessRounded';
import ExpandMoreRoundedIcon from '@mui/icons-material/ExpandMoreRounded';
import { Box, Collapse, Stack, Typography } from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useState } from 'react';
import { IntegerStepperField } from './IntegerStepperField';

const LEVELS: { key: 'level1' | 'level2' | 'level3'; label: string; hint: string; tone: string }[] = [
  {
    key: 'level1',
    label: 'NB chăm sóc cấp 1',
    hint: 'Chăm sóc toàn diện / nặng',
    tone: '#be123c',
  },
  {
    key: 'level2',
    label: 'NB chăm sóc cấp 2',
    hint: 'Chăm sóc hỗ trợ',
    tone: '#b45309',
  },
  {
    key: 'level3',
    label: 'NB chăm sóc cấp 3',
    hint: 'Chăm sóc cơ bản',
    tone: '#0369a1',
  },
];

type Props = {
  level1: number;
  level2: number;
  level3: number;
  onChange: (next: { level1: number; level2: number; level3: number }) => void;
  accent?: string;
  disabled?: boolean;
  defaultExpanded?: boolean;
};

/** Accordion nhập NB nội trú theo 3 cấp chăm sóc — tổng = cấp 1+2+3. */
export function InpatientCareLevelAccordion({
  level1,
  level2,
  level3,
  onChange,
  accent = '#0369a1',
  disabled = false,
  defaultExpanded = true,
}: Props) {
  const [open, setOpen] = useState(defaultExpanded);
  const total = Math.max(0, level1) + Math.max(0, level2) + Math.max(0, level3);
  const values = { level1, level2, level3 };

  return (
    <Box
      sx={{
        borderRadius: 2.25,
        border: `1px solid ${total > 0 ? alpha(accent, 0.28) : alpha('#0f172a', 0.08)}`,
        bgcolor: total > 0 ? alpha(accent, 0.035) : '#fafbfc',
        overflow: 'hidden',
        transition: 'border-color 0.15s ease, background-color 0.15s ease, box-shadow 0.15s ease',
        boxShadow: open ? `0 4px 14px ${alpha(accent, 0.08)}` : 'none',
      }}
    >
      <Box
        component="button"
        type="button"
        disabled={disabled}
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        sx={{
          all: 'unset',
          boxSizing: 'border-box',
          width: '100%',
          cursor: disabled ? 'default' : 'pointer',
          display: 'flex',
          alignItems: 'center',
          gap: 1.25,
          px: 1.5,
          py: 1.2,
          bgcolor: alpha(accent, open ? 0.08 : 0.04),
          borderBottom: open ? `1px solid ${alpha(accent, 0.12)}` : 'none',
          '&:hover': disabled ? undefined : { bgcolor: alpha(accent, 0.1) },
          '&:focus-visible': {
            outline: `2px solid ${alpha(accent, 0.45)}`,
            outlineOffset: -2,
          },
        }}
      >
        <Box
          sx={{
            width: 36,
            height: 36,
            borderRadius: 1.75,
            display: 'grid',
            placeItems: 'center',
            flexShrink: 0,
            fontWeight: 900,
            fontSize: '0.95rem',
            letterSpacing: '-0.03em',
            color: '#fff',
            bgcolor: accent,
            boxShadow: `0 2px 8px ${alpha(accent, 0.35)}`,
          }}
        >
          {total}
        </Box>
        <Box sx={{ minWidth: 0, flex: 1 }}>
          <Typography
            variant="subtitle2"
            fontWeight={800}
            sx={{ letterSpacing: '-0.015em', lineHeight: 1.25, color: '#0f172a' }}
          >
            Người bệnh nội trú
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ lineHeight: 1.35 }}>
            {open
              ? 'Nhập theo 3 cấp chăm sóc — tổng tự cộng'
              : total > 0
                ? `Cấp 1: ${level1} · Cấp 2: ${level2} · Cấp 3: ${level3}`
                : 'Nhấn để nhập theo cấp chăm sóc'}
          </Typography>
        </Box>
        <Box
          sx={{
            width: 28,
            height: 28,
            borderRadius: '50%',
            display: 'grid',
            placeItems: 'center',
            color: accent,
            bgcolor: '#fff',
            border: `1px solid ${alpha(accent, 0.2)}`,
            flexShrink: 0,
          }}
        >
          {open ? (
            <ExpandLessRoundedIcon sx={{ fontSize: 18 }} />
          ) : (
            <ExpandMoreRoundedIcon sx={{ fontSize: 18 }} />
          )}
        </Box>
      </Box>

      <Collapse in={open} timeout={220} unmountOnExit={false}>
        <Box sx={{ p: 1.25 }}>
          <Stack spacing={1}>
            {LEVELS.map((lv) => (
              <Box
                key={lv.key}
                sx={{
                  display: 'grid',
                  gridTemplateColumns: { xs: '1fr', sm: 'minmax(0, 1.15fr) minmax(160px, 0.85fr)' },
                  gap: 1,
                  alignItems: 'stretch',
                  px: 1.1,
                  py: 1,
                  borderRadius: 2,
                  bgcolor: '#fff',
                  border: `1px solid ${alpha(lv.tone, values[lv.key] > 0 ? 0.28 : 0.12)}`,
                }}
              >
                <Stack spacing={0.35} justifyContent="center" sx={{ minWidth: 0, pl: 0.25 }}>
                  <Stack direction="row" spacing={0.85} alignItems="center">
                    <Box
                      sx={{
                        width: 8,
                        height: 8,
                        borderRadius: '50%',
                        bgcolor: lv.tone,
                        boxShadow: `0 0 0 3px ${alpha(lv.tone, 0.15)}`,
                        flexShrink: 0,
                      }}
                    />
                    <Typography
                      variant="body2"
                      fontWeight={800}
                      sx={{ letterSpacing: '-0.01em', color: '#0f172a', lineHeight: 1.3 }}
                    >
                      {lv.label}
                    </Typography>
                  </Stack>
                  <Typography
                    variant="caption"
                    color="text.secondary"
                    sx={{ pl: 2.1, lineHeight: 1.35 }}
                  >
                    {lv.hint}
                  </Typography>
                </Stack>
                <IntegerStepperField
                  label="Số lượng"
                  value={values[lv.key]}
                  disabled={disabled}
                  accent={lv.tone}
                  onChange={(v) => onChange({ ...values, [lv.key]: v })}
                />
              </Box>
            ))}
          </Stack>
          <Stack
            direction="row"
            alignItems="center"
            justifyContent="space-between"
            sx={{
              mt: 1.1,
              px: 1.15,
              py: 0.85,
              borderRadius: 1.75,
              bgcolor: alpha(accent, 0.07),
              border: `1px dashed ${alpha(accent, 0.28)}`,
            }}
          >
            <Typography variant="caption" fontWeight={700} color="text.secondary">
              Tổng người bệnh nội trú
            </Typography>
            <Typography
              variant="subtitle1"
              fontWeight={900}
              sx={{ color: accent, letterSpacing: '-0.03em', lineHeight: 1 }}
            >
              {total}
            </Typography>
          </Stack>
        </Box>
      </Collapse>
    </Box>
  );
}
