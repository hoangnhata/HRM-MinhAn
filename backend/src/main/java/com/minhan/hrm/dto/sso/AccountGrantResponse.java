package com.minhan.hrm.dto.sso;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor
public class AccountGrantResponse {
    private String message;
    private String id;
}
