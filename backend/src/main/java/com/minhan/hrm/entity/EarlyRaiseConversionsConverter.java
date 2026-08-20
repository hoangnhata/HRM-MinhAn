package com.minhan.hrm.entity;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.minhan.hrm.dto.salary.EarlyRaiseConversionDto;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

import java.util.ArrayList;
import java.util.List;

@Converter
public class EarlyRaiseConversionsConverter
        implements AttributeConverter<List<EarlyRaiseConversionDto>, String> {

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    private static final TypeReference<List<EarlyRaiseConversionDto>> TYPE = new TypeReference<>() {};

    @Override
    public String convertToDatabaseColumn(List<EarlyRaiseConversionDto> attribute) {
        if (attribute == null || attribute.isEmpty()) {
            return "[]";
        }
        try {
            return MAPPER.writeValueAsString(attribute);
        } catch (Exception e) {
            throw new IllegalStateException("Không ghi được early_raise_conversions", e);
        }
    }

    @Override
    public List<EarlyRaiseConversionDto> convertToEntityAttribute(String dbData) {
        if (dbData == null || dbData.isBlank()) {
            return new ArrayList<>();
        }
        try {
            List<EarlyRaiseConversionDto> list = MAPPER.readValue(dbData, TYPE);
            return list != null ? new ArrayList<>(list) : new ArrayList<>();
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }
}
