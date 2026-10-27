package com.inseong.coordit.data

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import androidx.test.platform.app.InstrumentationRegistry
import com.inseong.coordit.sharing.SharedProductImports
import com.inseong.coordit.ui.closet.GarmentPhotoStore
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.util.UUID

class ParityStorageTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test fun sharedLinksSurviveRecreationAndRejectUnsupportedIntents() {
        context.getSharedPreferences("shared-product-imports", 0).edit().clear().commit()
        val imports = SharedProductImports(context)
        val shared = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "상품 https://shop.example/item?size=M")
        imports.accept(shared)
        imports.accept(shared)
        imports.accept(Intent(Intent.ACTION_VIEW, Uri.parse("https://shop.example/ignored")))
        imports.accept(Intent(Intent.ACTION_VIEW, Uri.parse("coordit://fitlab/shared?url=file%3A%2F%2F%2Fetc%2Fhosts")))
        assertEquals(listOf("https://shop.example/item?size=M"), SharedProductImports(context).pending.value)
        imports.accept(Intent(Intent.ACTION_VIEW, Uri.parse("coordit://fitlab/shared?url=https%3A%2F%2Fshop.example%2Fsecond")))
        assertEquals(2, imports.pending.value.size)
        imports.consume("https://shop.example/item?size=M")
        assertEquals(listOf("https://shop.example/second"), SharedProductImports(context).pending.value)
        imports.consume("https://shop.example/second")
    }

    @Test fun garmentPhotosSurviveStoreRecreationAndStayIsolatedByAccount() = runBlocking {
        val owner = "photo-qa-${UUID.randomUUID()}"
        val bitmap = Bitmap.createBitmap(32, 48, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.RED) }
        try {
            GarmentPhotoStore(context, owner).save("item/../same-id", bitmap)
            val restored = requireNotNull(GarmentPhotoStore(context, owner).load("item/../same-id"))
            assertEquals(32, restored.width)
            assertEquals(48, restored.height)
            assertTrue(Color.red(restored.getPixel(0, 0)) > 240)
            assertNull(GarmentPhotoStore(context, "$owner-other").load("item/../same-id"))
            restored.recycle()
        } finally { bitmap.recycle() }
    }
}
