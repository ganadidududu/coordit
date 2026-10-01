package com.inseong.coordit.data.model

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.JsonParseException
import com.google.gson.TypeAdapter
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonWriter
import java.io.IOException

object CoorditJson {
    fun create(): Gson = GsonBuilder()
        .registerTypeAdapter(AuthSession::class.java, AuthSessionAdapter())
        .create()
}

private class AuthSessionAdapter : TypeAdapter<AuthSession>() {
    override fun read(reader: JsonReader): AuthSession {
        val element = try {
            JsonParser.parseReader(reader)
        } catch (error: JsonParseException) {
            throw IOException("Invalid authentication JSON", error)
        }
        if (!element.isJsonObject) throw IOException("Authentication response must be an object")
        val body = element.asJsonObject
        val userElement = body.get("user")
        if (userElement == null || !userElement.isJsonObject) throw IOException("Authentication user must be an object")
        val user = userElement.asJsonObject
        return AuthSession(
            body.requiredString("accessToken", allowEmpty = false),
            body.requiredString("refreshToken", allowEmpty = false),
            AuthUser(user.requiredString("id", allowEmpty = false), user.requiredString("email", allowEmpty = true)),
        )
    }

    override fun write(writer: JsonWriter, session: AuthSession?) {
        if (session == null || !session.isValid()) throw IOException("Invalid authentication session")
        writer.beginObject()
        writer.name("accessToken").value(session.accessToken)
        writer.name("refreshToken").value(session.refreshToken)
        writer.name("user").beginObject()
        writer.name("id").value(session.user.id)
        writer.name("email").value(session.user.email)
        writer.endObject()
        writer.endObject()
    }

    private fun JsonObject.requiredString(name: String, allowEmpty: Boolean): String {
        val field = get(name)
        if (field == null || !field.isJsonPrimitive || !field.asJsonPrimitive.isString) {
            throw IOException("Authentication field $name must be a string")
        }
        return field.asString.also {
            if (!allowEmpty && it.isBlank()) throw IOException("Authentication field $name must not be blank")
        }
    }
}
