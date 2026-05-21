import AddIcon from '@mui/icons-material/Add';
import CloseIcon from '@mui/icons-material/Close';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import SearchIcon from '@mui/icons-material/Search';
import {
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  InputAdornment,
  Link,
  Paper,
  Skeleton,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import * as announcementService from '../services/announcementService';
import api from '../services/api';

const DEFAULT_CATEGORY = 'THONG_BAO_CHUNG';

function formatViDateLine(isoDate: string | null, publishedAt: string): string {
  if (isoDate && /^\d{4}-\d{2}-\d{2}$/.test(isoDate)) {
    const [y, m, d] = isoDate.split('-');
    return `${d}/${m}/${y}:`;
  }
  const dt = new Date(publishedAt);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(dt.getDate())}/${pad(dt.getMonth() + 1)}/${dt.getFullYear()}:`;
}

/** Chuỗi yyyy-mm-dd để so sánh lọc — ưu tiên ngày hiển thị, không thì ngày đăng (local). */
function effectiveDateKey(a: announcementService.Announcement): string {
  if (a.displayDate && /^\d{4}-\d{2}-\d{2}$/.test(a.displayDate)) {
    return a.displayDate;
  }
  const d = new Date(a.publishedAt);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function filterAnnouncements(
  list: announcementService.Announcement[],
  titleQ: string,
  from: string,
  to: string,
): announcementService.Announcement[] {
  const q = titleQ.trim().toLowerCase();
  let lo = from;
  let hi = to;
  if (lo && hi && lo > hi) {
    [lo, hi] = [hi, lo];
  }
  return list.filter((a) => {
    if (q && !a.title.toLowerCase().includes(q)) {
      return false;
    }
    const key = effectiveDateKey(a);
    if (lo && key < lo) {
      return false;
    }
    if (hi && key > hi) {
      return false;
    }
    return true;
  });
}

function isImageAttachment(att: announcementService.AnnouncementAttachment): boolean {
  const ct = (att.contentType ?? '').toLowerCase();
  if (ct.startsWith('image/')) return true;
  const n = att.originalName.toLowerCase();
  return /\.(jpe?g|png|gif|webp|bmp|svg)$/.test(n);
}

function InlineAnnouncementImage({ attachmentId, alt }: { attachmentId: number; alt: string }) {
  const [src, setSrc] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    let objectUrl: string | null = null;
    (async () => {
      try {
        const res = await api.get(`/v1/announcements/attachments/${attachmentId}/file`, {
          responseType: 'blob',
        });
        const ct = res.headers['content-type'] || 'application/octet-stream';
        if (cancelled) return;
        objectUrl = URL.createObjectURL(new Blob([res.data], { type: ct }));
        setSrc(objectUrl);
      } catch {
        if (!cancelled) setFailed(true);
      }
    })();
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [attachmentId]);

  if (failed) {
    return (
      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
        Không tải được ảnh.
      </Typography>
    );
  }
  if (!src) {
    return <Skeleton variant="rounded" height={180} sx={{ mt: 1, borderRadius: 1 }} />;
  }
  return (
    <Box
      component="img"
      src={src}
      alt={alt}
      sx={{
        mt: 1,
        maxWidth: '100%',
        maxHeight: 420,
        objectFit: 'contain',
        borderRadius: 1,
        border: (t) => `1px solid ${alpha(t.palette.divider, 0.9)}`,
        display: 'block',
      }}
    />
  );
}

type Props = {
  isAdmin: boolean;
  /** Từ URL /announcements?announcement=id — cuộn tới và làm nổi mục thông báo */
  focusAnnouncementId?: number | null;
};

export function AnnouncementBoard({ isAdmin, focusAnnouncementId = null }: Props) {
  const theme = useTheme();
  const navigate = useNavigate();
  const [flashId, setFlashId] = useState<number | null>(null);
  const scrollDoneRef = useRef<number | null>(null);
  const [items, setItems] = useState<announcementService.Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [dialogOpen, setDialogOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formTitle, setFormTitle] = useState('');
  const [formBody, setFormBody] = useState('');
  const [formDate, setFormDate] = useState('');
  const [formFiles, setFormFiles] = useState<File[]>([]);
  const [formLinkLabel, setFormLinkLabel] = useState('tại đây');

  const [filterTitle, setFilterTitle] = useState('');
  const [filterFrom, setFilterFrom] = useState('');
  const [filterTo, setFilterTo] = useState('');

  const filteredItems = useMemo(
    () => filterAnnouncements(items, filterTitle, filterFrom, filterTo),
    [items, filterTitle, filterFrom, filterTo],
  );

  const hasActiveFilters = Boolean(filterTitle.trim() || filterFrom || filterTo);

  const clearFilters = () => {
    setFilterTitle('');
    setFilterFrom('');
    setFilterTo('');
  };

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await announcementService.fetchAnnouncements();
      setItems(data);
    } catch {
      setError('Không tải được thông báo.');
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (focusAnnouncementId == null) {
      scrollDoneRef.current = null;
      return;
    }
    setFilterTitle('');
    setFilterFrom('');
    setFilterTo('');
  }, [focusAnnouncementId]);

  useEffect(() => {
    if (focusAnnouncementId == null || loading) return;
    if (!filteredItems.some((x) => x.id === focusAnnouncementId)) return;
    if (scrollDoneRef.current === focusAnnouncementId) return;
    scrollDoneRef.current = focusAnnouncementId;
    setFlashId(focusAnnouncementId);
    const t = window.setTimeout(() => {
      document.getElementById(`announcement-card-${focusAnnouncementId}`)?.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      });
      navigate({ pathname: '/', search: '' }, { replace: true });
    }, 120);
    const c = window.setTimeout(() => setFlashId(null), 5000);
    return () => {
      window.clearTimeout(t);
      window.clearTimeout(c);
    };
  }, [focusAnnouncementId, loading, filteredItems, navigate]);

  const openCreate = () => {
    setFormTitle('');
    setFormBody('');
    setFormDate('');
    setFormFiles([]);
    setFormLinkLabel('tại đây');
    setDialogOpen(true);
  };

  const onPickFiles = (e: React.ChangeEvent<HTMLInputElement>) => {
    const list = e.target.files;
    setFormFiles(list ? Array.from(list) : []);
  };

  const submitCreate = async () => {
    if (!formTitle.trim() || !formBody.trim()) return;
    setSaving(true);
    try {
      const payload: announcementService.CreateAnnouncementPayload = {
        title: formTitle.trim(),
        body: formBody,
        category: DEFAULT_CATEGORY,
        displayDate: formDate || null,
        linkLabels: formFiles.map(() => formLinkLabel.trim() || 'tại đây'),
      };
      if (formFiles.length > 0) {
        await announcementService.createAnnouncementWithFiles(payload, formFiles);
      } else {
        await announcementService.createAnnouncementJson(payload);
      }
      setDialogOpen(false);
      await load();
    } catch {
      setError('Không đăng được thông báo. Thử lại.');
    } finally {
      setSaving(false);
    }
  };

  const onDelete = async (id: number) => {
    if (!window.confirm('Xóa thông báo này?')) return;
    try {
      await announcementService.deleteAnnouncement(id);
      await load();
    } catch {
      setError('Không xóa được thông báo.');
    }
  };

  return (
    <Box id="hospital-announcements" sx={{ mb: 3 }}>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1.5 }} flexWrap="wrap" gap={1}>
        <Typography variant="h6" sx={{ fontWeight: 700, letterSpacing: '-0.02em', color: 'text.primary' }}>
          Thông báo toàn viện
        </Typography>
        {isAdmin && (
          <Button variant="contained" size="small" startIcon={<AddIcon />} onClick={openCreate} sx={{ textTransform: 'none' }}>
            Tạo thông báo
          </Button>
        )}
      </Stack>

      <Paper
        elevation={0}
        sx={{
          borderRadius: 3,
          border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
          overflow: 'hidden',
          bgcolor: 'background.paper',
          transition: 'box-shadow 0.2s ease',
          '&:hover': { boxShadow: `0 8px 24px ${alpha('#0f172a', 0.06)}` },
        }}
      >
        <Box sx={{ p: 2.5, minHeight: 120 }}>
          {!loading && !error && (
            <Stack
              direction={{ xs: 'column', sm: 'row' }}
              spacing={1.5}
              useFlexGap
              flexWrap="wrap"
              alignItems={{ xs: 'stretch', sm: 'flex-end' }}
              sx={{
                mb: 2,
                pb: 2,
                borderBottom: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
              }}
            >
              <TextField
                size="small"
                label="Tìm theo tiêu đề"
                value={filterTitle}
                onChange={(e) => setFilterTitle(e.target.value)}
                placeholder="Nhập một phần tiêu đề…"
                sx={{ flex: 1, minWidth: { xs: '100%', sm: 220 } }}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <SearchIcon fontSize="small" color="action" />
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                size="small"
                label="Từ ngày"
                type="date"
                value={filterFrom}
                onChange={(e) => setFilterFrom(e.target.value)}
                sx={{ minWidth: { xs: '100%', sm: 160 } }}
                InputLabelProps={{ shrink: true }}
              />
              <TextField
                size="small"
                label="Đến ngày"
                type="date"
                value={filterTo}
                onChange={(e) => setFilterTo(e.target.value)}
                sx={{ minWidth: { xs: '100%', sm: 160 } }}
                InputLabelProps={{ shrink: true }}
              />
              <Button
                variant="text"
                size="small"
                onClick={clearFilters}
                disabled={!hasActiveFilters}
                sx={{ textTransform: 'none', alignSelf: { xs: 'flex-start', sm: 'center' } }}
              >
                Xóa lọc
              </Button>
            </Stack>
          )}

          {loading && (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 3 }}>
              <CircularProgress size={28} color="primary" />
            </Box>
          )}
          {!loading && error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
          {!loading && !error && items.length === 0 && (
            <Typography variant="body2" color="text.secondary">
              Chưa có thông báo.
            </Typography>
          )}
          {!loading && !error && items.length > 0 && filteredItems.length === 0 && (
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Không có thông báo phù hợp bộ lọc. Thử đổi ngày hoặc từ khóa.
            </Typography>
          )}
          {!loading &&
            !error &&
            filteredItems.map((a) => (
              <Box
                key={a.id}
                id={`announcement-card-${a.id}`}
                sx={{
                  mb: 2.5,
                  pb: 2.5,
                  borderBottom: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
                  borderRadius: flashId === a.id ? 1 : 0,
                  px: flashId === a.id ? 1 : 0,
                  mx: flashId === a.id ? -1 : 0,
                  outline: flashId === a.id ? `2px solid ${alpha(theme.palette.primary.main, 0.55)}` : 'none',
                  outlineOffset: flashId === a.id ? 2 : 0,
                  transition: 'outline 0.2s ease',
                  '&:last-child': { borderBottom: 'none', mb: 0, pb: 0 },
                }}
              >
                <Stack direction="row" alignItems="flex-start" justifyContent="space-between" gap={1}>
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Typography component="div" sx={{ fontSize: '0.95rem', lineHeight: 1.5 }}>
                      <Box component="span" sx={{ color: 'text.secondary', fontWeight: 700 }}>
                        {formatViDateLine(a.displayDate, a.publishedAt)}
                      </Box>{' '}
                      <Box component="span" sx={{ color: 'primary.main', fontWeight: 700 }}>
                        {a.title}
                      </Box>
                    </Typography>
                    <Typography
                      component="div"
                      sx={{
                        mt: 1,
                        color: 'text.secondary',
                        whiteSpace: 'pre-wrap',
                        fontSize: '0.9rem',
                        lineHeight: 1.7,
                      }}
                    >
                      {a.body}
                    </Typography>
                    {a.attachments?.length > 0 && (
                      <Stack spacing={1} sx={{ mt: 1 }}>
                        {a.attachments.map((att) =>
                          isImageAttachment(att) ? (
                            <InlineAnnouncementImage
                              key={att.id}
                              attachmentId={att.id}
                              alt={att.originalName || 'Ảnh đính kèm'}
                            />
                          ) : (
                            <Typography key={att.id} component="div" variant="body2" color="text.secondary">
                              <Link
                                component="button"
                                type="button"
                                onClick={() => void announcementService.openAnnouncementAttachmentInline(att.id)}
                                sx={{
                                  cursor: 'pointer',
                                  verticalAlign: 'baseline',
                                  textDecoration: 'underline',
                                  fontWeight: 500,
                                }}
                              >
                                {att.linkLabel}
                              </Link>
                            </Typography>
                          ),
                        )}
                      </Stack>
                    )}
                  </Box>
                  {isAdmin && (
                    <IconButton
                      size="small"
                      onClick={() => void onDelete(a.id)}
                      sx={{ color: 'text.secondary' }}
                      aria-label="Xóa"
                    >
                      <DeleteOutlineIcon fontSize="small" />
                    </IconButton>
                  )}
                </Stack>
              </Box>
            ))}
        </Box>
      </Paper>

      <Dialog
        open={dialogOpen}
        onClose={() => !saving && setDialogOpen(false)}
        maxWidth="sm"
        fullWidth
        PaperProps={{ sx: { overflow: 'visible' } }}
      >
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          Đăng thông báo
          <IconButton size="small" onClick={() => setDialogOpen(false)} disabled={saving}>
            <CloseIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent
          sx={{
            display: 'flex',
            flexDirection: 'column',
            gap: 2,
            pt: 3,
            pb: 2,
            px: 3,
            overflow: 'visible',
          }}
        >
          <TextField
            label="Ngày hiển thị"
            type="date"
            value={formDate}
            onChange={(e) => setFormDate(e.target.value)}
            fullWidth
            size="small"
            InputLabelProps={{ shrink: true }}
            helperText="Để trống sẽ dùng ngày đăng."
            inputProps={{ 'aria-label': 'Ngày hiển thị' }}
          />
          <TextField label="Tiêu đề" value={formTitle} onChange={(e) => setFormTitle(e.target.value)} fullWidth required size="small" />
          <TextField
            label="Nội dung"
            value={formBody}
            onChange={(e) => setFormBody(e.target.value)}
            fullWidth
            required
            multiline
            minRows={5}
            size="small"
          />
          <Button variant="outlined" component="label" sx={{ alignSelf: 'flex-start', textTransform: 'none' }}>
            Đính kèm (ảnh hoặc tài liệu, tùy chọn)
            <input type="file" hidden multiple accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.zip" onChange={onPickFiles} />
          </Button>
          {formFiles.length > 0 && (
            <Typography variant="caption" color="text.secondary">
              Đã chọn {formFiles.length} file — nhãn liên kết tài liệu:
            </Typography>
          )}
          <TextField
            label="Chữ hiển thị cho mỗi liên kết (tài liệu)"
            value={formLinkLabel}
            onChange={(e) => setFormLinkLabel(e.target.value)}
            fullWidth
            size="small"
            placeholder="tại đây"
            helperText="Áp dụng cho file không phải ảnh. Ảnh hiển thị trực tiếp, không cần nhãn."
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setDialogOpen(false)} disabled={saving}>
            Hủy
          </Button>
          <Button variant="contained" onClick={() => void submitCreate()} disabled={saving || !formTitle.trim() || !formBody.trim()}>
            {saving ? <CircularProgress size={22} /> : 'Đăng'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
