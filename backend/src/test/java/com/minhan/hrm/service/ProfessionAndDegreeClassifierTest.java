package com.minhan.hrm.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static com.minhan.hrm.service.DegreeLevelNormalizer.Level;
import static com.minhan.hrm.service.ProfessionClassifier.Profession;

class ProfessionAndDegreeClassifierTest {

    @Test
    void classifiesProfessionsFromTitles() {
        assertEquals(Profession.DOCTOR, ProfessionClassifier.classify("Bác sĩ đa khoa"));
        assertEquals(Profession.NURSE, ProfessionClassifier.classify("Điều dưỡng trưởng"));
        assertEquals(Profession.MIDWIFE, ProfessionClassifier.classify("Hộ sinh"));
        assertEquals(Profession.TECHNICIAN, ProfessionClassifier.classify("Kỹ thuật viên xét nghiệm"));
        assertEquals(Profession.ASSISTANT_PHYSICIAN, ProfessionClassifier.classify("Y sĩ YHCT"));
        assertEquals(Profession.PHARMACIST, ProfessionClassifier.classify("Dược sĩ đại học"));
        assertEquals(Profession.OTHER, ProfessionClassifier.classify("Kế toán"));
    }

    @Test
    void normalizesDegreeLevels() {
        assertEquals(Level.TIEN_SI, DegreeLevelNormalizer.normalize("Tiến sĩ y khoa"));
        assertEquals(Level.THAC_SI, DegreeLevelNormalizer.normalize("Thạc sĩ"));
        assertEquals(Level.CK2, DegreeLevelNormalizer.normalize("BSCKII"));
        assertEquals(Level.CK1, DegreeLevelNormalizer.normalize("Chuyên khoa I"));
        assertEquals(Level.DAI_HOC, DegreeLevelNormalizer.normalize("Đại học"));
        assertEquals(Level.CAO_DANG, DegreeLevelNormalizer.normalize("Cao đẳng điều dưỡng"));
        assertEquals(Level.TRUNG_CAP, DegreeLevelNormalizer.normalize("Trung cấp"));
        assertEquals(Level.MISSING, DegreeLevelNormalizer.normalize(null));
        assertEquals(Level.MISSING, DegreeLevelNormalizer.normalize("  "));
        assertEquals(Level.OTHER, DegreeLevelNormalizer.normalize("Văn bằng XYZ"));
    }
}
