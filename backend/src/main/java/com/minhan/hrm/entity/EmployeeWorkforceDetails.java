package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "employee_workforce_details")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmployeeWorkforceDetails {

    @Id
    @Column(name = "employee_id")
    private Long employeeId;

    @OneToOne(fetch = FetchType.LAZY)
    @MapsId
    @JoinColumn(name = "employee_id")
    private Employee employee;

    @Column(name = "payroll_display_name", length = 255)
    private String payrollDisplayName;

    @Column(name = "duplicate_check_flag", length = 32)
    private String duplicateCheckFlag;

    @Column(name = "id_card_issue_date")
    private LocalDate idCardIssueDate;

    @Column(columnDefinition = "TEXT")
    private String specialty;

    @Column(length = 500)
    private String degree;

    @Column(name = "bank_account", length = 100)
    private String bankAccount;

    @Column(name = "bank_name", length = 255)
    private String bankName;

    @Column(name = "work_unit_detail", length = 255)
    private String workUnitDetail;

    @Column(name = "insurance_participation", length = 255)
    private String insuranceParticipation;

    @Column(name = "workforce_notes", columnDefinition = "TEXT")
    private String workforceNotes;

    @Column(name = "probation_start_date")
    private LocalDate probationStartDate;

    @Column(name = "official_start_date")
    private LocalDate officialStartDate;

    @Column(name = "contract_number", length = 128)
    private String contractNumber;

    @Column(name = "contract_sign_date")
    private LocalDate contractSignDate;

    @Column(name = "contract_term", columnDefinition = "TEXT")
    private String contractTerm;

    @Column(name = "tenure_text", length = 255)
    private String tenureText;

    @Column(name = "social_insurance_book", length = 64)
    private String socialInsuranceBook;

    @Column(name = "attendance_code", length = 64)
    private String attendanceCode;

    @Column(name = "practice_cert_number", length = 128)
    private String practiceCertNumber;

    @Column(name = "practice_cert_date_raw", length = 64)
    private String practiceCertDateRaw;

    @Column(name = "professional_diploma", columnDefinition = "TEXT")
    private String professionalDiploma;

    @Column(name = "practice_scope", columnDefinition = "TEXT")
    private String practiceScope;

    @Column(name = "other_training_certificates", columnDefinition = "TEXT")
    private String otherTrainingCertificates;

    @Column(columnDefinition = "TEXT")
    private String cki;

    @Column(name = "dependents_info", columnDefinition = "TEXT")
    private String dependentsInfo;

    @Column(length = 64)
    private String ethnicity;

    @Column(name = "place_of_origin", length = 255)
    private String placeOfOrigin;

    @Column(name = "marital_status", length = 64)
    private String maritalStatus;

    @Column(name = "blood_type", length = 16)
    private String bloodType;

    @Column(name = "emergency_contact", length = 255)
    private String emergencyContact;

    @Column(name = "emergency_phone", length = 32)
    private String emergencyPhone;
}
