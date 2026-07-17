package com.minhan.hrm.dto.auth;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Builder;
import lombok.Value;

@Value
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ErpProfileUpdateBody {

    @JsonProperty("UserFullName")
    String userFullName;

    @JsonProperty("Email")
    String email;

    @JsonProperty("DOB")
    String dob;

    @JsonProperty("UserAvatar")
    String userAvatar;
}
