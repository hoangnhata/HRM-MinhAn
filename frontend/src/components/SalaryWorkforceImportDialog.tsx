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
import * as importService from '../services/importService';

type Props = {
  open: boolean;
  onClose: () => void;
  onImported?: () => void;
};

/**
 * Import bảng lương / thâm niên từ file NHÂN LỰC BỆNH VIỆN MINH AN.
 */
export function SalaryWorkforceImportDialog({ open, onClose, onImported }: Props) {
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<importService.ImportWorkforceResult | null>(null);
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
      setErr('Chọn file Excel NHÂN LỰC BỆNH VIỆN MINH AN (.xlsx).');
      return;
    }
    setLoading(true);
    try {
      const r = await importService.importWorkforceExcel(file);
      setResult(r);
      onImported?.();
    } catch {
      setErr('Import thất bại. Kiểm tra định dạng file và quyền ADMIN/HCNS.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open={open} onClose={loading ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Import bảng lương</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          File <strong>NHÂN LỰC BỆNH VIỆN MINH AN.xlsx</strong> — sheet{' '}
          <em>DS NV chính thức phần mềm</em>:
        </Typography>
        <Box component="ul" sx={{ m: 0, mb: 2, pl: 2.5 }}>
          <li>
            <Typography variant="body2" component="span">
              Thâm niên mốc <strong>30/06</strong> → hiện tại = mốc + (ngày hiện tại − 30/06) / 365
            </Typography>
          </li>
          <li>
            <Typography variant="body2" component="span">
              Không có mốc → (ngày hiện tại − ngày bắt đầu tính thang bảng lương) / 365
            </Typography>
          </li>
          <li>
            <Typography variant="body2" component="span">
              Bậc / đối tượng / lương cơ bản / lương đảm bảo SP / LĐG
            </Typography>
          </li>
        </Box>

        <Box component="form" id="salary-workforce-import-form" onSubmit={onSubmit}>
          <Button variant="outlined" component="label" startIcon={<CloudUploadIcon />} sx={{ mb: 2 }}>
            Chọn file .xlsx
            <input
              type="file"
              hidden
              accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              onChange={(ev) => setFile(ev.target.files?.[0] ?? null)}
            />
          </Button>
          {file && (
            <Typography variant="body2" sx={{ mb: 2 }}>
              Đã chọn: {file.name}
            </Typography>
          )}
          {loading && <LinearProgress sx={{ mb: 2 }} />}
          {err && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {err}
            </Alert>
          )}
          {result && (
            <Alert severity={result.errors?.length ? 'warning' : 'success'} sx={{ mb: 1 }}>
              Tạo mới {result.created ?? 0}, cập nhật {result.updated ?? 0}
              {result.errors?.length ? `, lỗi ${result.errors.length}` : ''}.
            </Alert>
          )}
        </Box>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={loading}>
          Đóng
        </Button>
        <Button type="submit" form="salary-workforce-import-form" variant="contained" disabled={loading || !file}>
          {loading ? 'Đang import…' : 'Import'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
