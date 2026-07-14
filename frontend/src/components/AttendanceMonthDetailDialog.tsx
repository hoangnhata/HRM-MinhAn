import {
  Chip,
  Dialog,
  DialogContent,
  DialogTitle,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from "@mui/material";
import { useEffect, useState } from "react";
import * as att from "../services/attendanceService";
import { formatWorkUnits } from "../utils/shiftSchedule";

type Props = {
  open: boolean;
  onClose: () => void;
  employeeId: number;
  employeeName: string;
  year: number;
  month: number;
};

export function AttendanceMonthDetailDialog({
  open,
  onClose,
  employeeId,
  employeeName,
  year,
  month,
}: Props) {
  const [detail, setDetail] = useState<att.MonthSummary | null>(null);

  useEffect(() => {
    if (!open) return;
    att
      .fetchMonthDetail(employeeId, year, month)
      .then(setDetail)
      .catch(() => setDetail(null));
  }, [open, employeeId, year, month]);

  return (
    <Dialog open={open} onClose={onClose} maxWidth="lg" fullWidth>
      <DialogTitle>
        Chi tiết công — {employeeName} ({month}/{year})
      </DialogTitle>
      <DialogContent>
        {detail && (
          <>
            <Typography variant="body2" sx={{ mb: 2 }}>
              Tổng công:{" "}
              <strong>{formatWorkUnits(detail.totalWorkUnits)}</strong> ·
              Muộn/sớm: {detail.lateMinutesTotal} phút →{" "}
              {att.formatMoney(detail.latePenalty)}{" "}
              {detail.latePenaltyTier && `(${detail.latePenaltyTier})`} · Quên
              chấm: {detail.forgotFineCount} lần phạt →{" "}
              {att.formatMoney(detail.forgotPenalty)}
            </Typography>
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Ngày</TableCell>
                    <TableCell>Sáng vào/ra</TableCell>
                    <TableCell>Chiều vào/ra</TableCell>
                    <TableCell align="right">Công</TableCell>
                    <TableCell align="right">Phút muộn</TableCell>
                    <TableCell>Ghi chú</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {(detail.days ?? []).map((d) => (
                    <TableRow key={d.workDate}>
                      <TableCell>{d.workDate}</TableCell>
                      <TableCell>
                        {d.morningCheckIn || "—"} / {d.morningCheckOut || "—"}
                      </TableCell>
                      <TableCell>
                        {d.afternoonCheckIn || "—"} /{" "}
                        {d.afternoonCheckOut || "—"}
                      </TableCell>
                      <TableCell align="right">
                        {formatWorkUnits(d.totalWorkUnits)}
                      </TableCell>
                      <TableCell align="right">
                        {d.lateMinutesExempt ? (
                          <Chip size="small" label="Miễn" color="success" />
                        ) : (
                          d.lateMinutes
                        )}
                      </TableCell>
                      <TableCell>
                        {d.forgotShifts ? `Thiếu: ${d.forgotShifts}` : d.note}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
