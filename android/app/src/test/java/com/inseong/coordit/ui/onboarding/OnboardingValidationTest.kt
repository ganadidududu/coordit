package com.inseong.coordit.ui.onboarding

import org.junit.Assert.*
import org.junit.Test

class OnboardingValidationTest {
    @Test fun optionalBirthdayMayBeAbsent() { assertNull(onboardingProfileError("민아", "", "", "")) }
    @Test fun blankNameIsRejected() { assertNotNull(onboardingProfileError("  ", "", "", "")) }
    @Test fun partialBirthdayIsRejected() { assertEquals("생일은 연·월·일을 모두 입력해 주세요.", onboardingProfileError("민아", "1998", "", "17")) }
    @Test fun calendarValidationRejectsImpossibleDates() {
        assertNull(onboardingBirthDate("2001", "2", "29", 2026))
        assertEquals("2000-02-29", onboardingBirthDate("2000", "2", "29", 2026))
        assertNull(onboardingBirthDate("1899", "1", "1", 2026))
        assertNull(onboardingBirthDate("2027", "1", "1", 2026))
    }
    @Test fun optionalMeasurementsOnlyAcceptPositiveFiniteNumbers() {
        listOf("", "oops", "0", "-3", "NaN", "Infinity").forEach { assertNull(onboardingMeasurement(it)) }
        assertEquals(170.5, onboardingMeasurement("170.5")!!, 0.0)
    }
}
