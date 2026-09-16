package com.minhan.hrm.service;

import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.io.ByteArrayInputStream;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DeploymentRequestExcelServiceTest {

    private static final int COL_FORM = 11;
    private static final int COL_ACTUAL_HOURS = 12;
    private static final int COL_CREDITED_HOURS = 13;
    private static final int COL_REASON = 14;
    private static final int COL_STATUS = 15;

    @Test
    void splitsDeploymentHoursIntoActualAndCreditedColumns() throws Exception {
        LocalDate day = LocalDate.of(2026, 9, 1);
        Sheet sheet = buildSheet(day, List.of(
                outsideShiftRow(day, 2.67, 4.0),
                insideShiftRow(day, 1.0)));

        Row header = headerRow(sheet);
        assertEquals("Hình thức", header.getCell(COL_FORM).getStringCellValue());
        assertEquals("Tổng giờ điều động", header.getCell(COL_ACTUAL_HOURS).getStringCellValue());
        assertEquals("Tổng giờ quy đổi", header.getCell(COL_CREDITED_HOURS).getStringCellValue());
        assertEquals("Lý do", header.getCell(COL_REASON).getStringCellValue());
        assertEquals("Trạng thái", header.getCell(COL_STATUS).getStringCellValue());

        Row outside = sheet.getRow(header.getRowNum() + 1);
        assertEquals("Ngoài ca", outside.getCell(COL_FORM).getStringCellValue());
        assertEquals(CellType.NUMERIC, outside.getCell(COL_ACTUAL_HOURS).getCellType());
        assertEquals(2.67, outside.getCell(COL_ACTUAL_HOURS).getNumericCellValue(), 1e-9);
        assertEquals(4.0, outside.getCell(COL_CREDITED_HOURS).getNumericCellValue(), 1e-9);
        assertTrue(outside.getCell(COL_ACTUAL_HOURS).getCellStyle().getDataFormatString().contains("giờ"));
        assertEquals("Điều động hỗ trợ", outside.getCell(COL_REASON).getStringCellValue());
    }

    @Test
    void insideShiftKeepsWorkUnitsAndLeavesCreditedBlank() throws Exception {
        LocalDate day = LocalDate.of(2026, 9, 2);
        Sheet sheet = buildSheet(day, List.of(insideShiftRow(day, 0.5)));

        Row inside = sheet.getRow(headerRow(sheet).getRowNum() + 1);
        assertEquals("Trong ca", inside.getCell(COL_FORM).getStringCellValue());
        assertEquals(0.5, inside.getCell(COL_ACTUAL_HOURS).getNumericCellValue(), 1e-9);
        assertTrue(inside.getCell(COL_ACTUAL_HOURS).getCellStyle().getDataFormatString().contains("công"));
        assertEquals("", inside.getCell(COL_CREDITED_HOURS).getStringCellValue());
    }

    private static Sheet buildSheet(LocalDate day, List<Map<String, Object>> rows) throws Exception {
        AttendanceWorkRequestService requestService = Mockito.mock(AttendanceWorkRequestService.class);
        Mockito.when(requestService.listDeploymentsForExport(day, day)).thenReturn(rows);
        byte[] bytes = new DeploymentRequestExcelService(requestService).buildReport(day, day);
        // Workbook để mở cho tới hết test — đóng sẽ làm sheet không đọc được nữa.
        return new XSSFWorkbook(new ByteArrayInputStream(bytes)).getSheetAt(0);
    }

    private static Row headerRow(Sheet sheet) {
        for (Row row : sheet) {
            Cell first = row.getCell(0);
            if (first != null && first.getCellType() == CellType.STRING && "STT".equals(first.getStringCellValue())) {
                return row;
            }
        }
        throw new AssertionError("Không tìm thấy dòng tiêu đề");
    }

    private static Map<String, Object> outsideShiftRow(LocalDate day, double actual, double credited) {
        Map<String, Object> row = baseRow(day);
        row.put("deploymentInsideShift", false);
        row.put("deploymentActualHours", actual);
        row.put("deploymentCreditedHours", credited);
        return row;
    }

    private static Map<String, Object> insideShiftRow(LocalDate day, double units) {
        Map<String, Object> row = baseRow(day);
        row.put("deploymentInsideShift", true);
        row.put("deploymentWorkUnits", units);
        return row;
    }

    private static Map<String, Object> baseRow(LocalDate day) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("employeeCode", "NV001");
        row.put("employeeName", "Nguyễn Văn A");
        row.put("positionTitle", "Điều dưỡng");
        row.put("department", "Khoa Nội");
        row.put("location", "Khoa Ngoại");
        row.put("workDate", day.toString());
        row.put("requestedStart", "17:00:00");
        row.put("requestedEnd", "19:40:00");
        row.put("reason", "Điều động hỗ trợ");
        row.put("status", "APPROVED");
        row.put("createdAt", day.toString());
        return row;
    }
}
