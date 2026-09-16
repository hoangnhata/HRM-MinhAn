import { Box, Typography } from '@mui/material';
import { alpha } from '@mui/material/styles';
import type { ReactElement } from 'react';
import { MODULE_A_ACCENT } from './moduleAUiStyles';

export type ModuleATabItem<T extends string> = {
  id: T;
  label: string;
  shortLabel?: string;
  icon: ReactElement;
};

type Props<T extends string> = {
  tabs: ModuleATabItem<T>[];
  value: T;
  onChange: (id: T) => void;
};

export function ModuleATabBar<T extends string>({ tabs, value, onChange }: Props<T>) {
  return (
    <Box
      sx={{
        mb: 2,
        borderRadius: 2.75,
        border: `1px solid ${alpha('#64748b', 0.12)}`,
        bgcolor: alpha('#f8fafc', 0.85),
        boxShadow: `inset 0 1px 0 ${alpha('#fff', 0.9)}`,
        overflow: 'hidden',
      }}
    >
      <Box
        role="tablist"
        aria-label="Nhóm báo cáo hoạt động điều dưỡng"
        sx={{
          display: 'flex',
          gap: 0.25,
          px: 0.75,
          py: 0.75,
          overflowX: 'auto',
          scrollbarWidth: 'thin',
          '&::-webkit-scrollbar': { height: 5 },
          '&::-webkit-scrollbar-thumb': {
            bgcolor: alpha(MODULE_A_ACCENT, 0.25),
            borderRadius: 99,
          },
        }}
      >
        {tabs.map((tab) => {
          const active = tab.id === value;
          return (
            <Box
              key={tab.id}
              role="tab"
              aria-selected={active}
              tabIndex={active ? 0 : -1}
              onClick={() => onChange(tab.id)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault();
                  onChange(tab.id);
                }
              }}
              sx={{
                flex: '0 0 auto',
                display: 'flex',
                alignItems: 'center',
                gap: 0.85,
                px: { xs: 1.15, sm: 1.45 },
                py: 0.85,
                borderRadius: 2,
                cursor: 'pointer',
                userSelect: 'none',
                position: 'relative',
                color: active ? MODULE_A_ACCENT : 'text.secondary',
                bgcolor: active ? '#fff' : 'transparent',
                border: active
                  ? `1px solid ${alpha(MODULE_A_ACCENT, 0.22)}`
                  : '1px solid transparent',
                boxShadow: active
                  ? `0 2px 10px ${alpha(MODULE_A_ACCENT, 0.1)}, inset 0 1px 0 ${alpha('#fff', 0.95)}`
                  : 'none',
                transition: 'color 0.15s ease, background-color 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease',
                '&:hover': {
                  color: MODULE_A_ACCENT,
                  bgcolor: active ? '#fff' : alpha('#fff', 0.72),
                  borderColor: alpha(MODULE_A_ACCENT, 0.14),
                },
                '&:focus-visible': {
                  outline: `2px solid ${alpha(MODULE_A_ACCENT, 0.45)}`,
                  outlineOffset: 1,
                },
              }}
            >
              <Box
                sx={{
                  width: 28,
                  height: 28,
                  borderRadius: 1.5,
                  display: 'grid',
                  placeItems: 'center',
                  flexShrink: 0,
                  color: active ? MODULE_A_ACCENT : alpha('#475569', 0.85),
                  bgcolor: active ? alpha(MODULE_A_ACCENT, 0.1) : alpha('#0f172a', 0.04),
                  border: `1px solid ${active ? alpha(MODULE_A_ACCENT, 0.16) : alpha('#64748b', 0.08)}`,
                  '& .MuiSvgIcon-root': { fontSize: 17 },
                }}
              >
                {tab.icon}
              </Box>
              <Typography
                component="span"
                sx={{
                  fontWeight: active ? 800 : 650,
                  fontSize: { xs: '0.8125rem', sm: '0.875rem' },
                  letterSpacing: '-0.015em',
                  whiteSpace: 'nowrap',
                  pr: 0.25,
                }}
              >
                <Box component="span" sx={{ display: { xs: 'none', md: 'inline' } }}>
                  {tab.label}
                </Box>
                <Box component="span" sx={{ display: { xs: 'inline', md: 'none' } }}>
                  {tab.shortLabel ?? tab.label}
                </Box>
              </Typography>
            </Box>
          );
        })}
      </Box>
    </Box>
  );
}
