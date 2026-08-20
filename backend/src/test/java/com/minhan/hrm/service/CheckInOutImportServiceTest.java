package com.minhan.hrm.service;

import com.minhan.hrm.entity.AttendanceRecord;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CheckInOutImportServiceTest {

    @Test
    void syncKeepsApprovedInsideDeploymentMarker() {
        String deployment = "Điều động trong ca [DDTC:S=07:00-11:30;A=-]";

        String result = CheckInOutImportService.appendSyncNote(deployment);

        assertTrue(result.contains(deployment));
        assertTrue(result.contains("Đồng bộ máy chấm công"));
    }

    @Test
    void repeatedSyncDoesNotDuplicateSyncNote() {
        String result = CheckInOutImportService.appendSyncNote(
                "Điều động trong ca; Đồng bộ máy chấm công");

        assertEquals(1, result.split("Đồng bộ máy chấm công", -1).length - 1);
    }

    @Test
    void leaveAndBusinessTripDaysAreProtectedFromPunchOverwrite() {
        AttendanceRecord leave = AttendanceRecord.builder().status("LEAVE").build();
        AttendanceRecord unpaid = AttendanceRecord.builder().status("UNPAID_LEAVE").build();
        AttendanceRecord trip = AttendanceRecord.builder().status("BUSINESS_TRIP").build();
        AttendanceRecord present = AttendanceRecord.builder().status("PRESENT").build();

        assertTrue(CheckInOutImportService.isSyncProtectedDay(leave));
        assertTrue(CheckInOutImportService.isSyncProtectedDay(unpaid));
        assertTrue(CheckInOutImportService.isSyncProtectedDay(trip));
        assertFalse(CheckInOutImportService.isSyncProtectedDay(present));
        assertFalse(CheckInOutImportService.isSyncProtectedDay(null));
    }
}
