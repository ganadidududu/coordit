package com.inseong.coordit.preview

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class FoundationState(
    val presses: Int = 0,
    val lastEvent: String = "아직 이벤트가 없습니다",
    val reduceMotion: Boolean = false,
)

class FoundationViewModel(private val savedState: SavedStateHandle) : ViewModel() {
    private val mutableState = MutableStateFlow(
        FoundationState(
            presses = savedState["presses"] ?: 0,
            lastEvent = savedState["lastEvent"] ?: "아직 이벤트가 없습니다",
            reduceMotion = savedState["reduceMotion"] ?: false,
        ),
    )
    val state = mutableState.asStateFlow()

    fun record(event: String) {
        mutableState.update { it.copy(presses = it.presses + 1, lastEvent = event) }
        savedState["presses"] = state.value.presses
        savedState["lastEvent"] = event
    }

    fun toggleMotion() {
        mutableState.update { it.copy(reduceMotion = !it.reduceMotion) }
        savedState["reduceMotion"] = state.value.reduceMotion
    }
}
