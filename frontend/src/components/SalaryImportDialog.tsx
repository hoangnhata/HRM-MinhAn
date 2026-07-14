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
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import { useEffect, useState } from 'react';
import * as importService from '../services/importService';

type Props = {
  open: boolean;
  onClose: () => void;
  onImported?: () => void;
};

export function SalaryImportDialog({ open, onClose, onImported }: Props) {
  const [tab, setTab] = useState(0);
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<importService.SalaryImportResult | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) {
      setTab(0);
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
      const r =
        tab === 0
          ? await importService.importSalarySeniorityExcel(file)
          : await importService.importSalaryScaleExcel(file);
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
      <DialogTitle>Import dữ liệu lương</DialogTitle>
      <DialogContent>
        <Tabs value={tab} onChange={(_, v) => { setTab(v); setFile(null); setResult(null); setErr(null); }} sx={{ mb: 2 }}>
          <Tab label="Thâm niên NV" />
          <Tab label="Thang bảng lương" />
        </Tabs>

        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          {tab === 0 ? (
            <>
              File <strong>thâm niên nv.xlsx</strong> (sheet <em>nv</em>): cập nhật khối, trình độ, thâm niên, lương thu hút
              theo CCCD / mã NV / họ tên.
            </>
          ) : (
            <>
              File <strong>thang bảng lương ma.xlsx</strong>: nạp thang lương nhân viên (trực tiếp / gián tiếp) và bác sỹ.
            </>
          )}
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
          {loading && (
            <>
              <LinearProgress sx={{ mb: 1 }} />
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                Đang xử lý…
              </Typography>
            </>
          )}
          {err && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {err}
            </Alert>
          )}
          {result && (
            <Alert severity={result.errorCount > 0 ? 'warning' : 'success'} sx={{ mb: 2 }}>
              Tổng {result.totalRows} dòng — thành công {result.successCount} (tạo {result.createdCount}, cập nhật{' '}
              {result.updatedCount}), lỗi {result.errorCount}, không tìm thấy NV {result.notFoundCount}.
              {result.errors.length > 0 && (
                <Typography component="div" variant="caption" sx={{ mt: 1, display: 'block' }}>
                  {result.errors.slice(0, 5).map((e, i) => (
                    <span key={i}>
                      Dòng {String(e.row ?? '?')}: {String(e.message ?? e.error ?? '')}
                      <br />
                    </span>
                  ))}
                  {result.errors.length > 5 && `… và ${result.errors.length - 5} lỗi khác`}
                </Typography>
              )}
            </Alert>
          )}
        </Box>
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
