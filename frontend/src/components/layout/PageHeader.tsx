import { Box, Stack, Typography } from '@mui/material';
import type { ReactNode } from 'react';

type Props = {
  /** Nhãn phụ phía trên (uppercase nhỏ) */
  overline?: string;
  title: string;
  description?: string;
  actions?: ReactNode;
  /** Khoảng cách dưới (theme spacing) */
  mb?: number;
};

/**
 * Tiêu đề trang thống nhất — dùng trên mọi màn hình trong layout chính.
 */
export function PageHeader({ overline, title, description, actions, mb = 3 }: Props) {
  return (
    <Stack
      direction={{ xs: 'column', lg: 'row' }}
      justifyContent="space-between"
      alignItems={{ xs: 'stretch', lg: 'flex-start' }}
      spacing={2}
      sx={{ mb }}
    >
      <Box sx={{ minWidth: 0, flex: 1 }}>
        {overline ? (
          <Typography
            variant="overline"
            color="primary"
            sx={{ fontWeight: 700, letterSpacing: '0.12em', display: 'block', mb: 0.75 }}
          >
            {overline}
          </Typography>
        ) : null}
        <Typography
          variant="h4"
          component="h1"
          sx={{ fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.25 }}
        >
          {title}
        </Typography>
        {description ? (
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1.25, maxWidth: 720, lineHeight: 1.65 }}>
            {description}
          </Typography>
        ) : null}
      </Box>
      {actions ? (
        <Stack
          direction="row"
          spacing={1}
          flexWrap="wrap"
          useFlexGap
          sx={{
            flexShrink: 0,
            alignItems: { xs: 'stretch', sm: 'center' },
            justifyContent: { lg: 'flex-end' },
          }}
        >
          {actions}
        </Stack>
      ) : null}
    </Stack>
  );
}
