package com.minhan.hrm.dto.salary;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Một lần quy đổi nâng lương sớm: ngày + hệ số năm. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EarlyRaiseConversionDto {

    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate raiseDate;

    @NotNull
    @DecimalMin("0")
    private BigDecimal years;
}
