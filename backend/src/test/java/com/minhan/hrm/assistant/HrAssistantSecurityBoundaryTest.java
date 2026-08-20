package com.minhan.hrm.assistant;

import com.minhan.hrm.dto.assistant.HrAssistantChatRequest;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Field;
import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

class HrAssistantSecurityBoundaryTest {

    @Test
    void frontendRequestCannotSubmitEmployeeId() {
        assertThat(Arrays.stream(HrAssistantChatRequest.class.getDeclaredFields()).map(Field::getName))
                .containsExactly("message");
    }

    @Test
    void assistantLayersDoNotDependOnRepositories() {
        assertThat(Arrays.stream(HrAssistantToolService.class.getDeclaredFields())
                .map(Field::getType)
                .map(Class::getName))
                .noneMatch(name -> name.contains(".repository."));
        assertThat(Arrays.stream(HrAssistantService.class.getDeclaredFields())
                .map(Field::getType)
                .map(Class::getName))
                .noneMatch(name -> name.contains(".repository."));
    }
}
