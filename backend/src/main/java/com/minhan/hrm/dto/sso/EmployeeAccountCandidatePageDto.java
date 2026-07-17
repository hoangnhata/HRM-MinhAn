package com.minhan.hrm.dto.sso;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
@AllArgsConstructor
public class EmployeeAccountCandidatePageDto {
    private long total;
    private int page;
    private int limit;
    private List<EmployeeAccountCandidateDto> data;
}
