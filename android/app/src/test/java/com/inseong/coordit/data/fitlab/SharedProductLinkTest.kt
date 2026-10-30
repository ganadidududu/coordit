package com.inseong.coordit.data.fitlab

import org.junit.Assert.*
import org.junit.Test

class SharedProductLinkTest {
    @Test fun acceptsProductURLInsideShoppingAppShareText() {
        assertEquals("https://shop.example/product?id=10", sharedProductLink("이 상품 어때요? (https://shop.example/product?id=10)."))
    }
    @Test fun rejectsNonWebLinksAndInvalidHosts() {
        listOf(null, "", "file:///private/item", "javascript:alert(1)", "https:///product").forEach { assertNull(sharedProductLink(it)) }
    }
}
