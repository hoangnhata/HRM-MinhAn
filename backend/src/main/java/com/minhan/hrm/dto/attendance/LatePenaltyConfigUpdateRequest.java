package com.minhan.hrm.dto.attendance;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import lombok.Data;

import java.util.List;

@Data
public class LatePenaltyConfigUpdateRequest {

    @NotEmpty
    @Valid
    private List<LatePenaltyTierRequest> tiers;
}
