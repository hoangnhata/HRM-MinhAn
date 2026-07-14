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
  /** Gọi sau khi import thành công (để làm mới danh sách) */
  onImported?: () => void;
};

export function WorkforceImportDialog({ open, onClose, onImported }: Props) {
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
      setErr('Chọn file .xlsx (TỔNG HỢP THÔNG TIN NHÂN LỰC.BVMA).');
      return;
    }
    setLoading(true);
    try {
      const r = await importService.importWorkforceExcel(file);
      setResult(r);
      onImported?.();
    } catch {
      setErr('Import thất bại. Kiểm tra định dạng file và quyền HCNS/ADMIN.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open={open} onClose={loading ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Import nhân lực từ Excel</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          File mẫu: <strong>TỔNG HỢP THÔNG TIN NHÂN LỰC.BVMA.xlsx</strong> — hỗ trợ sheet{' '}
          <em>Danh sách NV chính thức</em> và <em>Thử việcThực tập</em>. Hệ thống tự nhận diện sheet và map cột vào hồ sơ.
        </Typography>

        <Box component="form" id="workforce-import-form" onSubmit={onSubmit}>
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
            <Typography variant="body2">Tạo mới: {result.created}</Typography>
            <Typography variant="body2">Cập nhật: {result.updated}</Typography>
            {result.sheetsProcessed && result.sheetsProcessed.length > 0 && (
              <Typography variant="body2" sx={{ mt: 1 }}>
                Sheet đã xử lý: {result.sheetsProcessed.join(', ')}
              </Typography>
            )}
            {result.errors.length > 0 && (
              <Box sx={{ mt: 2 }}>
                <Typography color="error" fontWeight={600}>
                  Lỗi theo dòng:
                </Typography>
                <Box component="ul" sx={{ m: 0, pl: 2.5 }}>
                  {result.errors.map((x, i) => (
                    <li key={i}>
                      <Typography variant="body2" component="span">
                        {x.sheet ? `${x.sheet} — ` : ''}Dòng {x.row}: {x.message}
                      </Typography>
                    </li>
                  ))}
                </Box>
              </Box>
            )}
          </Box>
        )}
      </DialogContent>
      <DialogActions sx={{ px: 3, pb: 2 }}>
        <Button onClick={onClose} disabled={loading}>
          Đóng
        </Button>
        <Button type="submit" form="workforce-import-form" variant="contained" disabled={loading}>
          Bắt đầu import
        </Button>
      </DialogActions>
    </Dialog>
  );
}
