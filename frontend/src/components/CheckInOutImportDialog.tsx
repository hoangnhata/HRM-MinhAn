import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  LinearProgress,
  Typography,
} from '@mui/material';
import { useEffect, useState } from 'react';
import axios from 'axios';
import * as importService from '../services/importService';

function importErrorMessage(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const status = err.response?.status;
    const msg = (err.response?.data as { message?: string } | undefined)?.message;
    if (status === 403) {
      return msg ?? 'Không có quyền import (cần tài khoản ADMIN hoặc HR).';
    }
    if (status === 413) {
      return 'File quá lớn (tối đa 100MB).';
    }
    if (msg) return msg;
    if (err.code === 'ECONNABORTED') {
      return 'Import quá thời gian chờ — file lớn có thể cần vài phút, thử lại hoặc chia nhỏ file.';
    }
  }
  return 'Import thất bại. Kiểm tra định dạng file, quyền ADMIN/HR và kích thước file (tối đa ~100MB).';
}

type Props = {
  open: boolean;
  onClose: () => void;
  onImported?: () => void;
};

export function CheckInOutImportDialog({ open, onClose, onImported }: Props) {
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<importService.ImportCheckInOutResult | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) {
      setFile(null);
      setResult(null);
      setErr(null);
      setLoading(false);
    }
  }, [open]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setResult(null);
    if (!file) {
      setErr('Chọn file .sql export từ máy chấm công (CheckInOut).');
      return;
    }
    setLoading(true);
    try {
      const r = await importService.importCheckInOutSql(file);
      setResult(r);
      onImported?.();
    } catch (e) {
      setErr(importErrorMessage(e));
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open={open} onClose={loading ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Import dữ liệu chấm công (SQL)</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Upload file export <strong>CheckInOut</strong> từ hệ thống máy chấm công. Hệ thống gộp các lần quẹt trong ngày
          thành giờ vào/ra và lưu vào bảng công. Mã chấm công lấy từ file Excel nhân lực (cột <strong>Mã chấm công</strong>)
          khi import nhân sự.
        </Typography>

        <Box component="form" id="checkinout-import-form" onSubmit={onSubmit}>
          <Button variant="outlined" component="label" startIcon={<CloudUploadIcon />} sx={{ mb: 2 }}>
            Chọn file .sql
            <input type="file" hidden accept=".sql,text/plain" onChange={(ev) => setFile(ev.target.files?.[0] ?? null)} />
          </Button>
          {file && (
            <Typography variant="body2" sx={{ mb: 2 }}>
              Đã chọn: {file.name} ({(file.size / (1024 * 1024)).toFixed(1)} MB)
            </Typography>
          )}
          {loading && (
            <>
              <LinearProgress sx={{ mb: 1 }} />
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                Đang xử lý… file lớn có thể mất vài phút.
              </Typography>
            </>
          )}
          {err && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {err}
            </Alert>
          )}
        </Box>

        {result && (
          <Box sx={{ mt: 1 }}>
            <Typography variant="subtitle2" gutterBottom>
              Kết quả
            </Typography>
            <Typography variant="body2">Lượt quẹt thẻ (raw): {result.rawPunches.toLocaleString()}</Typography>
            <Typography variant="body2">Ngày công (gộp): {result.dailyRecords.toLocaleString()}</Typography>
            <Typography variant="body2">Đã lưu bảng công: {result.upserted.toLocaleString()}</Typography>
            <Typography variant="body2">
              Bỏ qua (chưa map NV): {result.skippedNoEmployee.toLocaleString()} — {result.unmappedEnrollCount} mã chấm công
            </Typography>
            {result.unmappedEnrollNumbers.length > 0 && (
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                Mã chưa map (tối đa 50): {result.unmappedEnrollNumbers.join(', ')}
              </Typography>
            )}
          </Box>
        )}
      </DialogContent>
      <DialogActions sx={{ px: 3, pb: 2 }}>
        <Button onClick={onClose} disabled={loading}>
          Đóng
        </Button>
        <Button type="submit" form="checkinout-import-form" variant="contained" disabled={loading}>
          Bắt đầu import
        </Button>
      </DialogActions>
    </Dialog>
  );
}
