package com.minhan.hrm.mapper;

import com.minhan.hrm.entity.EmployeeWorkforceDetails;

import java.util.LinkedHashMap;
import java.util.Map;

public final class WorkforceProfileMapper {

    private WorkforceProfileMapper() {
    }

    /**
     * Map trường mở rộng từ Excel — thứ tự nhóm theo nội dung; không đưa cột kiểm tra trùng / thâm niên (công thức Excel).
     */
    public static Map<String, Object> toMap(EmployeeWorkforceDetails w) {
        Map<String, Object> m = new LinkedHashMap<>();
        put(m, "payrollDisplayName", w.getPayrollDisplayName());
        put(m, "specialty", w.getSpecialty());
        put(m, "degree", w.getDegree());
        put(m, "professionalDiploma", w.getProfessionalDiploma());
        put(m, "practiceScope", w.getPracticeScope());
        put(m, "practiceCertNumber", w.getPracticeCertNumber());
        put(m, "practiceCertDateRaw", w.getPracticeCertDateRaw());
        put(m, "otherTrainingCertificates", w.getOtherTrainingCertificates());
        put(m, "cki", w.getCki());
        put(m, "bankAccount", w.getBankAccount());
        put(m, "bankName", w.getBankName());
        put(m, "attendanceCode", w.getAttendanceCode());
        put(m, "insuranceParticipation", w.getInsuranceParticipation());
        put(m, "socialInsuranceBook", w.getSocialInsuranceBook());
        put(m, "idCardIssueDate", w.getIdCardIssueDate() != null ? w.getIdCardIssueDate().toString() : null);
        put(m, "probationStartDate", w.getProbationStartDate() != null ? w.getProbationStartDate().toString() : null);
        put(m, "officialStartDate", w.getOfficialStartDate() != null ? w.getOfficialStartDate().toString() : null);
        put(m, "contractNumber", w.getContractNumber());
        put(m, "contractSignDate", w.getContractSignDate() != null ? w.getContractSignDate().toString() : null);
        put(m, "contractTerm", w.getContractTerm());
        put(m, "workUnitDetail", w.getWorkUnitDetail());
        put(m, "workforceNotes", w.getWorkforceNotes());
        put(m, "dependentsInfo", w.getDependentsInfo());
        put(m, "ethnicity", w.getEthnicity());
        put(m, "placeOfOrigin", w.getPlaceOfOrigin());
        put(m, "maritalStatus", w.getMaritalStatus());
        put(m, "bloodType", w.getBloodType());
        put(m, "emergencyContact", w.getEmergencyContact());
        put(m, "emergencyPhone", w.getEmergencyPhone());
        m.entrySet().removeIf(e -> e.getValue() == null);
        return m;
    }

    private static void put(Map<String, Object> m, String k, Object v) {
        m.put(k, v);
    }
}
