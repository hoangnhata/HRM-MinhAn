package com.minhan.hrm.dto.auth;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class ErpProfileResponse {

    private ErpProfile profile;

    @Data
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class ErpProfile {
        @JsonProperty("UserEnrollNumber")
        private Integer userEnrollNumber;

        private String phone;

        @JsonProperty("UserFullName")
        private String userFullName;

        private String roles;

        @JsonProperty("RoleId")
        private Integer roleId;

        @JsonProperty("roleId_ts")
        private Integer roleIdTs;

        @JsonProperty("UserAvatar")
        private String userAvatar;

        @JsonProperty("Email")
        private String email;

        @JsonProperty("DOB")
        private String dob;

        @JsonProperty("Phong_khoa")
        private String phongKhoa;

        private Long deptId;
    }
}
