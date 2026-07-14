package com.minhan.hrm.dto.salary;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class UpdateEmployeeScaleBaseRequest {

    @NotNull
    @DecimalMin("0.01")
    private BigDecimal baseTotalIncome;

    /** Trình độ: Đại học, Cao đẳng trung cấp, Lao động phổ thông */
    private String qualification;
}
