import DrawIcon from '@mui/icons-material/Draw';
import UploadFileIcon from '@mui/icons-material/UploadFile';
import {
  Alert,
  Box,
  Button,
  Paper,
  Stack,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useRef, useState } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import * as accountService from '../services/accountService';

export default function SignaturePage() {
  const theme = useTheme();
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const drawing = useRef(false);
  const [hasSignature, setHasSignature] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);

  const clearCanvas = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = '#0f172a';
    ctx.lineWidth = 2.5;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
  }, []);

  const loadExisting = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const me = await accountService.fetchAccountMe();
      setHasSignature(Boolean(me.hasSignature));
      if (previewUrl) URL.revokeObjectURL(previewUrl);
      if (me.hasSignature) {
        const url = await accountService.fetchMySignatureObjectUrl();
        setPreviewUrl(url);
      } else {
        setPreviewUrl(null);
      }
    } catch {
      setErr('Không tải được thông tin chữ ký.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadExisting();
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ratio = window.devicePixelRatio || 1;
    const cssW = canvas.clientWidth || 640;
    const cssH = 220;
    canvas.width = Math.floor(cssW * ratio);
    canvas.height = Math.floor(cssH * ratio);
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    clearCanvas();
  }, [clearCanvas, loading]);

  function pointerPos(e: React.PointerEvent<HTMLCanvasElement>) {
    const canvas = canvasRef.current!;
    const rect = canvas.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  }

  function onPointerDown(e: React.PointerEvent<HTMLCanvasElement>) {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext('2d');
    if (!canvas || !ctx) return;
    drawing.current = true;
    canvas.setPointerCapture(e.pointerId);
    const p = pointerPos(e);
    ctx.beginPath();
    ctx.moveTo(p.x, p.y);
  }

  function onPointerMove(e: React.PointerEvent<HTMLCanvasElement>) {
    if (!drawing.current) return;
    const ctx = canvasRef.current?.getContext('2d');
    if (!ctx) return;
    const p = pointerPos(e);
    ctx.lineTo(p.x, p.y);
    ctx.stroke();
  }

  function onPointerUp(e: React.PointerEvent<HTMLCanvasElement>) {
    drawing.current = false;
    try {
      canvasRef.current?.releasePointerCapture(e.pointerId);
    } catch {
      /* ignore */
    }
  }

  function canvasHasInk(): boolean {
    const canvas = canvasRef.current;
    if (!canvas) return false;
    const ctx = canvas.getContext('2d');
    if (!ctx) return false;
    const { data } = ctx.getImageData(0, 0, canvas.width, canvas.height);
    for (let i = 0; i < data.length; i += 4) {
      // non-white pixel
      if (data[i] < 250 || data[i + 1] < 250 || data[i + 2] < 250) return true;
    }
    return false;
  }

  async function saveFromCanvas() {
    if (!canvasHasInk()) {
      setErr('Hãy ký trên khung bên dưới trước khi lưu.');
      return;
    }
    const dataUrl = canvasRef.current?.toDataURL('image/png');
    if (!dataUrl) return;
    await persist(dataUrl);
  }

  async function onUploadFile(file: File | null) {
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      setErr('Chỉ chấp nhận file ảnh PNG/JPG.');
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setErr('Ảnh tối đa 2MB.');
      return;
    }
    const reader = new FileReader();
    reader.onload = async () => {
      const result = typeof reader.result === 'string' ? reader.result : null;
      if (!result) return;
      await persist(result);
    };
    reader.readAsDataURL(file);
  }

  async function persist(imageBase64: string) {
    setSaving(true);
    setErr(null);
    setMsg(null);
    try {
      await accountService.saveMySignature(imageBase64);
      setMsg('Đã lưu chữ ký vào tài khoản của bạn.');
      clearCanvas();
      await loadExisting();
    } catch {
      setErr('Không lưu được chữ ký. Thử lại.');
    } finally {
      setSaving(false);
    }
  }

  async function removeSignature() {
    if (!window.confirm('Xóa chữ ký hiện tại?')) return;
    setSaving(true);
    setErr(null);
    setMsg(null);
    try {
      await accountService.deleteMySignature();
      setMsg('Đã xóa chữ ký.');
      await loadExisting();
    } catch {
      setErr('Không xóa được chữ ký.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <Box>
      <PageHeader
        overline="Tài khoản"
        title="Chữ ký số"
        description="Mỗi tài khoản tạo một chữ ký riêng. Chữ ký này chỉ bạn sử dụng khi ký trên hệ thống."
      />

      {err && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErr(null)}>
          {err}
        </Alert>
      )}
      {msg && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setMsg(null)}>
          {msg}
        </Alert>
      )}

      <Stack spacing={2.5}>
        <Paper
          elevation={0}
          sx={{
            p: 2.5,
            borderRadius: 2.5,
            border: `1px solid ${theme.palette.divider}`,
          }}
        >
          <Typography variant="subtitle1" fontWeight={700} gutterBottom>
            Chữ ký hiện tại
          </Typography>
          {loading ? (
            <Typography variant="body2" color="text.secondary">
              Đang tải…
            </Typography>
          ) : hasSignature && previewUrl ? (
            <Stack spacing={1.5} alignItems="flex-start">
              <Box
                component="img"
                src={previewUrl}
                alt="Chữ ký của tôi"
                sx={{
                  maxWidth: '100%',
                  maxHeight: 160,
                  objectFit: 'contain',
                  bgcolor: '#fff',
                  border: `1px dashed ${alpha(theme.palette.primary.main, 0.35)}`,
                  borderRadius: 1.5,
                  p: 1,
                }}
              />
              <Button color="error" variant="outlined" disabled={saving} onClick={() => void removeSignature()}>
                Xóa chữ ký
              </Button>
            </Stack>
          ) : (
            <Typography variant="body2" color="text.secondary">
              Bạn chưa có chữ ký. Vẽ hoặc tải ảnh bên dưới để tạo.
            </Typography>
          )}
        </Paper>

        <Paper
          elevation={0}
          sx={{
            p: 2.5,
            borderRadius: 2.5,
            border: `1px solid ${theme.palette.divider}`,
          }}
        >
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.5 }}>
            <DrawIcon color="action" fontSize="small" />
            <Typography variant="subtitle1" fontWeight={700}>
              Vẽ chữ ký
            </Typography>
          </Stack>
          <Box
            sx={{
              border: `1px solid ${theme.palette.divider}`,
              borderRadius: 2,
              overflow: 'hidden',
              bgcolor: '#fff',
              touchAction: 'none',
            }}
          >
            <canvas
              ref={canvasRef}
              style={{ width: '100%', height: 220, display: 'block', cursor: 'crosshair' }}
              onPointerDown={onPointerDown}
              onPointerMove={onPointerMove}
              onPointerUp={onPointerUp}
              onPointerLeave={onPointerUp}
            />
          </Box>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ mt: 2 }}>
            <Button variant="outlined" onClick={clearCanvas} disabled={saving}>
              Xóa nét vẽ
            </Button>
            <Button variant="contained" onClick={() => void saveFromCanvas()} disabled={saving}>
              {saving ? 'Đang lưu…' : 'Lưu chữ ký từ khung vẽ'}
            </Button>
          </Stack>
        </Paper>

        <Paper
          elevation={0}
          sx={{
            p: 2.5,
            borderRadius: 2.5,
            border: `1px solid ${theme.palette.divider}`,
          }}
        >
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.5 }}>
            <UploadFileIcon color="action" fontSize="small" />
            <Typography variant="subtitle1" fontWeight={700}>
              Tải ảnh chữ ký
            </Typography>
          </Stack>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
            PNG hoặc JPG, tối đa 2MB. Nên dùng nền trắng, chữ ký rõ.
          </Typography>
          <Button variant="outlined" component="label" disabled={saving}>
            Chọn file ảnh
            <input
              hidden
              type="file"
              accept="image/png,image/jpeg"
              onChange={(e) => void onUploadFile(e.target.files?.[0] ?? null)}
            />
          </Button>
        </Paper>
      </Stack>
    </Box>
  );
}
