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
            assertEquals(5, workbook.getNumberOfSheets());
            assertEquals("Tổng hợp", workbook.getSheetName(0));
            assertEquals("Bảng chấm công", workbook.getSheetName(1));
            assertEquals("Bảng công trực", workbook.getSheetName(2));
            assertEquals("Bảng công phép", workbook.getSheetName(3));
            assertEquals("Chi tiết theo ngày", workbook.getSheetName(4));

            Sheet summary = workbook.getSheet("Tổng hợp");
            Row summaryHeader = summary.getRow(4);
            Row summaryData = summary.getRow(5);
            assertEquals("Công phép", summaryHeader.getCell(6).getStringCellValue());
            assertEquals(1d, summaryData.getCell(6).getNumericCellValue(), 0.001d);
            assertEquals(2.33d, summaryData.getCell(8).getNumericCellValue(), 0.001d);
            assertEquals("Phụ cấp Quang Trung (đ)", summaryHeader.getCell(16).getStringCellValue());
            assertEquals(100000d, summaryData.getCell(16).getNumericCellValue(), 0.001d);
            assertEquals("Tiền hỗ trợ (đ)", summaryHeader.getCell(17).getStringCellValue());
            assertEquals(500000d, summaryData.getCell(17).getNumericCellValue(), 0.001d);
            assertEquals("Kỷ luật", summaryHeader.getCell(18).getStringCellValue());
            assertEquals("#,##0", summaryData.getCell(16).getCellStyle().getDataFormatString());
            assertEquals("#,##0", summaryData.getCell(17).getCellStyle().getDataFormatString());
            assertTrue(summary.getColumnWidth(16) >= 5000);
            Row summaryTotal = summary.getRow(6);
            assertEquals(100000d, summaryTotal.getCell(16).getNumericCellValue(), 0.001d);
            assertEquals(500000d, summaryTotal.getCell(17).getNumericCellValue(), 0.001d);

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
        }
    }

    private static Map<String, Object> employeeRow() {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("employeeCode", "NV001");
        row.put("fullName", "Nguyễn Văn A");
        row.put("department", "Phòng Hành chính");
        row.put("position", "Nhân viên");
        row.put("attendanceWorkUnits", new BigDecimal("2.00"));
        row.put("dutyWorkUnitsTotal", new BigDecimal("0.33"));
        row.put("totalWorkUnits", new BigDecimal("2.33"));
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
                day("2026-07-06", "LEAVE", "1.00"),
                day("2026-07-07", "UNPAID_LEAVE", "0.00"),
                day("2026-07-08", "PRESENT", "1.00"))));
        row.put("dutyDays", List.of(Map.of(
                "workDate", "2026-07-08",
                "workUnits", new BigDecimal("0.33"),
                "shiftTypeLabel", "Trực chính")));
        return row;
    }

    private static Map<String, Object> day(String workDate, String status, String totalWorkUnits) {
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
        day.put("note", "");
        return day;
    }
}
