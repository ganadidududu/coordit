package com.inseong.coordit.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import com.inseong.coordit.ui.theme.*

@Composable
fun SettingsCard(scale: Float, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape((7 * scale).dp))
        .border(1.dp, AppColors.line.copy(alpha = .7f), RoundedCornerShape((7 * scale).dp))
        .padding(vertical = (12 * scale).dp), content = content)
}

@Composable
fun SettingsDetailRow(title: String, scale: Float, modifier: Modifier = Modifier, subtitle: String? = null,
    trailing: @Composable RowScope.() -> Unit = {}) {
    Row(modifier.fillMaxWidth().height((55 * scale).dp).padding(horizontal = (13 * scale).dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((12 * scale).dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((3 * scale).dp)) {
            CoorditText(title, CoorditTypography.gmarketBold(12 * scale).copy(color = Color.Black))
            if (subtitle != null) CoorditText(subtitle, CoorditTypography.gmarketMedium(9 * scale).copy(color = AppColors.muted))
        }
        trailing()
    }
}

@Composable
fun SettingsDivider(scale: Float, modifier: Modifier = Modifier) {
    Box(modifier.padding(start = (13 * scale).dp).fillMaxWidth().height(1.dp).background(AppColors.line))
}

@Composable
fun SettingsValuePill(text: String, scale: Float, modifier: Modifier = Modifier) {
    Box(modifier.height((26 * scale).dp).background(AppColors.settingsValue, CircleShape)
        .padding(horizontal = (10 * scale).dp), contentAlignment = Alignment.Center) {
        CoorditText(text, CoorditTypography.gmarketBold(9 * scale))
    }
}

@Composable
fun SettingsToggle(isOn: Boolean, onValueChange: (Boolean) -> Unit, label: String, scale: Float, modifier: Modifier = Modifier) {
    Pressable({ onValueChange(!isOn) }, modifier.size((44 * scale).dp).semantics {
        contentDescription = label; stateDescription = if (isOn) "켜짐" else "꺼짐"; role = Role.Switch
    }) {
        Box(Modifier.size((42 * scale).dp, (24 * scale).dp)
            .background(if (isOn) AppColors.ink else AppColors.toggleOff, CircleShape).padding((2 * scale).dp),
            contentAlignment = if (isOn) Alignment.CenterEnd else Alignment.CenterStart) {
            Box(Modifier.size((20 * scale).dp).background(Color.White, CircleShape))
        }
    }
}

@Composable
fun CoorditField(value: String, onValueChange: (String) -> Unit, label: String, modifier: Modifier = Modifier,
    placeholder: String = "", enabled: Boolean = true) {
    BasicTextField(value, onValueChange, modifier.fillMaxWidth().heightIn(min = 48.dp)
        .clip(RoundedCornerShape(7.dp)).background(AppColors.settingsField).padding(13.dp)
        .semantics { contentDescription = label }, enabled = enabled,
        textStyle = CoorditTypography.gmarketMedium(13f), cursorBrush = SolidColor(AppColors.ink), singleLine = true,
        decorationBox = { inner ->
            Box(contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) CoorditText(placeholder, CoorditTypography.gmarketMedium(13f).copy(color = AppColors.muted))
                inner()
            }
        })
}
