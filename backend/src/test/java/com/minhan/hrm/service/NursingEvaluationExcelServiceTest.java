package com.minhan.hrm.service;

import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class NursingEvaluationExcelServiceTest {

    private static NursingEvaluationService.RankingSection sec(String name, String max, boolean bonus, boolean penalty) {
        return new NursingEvaluationService.RankingSection(name, max == null ? null : new BigDecimal(max), bonus, penalty);
    }

    private static Map<String, BigDecimal> pts(String... kv) {
        Map<String, BigDecimal> m = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) {
            m.put(kv[i], new BigDecimal(kv[i + 1]));
        }
        return m;
    }

    @Test
    void buildsMonthlyRankingInTemplateLayout() throws Exception {
        List<NursingEvaluationService.RankingSection> sections = List.of(
                sec("I. Tuân thủ nội quy", "15", false, false),
                sec("II. Năng lực chuyên môn – an toàn người bệnh - HSBA", "45", false, false),
                sec("III. Công tác 5S - KSNK - Tài sản", "15", false, false),
                sec("IV. Chuẩn mực giao tiếp, ứng xử, thái độ làm việc", "15", false, false),
                sec("V. Tham gia đào tạo – truyền thông", "10", false, false),
                sec("VI. Điểm thưởng", null, true, false),
                sec("VII. Điểm trừ", null, false, true));
        String i = "I. Tuân thủ nội quy";
        String ii = "II. Năng lực chuyên môn – an toàn người bệnh - HSBA";
        String iii = "III. Công tác 5S - KSNK - Tài sản";
        String iv = "IV. Chuẩn mực giao tiếp, ứng xử, thái độ làm việc";
        String v = "V. Tham gia đào tạo – truyền thông";
        List<NursingEvaluationService.RankingRow> rows = List.of(
                new NursingEvaluationService.RankingRow("Nguyễn Thị An", "NV01", "KHOA HỒI SỨC CẤP CỨU",
                        pts(i, "15", ii, "40", iii, "15", iv, "15", v, "10", "VI. Điểm thưởng", "5", "VII. Điểm trừ", "0"),
                        new BigDecimal("100"), "Xuất sắc", "APPROVED"),
                new NursingEvaluationService.RankingRow("Trần Văn Bình", "NV02", "KHOA HỒI SỨC CẤP CỨU",
                        pts(i, "13", ii, "35", iii, "13", iv, "13", v, "8", "VI. Điểm thưởng", "0", "VII. Điểm trừ", "0"),
                        new BigDecimal("82"), "Tốt", "PENDING_HR"),
                new NursingEvaluationService.RankingRow("Lê Thị Cúc", "NV03", "KHOA KHÁM BỆNH",
                        pts(i, "12", ii, "30", iii, "10", iv, "13", v, "7", "VI. Điểm thưởng", "0", "VII. Điểm trừ", "-5"),
                        new BigDecimal("67"), "Khá", "PENDING_DIRECTOR"),
                new NursingEvaluationService.RankingRow("Phạm Văn Dũng", "NV04", "KHOA LIÊN CHUYÊN KHOA",
                        pts(i, "10", ii, "25", iii, "8", iv, "10", v, "5"),
                        new BigDecimal("58"), "Chưa đạt", "APPROVED"),
                new NursingEvaluationService.RankingRow("Đỗ Thị Em", "NV05", "KHOA LIÊN CHUYÊN KHOA",
                        pts(i, "15", ii, "38", iii, "14", iv, "14", v, "9"),
                        new BigDecimal("90"), "Xuất sắc", "APPROVED"));
        NursingEvaluationService data = mock(NursingEvaluationService.class);
        when(data.monthlyRankingForExport(2026, 9, "DD_KTV_HS_MA_2026")).thenReturn(
                new NursingEvaluationService.MonthlyRanking(
                        "Bảng đánh giá kết quả làm việc tháng — Điều dưỡng viên (MA 2026)",
                        sections,
                        NursingEvaluationTemplateService.DEFAULT_GRADING_SCALE,
                        rows));

        byte[] bytes = new NursingEvaluationExcelService(data).buildMonthlyRanking(2026, 9, "DD_KTV_HS_MA_2026");

        String out = System.getProperty("excelPreviewOut");
        if (out != null) {
            Files.write(Path.of(out), bytes);
        }
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(bytes))) {
            Sheet sh = wb.getSheetAt(0);
            assertEquals("Xếp loại T9-2026", sh.getSheetName());
            Row h1 = sh.getRow(4);
            Row h2 = sh.getRow(5);
            assertEquals("Họ tên", h1.getCell(1).getStringCellValue());
            assertEquals("Khoa / Phòng", h1.getCell(2).getStringCellValue());
            assertEquals("Điểm tiêu chí", h1.getCell(3).getStringCellValue());
            assertTrue(h2.getCell(3).getStringCellValue().startsWith("I. Tuân thủ nội quy"));
            assertTrue(h2.getCell(9).getStringCellValue().startsWith("VII. Điểm trừ"));
            assertEquals("Tổng điểm", h1.getCell(10).getStringCellValue());
            assertEquals("Xếp loại", h1.getCell(11).getStringCellValue());
            Row first = sh.getRow(6);
            assertEquals("Nguyễn Thị An", first.getCell(1).getStringCellValue());
            assertEquals(100.0, first.getCell(10).getNumericCellValue());
            assertEquals(-5.0, sh.getRow(8).getCell(9).getNumericCellValue());
            Row avg = sh.getRow(11);
            assertEquals("Điểm trung bình", avg.getCell(0).getStringCellValue());
            assertEquals(79.4, avg.getCell(10).getNumericCellValue(), 0.001);
        }
    }
}
