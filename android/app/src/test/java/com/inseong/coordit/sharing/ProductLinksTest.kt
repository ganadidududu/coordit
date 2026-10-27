package com.inseong.coordit.sharing

import org.junit.Assert.*
import org.junit.Test

class ProductLinksTest {
    @Test fun extractsSharedShoppingLinkWithoutCaptionOrClosingPunctuation() {
        assertEquals("https://shop.example/item?id=42", ProductLinks.fromText("이 옷 어때요? (https://shop.example/item?id=42)."))
        assertEquals("https://shop.example/a%20b?q=shirt#size", ProductLinks.fromText("상품\nhttps://shop.example/a%20b?q=shirt#size\n공유"))
    }

    @Test fun rejectsUnsupportedAndCredentialBearingUrls() {
        listOf("file:///tmp/photo", "javascript:alert(1)", "https:///item", "https://user:password@shop.example/item", "https://shop.example/a b").forEach {
            assertFalse(it, ProductLinks.isProductUrl(it))
        }
        assertNull(ProductLinks.fromText("https://user:password@shop.example/item"))
        assertTrue(ProductLinks.isProductUrl("https://shop.example:8443/item?q=M"))
    }
}
