import AccountTreeOutlinedIcon from '@mui/icons-material/AccountTreeOutlined';
import AddIcon from '@mui/icons-material/Add';
import ApartmentIcon from '@mui/icons-material/Apartment';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import DescriptionOutlinedIcon from '@mui/icons-material/DescriptionOutlined';
import DomainIcon from '@mui/icons-material/Domain';
import EditIcon from '@mui/icons-material/Edit';
import GroupsIcon from '@mui/icons-material/Groups';
import SearchIcon from '@mui/icons-material/Search';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Grid,
  IconButton,
  InputAdornment,
  List,
  ListItem,
  ListItemSecondaryAction,
  ListItemText,
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
import { useEffect, useMemo, useState } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import { useAuth } from '../context/AuthContext';
import * as departmentService from '../services/departmentService';
import * as employeeService from '../services/employeeService';

type DeptEmployeeStats = { total: number; official: number; trial: number };

function StatCard({
  label,
  value,
  icon,
  tone,
}: {
  label: string;
  value: number;
  icon: React.ReactNode;
  tone: 'primary' | 'success' | 'neutral';
}) {
  const theme = useTheme();
  const palette =
    tone === 'primary'
      ? theme.palette.primary
      : tone === 'success'
        ? theme.palette.success
        : { main: '#64748b', dark: '#475569' };

  return (
    <Card
      elevation={0}
      sx={{
        height: '100%',
        border: `1px solid ${alpha(palette.main, 0.14)}`,
        background: `linear-gradient(135deg, ${alpha(palette.main, 0.07)} 0%, ${theme.palette.background.paper} 100%)`,
      }}
    >
      <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2, py: 2.25 }}>
        <Box
          sx={{
            width: 48,
            height: 48,
            borderRadius: 2,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            bgcolor: alpha(palette.main, 0.12),
            color: palette.dark ?? palette.main,
          }}
        >
          {icon}
        </Box>
        <Box>
          <Typography variant="h5" fontWeight={700} lineHeight={1.2}>
            {value}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {label}
          </Typography>
        </Box>
      </CardContent>
    </Card>
  );
}

