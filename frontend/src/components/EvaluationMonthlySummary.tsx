import {
  Alert,
  Box,
  Button,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import VisibilityIcon from '@mui/icons-material/Visibility';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { NursingEvaluationDetailDialog, type NursingDetailEditRequest } from './NursingEvaluationDetailDialog';
import * as ne from '../services/nursingEvaluationService';

type Props = {
  templateCode: string;
  /** Tăng sau khi lưu phiếu ở panel để tải lại bảng và chi tiết */
  refreshKey?: number;
  onRequestEditEvaluation?: (p: NursingDetailEditRequest) => void;
};

function cellNum(n: number | null | undefined): string {
  if (n == null || Number.isNaN(Number(n))) return '—';
  return String(n);
}

function cellGrade(g: string | null | undefined): string {
  if (g == null || g === '') return '—';
  return String(g);
}

/** P.HCNS / ADMIN: danh sách xếp loại + xem chi tiết từng người */
export function EvaluationMonthlySummary({ templateCode, refreshKey = 0, onRequestEditEvaluation }: Props) {
  const theme = useTheme();
  const [year, setYear] = useState(new Date().getFullYear());
  const [month, setMonth] = useState(new Date().getMonth() + 1);
  const [rows, setRows] = useState<ne.MonthlyEvalSummaryRow[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [detailId, setDetailId] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    ne
      .fetchNursingMonthlySummary(year, month, templateCode)
      .then((r) => {
        if (!cancelled) {
          setRows(r);
          setErr(null);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setErr('Không tải được tổng hợp.');
          setRows([]);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [year, month, templateCode, refreshKey]);

  return (
    <Paper
      variant="outlined"
      sx={{
        p: 2.5,
        mb: 2.5,
        borderRadius: 2.5,
        borderColor: alpha(theme.palette.primary.main, 0.2),
        boxShadow: '0 1px 12px rgba(15, 23, 42, 0.06)',
      }}
    >
      <Typography variant="subtitle1" fontWeight={700} gutterBottom sx={{ mb: 2 }}>
        Tổng hợp xếp loại theo tháng (P. HCNS)
      </Typography>
      <Stack direction="row" spacing={2} sx={{ mb: 2 }} flexWrap="wrap" useFlexGap>
        <TextField
          size="small"
          type="number"
          label="Năm"
          value={year}
          onChange={(e) => setYear(Number(e.target.value))}
          sx={{ width: 120 }}
        />
        <TextField
          size="small"
          type="number"
          label="Tháng"
          value={month}
          onChange={(e) => setMonth(Number(e.target.value))}
          inputProps={{ min: 1, max: 12 }}
          sx={{ width: 120 }}
        />
      </Stack>
      {err && (
        <Alert severity="error" sx={{ mb: 1 }}>
          {err}
        </Alert>
      )}
      <Box sx={{ overflowX: 'auto' }}>
        <Table
          size="small"
          sx={{
            minWidth: 880,
            border: `1px solid ${alpha(theme.palette.divider, 1)}`,
            '& th': { fontWeight: 700, bgcolor: alpha(theme.palette.primary.main, 0.06) },
          }}
        >
          <TableHead>
            <TableRow>
              <TableCell>Khoa / phòng</TableCell>
              <TableCell>Họ tên</TableCell>
              <TableCell align="right">TB 70</TableCell>
              <TableCell align="right">Hội đồng 30</TableCell>
              <TableCell align="right">Tổng 100</TableCell>
              <TableCell>Loại</TableCell>
              <TableCell align="center">Chi tiết</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.length === 0 && (
              <TableRow>
                <TableCell colSpan={7}>
                  <Typography color="text.secondary" variant="body2">
                    Chưa có bản đánh giá nào trong kỳ này.
                  </Typography>
                </TableCell>
              </TableRow>
            )}
            {rows.map((r) => (
              <TableRow key={r.evaluationId} hover>
                <TableCell>{r.departmentName}</TableCell>
                <TableCell>{r.fullName}</TableCell>
                <TableCell align="right">{cellNum(r.deptAvg70)}</TableCell>
                <TableCell align="right">{cellNum(r.hdTotal30)}</TableCell>
                <TableCell align="right">{cellNum(r.total100)}</TableCell>
                <TableCell>{cellGrade(r.overallGrade)}</TableCell>
                <TableCell align="center">
                  <Button
                    size="small"
                    variant="outlined"
                    startIcon={<VisibilityIcon />}
                    onClick={() => setDetailId(r.evaluationId)}
                  >
                    Chi tiết
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Box>

      <NursingEvaluationDetailDialog
        open={detailId != null}
        evaluationId={detailId}
        templateCode={templateCode}
        dataVersion={refreshKey}
        onClose={() => setDetailId(null)}
        onRequestEdit={onRequestEditEvaluation}
      />
    </Paper>
  );
}
