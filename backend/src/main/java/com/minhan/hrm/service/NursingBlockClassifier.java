package com.minhan.hrm.service;

import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.Employee;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa – Y sĩ
 * + Dược sĩ chỉ tại khoa Y học cổ truyền;
 * + Nhân viên tại khoa YHCT hoặc Khoa khám bệnh.
 * Phạm vi Trưởng phòng ĐD ({@link #matchesNursingHeadScope}) loại trừ
 * Kế hoạch tổng hợp, Kinh doanh/Phát triển, Phòng Điều dưỡng.
 */
public final class NursingBlockClassifier {

    public enum SubGroup {
        NURSE,
        TECHNICIAN,
        MIDWIFE,
        MEDICAL_SECRETARY,
        ASSISTANT_PHYSICIAN,
        PHARMACIST,
        STAFF,
        OTHER_NURSING
    }

    private static final Pattern MIDWIFE = Pattern.compile("ho\\s*sinh|midwife");
    private static final Pattern TECHNICIAN = Pattern.compile(
            "ky\\s*thuat\\s*vien|\\bktv\\b|technici");
    private static final Pattern MEDICAL_SECRETARY = Pattern.compile(
            "thu\\s*ky\\s*y\\s*khoa|thu\\s*ky\\s*ykhoa|medical\\s*secretar");
    private static final Pattern NURSE = Pattern.compile(
            "dieu\\s*duong|\\bdd\\b|y\\s*ta|\\bnurse\\b");
    /** Chức danh «Y sĩ / Y sỹ» — thuộc khối Trưởng phòng Điều dưỡng. */
    private static final Pattern ASSISTANT_PHYSICIAN = Pattern.compile(
            "\\by\\s*s[iy]\\b|assistant\\s*physician|physician\\s*assistant");
    /** Chức danh «Dược sĩ» — chỉ tính khi thuộc khoa Y học cổ truyền. */
    private static final Pattern PHARMACIST = Pattern.compile(
            "duoc\\s*si|\\bduocsy\\b|pharmacist");
    /** Chức danh «Nhân viên» — YHCT hoặc Khoa khám bệnh. */
    private static final Pattern STAFF = Pattern.compile("\\bnhan\\s*vien\\b");
    /** Khối theo chức danh (không gồm Nhân viên / Dược sĩ — gắn khoa đặc thù). */
    private static final Pattern BLOCK = Pattern.compile(
            "dieu\\s*duong|\\bdd\\b|ho\\s*sinh|ky\\s*thuat\\s*vien|\\bktv\\b|y\\s*ta|\\bnurse\\b"
                    + "|thu\\s*ky\\s*y\\s*khoa|thu\\s*ky\\s*ykhoa|medical\\s*secretar|midwife|technici"
                    + "|\\by\\s*s[iy]\\b|assistant\\s*physician|physician\\s*assistant");
    /** Khoa Y học cổ truyền (YHCT). */
    private static final Pattern TRADITIONAL_MEDICINE_DEPT = Pattern.compile(
            "y\\s*hoc\\s*co\\s*truyen|\\byhct\\b");
    /** Khoa khám bệnh (OPD). */
    private static final Pattern OUTPATIENT_DEPT = Pattern.compile(
            "khoa\\s*kham\\s*benh|^kham\\s*benh$");
    /**
     * Phòng ban ngoài phạm vi quản lý lâm sàng của Trưởng phòng Điều dưỡng
     * (văn phòng / hành chính có nhân sự mang chức danh khối ĐD).
     */
    private static final Pattern EXCLUDED_NURSING_HEAD_DEPT = Pattern.compile(
            "ke\\s*hoach\\s*tong\\s*hop|kinh\\s*doanh|phat\\s*trien");
    /** Phòng Điều dưỡng (văn phòng quản lý khối) — ẩn khỏi phạm vi Trưởng phòng ĐD. */
    private static final Pattern NURSING_OFFICE_DEPT = Pattern.compile("^phong\\s+dieu\\s+duong$");

    private NursingBlockClassifier() {}

    public static boolean matches(Employee employee) {
        if (employee == null) {
            return false;
        }
        String title = employee.getPosition() != null ? employee.getPosition().getTitle() : null;
        String deptName = employee.getDepartment() != null ? employee.getDepartment().getName() : null;
        return matchesTitleAndDepartment(title, deptName);
    }

    /** Khớp chức danh khối (không gồm «Nhân viên» / «Dược sĩ» — cần kèm khoa đặc thù). */
    public static boolean matchesTitle(String positionTitle) {
        String norm = normalize(positionTitle);
        return norm != null && !norm.isBlank() && BLOCK.matcher(norm).find();
    }

    public static boolean matchesTitleAndDepartment(String positionTitle, String departmentName) {
        if (matchesTitle(positionTitle)) {
            return true;
        }
        if (isStaffTitle(positionTitle) && isStaffEligibleDepartment(departmentName)) {
            return true;
        }
        return isPharmacistTitle(positionTitle) && isTraditionalMedicineDepartment(departmentName);
    }

    public static boolean isStaffTitle(String positionTitle) {
        String norm = normalize(positionTitle);
        return norm != null && !norm.isBlank() && STAFF.matcher(norm).find();
    }

    public static boolean isPharmacistTitle(String positionTitle) {
        String norm = normalize(positionTitle);
        return norm != null && !norm.isBlank() && PHARMACIST.matcher(norm).find();
    }

    public static boolean isTraditionalMedicineDepartment(String departmentName) {
        String norm = normalize(departmentName);
        return norm != null && !norm.isBlank() && TRADITIONAL_MEDICINE_DEPT.matcher(norm).find();
    }

    public static boolean isTraditionalMedicineDepartment(Department department) {
        return department != null && isTraditionalMedicineDepartment(department.getName());
    }

    public static boolean isOutpatientDepartment(String departmentName) {
        String norm = normalize(departmentName);
        return norm != null && !norm.isBlank() && OUTPATIENT_DEPT.matcher(norm).find();
    }

    public static boolean isOutpatientDepartment(Department department) {
        return department != null && isOutpatientDepartment(department.getName());
    }

    /** Khoa được tính chức danh «Nhân viên» vào khối đánh giá ĐD. */
    public static boolean isStaffEligibleDepartment(String departmentName) {
        return isTraditionalMedicineDepartment(departmentName) || isOutpatientDepartment(departmentName);
    }

    public static boolean isStaffEligibleDepartment(Department department) {
        return department != null && isStaffEligibleDepartment(department.getName());
    }

    /**
     * Phòng Kế hoạch tổng hợp / Kinh doanh–Phát triển / Phòng Điều dưỡng:
     * không thuộc Trưởng phòng ĐD — do trưởng khoa/phòng đó quản lý đơn, duyệt, xếp loại.
     */
    public static boolean isExcludedFromNursingHeadScopeDepartment(String departmentName) {
        String norm = normalize(departmentName);
        if (norm == null || norm.isBlank()) {
            return false;
        }
        if (NURSING_OFFICE_DEPT.matcher(norm).matches()) {
            return true;
        }
        return EXCLUDED_NURSING_HEAD_DEPT.matcher(norm).find();
    }

    public static boolean isExcludedFromNursingHeadScopeDepartment(Department department) {
        return department != null && isExcludedFromNursingHeadScopeDepartment(department.getName());
    }

    /**
     * Khối ĐD–KTV–HS–Thư ký (+ Dược sĩ YHCT / Nhân viên YHCT hoặc Khoa khám bệnh)
     * thuộc phạm vi Trưởng phòng ĐD: đúng chức danh (và khoa nếu là Nhân viên/Dược sĩ)
     * và không thuộc phòng ban loại trừ.
     */
    public static boolean matchesNursingHeadScope(Employee employee) {
        if (!matches(employee)) {
            return false;
        }
        if (employee.getDepartment() != null
                && isExcludedFromNursingHeadScopeDepartment(employee.getDepartment())) {
            return false;
        }
        return true;
    }

    public static SubGroup subGroup(Employee employee) {
        String title = employee != null && employee.getPosition() != null
                ? employee.getPosition().getTitle()
                : null;
        String dept = employee != null && employee.getDepartment() != null
                ? employee.getDepartment().getName()
                : null;
        return subGroupOfTitle(title, dept);
    }

    public static SubGroup subGroupOfTitle(String positionTitle) {
        return subGroupOfTitle(positionTitle, null);
    }

    public static SubGroup subGroupOfTitle(String positionTitle, String departmentName) {
        String norm = normalize(positionTitle);
        if (norm == null || norm.isBlank()) {
            return SubGroup.OTHER_NURSING;
        }
        if (MEDICAL_SECRETARY.matcher(norm).find()) {
            return SubGroup.MEDICAL_SECRETARY;
        }
        if (MIDWIFE.matcher(norm).find()) {
            return SubGroup.MIDWIFE;
        }
        if (TECHNICIAN.matcher(norm).find()) {
            return SubGroup.TECHNICIAN;
        }
        if (NURSE.matcher(norm).find()) {
            return SubGroup.NURSE;
        }
        if (ASSISTANT_PHYSICIAN.matcher(norm).find()) {
            return SubGroup.ASSISTANT_PHYSICIAN;
        }
        if (PHARMACIST.matcher(norm).find() && isTraditionalMedicineDepartment(departmentName)) {
            return SubGroup.PHARMACIST;
        }
        if (STAFF.matcher(norm).find() && isStaffEligibleDepartment(departmentName)) {
            return SubGroup.STAFF;
        }
        return SubGroup.OTHER_NURSING;
    }

    public static String subGroupLabel(SubGroup g) {
        return switch (g) {
            case NURSE -> "Điều dưỡng";
            case TECHNICIAN -> "KTV";
            case MIDWIFE -> "Hộ sinh";
            case MEDICAL_SECRETARY -> "Thư ký y khoa";
            case ASSISTANT_PHYSICIAN -> "Y sĩ";
            case PHARMACIST -> "Dược sĩ (YHCT)";
            case STAFF -> "Nhân viên (YHCT/Khám bệnh)";
            case OTHER_NURSING -> "Khác (khối ĐD)";
        };
    }

    public static String normalize(String raw) {
        if (raw == null) {
            return null;
        }
        String n = Normalizer.normalize(raw, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.ROOT)
                .replace('đ', 'd');
        return n.replaceAll("\\s+", " ").trim();
    }
}
