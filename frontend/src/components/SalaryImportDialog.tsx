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
 * Chỉ còn import định nghĩa thang bảng lương (bậc/hệ số).
 * Thâm niên & lương từng NV đã gộp vào Import nhân lực (file NHÂN LỰC BỆNH VIỆN MINH AN).
 */
export function SalaryImportDialog({ open, onClose, onImported }: Props) {
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<importService.SalaryImportResult | null>(null);
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
      setErr('Chọn file Excel (.xlsx).');
      return;
    }
    setLoading(true);
    try {
      const r = await importService.importSalaryScaleExcel(file);
      setResult(r);
      onImported?.();
    } catch {
      setErr('Import thất bại. Kiểm tra định dạng file và quyền ADMIN/HR.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open={open} onClose={loading ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Import thang bảng lương</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          File <strong>thang bảng lương ma.xlsx</strong>: nạp định nghĩa bậc (trực tiếp / gián tiếp / bác sỹ).
          <br />
          Thâm niên và lương từng nhân viên: dùng <strong>Import nhân lực</strong> (file NHÂN LỰC BỆNH VIỆN MINH AN).
        </Typography>

        <Box component="form" id="salary-import-form" onSubmit={onSubmit}>
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
        </Box>

        {result && (
          <Box sx={{ mt: 1 }}>
            <Typography variant="subtitle2" gutterBottom>
              Kết quả
            </Typography>
            <Typography variant="body2">Tổng dòng: {result.totalRows}</Typography>
            <Typography variant="body2">Thành công: {result.successCount}</Typography>
            <Typography variant="body2">Tạo mới: {result.createdCount}</Typography>
            <Typography variant="body2">Cập nhật: {result.updatedCount}</Typography>
            {result.errorCount > 0 && (
              <Typography variant="body2" color="error">
                Lỗi: {result.errorCount}
              </Typography>
            )}
          </Box>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={loading}>
          Đóng
        </Button>
        <Button type="submit" form="salary-import-form" variant="contained" disabled={loading || !file}>
          Import
        </Button>
      </DialogActions>
    </Dialog>
  );
}
