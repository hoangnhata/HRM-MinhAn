import CloseIcon from '@mui/icons-material/Close';
import ZoomInIcon from '@mui/icons-material/ZoomIn';
import { Box, Dialog, DialogContent, IconButton, Stack, Tooltip, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { fetchApprovalSignatureObjectUrl } from '../services/approvalSignatureService';
import { useRequestAccent } from './work/WorkRequestFormUi';

function defaultFormatTimestamp(iso: string) {
  try {
    return new Date(iso).toLocaleString('vi-VN');
  } catch {
    return iso;
  }
}

type Props = {
  role: string;
  timestamp?: string | null;
  comment?: string | null;
  signatureUrl?: string | null;
  formatTimestamp?: (iso: string) => string;
};

/** Thẻ ghi chú duyệt kèm ảnh chữ ký snapshot (nếu có). */
export function ApprovalReviewNoteCard({
  role,
  timestamp,
  comment,
  signatureUrl,
  formatTimestamp = defaultFormatTimestamp,
}: Props) {
  const theme = useTheme();
  const accent = useRequestAccent();
  const [imgUrl, setImgUrl] = useState<string | null>(null);
  const [previewOpen, setPreviewOpen] = useState(false);

  useEffect(() => {
    let cancelled = false;
    let created: string | null = null;
    setImgUrl(null);
    setPreviewOpen(false);
    if (!signatureUrl) return;

    void (async () => {
      const u = await fetchApprovalSignatureObjectUrl(signatureUrl);
      if (cancelled) {
        if (u) URL.revokeObjectURL(u);
        return;
      }
      created = u;
      setImgUrl(u);
    })();

    return () => {
      cancelled = true;
      if (created) URL.revokeObjectURL(created);
    };
  }, [signatureUrl]);

  return (
    <Box
      sx={{
        position: 'relative',
        p: 2,
        pl: 2.25,
        borderRadius: 2.5,
        bgcolor: alpha(accent, 0.03),
        border: `1px solid ${alpha(accent, 0.12)}`,
        overflow: 'hidden',
        '&::before': {
          content: '""',
          position: 'absolute',
          left: 0,
          top: 0,
          bottom: 0,
          width: 3,
          bgcolor: accent,
        },
      }}
    >
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1.5}>
        <Typography variant="subtitle2" fontWeight={800} sx={{ letterSpacing: '0.01em' }}>
          {role}
        </Typography>
        {timestamp && (
          <Typography
            variant="caption"
            sx={{
              color: 'text.secondary',
              fontWeight: 600,
              whiteSpace: 'nowrap',
              px: 1,
              py: 0.35,
              borderRadius: 1.25,
              bgcolor: alpha(theme.palette.grey[500], 0.08),
            }}
          >
            {formatTimestamp(timestamp)}
          </Typography>
        )}
      </Stack>
      <Typography
        variant="body2"
        sx={{
          mt: 1,
          lineHeight: 1.65,
          color: comment?.trim() ? 'text.primary' : 'text.secondary',
          fontStyle: comment?.trim() ? 'normal' : 'italic',
        }}
      >
        {comment?.trim() ? comment : 'Không có ghi chú.'}
      </Typography>
      {imgUrl && (
        <Box sx={{ mt: 1.5 }}>
          <Typography
            variant="caption"
            sx={{
              display: 'block',
              mb: 0.75,
              fontWeight: 700,
              letterSpacing: '0.04em',
              textTransform: 'uppercase',
              fontSize: '0.68rem',
              color: 'text.secondary',
            }}
          >
            Chữ ký số
          </Typography>
          <Tooltip title="Nhấn để xem chữ ký lớn">
            <Box
              component="button"
              type="button"
              onClick={() => setPreviewOpen(true)}
              aria-label={`Xem lớn chữ ký ${role}`}
              sx={{
                position: 'relative',
                display: 'block',
                m: 0,
                p: 1,
                cursor: 'zoom-in',
                bgcolor: '#fff',
                border: `1px solid ${alpha(theme.palette.divider, 0.7)}`,
                borderRadius: 1.5,
                boxShadow: `0 4px 14px ${alpha('#0f172a', 0.05)}`,
                transition: 'border-color 150ms ease, box-shadow 150ms ease',
                '&:hover, &:focus-visible': {
                  borderColor: accent,
                  boxShadow: `0 5px 18px ${alpha(accent, 0.18)}`,
                  outline: 'none',
                },
              }}
            >
              <Box
                component="img"
                src={imgUrl}
                alt={`Chữ ký ${role}`}
                sx={{
                  maxWidth: 240,
                  maxHeight: 96,
                  objectFit: 'contain',
                  display: 'block',
                }}
              />
              <ZoomInIcon
                sx={{
                  position: 'absolute',
                  right: 4,
                  bottom: 4,
                  p: 0.35,
                  fontSize: 22,
                  color: '#fff',
                  bgcolor: alpha('#0f172a', 0.62),
                  borderRadius: '50%',
                }}
              />
            </Box>
          </Tooltip>
          <Dialog
            open={previewOpen}
            onClose={() => setPreviewOpen(false)}
            maxWidth="md"
            fullWidth
            aria-labelledby="approval-signature-preview-title"
          >
            <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ px: 2, pt: 1.5 }}>
              <Typography id="approval-signature-preview-title" variant="subtitle1" fontWeight={800}>
                Chữ ký số — {role}
              </Typography>
              <IconButton onClick={() => setPreviewOpen(false)} aria-label="Đóng ảnh chữ ký">
                <CloseIcon />
              </IconButton>
            </Stack>
            <DialogContent sx={{ display: 'flex', justifyContent: 'center', pt: 1, bgcolor: '#f8fafc' }}>
              <Box
                component="img"
                src={imgUrl}
                alt={`Chữ ký ${role} phóng to`}
                sx={{
                  width: 'auto',
                  height: 'auto',
                  maxWidth: '100%',
                  maxHeight: '70vh',
                  objectFit: 'contain',
                  bgcolor: '#fff',
                  borderRadius: 2,
                  boxShadow: `0 10px 30px ${alpha('#0f172a', 0.12)}`,
                }}
              />
            </DialogContent>
          </Dialog>
        </Box>
      )}
    </Box>
  );
}
