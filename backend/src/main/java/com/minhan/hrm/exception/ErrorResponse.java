package com.minhan.hrm.exception;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Value;

import java.time.Instant;
import java.util.Map;

@Value
@Builder
@JsonInclude(JsonInclude.Include.NON_EMPTY)
public class ErrorResponse {
    Instant timestamp;
    int status;
    String error;
    String message;
    String path;
    Map<String, String> fieldErrors;
}
