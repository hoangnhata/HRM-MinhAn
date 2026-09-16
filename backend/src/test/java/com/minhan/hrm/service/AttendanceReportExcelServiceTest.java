package com.minhan.hrm.service;

import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class AttendanceReportExcelServiceTest {

    @Test
    void exportsPaidLeaveCalendarAndLeaveUnitsInSummary() throws Exception {
        AttendanceSummaryService summaryService = mock(AttendanceSummaryService.class);
        when(summaryService.monthReport(2026, 7, null)).thenReturn(List.of(employeeRow()));

        AttendanceReportExcelService service = new AttendanceReportExcelService(summaryService);
        byte[] report = service.buildMonthlyReport(2026, 7, null);

        try (XSSFWorkbook workbook = new XSSFWorkbook(new ByteArrayInputStream(report))) {
            assertEquals(6, workbook.getNumberOfSheets());
            assertEquals("Tổng hợp", workbook.getSheetName(0));
            assertEquals("Bảng chấm công", workbook.getSheetName(1));
            assertEquals("Bảng công trực", workbook.getSheetName(2));
            assertEquals("Bảng công phép", workbook.getSheetName(3));
            assertEquals("Bảng công Quang Trung", workbook.getSheetName(4));
            assertEquals("Chi tiết theo ngày", workbook.getSheetName(5));

            Sheet summary = workbook.getSheet("Tổng hợp");
            Row summaryHeader = summary.getRow(4);
            Row summaryData = summary.getRow(5);
            assertEquals("Bộ phận", summaryHeader.getCell(4).getStringCellValue());
            assertEquals("Tổ hành chính", summaryData.getCell(4).getStringCellValue());
            assertEquals("Chức vụ", summaryHeader.getCell(5).getStringCellValue());
            assertEquals("Công chấm", summaryHeader.getCell(6).getStringCellValue());
            assertEquals(1d, summaryData.getCell(6).getNumericCellValue(), 0.001d);
            assertEquals("Công điều động", summaryHeader.getCell(7).getStringCellValue());
            assertEquals(0d, summaryData.getCell(7).getNumericCellValue(), 0.001d);
            assertEquals("Công trực", summaryHeader.getCell(8).getStringCellValue());
            assertEquals(0.33d, summaryData.getCell(8).getNumericCellValue(), 0.001d);
            assertEquals("Công Quang Trung", summaryHeader.getCell(9).getStringCellValue());
            assertEquals(1d, summaryData.getCell(9).getNumericCellValue(), 0.001d);
            assertEquals("Tổng công", summaryHeader.getCell(10).getStringCellValue());
            // Tổng = chấm 1 + điều động 0 + trực 0.33 (phép không cộng)
            assertEquals(1.33d, summaryData.getCell(10).getNumericCellValue(), 0.001d);
            assertEquals("Công phép", summaryHeader.getCell(11).getStringCellValue());
            assertEquals(1d, summaryData.getCell(11).getNumericCellValue(), 0.001d);
            assertEquals("Phụ cấp Quang Trung (đ)", summaryHeader.getCell(19).getStringCellValue());
            assertEquals(100000d, summaryData.getCell(19).getNumericCellValue(), 0.001d);
            assertEquals("Tiền hỗ trợ (đ)", summaryHeader.getCell(20).getStringCellValue());
            assertEquals(500000d, summaryData.getCell(20).getNumericCellValue(), 0.001d);
            assertEquals("Kỷ luật", summaryHeader.getCell(21).getStringCellValue());
            assertEquals("#,##0", summaryData.getCell(19).getCellStyle().getDataFormatString());
            assertEquals("#,##0", summaryData.getCell(20).getCellStyle().getDataFormatString());
            assertTrue(summary.getColumnWidth(19) >= 5000);
            Row summaryTotal = summary.getRow(6);
            assertEquals(1d, summaryTotal.getCell(9).getNumericCellValue(), 0.001d);
            assertEquals(1.33d, summaryTotal.getCell(10).getNumericCellValue(), 0.001d);
            assertEquals(1d, summaryTotal.getCell(11).getNumericCellValue(), 0.001d);
            assertEquals(100000d, summaryTotal.getCell(19).getNumericCellValue(), 0.001d);
            assertEquals(500000d, summaryTotal.getCell(20).getNumericCellValue(), 0.001d);

            Sheet leave = workbook.getSheet("Bảng công phép");
            assertNotNull(leave);
            Row leaveData = leave.getRow(5);
            int firstDayCol = 4;
            int countCol = firstDayCol + 31;
            int unitsCol = countCol + 1;
            assertEquals(1d, leaveData.getCell(firstDayCol + 5).getNumericCellValue(), 0.001d);
            assertEquals("", leaveData.getCell(firstDayCol + 6).getStringCellValue());
            assertEquals(1d, leaveData.getCell(countCol).getNumericCellValue(), 0.001d);
            assertEquals(1d, leaveData.getCell(unitsCol).getNumericCellValue(), 0.001d);

            Sheet quangTrung = workbook.getSheet("Bảng công Quang Trung");
            assertNotNull(quangTrung);
            Row qtData = quangTrung.getRow(5);
            int qtCountCol = firstDayCol + 31;
            int qtUnitsCol = qtCountCol + 1;
            int qtAllowanceCol = qtUnitsCol + 1;
            assertEquals(1d, qtData.getCell(firstDayCol + 7).getNumericCellValue(), 0.001d);
            assertEquals(1d, qtData.getCell(qtCountCol).getNumericCellValue(), 0.001d);
            assertEquals(1d, qtData.getCell(qtUnitsCol).getNumericCellValue(), 0.001d);
            assertEquals(100000d, qtData.getCell(qtAllowanceCol).getNumericCellValue(), 0.001d);
        }
    }

    private static Map<String, Object> employeeRow() {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("employeeCode", "NV001");
        row.put("fullName", "Nguyễn Văn A");
        row.put("department", "Phòng Hành chính");
        row.put("workUnitDetail", "Tổ hành chính");
        row.put("position", "Nhân viên");
        row.put("attendanceWorkUnits", new BigDecimal("1.00"));
        row.put("clockedWorkUnits", new BigDecimal("1.00"));
        row.put("leaveWorkUnits", new BigDecimal("1.00"));
        row.put("deploymentWorkUnits", BigDecimal.ZERO);
        row.put("dutyWorkUnitsTotal", new BigDecimal("0.33"));
        row.put("totalWorkUnits", new BigDecimal("1.33"));
        row.put("dutyShiftCount", 1);
        row.put("lateMinutesTotal", 0);
        row.put("latePenalty", BigDecimal.ZERO);
        row.put("forgotFineCount", 0);
        row.put("forgotPenalty", BigDecimal.ZERO);
        row.put("dutyBonusTotal", new BigDecimal("230000"));
        row.put("mealAllowance", new BigDecimal("60000"));
        row.put("quangTrungAllowance", new BigDecimal("100000"));
        row.put("seminarSupportTotal", new BigDecimal("500000"));
        row.put("requiresDiscipline", false);
        row.put("days", new ArrayList<>(List.of(
                day("2026-07-06", "LEAVE", "1.00", false),
                day("2026-07-07", "UNPAID_LEAVE", "0.00", false),
                day("2026-07-08", "PRESENT", "1.00", true))));
        row.put("dutyDays", List.of(Map.of(
                "workDate", "2026-07-08",
                "workUnits", new BigDecimal("0.33"),
                "shiftTypeLabel", "Trực chính")));
        return row;
    }

    private static Map<String, Object> day(
            String workDate, String status, String totalWorkUnits, boolean quangTrung) {
        Map<String, Object> day = new LinkedHashMap<>();
        day.put("workDate", workDate);
        day.put("status", status);
        day.put("morningCheckIn", "");
        day.put("morningCheckOut", "");
        day.put("afternoonCheckIn", "");
        day.put("afternoonCheckOut", "");
        day.put("morningWorkUnits", BigDecimal.ZERO);
        day.put("afternoonWorkUnits", BigDecimal.ZERO);
        day.put("overtimeWorkUnits", BigDecimal.ZERO);
        day.put("totalWorkUnits", new BigDecimal(totalWorkUnits));
        day.put("lateMinutes", 0);
        day.put("quangTrung", quangTrung);
        day.put("note", quangTrung ? AttendanceService.QUANG_TRUNG_NOTE_MARKER : "");
        return day;
    }
}
