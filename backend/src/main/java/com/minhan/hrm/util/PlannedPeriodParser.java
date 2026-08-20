package com.minhan.hrm.util;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Optional;
import java.util.regex.Pattern;

/** Parse chuỗi khoảng thời gian dạng dd/MM/yyyy – dd/MM/yyyy từ phiếu đào tạo. */
public final class PlannedPeriodParser {

    private static final DateTimeFormatter VN = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final Pattern SPLIT = Pattern.compile("\\s*[–—\\-→]+\\s*|\\s+to\\s+", Pattern.CASE_INSENSITIVE);

    private PlannedPeriodParser() {
    }

    public record Period(LocalDate start, LocalDate end) {
    }

    public static Optional<Period> parse(String raw) {
        if (raw == null || raw.isBlank()) {
            return Optional.empty();
        }
        String[] parts = SPLIT.split(raw.trim());
        if (parts.length == 1) {
            return parseDate(parts[0]).map(d -> new Period(d, d));
        }
        if (parts.length >= 2) {
            Optional<LocalDate> start = parseDate(parts[0]);
            Optional<LocalDate> end = parseDate(parts[parts.length - 1]);
            if (start.isPresent() && end.isPresent()) {
                LocalDate from = start.get();
                LocalDate to = end.get();
                if (to.isBefore(from)) {
                    return Optional.of(new Period(to, from));
                }
                return Optional.of(new Period(from, to));
            }
        }
        return Optional.empty();
    }

    public static Optional<LocalDate> parseEnd(String raw) {
        return parse(raw).map(Period::end);
    }

    private static Optional<LocalDate> parseDate(String token) {
        if (token == null || token.isBlank()) {
            return Optional.empty();
        }
        String t = token.trim();
        try {
            if (t.matches("\\d{4}-\\d{2}-\\d{2}")) {
                return Optional.of(LocalDate.parse(t));
            }
            return Optional.of(LocalDate.parse(t, VN));
        } catch (DateTimeParseException ex) {
            return Optional.empty();
        }
    }
}
