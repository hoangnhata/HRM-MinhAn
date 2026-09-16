package com.minhan.hrm.service;

import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.Position;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class NursingBlockClassifierTest {

    @Test
    void excludesAdminDepartmentsFromNursingHeadScope() {
        assertTrue(NursingBlockClassifier.isExcludedFromNursingHeadScopeDepartment("Phòng Kế hoạch Tổng hợp"));
        assertTrue(NursingBlockClassifier.isExcludedFromNursingHeadScopeDepartment("Phòng Kinh doanh & Phát triển"));
        assertTrue(NursingBlockClassifier.isExcludedFromNursingHeadScopeDepartment("Phòng Điều dưỡng"));
        assertFalse(NursingBlockClassifier.isExcludedFromNursingHeadScopeDepartment("Khoa Nội tổng hợp"));
    }

    @Test
    void nursingHeadScopeRequiresClinicalDepartment() {
        Employee nurseInWard = employee("Điều dưỡng viên", "Khoa Ngoại");
        Employee nurseInOffice = employee("Điều dưỡng viên", "Phòng Điều dưỡng");
        Employee nurseInPlanning = employee("Kỹ thuật viên", "Phòng Kế hoạch Tổng hợp");

        assertTrue(NursingBlockClassifier.matches(nurseInWard));
        assertTrue(NursingBlockClassifier.matchesNursingHeadScope(nurseInWard));

        assertTrue(NursingBlockClassifier.matches(nurseInOffice));
        assertFalse(NursingBlockClassifier.matchesNursingHeadScope(nurseInOffice));

        assertTrue(NursingBlockClassifier.matches(nurseInPlanning));
        assertFalse(NursingBlockClassifier.matchesNursingHeadScope(nurseInPlanning));
    }

    @Test
    void staffAndPharmacistDepartmentRules() {
        assertFalse(NursingBlockClassifier.matchesTitle("Dược sĩ"));
        assertFalse(NursingBlockClassifier.matchesTitle("Nhân viên"));
        assertFalse(NursingBlockClassifier.matchesTitle("Nhân viên phòng khám"));
        assertFalse(NursingBlockClassifier.matchesTitle("Bác sĩ"));
        assertFalse(NursingBlockClassifier.matchesTitle("Kế toán viên"));

        assertTrue(NursingBlockClassifier.matchesTitleAndDepartment(
                "Nhân viên", "Khoa Y học cổ truyền"));
        assertTrue(NursingBlockClassifier.matchesTitleAndDepartment(
                "Nhân viên", "YHCT"));
        assertTrue(NursingBlockClassifier.matchesTitleAndDepartment(
                "Nhân viên", "Khoa khám bệnh"));
        assertFalse(NursingBlockClassifier.matchesTitleAndDepartment(
                "Nhân viên", "Khoa Nội"));

        assertTrue(NursingBlockClassifier.matchesTitleAndDepartment(
                "Dược sĩ", "Khoa Y học cổ truyền"));
        assertTrue(NursingBlockClassifier.matchesTitleAndDepartment(
                "Dược sĩ", "YHCT"));
        assertFalse(NursingBlockClassifier.matchesTitleAndDepartment(
                "Dược sĩ", "Khoa khám bệnh"));
        assertFalse(NursingBlockClassifier.matchesTitleAndDepartment(
                "Dược sĩ", "Khoa Dược"));
        assertFalse(NursingBlockClassifier.matchesTitleAndDepartment(
                "Dược sĩ", "Khoa Nội"));

        Employee staffYhct = employee("Nhân viên", "Khoa Y học cổ truyền");
        Employee staffKkb = employee("Nhân viên", "Khoa khám bệnh");
        Employee staffNoi = employee("Nhân viên", "Khoa Nội");
        Employee pharmacistYhct = employee("Dược sĩ", "Khoa Y học cổ truyền");
        Employee pharmacistKkb = employee("Dược sĩ", "Khoa khám bệnh");
        Employee pharmacistDuoc = employee("Dược sĩ", "Khoa Dược");
        assertTrue(NursingBlockClassifier.matchesNursingHeadScope(staffYhct));
        assertTrue(NursingBlockClassifier.matchesNursingHeadScope(staffKkb));
        assertFalse(NursingBlockClassifier.matches(staffNoi));
        assertFalse(NursingBlockClassifier.matchesNursingHeadScope(staffNoi));
        assertTrue(NursingBlockClassifier.matchesNursingHeadScope(pharmacistYhct));
        assertFalse(NursingBlockClassifier.matches(pharmacistKkb));
        assertFalse(NursingBlockClassifier.matches(pharmacistDuoc));
        assertFalse(NursingBlockClassifier.matchesNursingHeadScope(pharmacistDuoc));
        assertEquals(NursingBlockClassifier.SubGroup.STAFF, NursingBlockClassifier.subGroup(staffYhct));
        assertEquals(NursingBlockClassifier.SubGroup.STAFF, NursingBlockClassifier.subGroup(staffKkb));
        assertEquals(NursingBlockClassifier.SubGroup.PHARMACIST, NursingBlockClassifier.subGroup(pharmacistYhct));
        assertEquals(NursingBlockClassifier.SubGroup.OTHER_NURSING, NursingBlockClassifier.subGroup(pharmacistDuoc));
        assertTrue(NursingBlockClassifier.isOutpatientDepartment("Khoa khám bệnh"));
        assertTrue(NursingBlockClassifier.isStaffEligibleDepartment("Khoa khám bệnh"));
    }

    @Test
    void assistantPhysicianBelongsToNursingHeadScope() {
        assertTrue(NursingBlockClassifier.matchesTitle("Y sĩ"));
        assertTrue(NursingBlockClassifier.matchesTitle("Y sỹ"));
        assertTrue(NursingBlockClassifier.matchesTitle("Y sĩ đa khoa"));
        assertTrue(NursingBlockClassifier.matchesTitle("Y sỹ y học cổ truyền"));
        assertFalse(NursingBlockClassifier.matchesTitle("Bác sĩ"));
        assertFalse(NursingBlockClassifier.matchesTitle("Bác sỹ"));
        assertFalse(NursingBlockClassifier.matchesTitle("Dược sỹ"));
        assertFalse(NursingBlockClassifier.matchesTitle("Kỹ sư"));

        Employee ysiWard = employee("Y sỹ", "Khoa Nội tổng hợp");
        Employee ysiOffice = employee("Y sĩ", "Phòng Điều dưỡng");
        assertTrue(NursingBlockClassifier.matchesNursingHeadScope(ysiWard));
        assertFalse(NursingBlockClassifier.matchesNursingHeadScope(ysiOffice));
        assertEquals(NursingBlockClassifier.SubGroup.ASSISTANT_PHYSICIAN,
                NursingBlockClassifier.subGroup(ysiWard));
        assertEquals("Y sĩ", NursingBlockClassifier.subGroupLabel(
                NursingBlockClassifier.SubGroup.ASSISTANT_PHYSICIAN));
    }

    @Test
    void planningDepartmentStaffNotInNursingHeadScope() {
        Employee nursePlanning = employee("Điều dưỡng viên", "Phòng Kế hoạch Tổng hợp");
        assertTrue(NursingBlockClassifier.matches(nursePlanning));
        assertFalse(NursingBlockClassifier.matchesNursingHeadScope(nursePlanning));
        assertTrue(NursingBlockClassifier.isExcludedFromNursingHeadScopeDepartment("Phòng Kế hoạch Tổng hợp"));
    }

    private static Employee employee(String title, String departmentName) {
        return Employee.builder()
                .fullName("Test")
                .position(Position.builder().title(title).build())
                .department(Department.builder().id(1L).name(departmentName).build())
                .build();
    }
}
