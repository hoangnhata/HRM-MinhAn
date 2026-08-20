import DrawIcon from '@mui/icons-material/Draw';
import UploadFileIcon from '@mui/icons-material/UploadFile';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Stack,
  Typography,
} from '@mui/material';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import * as accountService from '../services/accountService';

/** Bắt buộc tạo chữ ký số sau đổi mật khẩu lần đầu. */
export function SignatureRequiredPage() {
  const { user, refreshUser } = useAuth();
  const navigate = useNavigate();
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const drawing = useRef(false);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  /** Ảnh đã tải — chờ người dùng xem và xác nhận trước khi lưu. */
  const [pendingImage, setPendingImage] = useState<string | null>(null);

  useEffect(() => {
    if (user?.mustChangePassword) {
      navigate('/change-password-required', { replace: true });
      return;
    }
    if (user && !user.mustSetSignature) {
      navigate('/', { replace: true });
    }
  }, [user, navigate]);

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

  useEffect(() => {
    if (pendingImage) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ratio = window.devicePixelRatio || 1;
    const cssW = canvas.clientWidth || 560;
    const cssH = 200;
    canvas.width = Math.floor(cssW * ratio);
    canvas.height = Math.floor(cssH * ratio);
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    clearCanvas();
  }, [clearCanvas, pendingImage]);

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
      if (data[i] < 250 || data[i + 1] < 250 || data[i + 2] < 250) return true;
    }
    return false;
  }

  async function persist(imageBase64: string) {
    setSaving(true);
    setErr(null);
    try {
      await accountService.saveMySignature(imageBase64);
      await refreshUser();
      navigate('/', { replace: true });
    } catch {
      setErr('Không lưu được chữ ký. Thử lại.');
    } finally {
      setSaving(false);
    }
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

  function onUploadFile(file: File | null) {
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      setErr('Chỉ chấp nhận file ảnh PNG/JPG.');
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setErr('Ảnh tối đa 2MB.');
      return;
    }
    setErr(null);
    const reader = new FileReader();
    reader.onload = () => {
      const result = typeof reader.result === 'string' ? reader.result : null;
      if (!result) return;
      setPendingImage(result);
    };
    reader.readAsDataURL(file);
  }

  function cancelPendingImage() {
    setPendingImage(null);
    setErr(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  }

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'grey.100',
        p: 2,
      }}
    >
      <Card sx={{ maxWidth: 640, width: '100%' }}>
        <CardContent sx={{ p: 3 }}>
          <Typography variant="h6" fontWeight={700} gutterBottom>
            Tạo chữ ký số
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2.5 }}>
            Xin chào <strong>{user?.fullName ?? user?.username}</strong>. Lần đầu đăng nhập bạn cần tạo chữ ký số
            để ký duyệt trên hệ thống.
          </Typography>
          {err && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {err}
            </Alert>
          )}

          {pendingImage ? (
            <>
              <Alert severity="info" sx={{ mb: 2 }}>
                Kiểm tra ảnh chữ ký bên dưới. Chỉ khi bạn bấm <strong>Xác nhận</strong> chữ ký mới được lưu.
              </Alert>
              <Box
                sx={{
                  border: '1px solid',
                  borderColor: 'divider',
                  borderRadius: 2,
                  bgcolor: '#fff',
                  mb: 2,
                  p: 2,
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  minHeight: 200,
                }}
              >
                <Box
                  component="img"
                  src={pendingImage}
                  alt="Xem trước chữ ký"
                  sx={{ maxWidth: '100%', maxHeight: 220, objectFit: 'contain' }}
                />
              </Box>
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}>
                <Button variant="outlined" onClick={cancelPendingImage} disabled={saving}>
                  Chọn lại
                </Button>
                <Button
                  variant="outlined"
                  component="label"
                  startIcon={<UploadFileIcon />}
                  disabled={saving}
                >
                  Tải ảnh khác
                  <input
                    ref={fileInputRef}
                    type="file"
                    hidden
                    accept="image/png,image/jpeg"
                    onChange={(e) => void onUploadFile(e.target.files?.[0] ?? null)}
                  />
                </Button>
                <Button
                  variant="contained"
                  onClick={() => void persist(pendingImage)}
                  disabled={saving}
                  sx={{ ml: { sm: 'auto' } }}
                >
                  {saving ? 'Đang lưu…' : 'Xác nhận và vào hệ thống'}
                </Button>
              </Stack>
            </>
          ) : (
            <>
              <Box
                sx={{
                  border: '1px solid',
                  borderColor: 'divider',
                  borderRadius: 2,
                  bgcolor: '#fff',
                  mb: 2,
                  overflow: 'hidden',
                }}
              >
                <canvas
                  ref={canvasRef}
                  style={{
                    width: '100%',
                    height: 200,
                    touchAction: 'none',
                    display: 'block',
                    cursor: 'crosshair',
                  }}
                  onPointerDown={onPointerDown}
                  onPointerMove={onPointerMove}
                  onPointerUp={onPointerUp}
                  onPointerLeave={onPointerUp}
                />
              </Box>
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}>
                <Button variant="outlined" onClick={clearCanvas} disabled={saving}>
                  Xóa chữ ký
                </Button>
                <Button
                  variant="outlined"
                  component="label"
                  startIcon={<UploadFileIcon />}
                  disabled={saving}
                >
                  Tải ảnh chữ ký
                  <input
                    ref={fileInputRef}
                    type="file"
                    hidden
                    accept="image/png,image/jpeg"
                    onChange={(e) => void onUploadFile(e.target.files?.[0] ?? null)}
                  />
                </Button>
                <Button
                  variant="contained"
                  startIcon={<DrawIcon />}
                  onClick={() => void saveFromCanvas()}
                  disabled={saving}
                  sx={{ ml: { sm: 'auto' } }}
                >
                  {saving ? 'Đang lưu…' : 'Lưu và vào hệ thống'}
                </Button>
              </Stack>
            </>
          )}
        </CardContent>
      </Card>
    </Box>
  );
}
