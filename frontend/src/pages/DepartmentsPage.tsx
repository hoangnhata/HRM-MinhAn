import AddIcon from '@mui/icons-material/Add';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import EditIcon from '@mui/icons-material/Edit';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Paper,
  Snackbar,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import * as departmentService from '../services/departmentService';

export default function DepartmentsPage() {
  const theme = useTheme();
  const [rows, setRows] = useState<departmentService.DepartmentRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [dialogMode, setDialogMode] = useState<'create' | 'edit'>('create');
  const [editId, setEditId] = useState<number | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [saving, setSaving] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<departmentService.DepartmentRow | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
    open: false,
    message: '',
    severity: 'success',
  });

  const load = async () => {
    setLoading(true);
    try {
      const data = await departmentService.fetchDepartments();
      setRows(data);
    } catch {
      setSnackbar({ open: true, message: 'Không tải được danh sách phòng ban.', severity: 'error' });
      setRows([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const openCreate = () => {
    setDialogMode('create');
    setEditId(null);
    setName('');
    setDescription('');
    setDialogOpen(true);
  };

  const openEdit = (d: departmentService.DepartmentRow) => {
    setDialogMode('edit');
    setEditId(d.id);
    setName(d.name);
    setDescription(d.description ?? '');
    setDialogOpen(true);
  };

  const submit = async () => {
    if (!name.trim()) return;
    setSaving(true);
    try {
      const payload: departmentService.DepartmentPayload = {
        name: name.trim(),
        description: description.trim() || null,
      };
      if (dialogMode === 'create') {
        await departmentService.createDepartment(payload);
        setSnackbar({ open: true, message: 'Đã thêm phòng ban.', severity: 'success' });
      } else if (editId != null) {
        await departmentService.updateDepartment(editId, payload);
        setSnackbar({ open: true, message: 'Đã cập nhật phòng ban.', severity: 'success' });
      }
      setDialogOpen(false);
      await load();
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? (e as { response?: { data?: { message?: string } } }).response?.data?.message
          : undefined;
      setSnackbar({
        open: true,
        message: msg || 'Không lưu được. Thử lại.',
        severity: 'error',
      });
    } finally {
      setSaving(false);
    }
  };

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await departmentService.deleteDepartment(deleteTarget.id);
      setSnackbar({ open: true, message: 'Đã xóa phòng ban.', severity: 'success' });
      setDeleteTarget(null);
      await load();
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? (e as { response?: { data?: { message?: string } } }).response?.data?.message
          : undefined;
      setSnackbar({
        open: true,
        message: msg || 'Không xóa được (có thể còn nhân viên thuộc phòng ban).',
        severity: 'error',
      });
    } finally {
      setDeleting(false);
    }
  };

  return (
    <Box sx={{ width: '100%' }}>
      <PageHeader
        overline="Quản trị"
        title="Phòng ban"
        description="Danh mục đơn vị / phòng ban — dùng khi gán nhân viên và thống kê. Mã nội bộ do hệ thống tự tạo."
        actions={
          <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate} sx={{ textTransform: 'none' }}>
            Thêm phòng ban
          </Button>
        }
      />

      <TableContainer
        component={Paper}
        elevation={0}
        sx={{
          borderRadius: 3,
          border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
        }}
      >
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
            <CircularProgress />
          </Box>
        ) : (
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell sx={{ fontWeight: 700 }}>Tên</TableCell>
                <TableCell sx={{ fontWeight: 700 }}>Mô tả</TableCell>
                <TableCell align="right" sx={{ fontWeight: 700, width: 120 }}>
                  Thao tác
                </TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {rows.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={3}>
                    <Typography variant="body2" color="text.secondary">
                      Chưa có phòng ban nào.
                    </Typography>
                  </TableCell>
                </TableRow>
              ) : (
                rows.map((r) => (
                  <TableRow key={r.id} hover>
                    <TableCell>{r.name}</TableCell>
                    <TableCell sx={{ maxWidth: 420 }}>
                      <Typography variant="body2" color="text.secondary" noWrap title={r.description ?? undefined}>
                        {r.description || '—'}
                      </Typography>
                    </TableCell>
                    <TableCell align="right">
                      <Tooltip title="Sửa">
                        <IconButton size="small" onClick={() => openEdit(r)} aria-label="Sửa">
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Xóa">
                        <IconButton size="small" color="error" onClick={() => setDeleteTarget(r)} aria-label="Xóa">
                          <DeleteOutlineIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        )}
      </TableContainer>

      <Dialog open={dialogOpen} onClose={() => !saving && setDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{dialogMode === 'create' ? 'Thêm phòng ban' : 'Sửa phòng ban'}</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
          <TextField label="Tên" value={name} onChange={(e) => setName(e.target.value)} required size="small" fullWidth />
          <TextField
            label="Mô tả"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            size="small"
            fullWidth
            multiline
            minRows={2}
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setDialogOpen(false)} disabled={saving}>
            Hủy
          </Button>
          <Button variant="contained" onClick={() => void submit()} disabled={saving || !name.trim()}>
            {saving ? <CircularProgress size={22} /> : 'Lưu'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={Boolean(deleteTarget)} onClose={() => !deleting && setDeleteTarget(null)}>
        <DialogTitle>Xóa phòng ban?</DialogTitle>
        <DialogContent>
          {deleteTarget && (
            <Typography variant="body2" color="text.secondary">
              Xóa <strong>{deleteTarget.name}</strong>? Chỉ xóa được khi không còn nhân viên thuộc phòng ban này.
            </Typography>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteTarget(null)} disabled={deleting}>
            Hủy
          </Button>
          <Button color="error" variant="contained" onClick={() => void confirmDelete()} disabled={deleting}>
            {deleting ? <CircularProgress size={22} /> : 'Xóa'}
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={5000}
        onClose={() => setSnackbar((s) => ({ ...s, open: false }))}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert severity={snackbar.severity} onClose={() => setSnackbar((s) => ({ ...s, open: false }))} variant="filled">
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
}
