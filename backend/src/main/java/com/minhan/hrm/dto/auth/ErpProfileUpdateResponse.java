package com.minhan.hrm.dto.auth;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class ErpProfileUpdateResponse {

    private String message;
    private String token;
    private ErpUser user;

    @Data
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class ErpUser {
        private Long id;
        private String name;
        private String dept;
        private Long deptId;
    }
}
