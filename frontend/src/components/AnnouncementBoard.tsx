import AddIcon from '@mui/icons-material/Add';
import AttachFileOutlinedIcon from '@mui/icons-material/AttachFileOutlined';
import CampaignOutlinedIcon from '@mui/icons-material/CampaignOutlined';
import CloseIcon from '@mui/icons-material/Close';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import FilterAltOffOutlinedIcon from '@mui/icons-material/FilterAltOffOutlined';
import SearchIcon from '@mui/icons-material/Search';
import {
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  Grid,
  IconButton,
  InputAdornment,
  Link,
  Paper,
  Skeleton,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PageHeader } from './layout/PageHeader';
import { DatePickerField, dateTimeFieldSx } from './ui/DateTimeFields';
import * as announcementService from '../services/announcementService';
import api from '../services/api';

const DEFAULT_CATEGORY = 'THONG_BAO_CHUNG';
const ACCENT = '#0f766e';

function formatViDate(isoDate: string | null, publishedAt: string): string {
  if (isoDate && /^\d{4}-\d{2}-\d{2}$/.test(isoDate)) {
    const [y, m, d] = isoDate.split('-');
    return `${d}/${m}/${y}`;
  }
  const dt = new Date(publishedAt);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(dt.getDate())}/${pad(dt.getMonth() + 1)}/${dt.getFullYear()}`;
}

function formatViDateLong(isoDate: string | null, publishedAt: string): string {
  const key =
    isoDate && /^\d{4}-\d{2}-\d{2}$/.test(isoDate)
      ? isoDate
      : (() => {
          const d = new Date(publishedAt);
          return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
        })();
  const [y, m, d] = key.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  return date.toLocaleDateString('vi-VN', {
    weekday: 'short',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

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
    if (q && !a.title.toLowerCase().includes(q)) return false;
    const key = effectiveDateKey(a);
    if (lo && key < lo) return false;
    if (hi && key > hi) return false;
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
    return <Skeleton variant="rounded" height={180} sx={{ mt: 1.5, borderRadius: 2 }} />;
  }
  return (
    <Box
      component="img"
      src={src}
      alt={alt}
      sx={{
        mt: 1.5,
        maxWidth: '100%',
        maxHeight: 420,
        objectFit: 'contain',
        borderRadius: 2,
        border: (t) => `1px solid ${alpha(t.palette.divider, 0.85)}`,
        display: 'block',
        bgcolor: alpha('#0f172a', 0.02),
      }}
    />
  );
}

type Props = {
  isAdmin: boolean;
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
      <PageHeader
        overline="Nội bộ"
        title="Thông báo toàn viện"
        description="Tin tức, lịch họp và thông báo chung tới toàn thể CBCNV."
        actions={
          isAdmin ? (
            <Button
              variant="contained"
              startIcon={<AddIcon />}
              onClick={openCreate}
              sx={{
                textTransform: 'none',
                fontWeight: 700,
                borderRadius: 2,
                px: 2,
                bgcolor: ACCENT,
                '&:hover': { bgcolor: '#0d9488' },
              }}
            >
              Tạo thông báo
            </Button>
          ) : undefined
        }
      />

      {/* Bộ lọc */}
      <Paper
        elevation={0}
        sx={{
          mb: 2.5,
          p: 2,
          borderRadius: 3,
          border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
          bgcolor: 'background.paper',
        }}
      >
        <Grid container spacing={1.5} alignItems="center">
          <Grid item xs={12} md={5}>
            <TextField
              size="small"
              fullWidth
              placeholder="Tìm theo tiêu đề…"
              value={filterTitle}
              onChange={(e) => setFilterTitle(e.target.value)}
              sx={dateTimeFieldSx}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <SearchIcon fontSize="small" color="action" />
                  </InputAdornment>
                ),
              }}
            />
          </Grid>
          <Grid item xs={6} sm={4} md={2}>
            <DatePickerField
              size="small"
              label="Từ ngày"
              value={filterFrom}
              onChange={setFilterFrom}
              sx={{ ...dateTimeFieldSx, width: '100%' }}
            />
          </Grid>
          <Grid item xs={6} sm={4} md={2}>
            <DatePickerField
              size="small"
              label="Đến ngày"
              value={filterTo}
              onChange={setFilterTo}
              sx={{ ...dateTimeFieldSx, width: '100%' }}
            />
          </Grid>
          <Grid item xs={12} sm={4} md={3}>
            <Stack direction="row" spacing={1} alignItems="center" justifyContent={{ xs: 'flex-start', md: 'flex-end' }}>
              {hasActiveFilters && (
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<FilterAltOffOutlinedIcon />}
                  onClick={clearFilters}
                  sx={{ textTransform: 'none', borderRadius: 2, whiteSpace: 'nowrap' }}
                >
                  Xóa lọc
                </Button>
              )}
              {!loading && !error && (
                <Chip
                  size="small"
                  label={`${filteredItems.length}/${items.length}`}
                  variant="outlined"
                  sx={{ fontWeight: 600, borderRadius: 1.5 }}
                />
              )}
            </Stack>
          </Grid>
        </Grid>
      </Paper>

      {/* Danh sách */}
      <Paper
        elevation={0}
        sx={{
          borderRadius: 3,
          border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
          overflow: 'hidden',
          bgcolor: 'background.paper',
        }}
      >
        <Box
          sx={{
            px: 2.5,
            py: 1.75,
            display: 'flex',
            alignItems: 'center',
            gap: 1.25,
            background: `linear-gradient(135deg, ${alpha(ACCENT, 0.1)} 0%, ${alpha(ACCENT, 0.03)} 100%)`,
            borderBottom: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
          }}
        >
          <Box
            sx={{
              width: 36,
              height: 36,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(ACCENT, 0.14),
              color: ACCENT,
            }}
          >
            <CampaignOutlinedIcon fontSize="small" />
          </Box>
          <Box sx={{ minWidth: 0 }}>
            <Typography variant="subtitle2" fontWeight={800} sx={{ letterSpacing: '-0.01em' }}>
              Bảng tin nội bộ
            </Typography>
            <Typography variant="caption" color="text.secondary">
              Sắp xếp theo ngày mới nhất
            </Typography>
          </Box>
        </Box>

        <Box sx={{ p: { xs: 1.5, sm: 2 } }}>
          {loading && (
            <Stack spacing={1.5} sx={{ py: 1 }}>
              {[0, 1, 2].map((i) => (
                <Skeleton key={i} variant="rounded" height={110} sx={{ borderRadius: 2.5 }} />
              ))}
            </Stack>
          )}

          {!loading && error && (
            <Box sx={{ py: 5, textAlign: 'center' }}>
              <Typography color="error" variant="body2" sx={{ mb: 1.5 }}>
                {error}
              </Typography>
              <Button size="small" variant="outlined" onClick={() => void load()} sx={{ textTransform: 'none' }}>
                Thử lại
              </Button>
            </Box>
          )}

          {!loading && !error && items.length === 0 && (
            <Box sx={{ py: 6, textAlign: 'center' }}>
              <CampaignOutlinedIcon sx={{ fontSize: 40, color: alpha(ACCENT, 0.35), mb: 1 }} />
              <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 0.5 }}>
                Chưa có thông báo
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {isAdmin ? 'Nhấn “Tạo thông báo” để đăng tin đầu tiên.' : 'Khi có tin mới sẽ hiện tại đây.'}
              </Typography>
            </Box>
          )}

          {!loading && !error && items.length > 0 && filteredItems.length === 0 && (
            <Box sx={{ py: 5, textAlign: 'center' }}>
              <Typography variant="subtitle2" fontWeight={700} sx={{ mb: 0.5 }}>
                Không có kết quả
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                Thử đổi từ khóa hoặc khoảng ngày.
              </Typography>
              <Button
                size="small"
                startIcon={<FilterAltOffOutlinedIcon />}
                onClick={clearFilters}
                sx={{ textTransform: 'none' }}
              >
                Xóa lọc
              </Button>
            </Box>
          )}

          {!loading && !error && filteredItems.length > 0 && (
            <Stack spacing={1.5}>
              {filteredItems.map((a) => {
                const focused = flashId === a.id;
                const fileCount = a.attachments?.filter((x) => !isImageAttachment(x)).length ?? 0;
                const imageCount = a.attachments?.filter((x) => isImageAttachment(x)).length ?? 0;
                return (
                  <Box
                    key={a.id}
                    id={`announcement-card-${a.id}`}
                    sx={{
                      position: 'relative',
                      borderRadius: 2.5,
                      border: `1px solid ${
                        focused ? alpha(ACCENT, 0.55) : alpha(theme.palette.divider, 0.9)
                      }`,
                      bgcolor: focused ? alpha(ACCENT, 0.04) : alpha(theme.palette.grey[500], 0.02),
                      boxShadow: focused ? `0 0 0 3px ${alpha(ACCENT, 0.12)}` : 'none',
                      transition: 'border-color 0.2s ease, box-shadow 0.2s ease, background 0.2s ease',
                      overflow: 'hidden',
                      '&:hover': {
                        borderColor: alpha(ACCENT, 0.35),
                        bgcolor: alpha(ACCENT, 0.03),
                      },
                    }}
                  >
                    <Box
                      sx={{
                        position: 'absolute',
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4,
                        bgcolor: ACCENT,
                        opacity: focused ? 1 : 0.55,
                      }}
                    />
                    <Stack
                      direction="row"
                      alignItems="flex-start"
                      justifyContent="space-between"
                      gap={1.5}
                      sx={{ p: { xs: 1.75, sm: 2.25 }, pl: { xs: 2.25, sm: 2.75 } }}
                    >
                      <Box sx={{ flex: 1, minWidth: 0 }}>
                        <Stack
                          direction="row"
                          spacing={1}
                          alignItems="center"
                          flexWrap="wrap"
                          useFlexGap
                          sx={{ mb: 1 }}
                        >
                          <Chip
                            size="small"
                            label={formatViDate(a.displayDate, a.publishedAt)}
                            sx={{
                              height: 24,
                              fontWeight: 700,
                              fontSize: 11,
                              borderRadius: 1.25,
                              bgcolor: alpha(ACCENT, 0.1),
                              color: ACCENT,
                              border: `1px solid ${alpha(ACCENT, 0.2)}`,
                            }}
                          />
                          <Typography variant="caption" color="text.secondary">
                            {formatViDateLong(a.displayDate, a.publishedAt)}
                          </Typography>
                          {(fileCount > 0 || imageCount > 0) && (
                            <Chip
                              size="small"
                              icon={<AttachFileOutlinedIcon sx={{ fontSize: '14px !important' }} />}
                              label={
                                fileCount + imageCount > 1
                                  ? `${fileCount + imageCount} đính kèm`
                                  : 'Đính kèm'
                              }
                              variant="outlined"
                              sx={{ height: 22, fontSize: 11, borderRadius: 1.25 }}
                            />
                          )}
                        </Stack>

                        <Typography
                          variant="subtitle1"
                          fontWeight={800}
                          sx={{
                            color: ACCENT,
                            letterSpacing: '-0.015em',
                            lineHeight: 1.35,
                            mb: 0.75,
                          }}
                        >
                          {a.title}
                        </Typography>

                        <Typography
                          component="div"
                          sx={{
                            color: 'text.secondary',
                            whiteSpace: 'pre-wrap',
                            fontSize: '0.9rem',
                            lineHeight: 1.7,
                          }}
                        >
                          {a.body}
                        </Typography>

                        {a.attachments?.length > 0 && (
                          <Stack spacing={1} sx={{ mt: 1.25 }}>
                            {a.attachments.map((att) =>
                              isImageAttachment(att) ? (
                                <InlineAnnouncementImage
                                  key={att.id}
                                  attachmentId={att.id}
                                  alt={att.originalName || 'Ảnh đính kèm'}
                                />
                              ) : (
                                <Link
                                  key={att.id}
                                  component="button"
                                  type="button"
                                  onClick={() =>
                                    void announcementService.openAnnouncementAttachmentInline(att.id)
                                  }
                                  sx={{
                                    alignSelf: 'flex-start',
                                    display: 'inline-flex',
                                    alignItems: 'center',
                                    gap: 0.75,
                                    cursor: 'pointer',
                                    textDecoration: 'none',
                                    fontWeight: 600,
                                    fontSize: '0.875rem',
                                    color: ACCENT,
                                    px: 1.25,
                                    py: 0.75,
                                    borderRadius: 1.5,
                                    bgcolor: alpha(ACCENT, 0.06),
                                    border: `1px solid ${alpha(ACCENT, 0.18)}`,
                                    '&:hover': {
                                      bgcolor: alpha(ACCENT, 0.1),
                                      textDecoration: 'underline',
                                    },
                                  }}
                                >
                                  <AttachFileOutlinedIcon sx={{ fontSize: 16 }} />
                                  {att.linkLabel || att.originalName}
                                </Link>
                              ),
                            )}
                          </Stack>
                        )}

                        {a.authorUsername && (
                          <Typography
                            variant="caption"
                            color="text.disabled"
                            display="block"
                            sx={{ mt: 1.5 }}
                          >
                            Đăng bởi {a.authorUsername}
                          </Typography>
                        )}
                      </Box>

                      {isAdmin && (
                        <Tooltip title="Xóa thông báo">
                          <IconButton
                            size="small"
                            onClick={() => void onDelete(a.id)}
                            sx={{
                              color: 'text.secondary',
                              border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                              borderRadius: 1.5,
                              '&:hover': {
                                color: 'error.main',
                                borderColor: alpha(theme.palette.error.main, 0.4),
                                bgcolor: alpha(theme.palette.error.main, 0.06),
                              },
                            }}
                            aria-label="Xóa"
                          >
                            <DeleteOutlineIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      )}
                    </Stack>
                  </Box>
                );
              })}
            </Stack>
          )}
        </Box>
      </Paper>

      <Dialog
        open={dialogOpen}
        onClose={() => !saving && setDialogOpen(false)}
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
            pb: 2,
            background: `linear-gradient(135deg, ${alpha(ACCENT, 0.14)} 0%, ${alpha(ACCENT, 0.04)} 100%)`,
            borderBottom: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
          }}
        >
          <Stack direction="row" alignItems="flex-start" justifyContent="space-between" gap={1}>
            <Stack direction="row" spacing={1.5} alignItems="center">
              <Box
                sx={{
                  width: 40,
                  height: 40,
                  borderRadius: 2,
                  display: 'grid',
                  placeItems: 'center',
                  bgcolor: alpha(ACCENT, 0.16),
                  color: ACCENT,
                }}
              >
                <CampaignOutlinedIcon />
              </Box>
              <Box>
                <Typography variant="overline" sx={{ fontWeight: 700, color: ACCENT, letterSpacing: '0.1em' }}>
                  Nội bộ
                </Typography>
                <Typography variant="h6" fontWeight={800} sx={{ letterSpacing: '-0.02em', lineHeight: 1.2 }}>
                  Đăng thông báo
                </Typography>
              </Box>
            </Stack>
            <IconButton size="small" onClick={() => setDialogOpen(false)} disabled={saving}>
              <CloseIcon />
            </IconButton>
          </Stack>
        </Box>

        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 2.5, pb: 1, px: 2.5 }}>
          <DatePickerField
            label="Ngày hiển thị"
            value={formDate}
            onChange={setFormDate}
            helperText="Để trống sẽ dùng ngày đăng."
            sx={dateTimeFieldSx}
          />
          <TextField
            label="Tiêu đề"
            value={formTitle}
            onChange={(e) => setFormTitle(e.target.value)}
            fullWidth
            required
            size="small"
            sx={dateTimeFieldSx}
          />
          <TextField
            label="Nội dung"
            value={formBody}
            onChange={(e) => setFormBody(e.target.value)}
            fullWidth
            required
            multiline
            minRows={5}
            size="small"
            sx={dateTimeFieldSx}
          />
          <Divider />
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ sm: 'center' }}>
            <Button
              variant="outlined"
              component="label"
              startIcon={<AttachFileOutlinedIcon />}
              sx={{ textTransform: 'none', borderRadius: 2, alignSelf: 'flex-start' }}
            >
              Đính kèm file
              <input
                type="file"
                hidden
                multiple
                accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.zip"
                onChange={onPickFiles}
              />
            </Button>
            {formFiles.length > 0 && (
              <Typography variant="body2" color="text.secondary">
                Đã chọn <strong>{formFiles.length}</strong> file
              </Typography>
            )}
          </Stack>
          <TextField
            label="Chữ hiển thị cho liên kết tài liệu"
            value={formLinkLabel}
            onChange={(e) => setFormLinkLabel(e.target.value)}
            fullWidth
            size="small"
            placeholder="tại đây"
            helperText="Áp dụng cho file không phải ảnh. Ảnh hiển thị trực tiếp."
            sx={dateTimeFieldSx}
          />
        </DialogContent>
        <DialogActions sx={{ px: 2.5, pb: 2.5, pt: 1, gap: 1 }}>
          <Button onClick={() => setDialogOpen(false)} disabled={saving} sx={{ textTransform: 'none' }}>
            Hủy
          </Button>
          <Button
            variant="contained"
            onClick={() => void submitCreate()}
            disabled={saving || !formTitle.trim() || !formBody.trim()}
            sx={{
              textTransform: 'none',
              fontWeight: 700,
              borderRadius: 2,
              px: 2.5,
              bgcolor: ACCENT,
              '&:hover': { bgcolor: '#0d9488' },
            }}
          >
            {saving ? <CircularProgress size={22} color="inherit" /> : 'Đăng thông báo'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
