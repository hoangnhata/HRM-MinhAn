package com.minhan.hrm.dto.salary;

import lombok.Builder;
import lombok.Value;

import java.util.List;
import java.util.Map;

@Value
@Builder
public class SalaryImportResultDto {
    int totalRows;
    int successCount;
    int createdCount;
    int updatedCount;
    int errorCount;
    int notFoundCount;
    List<Map<String, Object>> warnings;
    List<Map<String, Object>> errors;
}
