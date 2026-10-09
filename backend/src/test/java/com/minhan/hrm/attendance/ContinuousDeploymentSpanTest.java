package com.minhan.hrm.attendance;

import org.junit.jupiter.api.Test;

import java.time.LocalTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ContinuousDeploymentSpanTest {

    private static final LocalTime DAY_START = LocalTime.of(6, 45);
    private static final LocalTime DAY_END = LocalTime.of(17, 0);

    @Test
    void fullyInside_isInside() {
        ContinuousDeploymentSpan.Result span = ContinuousDeploymentSpan.classify(
                LocalTime.of(6, 45), LocalTime.of(17, 0), DAY_START, DAY_END);
        assertEquals(ContinuousDeploymentSpan.Kind.INSIDE, span.kind());
        assertEquals(0, span.outsideMinutes());
    }

    @Test
    void fullyOutside_isOutside() {
        ContinuousDeploymentSpan.Result span = ContinuousDeploymentSpan.classify(
                LocalTime.of(18, 0), LocalTime.of(21, 0), DAY_START, DAY_END);
        assertEquals(ContinuousDeploymentSpan.Kind.OUTSIDE, span.kind());
        assertFalse(span.hasInside());
        assertEquals(180, span.outsideMinutes());
    }

    @Test
    void touchingShiftEnd_isOutside() {
        ContinuousDeploymentSpan.Result span = ContinuousDeploymentSpan.classify(
                LocalTime.of(17, 0), LocalTime.of(19, 0), DAY_START, DAY_END);
        assertEquals(ContinuousDeploymentSpan.Kind.OUTSIDE, span.kind());
        assertEquals(120, span.outsideMinutes());
    }

    @Test
    void beforeAndAfter_isMixed() {
        ContinuousDeploymentSpan.Result span = ContinuousDeploymentSpan.classify(
                LocalTime.of(5, 0), LocalTime.of(19, 0), DAY_START, DAY_END);
        assertEquals(ContinuousDeploymentSpan.Kind.MIXED, span.kind());
        assertEquals(LocalTime.of(6, 45), span.insideStart());
        assertEquals(LocalTime.of(17, 0), span.insideEnd());
        assertEquals(105 + 120, span.outsideMinutes());
    }

    @Test
    void splitShift_rangeAcrossLunch_isMixed() {
        ContinuousDeploymentSpan.Windows span = ContinuousDeploymentSpan.classifyWindows(
                LocalTime.of(5, 0),
                LocalTime.of(19, 0),
                LocalTime.of(6, 45),
                LocalTime.of(11, 45),
                LocalTime.of(14, 0),
                LocalTime.of(17, 0));
        assertEquals(ContinuousDeploymentSpan.Kind.MIXED, span.kind());
        assertEquals(LocalTime.of(6, 45), span.morningStart());
        assertEquals(LocalTime.of(11, 45), span.morningEnd());
        assertEquals(LocalTime.of(14, 0), span.afternoonStart());
        assertEquals(LocalTime.of(17, 0), span.afternoonEnd());
        assertEquals(105 + 135 + 120, span.outsideMinutes());
    }

    @Test
    void splitShift_morningOnly_isInside() {
        ContinuousDeploymentSpan.Windows span = ContinuousDeploymentSpan.classifyWindows(
                LocalTime.of(7, 0),
                LocalTime.of(11, 0),
                LocalTime.of(6, 45),
                LocalTime.of(11, 45),
                LocalTime.of(14, 0),
                LocalTime.of(17, 0));
        assertEquals(ContinuousDeploymentSpan.Kind.INSIDE, span.kind());
        assertEquals(0, span.outsideMinutes());
        assertFalse(span.hasAfternoon());
    }

    @Test
    void onlyAfterShift_isMixed() {
        ContinuousDeploymentSpan.Result span = ContinuousDeploymentSpan.classify(
                LocalTime.of(6, 45), LocalTime.of(19, 0), DAY_START, DAY_END);
        assertEquals(ContinuousDeploymentSpan.Kind.MIXED, span.kind());
        assertTrue(span.hasInside());
        assertEquals(120, span.outsideMinutes());
    }
}
