import { Box, Stack, Typography } from '@mui/material';
import { alpha } from '@mui/material/styles';
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
      component="header"
      direction={{ xs: 'column', md: 'row' }}
      justifyContent="space-between"
      alignItems={{ xs: 'stretch', md: 'flex-start' }}
      spacing={{ xs: 2, md: 3 }}
      sx={{
        mb,
        pb: { xs: 2, md: 2.5 },
        borderBottom: (theme) => `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
      }}
    >
      <Box
        sx={(theme) => ({
          minWidth: 0,
          flex: 1,
          ...(overline && {
            position: 'relative',
            pl: { xs: 1.5, sm: 1.75 },
            '&::before': {
              position: 'absolute',
              top: 2,
              bottom: 3,
              left: 0,
              width: 4,
              borderRadius: 99,
              content: '""',
              background: `linear-gradient(180deg, ${theme.palette.primary.main}, ${theme.palette.secondary.main})`,
            },
          }),
        })}
      >
        {overline ? (
          <Typography
            variant="overline"
            color="primary"
            sx={{
              display: 'block',
              mb: 0.5,
              color: 'primary.dark',
              fontWeight: 750,
              letterSpacing: '0.115em',
              lineHeight: 1.45,
            }}
          >
            {overline}
          </Typography>
        ) : null}
        <Typography
          variant="h4"
          component="h1"
          sx={{
            maxWidth: 880,
            fontSize: { xs: '1.5rem', sm: '1.75rem', md: '2rem' },
            fontWeight: 750,
            letterSpacing: '-0.035em',
            lineHeight: 1.18,
            overflowWrap: 'anywhere',
            textWrap: 'balance',
          }}
        >
          {title}
        </Typography>
        {description ? (
          <Typography
            variant="body1"
            color="text.secondary"
            sx={{
              mt: 1,
              maxWidth: 760,
              fontSize: { xs: '0.875rem', sm: '0.9375rem' },
              lineHeight: 1.65,
              overflowWrap: 'anywhere',
            }}
          >
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
            width: { xs: '100%', md: 'auto' },
            flexShrink: 0,
            alignItems: { xs: 'stretch', sm: 'center' },
            justifyContent: { xs: 'flex-start', md: 'flex-end' },
            '& > .MuiButton-root': {
              flex: { xs: '1 1 164px', sm: '0 1 auto' },
            },
            '& > .MuiButton-root:only-child': {
              flexBasis: { xs: 'auto', sm: 'auto' },
              alignSelf: { xs: 'flex-start', md: 'auto' },
            },
          }}
        >
          {actions}
        </Stack>
      ) : null}
    </Stack>
  );
}
