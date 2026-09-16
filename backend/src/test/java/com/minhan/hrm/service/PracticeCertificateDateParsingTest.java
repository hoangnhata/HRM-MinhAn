package com.minhan.hrm.service;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

/** Ngày cấp CCHN trên hồ sơ là chuỗi tự do — báo cáo phải đọc được các dạng phổ biến. */
class PracticeCertificateDateParsingTest {

    @Test
    void parsesCommonVietnameseFormats() {
        assertEquals(LocalDate.of(2019, 5, 12), ProfessionalQualificationReportService.parseIssueDate("12/05/2019"));
        assertEquals(LocalDate.of(2019, 5, 2), ProfessionalQualificationReportService.parseIssueDate("2/5/2019"));
        assertEquals(LocalDate.of(2021, 3, 8), ProfessionalQualificationReportService.parseIssueDate("08-03-2021"));
        assertEquals(LocalDate.of(2024, 2, 1), ProfessionalQualificationReportService.parseIssueDate("2024-02-01"));
        assertEquals(LocalDate.of(2018, 7, 1), ProfessionalQualificationReportService.parseIssueDate("07/2018"));
        assertEquals(LocalDate.of(2015, 1, 1), ProfessionalQualificationReportService.parseIssueDate("Cấp năm 2015"));
        assertEquals(LocalDate.of(2020, 9, 30),
                ProfessionalQualificationReportService.parseIssueDate("30/09/2020 (Sở Y tế Nghệ An)"));
    }

    @Test
    void rejectsUnreadableValues() {
        assertNull(ProfessionalQualificationReportService.parseIssueDate(null));
        assertNull(ProfessionalQualificationReportService.parseIssueDate("   "));
        assertNull(ProfessionalQualificationReportService.parseIssueDate("chưa rõ"));
        assertNull(ProfessionalQualificationReportService.parseIssueDate("31/02/2020"));
    }
}
