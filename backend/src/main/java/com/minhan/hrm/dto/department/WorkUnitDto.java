package com.minhan.hrm.dto.department;

import lombok.Builder;
import lombok.Value;

import java.time.Instant;

@Value
@Builder
public class WorkUnitDto {
    Long id;
    Long departmentId;
    String departmentName;
    String name;
    String description;
    Instant createdAt;
    Instant updatedAt;
}
