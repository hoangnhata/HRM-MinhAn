import CloseIcon from '@mui/icons-material/Close';
import {
  Box,
  Dialog,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import type { DepartmentDetailReport } from '../../../services/nursingActivityReportService';

const ACCENT = '#0f766e';

type Props = {
  open: boolean;
  detail: DepartmentDetailReport | null;
  loading: boolean;
  onClose: () => void;
};

export function ModuleADepartmentDetailDialog({ open, detail, loading, onClose }: Props) {
  const m = detail?.metrics;

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle sx={{ pr: 6 }}>
        Chi tiết khoa — {detail?.departmentName ?? '…'}
        <IconButton onClick={onClose} sx={{ position: 'absolute', right: 12, top: 12 }} aria-label="Đóng">
          <CloseIcon />
        </IconButton>
      </DialogTitle>
      <DialogContent dividers>
        {loading && !detail ? (
          <Typography color="text.secondary" sx={{ py: 4, textAlign: 'center' }}>Đang tải…</Typography>
        ) : detail && m ? (
          <Stack spacing={2}>
            <Typography variant="caption" color="text.secondary">
              Kỳ: {detail.fromLabel} – {detail.toLabel}
            </Typography>
            <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr 1fr', sm: 'repeat(3, 1fr)' }, gap: 1 }}>
              {[
                ['ĐD đi làm', detail.rawTotals.workingStaff],
                ['NB nội trú', detail.rawTotals.inpatients],
                ['Tổng nhân viên', detail.rawTotals.totalStaff],
                ['Giường thực kê', detail.rawTotals.actualBeds],
                ['Ngày nằm viện', detail.rawTotals.inpatientTreatmentDays],
                ['Ca té ngã', detail.rawTotals.falls],
                ['Ca loét mới', detail.rawTotals.newPressureUlcers],
                ['Nhầm xác định NB', detail.rawTotals.idMixups],
                ['NB sai sót thuốc', detail.rawTotals.medicationErrors],
              ].map(([label, val]) => (
                <Box key={label} sx={{ p: 1.2, borderRadius: 2, border: `1px solid ${alpha('#64748b', 0.12)}` }}>
                  <Typography variant="caption" color="text.secondary">{label}</Typography>
                  <Typography variant="subtitle1" fontWeight={800} sx={{ color: ACCENT }}>{val}</Typography>
                </Box>
              ))}
            </Box>
            <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 1 }}>
              {[
                ['Té ngã', m.fallRateLabel, m.fallFrequencyLabel],
                ['Loét tì đè', m.pressureUlcerRateLabel, m.pressureUlcerFrequencyLabel],
                ['ĐD/NB', m.nurseBedRatioLabel, null],
                ['Nhầm NB', m.idMixupFrequencyLabel, null],
                ['Sai sót thuốc', m.medicationErrorRateLabel, null],
              ].map(([title, a, b]) => (
                <Box key={title} sx={{ p: 1.2, borderRadius: 2, bgcolor: alpha(ACCENT, 0.04), border: `1px solid ${alpha(ACCENT, 0.12)}` }}>
                  <Typography variant="caption" fontWeight={800} color="text.secondary">{title}</Typography>
                  <Typography variant="body2" fontWeight={700}>{a}</Typography>
                  {b && <Typography variant="caption" color="text.secondary">{b}</Typography>}
                </Box>
              ))}
            </Box>
            <Typography variant="subtitle2" fontWeight={800}>Dữ liệu từng ngày</Typography>
            <TableContainer sx={{ borderRadius: 2, border: `1px solid ${alpha('#64748b', 0.1)}` }}>
              <Table size="small">
                <TableHead>
                  <TableRow sx={{ bgcolor: alpha(ACCENT, 0.06) }}>
                    <TableCell sx={{ fontWeight: 800 }}>Ngày</TableCell>
                    <TableCell align="right" sx={{ fontWeight: 800 }}>NB nội trú</TableCell>
                    <TableCell align="right" sx={{ fontWeight: 800 }}>Té ngã</TableCell>
                    <TableCell align="right" sx={{ fontWeight: 800 }}>Loét mới</TableCell>
                    <TableCell align="right" sx={{ fontWeight: 800 }}>Nhầm NB</TableCell>
                    <TableCell align="right" sx={{ fontWeight: 800 }}>Sai sót thuốc</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {detail.dailyRows.length === 0 ? (
                    <TableRow><TableCell colSpan={6} align="center" sx={{ py: 3, color: 'text.secondary' }}>Chưa có dữ liệu</TableCell></TableRow>
                  ) : detail.dailyRows.map((r) => (
                    <TableRow key={r.reportDate}>
                      <TableCell>{r.reportDateLabel}</TableCell>
                      <TableCell align="right">{r.inpatients}</TableCell>
                      <TableCell align="right">{r.falls}</TableCell>
                      <TableCell align="right">{r.newPressureUlcers}</TableCell>
                      <TableCell align="right">{r.idMixups}</TableCell>
                      <TableCell align="right">{r.medicationErrors}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </Stack>
        ) : (
          <Typography color="text.secondary" sx={{ py: 3, textAlign: 'center' }}>Không tải được dữ liệu</Typography>
        )}
      </DialogContent>
    </Dialog>
  );
}
