package com.inseong.coordit.auth

import org.junit.Assert.*
import org.junit.Test

class GoogleNonceTest {
    @Test fun hashedNonceMatchesExistingIosBackendContract() {
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", GoogleNonce.requestHash("abc"))
    }
    @Test fun nonceContainsIndependent256BitUrlSafeEntropy() {
        val first = GoogleNonce.create()
        val second = GoogleNonce.create()
        assertNotEquals(first, second)
        assertTrue(first.matches(Regex("[A-Za-z0-9_-]{43}")))
        assertEquals(32, java.util.Base64.getUrlDecoder().decode(first).size)
        assertEquals("GoogleCredential(redacted)", GoogleCredential(first, second).toString())
    }
}