export default function DepartmentsPage() {
  const theme = useTheme();
  const { user } = useAuth();
  const canEdit = user?.role === 'ADMIN' || user?.role === 'HR';
  const [rows, setRows] = useState<departmentService.DepartmentRow[]>([]);
  const [employeeCounts, setEmployeeCounts] = useState<Map<number, DeptEmployeeStats>>(new Map());
  const [workUnitCounts, setWorkUnitCounts] = useState<Map<number, number>>(new Map());
  const [loading, setLoading] = useState(true);
  const [qInput, setQInput] = useState('');
  const [q, setQ] = useState('');
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
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

  const [unitsDept, setUnitsDept] = useState<departmentService.DepartmentRow | null>(null);
  const [workUnits, setWorkUnits] = useState<departmentService.WorkUnitRow[]>([]);
  const [unitsLoading, setUnitsLoading] = useState(false);
  const [unitDialogOpen, setUnitDialogOpen] = useState(false);
  const [unitEditId, setUnitEditId] = useState<number | null>(null);
  const [unitName, setUnitName] = useState('');
  const [unitDescription, setUnitDescription] = useState('');
  const [unitSaving, setUnitSaving] = useState(false);
  const [unitDeleteId, setUnitDeleteId] = useState<number | null>(null);

  useEffect(() => {
    const t = setTimeout(() => {
      setQ(qInput);
      setPage(0);
    }, 300);
    return () => clearTimeout(t);
  }, [qInput]);

  const load = async () => {
    setLoading(true);
    try {
      const statsPromise =
        user?.role === 'ADMIN' || user?.role === 'HR'
          ? employeeService.fetchDashboardStats().catch(() => null)
          : Promise.resolve(null);
      const [data, stats] = await Promise.all([departmentService.fetchDepartments(), statsPromise]);
      setRows(data);
      if (stats?.employeesByDepartment) {
        const map = new Map<number, DeptEmployeeStats>();
        for (const item of stats.employeesByDepartment) {
          if (item.departmentId != null) {
            map.set(item.departmentId, {
              total: item.count ?? 0,
              official: item.officialCount ?? 0,
              trial: item.trialCount ?? 0,
            });
          }
        }
        setEmployeeCounts(map);
      } else {
        setEmployeeCounts(new Map());
      }

      const unitCountMap = new Map<number, number>();
      await Promise.all(
        data.map(async (d) => {
          try {
            const units = await departmentService.fetchWorkUnits(d.id);
            unitCountMap.set(d.id, units.length);
          } catch {
            unitCountMap.set(d.id, 0);
          }
        }),
      );
      setWorkUnitCounts(unitCountMap);
    } catch {
      setSnackbar({ open: true, message: 'Không tải được danh sách phòng ban.', severity: 'error' });
      setRows([]);
      setEmployeeCounts(new Map());
      setWorkUnitCounts(new Map());
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, [user?.role]);

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    if (!needle) return rows;
    return rows.filter(
      (r) =>
        r.name.toLowerCase().includes(needle) ||
        r.code.toLowerCase().includes(needle) ||
        (r.description?.toLowerCase().includes(needle) ?? false)
    );
  }, [rows, q]);

  const paged = useMemo(() => {
    const start = page * rowsPerPage;
    return filtered.slice(start, start + rowsPerPage);
  }, [filtered, page, rowsPerPage]);

  const statsSummary = useMemo(() => {
    const withDescription = rows.filter((r) => r.description?.trim()).length;
    let totalEmployees = 0;
    employeeCounts.forEach((v) => {
      totalEmployees += v.total;
    });
    let totalUnits = 0;
    workUnitCounts.forEach((v) => {
      totalUnits += v;
    });
    return { total: rows.length, withDescription, totalEmployees, totalUnits };
  }, [rows, employeeCounts, workUnitCounts]);

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

  async function openWorkUnits(dept: departmentService.DepartmentRow) {
    setUnitsDept(dept);
    setUnitsLoading(true);
    try {
      const list = await departmentService.fetchWorkUnits(dept.id);
      setWorkUnits(list);
    } catch {
      setWorkUnits([]);
      setSnackbar({ open: true, message: 'Không tải được danh sách bộ phận.', severity: 'error' });
    } finally {
      setUnitsLoading(false);
    }
  }

  function openCreateUnit() {
    setUnitEditId(null);
    setUnitName('');
    setUnitDescription('');
    setUnitDialogOpen(true);
  }

  function openEditUnit(u: departmentService.WorkUnitRow) {
    setUnitEditId(u.id);
    setUnitName(u.name);
    setUnitDescription(u.description ?? '');
    setUnitDialogOpen(true);
  }

  async function submitUnit() {
    if (!unitsDept || !unitName.trim()) return;
    setUnitSaving(true);
    try {
      const payload = { name: unitName.trim(), description: unitDescription.trim() || null };
      if (unitEditId == null) {
        await departmentService.createWorkUnit(unitsDept.id, payload);
        setSnackbar({ open: true, message: 'Đã thêm bộ phận.', severity: 'success' });
      } else {
        await departmentService.updateWorkUnit(unitsDept.id, unitEditId, payload);
        setSnackbar({ open: true, message: 'Đã cập nhật bộ phận.', severity: 'success' });
      }
      setUnitDialogOpen(false);
      const list = await departmentService.fetchWorkUnits(unitsDept.id);
      setWorkUnits(list);
      setWorkUnitCounts((prev) => new Map(prev).set(unitsDept.id, list.length));
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? (e as { response?: { data?: { message?: string } } }).response?.data?.message
          : undefined;
      setSnackbar({ open: true, message: msg || 'Không lưu được bộ phận.', severity: 'error' });
    } finally {
      setUnitSaving(false);
    }
  }

  async function confirmDeleteUnit() {
    if (!unitsDept || unitDeleteId == null) return;
    setUnitSaving(true);
    try {
      await departmentService.deleteWorkUnit(unitsDept.id, unitDeleteId);
      setUnitDeleteId(null);
      setSnackbar({ open: true, message: 'Đã xóa bộ phận.', severity: 'success' });
      const list = await departmentService.fetchWorkUnits(unitsDept.id);
      setWorkUnits(list);
      setWorkUnitCounts((prev) => new Map(prev).set(unitsDept.id, list.length));
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? (e as { response?: { data?: { message?: string } } }).response?.data?.message
          : undefined;
      setSnackbar({ open: true, message: msg || 'Không xóa được bộ phận.', severity: 'error' });
    } finally {
      setUnitSaving(false);
    }
  }

  return (
    <Box sx={{ width: '100%' }}>
      <PageHeader
        overline="Tổ chức"
        title="Phòng ban"
        description={
          canEdit
            ? 'Quản lý phòng ban và bộ phận bên trong — 1 phòng ban có nhiều bộ phận. Import Excel tự tạo bộ phận theo cột «Bộ phận».'
            : 'Danh mục phòng ban / bộ phận (chỉ xem).'
        }
        actions={
          canEdit ? (
            <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate} sx={{ textTransform: 'none' }}>
              Thêm phòng ban
            </Button>
          ) : undefined
        }
      />

      <Grid container spacing={2} sx={{ mb: 2.5 }}>
        <Grid item xs={12} sm={3}>
          <StatCard label="Tổng phòng ban" value={statsSummary.total} icon={<DomainIcon />} tone="primary" />
        </Grid>
        <Grid item xs={12} sm={3}>
          <StatCard label="Tổng bộ phận" value={statsSummary.totalUnits} icon={<AccountTreeOutlinedIcon />} tone="success" />
        </Grid>
        <Grid item xs={12} sm={3}>
          <StatCard label="Đã có mô tả" value={statsSummary.withDescription} icon={<DescriptionOutlinedIcon />} tone="neutral" />
        </Grid>
        <Grid item xs={12} sm={3}>
          <StatCard label="Nhân viên đang gán" value={statsSummary.totalEmployees} icon={<GroupsIcon />} tone="success" />
        </Grid>
      </Grid>

      <Paper
        elevation={0}
        sx={{
          p: 2.25,
          mb: 2.5,
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
          bgcolor: alpha(theme.palette.background.paper, 0.92),
        }}
      >
        <TextField
          size="small"
          fullWidth
          placeholder="Tìm theo tên, mã hoặc mô tả phòng ban…"
          value={qInput}
          onChange={(e) => setQInput(e.target.value)}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon fontSize="small" color="action" />
              </InputAdornment>
            ),
          }}
          sx={{ maxWidth: 480 }}
        />
      </Paper>

      <TableContainer
        component={Paper}
        elevation={0}
        sx={{
          borderRadius: 2.5,
          border: `1px solid ${theme.palette.divider}`,
          overflow: 'hidden',
        }}
      >
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
            <CircularProgress />
          </Box>
        ) : (
          <>
            <Table size="small" stickyHeader>
              <TableHead>
                <TableRow>
                  <TableCell sx={{ fontWeight: 700, bgcolor: 'background.paper', width: 100 }}>Mã</TableCell>
                  <TableCell sx={{ fontWeight: 700, bgcolor: 'background.paper' }}>Tên phòng ban</TableCell>
                  <TableCell sx={{ fontWeight: 700, bgcolor: 'background.paper' }}>Mô tả</TableCell>
                  <TableCell sx={{ fontWeight: 700, bgcolor: 'background.paper', width: 120 }} align="center">
                    Bộ phận
                  </TableCell>
                  <TableCell sx={{ fontWeight: 700, bgcolor: 'background.paper', width: 140 }} align="center">
                    Nhân viên
                  </TableCell>
                  {canEdit && (
                    <TableCell align="right" sx={{ fontWeight: 700, bgcolor: 'background.paper', width: 140 }}>
                      Thao tác
                    </TableCell>
                  )}
                </TableRow>
              </TableHead>
              <TableBody>
                {paged.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={canEdit ? 6 : 5}>
                      <Stack alignItems="center" spacing={1.5} sx={{ py: 5 }}>
                        <ApartmentIcon sx={{ fontSize: 48, color: alpha(theme.palette.primary.main, 0.35) }} />
                        <Typography variant="body1" fontWeight={600}>
                          {q ? 'Không tìm thấy phòng ban phù hợp' : 'Chưa có phòng ban nào'}
                        </Typography>
                        <Typography variant="body2" color="text.secondary" textAlign="center" maxWidth={360}>
                          {q
                            ? 'Thử từ khóa khác hoặc xóa bộ lọc tìm kiếm.'
                            : canEdit
                              ? 'Bấm "Thêm phòng ban" để tạo đơn vị đầu tiên trong hệ thống.'
                              : 'Liên hệ quản trị viên để thêm phòng ban.'}
                        </Typography>
                        {canEdit && !q && (
                          <Button variant="outlined" startIcon={<AddIcon />} onClick={openCreate} sx={{ mt: 0.5 }}>
                            Thêm phòng ban
                          </Button>
                        )}
                      </Stack>
                    </TableCell>
                  </TableRow>
                ) : (
                  paged.map((r) => {
                    const counts = employeeCounts.get(r.id);
                    const unitCount = workUnitCounts.get(r.id) ?? 0;
                    return (
                      <TableRow
                        key={r.id}
                        hover
                        sx={{
                          '&:last-child td': { borderBottom: 0 },
                          transition: 'background-color 0.15s ease',
                        }}
                      >
                        <TableCell>
                          <Chip
                            size="small"
                            label={r.code}
                            sx={{
                              fontWeight: 600,
                              fontFamily: 'monospace',
                              bgcolor: alpha(theme.palette.primary.main, 0.08),
                            }}
                          />
                        </TableCell>
                        <TableCell>
                          <Stack direction="row" spacing={1.25} alignItems="center">
                            <Box
                              sx={{
                                width: 32,
                                height: 32,
                                borderRadius: 1.5,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                bgcolor: alpha(theme.palette.primary.main, 0.08),
                                color: theme.palette.primary.main,
                                flexShrink: 0,
                              }}
                            >
                              <DomainIcon sx={{ fontSize: 18 }} />
                            </Box>
                            <Typography variant="body2" fontWeight={600}>
                              {r.name}
                            </Typography>
                          </Stack>
                        </TableCell>
                        <TableCell sx={{ maxWidth: 360 }}>
                          <Typography
                            variant="body2"
                            color={r.description ? 'text.primary' : 'text.secondary'}
                            sx={{
                              display: '-webkit-box',
                              WebkitLineClamp: 2,
                              WebkitBoxOrient: 'vertical',
                              overflow: 'hidden',
                            }}
                            title={r.description ?? undefined}
                          >
                            {r.description?.trim() || 'Chưa có mô tả'}
                          </Typography>
                        </TableCell>
                        <TableCell align="center">
                          <Chip
                            size="small"
                            icon={<AccountTreeOutlinedIcon sx={{ fontSize: '16px !important' }} />}
                            label={unitCount}
                            color={unitCount > 0 ? 'success' : 'default'}
                            variant={unitCount > 0 ? 'filled' : 'outlined'}
                            onClick={() => void openWorkUnits(r)}
                            sx={{ cursor: 'pointer', minWidth: 64 }}
                          />
                        </TableCell>
                        <TableCell align="center">
                          {counts ? (
                            <Tooltip
                              title={`Chính thức: ${counts.official} · Thử việc/TT: ${counts.trial}`}
                            >
                              <Chip
                                size="small"
                                icon={<GroupsIcon sx={{ fontSize: '16px !important' }} />}
                                label={counts.total}
                                color={counts.total > 0 ? 'primary' : 'default'}
                                variant={counts.total > 0 ? 'filled' : 'outlined'}
                                sx={{
                                  width: 70,
                                  minWidth: 70,
                                  justifyContent: 'center',
                                  '& .MuiChip-label': { flex: 1, textAlign: 'center', px: 0.25 },
                                }}
                              />
                            </Tooltip>
                          ) : (
                            <Typography variant="caption" color="text.secondary">
                              —
                            </Typography>
                          )}
                        </TableCell>
                        {canEdit && (
                          <TableCell align="right">
                            <Tooltip title="Quản lý bộ phận">
                              <IconButton size="small" onClick={() => void openWorkUnits(r)} aria-label="Bộ phận">
                                <ApartmentIcon fontSize="small" />
                              </IconButton>
                            </Tooltip>
                            <Tooltip title="Sửa">
                              <IconButton size="small" onClick={() => openEdit(r)} aria-label="Sửa">
                                <EditIcon fontSize="small" />
                              </IconButton>
                            </Tooltip>
                            <Tooltip title="Xóa">
                              <IconButton
                                size="small"
                                color="error"
                                onClick={() => setDeleteTarget(r)}
                                aria-label="Xóa"
                              >
                                <DeleteOutlineIcon fontSize="small" />
                              </IconButton>
                            </Tooltip>
                          </TableCell>
                        )}
                      </TableRow>
                    );
                  })
                )}
              </TableBody>
            </Table>
            {filtered.length > 0 && (
              <TablePagination
                component="div"
                count={filtered.length}
                page={page}
                onPageChange={(_, p) => setPage(p)}
                rowsPerPage={rowsPerPage}
                onRowsPerPageChange={(e) => {
                  setRowsPerPage(parseInt(e.target.value, 10));
                  setPage(0);
                }}
                rowsPerPageOptions={[10, 25, 50, 100]}
                labelRowsPerPage="Số dòng"
                labelDisplayedRows={({ from, to, count }) => `${from}–${to} / ${count}`}
              />
            )}
          </>
        )}
      </TableContainer>

      <Dialog
        open={dialogOpen}
        onClose={() => !saving && setDialogOpen(false)}
        maxWidth="sm"
        fullWidth
        PaperProps={{ sx: { borderRadius: 2.5 } }}
      >
        <DialogTitle sx={{ pb: 0.5 }}>
          <Stack direction="row" spacing={1.5} alignItems="center">
            <Box
              sx={{
                width: 40,
                height: 40,
                borderRadius: 2,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: alpha(theme.palette.primary.main, 0.1),
                color: theme.palette.primary.main,
              }}
            >
              <DomainIcon />
            </Box>
            <Box>
              <Typography variant="h6" fontWeight={700}>
                {dialogMode === 'create' ? 'Thêm phòng ban' : 'Sửa phòng ban'}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Mã nội bộ được hệ thống tự sinh khi lưu
              </Typography>
            </Box>
          </Stack>
        </DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 2 }}>
          <TextField
            label="Tên phòng ban"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            size="small"
            fullWidth
            placeholder="VD: KHOA NỘI TỔNG HỢP"
          />
          <TextField
            label="Mô tả"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            size="small"
            fullWidth
            multiline
            minRows={3}
            placeholder="Ghi chú chức năng, vị trí trong cơ cấu tổ chức (tùy chọn)…"
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5, pt: 1 }}>
          <Button onClick={() => setDialogOpen(false)} disabled={saving}>
            Hủy
          </Button>
          <Button variant="contained" onClick={() => void submit()} disabled={saving || !name.trim()}>
            {saving ? <CircularProgress size={22} /> : 'Lưu'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={Boolean(deleteTarget)} onClose={() => !deleting && setDeleteTarget(null)} PaperProps={{ sx: { borderRadius: 2.5 } }}>
        <DialogTitle>Xóa phòng ban?</DialogTitle>
        <DialogContent>
          {deleteTarget && (
            <Typography variant="body2" color="text.secondary">
              Xóa <strong>{deleteTarget.name}</strong> (mã <strong>{deleteTarget.code}</strong>)? Chỉ xóa được khi
              không còn nhân viên thuộc phòng ban này. Các bộ phận thuộc phòng ban cũng sẽ bị xóa.
            </Typography>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setDeleteTarget(null)} disabled={deleting}>
            Hủy
          </Button>
          <Button color="error" variant="contained" onClick={() => void confirmDelete()} disabled={deleting}>
            {deleting ? <CircularProgress size={22} /> : 'Xóa'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={Boolean(unitsDept)}
        onClose={() => !unitSaving && setUnitsDept(null)}
        maxWidth="sm"
        fullWidth
        PaperProps={{ sx: { borderRadius: 2.5 } }}
      >
        <DialogTitle>
          <Stack direction="row" justifyContent="space-between" alignItems="center" spacing={2}>
            <Box>
              <Typography variant="h6" fontWeight={700}>
                Bộ phận — {unitsDept?.name}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                1 phòng ban có nhiều bộ phận (VD: Khoa CĐHA → Phòng Siêu âm, Phòng Xquang)
              </Typography>
            </Box>
            {canEdit && (
              <Button size="small" startIcon={<AddIcon />} variant="contained" onClick={openCreateUnit}>
                Thêm
              </Button>
            )}
          </Stack>
        </DialogTitle>
        <DialogContent dividers>
          {unitsLoading ? (
            <Box sx={{ py: 4, display: 'flex', justifyContent: 'center' }}>
              <CircularProgress size={28} />
            </Box>
          ) : workUnits.length === 0 ? (
            <Typography variant="body2" color="text.secondary" sx={{ py: 2 }}>
              Chưa có bộ phận. Import Excel hoặc thêm thủ công.
            </Typography>
          ) : (
            <List dense>
              {workUnits.map((u) => (
                <ListItem key={u.id} divider>
                  <ListItemText
                    primary={u.name}
                    secondary={u.description || undefined}
                    primaryTypographyProps={{ fontWeight: 600 }}
                  />
                  {canEdit && (
                    <ListItemSecondaryAction>
                      <IconButton edge="end" size="small" onClick={() => openEditUnit(u)}>
                        <EditIcon fontSize="small" />
                      </IconButton>
                      <IconButton edge="end" size="small" color="error" onClick={() => setUnitDeleteId(u.id)}>
                        <DeleteOutlineIcon fontSize="small" />
                      </IconButton>
                    </ListItemSecondaryAction>
                  )}
                </ListItem>
              ))}
            </List>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setUnitsDept(null)}>Đóng</Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={unitDialogOpen}
        onClose={() => !unitSaving && setUnitDialogOpen(false)}
        maxWidth="xs"
        fullWidth
        PaperProps={{ sx: { borderRadius: 2.5 } }}
      >
        <DialogTitle>{unitEditId == null ? 'Thêm bộ phận' : 'Sửa bộ phận'}</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
          <TextField
            label="Tên bộ phận"
            value={unitName}
            onChange={(e) => setUnitName(e.target.value)}
            required
            size="small"
            fullWidth
            placeholder="VD: PHÒNG SIÊU ÂM"
            autoFocus
          />
          <TextField
            label="Mô tả"
            value={unitDescription}
            onChange={(e) => setUnitDescription(e.target.value)}
            size="small"
            fullWidth
            multiline
            minRows={2}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setUnitDialogOpen(false)} disabled={unitSaving}>
            Hủy
          </Button>
          <Button variant="contained" disabled={unitSaving || !unitName.trim()} onClick={() => void submitUnit()}>
            {unitSaving ? <CircularProgress size={22} /> : 'Lưu'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={unitDeleteId != null} onClose={() => !unitSaving && setUnitDeleteId(null)} PaperProps={{ sx: { borderRadius: 2.5 } }}>
        <DialogTitle>Xóa bộ phận?</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary">
            Xóa bộ phận này khỏi phòng ban? Nhân viên vẫn giữ tên bộ phận trên hồ sơ, chỉ bỏ khỏi danh mục.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setUnitDeleteId(null)} disabled={unitSaving}>
            Hủy
          </Button>
          <Button color="error" variant="contained" disabled={unitSaving} onClick={() => void confirmDeleteUnit()}>
            Xóa
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
