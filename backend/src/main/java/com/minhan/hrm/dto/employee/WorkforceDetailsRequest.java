package com.minhan.hrm.dto.employee;

import lombok.Data;

import java.time.LocalDate;

/** Trường hồ sơ nhân lực mở rộng khi tạo / cập nhật NV. */
@Data
public class WorkforceDetailsRequest {
    private String payrollDisplayName;
    private String specialty;
    private String degree;
    private String professionalDiploma;
    private String practiceScope;
    private String practiceCertNumber;
    private String practiceCertDateRaw;
    private String otherTrainingCertificates;
    private String cki;
    private String bankAccount;
    private String bankName;
    private String attendanceCode;
    private String insuranceParticipation;
    private String socialInsuranceBook;
    private LocalDate idCardIssueDate;
    private LocalDate probationStartDate;
    private LocalDate officialStartDate;
    private String contractNumber;
    private LocalDate contractSignDate;
    private String contractTerm;
    private String workUnitDetail;
    private String workforceNotes;
    private String dependentsInfo;
    private String ethnicity;
    private String placeOfOrigin;
    private String maritalStatus;
    private String bloodType;
    private String emergencyContact;
    private String emergencyPhone;
}
