package com.minhan.hrm.service;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeSalaryProfile;
import com.minhan.hrm.entity.ProbationFormType;
import com.minhan.hrm.entity.SalaryCategory;
import com.minhan.hrm.repository.EmployeeSalaryProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

@Component
@RequiredArgsConstructor
public class ProbationFormTypeResolver {

    private static final Pattern DOCTOR = Pattern.compile(
            "\\b(bac\\s*si|bs\\.?|doctor)\\b|bacsi");
    private static final Pattern NURSE = Pattern.compile(
            "dieu\\s*duong|\\bdd\\b|ho\\s*sinh|ky\\s*thuat\\s*vien|\\bktv\\b|y\\s*ta|nurse");

    private final EmployeeSalaryProfileRepository salaryProfileRepository;

    public ProbationFormType resolve(Employee employee) {
        EmployeeSalaryProfile profile = salaryProfileRepository.findByEmployeeId(employee.getId()).orElse(null);
        if (profile != null && profile.getSalaryCategory() == SalaryCategory.DOCTOR) {
            return ProbationFormType.DOCTOR;
        }
        String title = employee.getPosition() != null ? employee.getPosition().getTitle() : null;
        String norm = normalize(title);
        if (norm != null && !norm.isBlank()) {
            if (DOCTOR.matcher(norm).find()) {
                return ProbationFormType.DOCTOR;
            }
            if (NURSE.matcher(norm).find()) {
                return ProbationFormType.NURSE;
            }
        }
        return ProbationFormType.STAFF;
    }

    private static String normalize(String raw) {
        if (raw == null) {
            return null;
        }
        String n = Normalizer.normalize(raw, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.ROOT)
                .replace('đ', 'd');
        return n.replaceAll("\\s+", " ").trim();
    }
}
