package com.minhan.hrm.dto.assistant;

import lombok.Builder;
import lombok.Value;

import java.util.List;

@Value
@Builder
public class HrAssistantChatResponse {
    String requestId;
    String answer;
    List<String> usedTools;
}
