package com.minhan.hrm.mapper;

import com.minhan.hrm.dto.employee.*;
import com.minhan.hrm.entity.Contract;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.SalaryInfo;

import java.util.List;

public final class EmployeeMapper {

    private EmployeeMapper() {
    }

    public static EmployeeSummaryDto toSummary(Employee e) {
        return EmployeeSummaryDto.builder()
                .id(e.getId())
                .employeeCode(e.getEmployeeCode())
                .userId(e.getUser().getId())
                .username(e.getUser().getUsername())
                .fullName(e.getFullName())
                .departmentName(e.getDepartment().getName())
                .positionTitle(e.getPosition().getTitle())
                .role(e.getUser().getRole())
                .status(e.getStatus())
                .hireDate(e.getHireDate())
                .build();
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
