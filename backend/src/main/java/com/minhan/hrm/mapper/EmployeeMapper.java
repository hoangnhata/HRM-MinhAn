package com.minhan.hrm.mapper;

import com.minhan.hrm.dto.employee.*;
import com.minhan.hrm.entity.Contract;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.entity.SalaryInfo;
import com.minhan.hrm.workforce.WorkforceInsurance;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;

public final class EmployeeMapper {

    private EmployeeMapper() {
    }

    public static EmployeeSummaryDto toSummary(Employee e) {
        return toSummary(e, null);
    }

    public static EmployeeSummaryDto toSummary(Employee e, EmployeeWorkforceDetails workforce) {
        LocalDate probationStart = resolveProbationStart(e, workforce);
        Integer probationMonths = computeProbationMonths(probationStart);
        boolean trial = isTrialStatus(e.getStatus());
        String insuranceParticipation = workforce != null ? workforce.getInsuranceParticipation() : null;
        return EmployeeSummaryDto.builder()
                .id(e.getId())
                .employeeCode(e.getEmployeeCode())
                .userId(e.getUser().getId())
                .username(e.getUser().getUsername())
                .fullName(e.getFullName())
                .departmentName(e.getDepartment().getName())
                .workUnitDetail(workforce != null ? workforce.getWorkUnitDetail() : null)
                .positionTitle(e.getPosition().getTitle())
                .role(e.getUser().getRole())
                .status(e.getStatus())
                .hireDate(e.getHireDate())
                .probationStartDate(probationStart)
                .probationMonths(trial ? probationMonths : null)
                .probationOverdue(trial && probationMonths != null && probationMonths > 3)
                .insuranceParticipation(insuranceParticipation)
                .maternityLeave(WorkforceInsurance.isMaternityLeave(insuranceParticipation))
                .build();
    }

    private static LocalDate resolveProbationStart(Employee e, EmployeeWorkforceDetails workforce) {
        if (isTrialStatus(e.getStatus())) {
            if (e.getHireDate() != null) {
                return e.getHireDate();
            }
            if (workforce != null && workforce.getProbationStartDate() != null) {
                return workforce.getProbationStartDate();
            }
            return null;
        }
        if (workforce != null && workforce.getProbationStartDate() != null) {
            return workforce.getProbationStartDate();
        }
        return null;
    }

    private static Integer computeProbationMonths(LocalDate start) {
        if (start == null) {
            return null;
        }
        LocalDate today = LocalDate.now();
        if (start.isAfter(today)) {
            return 0;
        }
        return (int) ChronoUnit.MONTHS.between(start, today);
    }

    private static boolean isTrialStatus(EmployeeStatus status) {
        return status == EmployeeStatus.PROBATION || status == EmployeeStatus.INTERN;
    }

    public static EmployeeDetailDto toDetail(Employee e, SalaryInfo salary, List<Contract> contracts) {
        SalaryInfoDto salDto = salary == null ? null : SalaryInfoDto.builder()
                .id(salary.getId())
                .baseSalary(salary.getBaseSalary())
                .allowance(salary.getAllowance())
                .lastRaiseDate(salary.getLastRaiseDate())
                .nextReviewDate(salary.getNextReviewDate())
                .build();
        List<ContractDto> cdtos = contracts.stream().map(EmployeeMapper::toContractDto).toList();
        return EmployeeDetailDto.builder()
                .id(e.getId())
                .employeeCode(e.getEmployeeCode())
                .userId(e.getUser().getId())
                .username(e.getUser().getUsername())
                .email(e.getUser().getEmail())
                .role(e.getUser().getRole())
                .fullName(e.getFullName())
                .phone(e.getPhone())
                .idCardNumber(e.getIdCardNumber())
                .dateOfBirth(e.getDateOfBirth())
                .address(e.getAddress())
                .gender(e.getGender())
                .departmentId(e.getDepartment().getId())
                .departmentName(e.getDepartment().getName())
                .positionId(e.getPosition().getId())
                .positionTitle(e.getPosition().getTitle())
                .hireDate(e.getHireDate())
                .status(e.getStatus())
                .continuousShift(e.isContinuousShift())
                .salary(salDto)
                .contracts(cdtos)
                .workforceProfile(null)
                .build();
    }

    public static ContractDto toContractDto(Contract c) {
        return ContractDto.builder()
                .id(c.getId())
                .contractType(c.getContractType())
                .startDate(c.getStartDate())
                .endDate(c.getEndDate())
                .salaryBase(c.getSalaryBase())
                .documentPath(c.getDocumentPath())
                .note(c.getNote())
                .build();
    }
}
