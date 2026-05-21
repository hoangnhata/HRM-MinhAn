import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import EditIcon from '@mui/icons-material/Edit';
import PersonAddIcon from '@mui/icons-material/PersonAdd';
import PictureAsPdfIcon from '@mui/icons-material/PictureAsPdf';
import VisibilityIcon from '@mui/icons-material/Visibility';
import {
  Backdrop,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  MenuItem,
  Paper,
  Snackbar,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { EmployeeFormDialog } from '../components/EmployeeFormDialog';
import { PageHeader } from '../components/layout/PageHeader';
import { WorkforceImportDialog } from '../components/WorkforceImportDialog';
import * as documentService from '../services/documentService';
import * as employeeService from '../services/employeeService';

const STATUS_OPTIONS = [
  { value: '', label: 'Tất cả trạng thái' },
  { value: 'ACTIVE', label: 'Đang làm việc' },
  { value: 'ON_LEAVE', label: 'Nghỉ phép' },
  { value: 'TERMINATED', label: 'Đã nghỉ việc' },
];

export default function EmployeesPage() {
  const theme = useTheme();
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<employeeService.EmployeeSummary[]>([]);
  const [total, setTotal] = useState(0);
  const [size, setSize] = useState(10);
  const [importOpen, setImportOpen] = useState(false);
  const [listVersion, setListVersion] = useState(0);

  const [qInput, setQInput] = useState('');
  const [q, setQ] = useState('');
  const [filterDept, setFilterDept] = useState<number | ''>('');
  const [filterStatus, setFilterStatus] = useState('');
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);

  const [formOpen, setFormOpen] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');
  const [editEmployeeId, setEditEmployeeId] = useState<number | undefined>();

  const [deleteTarget, setDeleteTarget] = useState<{ id: number; name: string } | null>(null);
  const [deleting, setDeleting] = useState(false);

  const [replaceDialogEmployeeId, setReplaceDialogEmployeeId] = useState<number | null>(null);
  const [pdfLoadingId, setPdfLoadingId] = useState<number | null>(null);
  const [uploading, setUploading] = useState(false);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string }>({ open: false, message: '' });

  const pdfTargetRef = useRef<{ employeeId: number; replace: boolean } | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const t = setTimeout(() => {
      setQ(qInput);
      setPage(0);
    }, 400);
    return () => clearTimeout(t);
  }, [qInput]);

  useEffect(() => {
    employeeService.fetchDepartments().then(setDepartments).catch(() => {});
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const data = await employeeService.fetchEmployees({
        page,
        size,
        q: q.trim() || undefined,
        departmentId: filterDept === '' ? undefined : filterDept,
        status: filterStatus || undefined,
      });
      if (!cancelled) {
        setRows(data.content);
        setTotal(data.totalElements);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [page, size, listVersion, q, filterDept, filterStatus]);

  function openCreate() {
    setFormMode('create');
    setEditEmployeeId(undefined);
    setFormOpen(true);
  }

  function openEdit(id: number) {
    setFormMode('edit');
    setEditEmployeeId(id);
    setFormOpen(true);
  }

  async function confirmDelete() {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await employeeService.deleteEmployee(deleteTarget.id);
      setSnackbar({ open: true, message: 'Đã cập nhật trạng thái nhân viên.' });
      setDeleteTarget(null);
      setListVersion((v) => v + 1);
    } catch {
      setSnackbar({ open: true, message: 'Không xóa được nhân viên.' });
    } finally {
      setDeleting(false);
    }
  }

  async function handlePdfClick(employeeId: number) {
    setPdfLoadingId(employeeId);
    try {
      const docs = await documentService.fetchDocuments(employeeId);
      if (docs.length > 0) {
        setReplaceDialogEmployeeId(employeeId);
      } else {
        pdfTargetRef.current = { employeeId, replace: false };
        fileInputRef.current?.click();
      }
    } catch {
      setSnackbar({ open: true, message: 'Không kiểm tra được tài liệu đính kèm.' });
    } finally {
      setPdfLoadingId(null);
    }
  }

  function handleReplaceConfirm() {
    const id = replaceDialogEmployeeId;
    setReplaceDialogEmployeeId(null);
    if (id != null) {
      pdfTargetRef.current = { employeeId: id, replace: true };
      fileInputRef.current?.click();
    }
  }

  function handleReplaceCancel() {
    setReplaceDialogEmployeeId(null);
  }

  async function handleFileSelected(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    const target = pdfTargetRef.current;
    e.target.value = '';
    pdfTargetRef.current = null;
    if (!file || !target) return;

    setUploading(true);
    try {
      if (target.replace) {
        await documentService.deleteAllEmployeeDocuments(target.employeeId);
      }
      await documentService.uploadEmployeePdf(target.employeeId, file);
      setSnackbar({ open: true, message: 'Đã đính kèm PDF thành công.' });
    } catch {
      setSnackbar({ open: true, message: 'Upload PDF thất bại. Chỉ chấp nhận file .pdf.' });
    } finally {
      setUploading(false);
    }
  }

  return (
    <Box>
      <input
        ref={fileInputRef}
        type="file"
        hidden
        accept="application/pdf,.pdf"
        onChange={handleFileSelected}
      />

      <EmployeeFormDialog
        open={formOpen}
        onClose={() => setFormOpen(false)}
        mode={formMode}
        employeeId={editEmployeeId}
        onSuccess={() => setListVersion((v) => v + 1)}
      />

      <Dialog open={replaceDialogEmployeeId != null} onClose={handleReplaceCancel} maxWidth="xs" fullWidth>
        <DialogTitle>Thay thế hồ sơ PDF?</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary">
            Nhân viên đã có hồ sơ. Bạn có muốn thay thế?
          </Typography>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={handleReplaceCancel}>Không</Button>
          <Button variant="contained" onClick={handleReplaceConfirm}>
            Có
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={deleteTarget != null} onClose={() => !deleting && setDeleteTarget(null)}>
        <DialogTitle>Xác nhận</DialogTitle>
        <DialogContent>
          <Typography variant="body2">
            Vô hiệu hóa nhân viên <strong>{deleteTarget?.name}</strong>? Tài khoản sẽ bị khóa.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteTarget(null)} disabled={deleting}>
            Hủy
          </Button>
          <Button color="error" variant="contained" onClick={confirmDelete} disabled={deleting}>
            {deleting ? 'Đang xử lý…' : 'Xác nhận'}
          </Button>
        </DialogActions>
      </Dialog>

      <Backdrop sx={{ color: '#fff', zIndex: (t) => t.zIndex.drawer + 1 }} open={uploading}>
        <CircularProgress color="inherit" />
      </Backdrop>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={5000}
        onClose={() => setSnackbar((s) => ({ ...s, open: false }))}
        message={snackbar.message}
      />

      <PageHeader
        overline="Nhân sự"
        title="Quản lý nhân viên"
        description="Danh sách hồ sơ, lọc theo phòng ban và trạng thái, import Excel BVMA và đính kèm PDF."
        actions={
          <>
            <Button variant="outlined" startIcon={<PersonAddIcon />} onClick={openCreate}>
              Thêm nhân viên
            </Button>
            <Button variant="contained" startIcon={<CloudUploadIcon />} onClick={() => setImportOpen(true)}>
              Import Excel
            </Button>
          </>
        }
      />

      <WorkforceImportDialog
        open={importOpen}
        onClose={() => setImportOpen(false)}
        onImported={() => setListVersion((v) => v + 1)}
      />

      <Paper
        elevation={0}
        sx={{
          p: 2.25,
          mb: 2.5,
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
          bgcolor: alpha(theme.palette.background.paper, 0.92),
          boxShadow: `0 4px 20px ${alpha('#0f172a', 0.04)}`,
        }}
      >
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} alignItems={{ xs: 'stretch', md: 'center' }}>
          <TextField
            size="small"
            label="Tìm theo tên, mã NV, username"
            placeholder="Nhập từ khóa…"
            value={qInput}
            onChange={(e) => setQInput(e.target.value)}
            sx={{ flex: 1, minWidth: 200 }}
          />
          <TextField
            size="small"
            select
            label="Phòng ban"
            value={filterDept}
            onChange={(e) => {
              setFilterDept(e.target.value === '' ? '' : Number(e.target.value));
              setPage(0);
            }}
            sx={{ minWidth: 200 }}
          >
            <MenuItem value="">Tất cả phòng ban</MenuItem>
            {departments.map((d) => (
              <MenuItem key={d.id} value={d.id}>
                {d.name}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            size="small"
            select
            label="Trạng thái"
            value={filterStatus}
            onChange={(e) => {
              setFilterStatus(e.target.value);
              setPage(0);
            }}
            sx={{ minWidth: 180 }}
          >
            {STATUS_OPTIONS.map((o) => (
              <MenuItem key={o.value || 'all'} value={o.value}>
                {o.label}
              </MenuItem>
            ))}
          </TextField>
          <Button
            size="small"
            onClick={() => {
              setQInput('');
              setFilterDept('');
              setFilterStatus('');
              setPage(0);
            }}
          >
            Xóa bộ lọc
          </Button>
        </Stack>
      </Paper>

      <TableContainer
        component={Paper}
        elevation={0}
        sx={{
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.divider, 1)}`,
          overflow: 'hidden',
          boxShadow: `0 4px 24px ${alpha('#0f172a', 0.05)}`,
        }}
      >
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Mã NV</TableCell>
              <TableCell>Họ tên</TableCell>
              <TableCell>Phòng ban</TableCell>
              <TableCell>Chức vụ</TableCell>
              <TableCell>Vai trò</TableCell>
              <TableCell>Trạng thái</TableCell>
              <TableCell align="right" sx={{ width: 168, whiteSpace: 'nowrap' }}>
                Thao tác
              </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((r) => (
              <TableRow key={r.id} hover>
                <TableCell>{r.employeeCode || '—'}</TableCell>
                <TableCell>{r.fullName}</TableCell>
                <TableCell>{r.departmentName}</TableCell>
                <TableCell>{r.positionTitle}</TableCell>
                <TableCell>{r.role}</TableCell>
                <TableCell>{r.status}</TableCell>
                <TableCell align="right">
                  <Stack direction="row" spacing={0.25} justifyContent="flex-end" alignItems="center" flexWrap="wrap">
                    <Tooltip title="Xem chi tiết">
                      <IconButton component={Link} to={`/employees/${r.id}`} size="small" color="primary" aria-label="Chi tiết">
                        <VisibilityIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Sửa">
                      <IconButton size="small" color="primary" aria-label="Sửa" onClick={() => openEdit(r.id)}>
                        <EditIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Xóa / vô hiệu hóa">
                      <IconButton
                        size="small"
                        color="error"
                        aria-label="Xóa"
                        onClick={() => setDeleteTarget({ id: r.id, name: r.fullName })}
                      >
                        <DeleteOutlineIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Đính kèm PDF">
                      <span>
                        <IconButton
                          size="small"
                          color="primary"
                          aria-label="Đính kèm PDF"
                          disabled={pdfLoadingId === r.id}
                          onClick={() => handlePdfClick(r.id)}
                        >
                          {pdfLoadingId === r.id ? <CircularProgress size={20} /> : <PictureAsPdfIcon fontSize="small" />}
                        </IconButton>
                      </span>
                    </Tooltip>
                  </Stack>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
        <TablePagination
          component="div"
          count={total}
          page={page}
          onPageChange={(_, p) => setPage(p)}
          rowsPerPage={size}
          onRowsPerPageChange={(e) => {
            setSize(parseInt(e.target.value, 10));
            setPage(0);
          }}
          rowsPerPageOptions={[5, 10, 20]}
          labelRowsPerPage="Số dòng"
        />
      </TableContainer>
    </Box>
  );
}
