package com.minhan.hrm.controller;

import com.minhan.hrm.assistant.HrAssistantService;
import com.minhan.hrm.dto.assistant.HrAssistantChatRequest;
import com.minhan.hrm.dto.assistant.HrAssistantChatResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/j1-api/v1/hr-assistant")
@RequiredArgsConstructor
public class HrAssistantController {

    private final HrAssistantService assistantService;

    @PostMapping("/chat")
    @PreAuthorize("isAuthenticated()")
    public HrAssistantChatResponse chat(@Valid @RequestBody HrAssistantChatRequest request) {
        return assistantService.chat(request.getMessage());
    }
}
