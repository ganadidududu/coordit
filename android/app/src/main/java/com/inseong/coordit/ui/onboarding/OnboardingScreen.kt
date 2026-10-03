package com.inseong.coordit.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.inseong.coordit.data.model.BodyMeasurement
import com.inseong.coordit.data.model.OnboardingRequest
import com.inseong.coordit.data.model.UserProfile
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*

private val stepLabels = listOf("프로필", "핏 정보", "약관 동의")
private val stepDetails = listOf("내 옷장에 표시할 기본 정보를 입력해 주세요.", "키와 몸무게는 선택이에요. 나중에 입력해도 괜찮아요.", "필수 약관에 동의하면 내 기록을 안전하게 저장합니다.")

@Composable
fun OnboardingScreen(
    profile: UserProfile?, body: BodyMeasurement?, busy: Boolean, error: String?,
    onSubmit: (OnboardingRequest) -> Unit, onExit: () -> Unit,
) {
    var step by rememberSaveable { mutableIntStateOf(0) }
    var name by rememberSaveable { mutableStateOf(profile?.displayName.orEmpty()) }
    var gender by rememberSaveable { mutableStateOf(profile?.gender.orEmpty()) }
    val birthParts = profile?.birthDate?.split("-").orEmpty()
    var year by rememberSaveable { mutableStateOf(birthParts.getOrNull(0).orEmpty()) }
    var month by rememberSaveable { mutableStateOf(birthParts.getOrNull(1).orEmpty()) }
    var day by rememberSaveable { mutableStateOf(birthParts.getOrNull(2).orEmpty()) }
    var height by rememberSaveable { mutableStateOf(body?.heightCm?.toString().orEmpty()) }
    var weight by rememberSaveable { mutableStateOf(body?.weightKg?.toString().orEmpty()) }
    var terms by rememberSaveable { mutableStateOf(false) }
    var privacy by rememberSaveable { mutableStateOf(false) }
    var fitData by rememberSaveable { mutableStateOf(false) }
    var marketing by rememberSaveable { mutableStateOf(false) }
    var document by rememberSaveable { mutableStateOf<String?>(null) }
    var validation by rememberSaveable { mutableStateOf<String?>(null) }
    val focus = LocalFocusManager.current
    val nameFocus = remember { FocusRequester() }
    fun move(next: Int) { focus.clearFocus(); validation = null; step = next }
    fun back() { if (!busy) { if (step == 0) onExit() else move(step - 1) } }
    fun advance() {
        if (busy) return
        validation = onboardingProfileError(name, year, month, day)
        if (validation == null) move(1) else if (name.isBlank()) nameFocus.requestFocus()
    }
    BackHandler { if (document != null) document = null else back() }
    BoxWithConstraints(Modifier.fillMaxSize().testTag("coordit-screen-onboarding")) {
        val scale = (maxWidth.value / AppDimensions.designWidth).coerceAtLeast(.1f)
        SharedAppBackground(scale)
        val safeArea = PaddingValues(top = coorditReferenceTopInset(scale), bottom = coorditReferenceBottomInset(scale))
        Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(safeArea.calculateBottomPadding()).background(AppColors.panel.copy(alpha = .97f)))
        Column(Modifier.fillMaxSize().padding(safeArea).consumeWindowInsets(safeArea).imePadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            OnboardingHeader(scale, busy, ::back)
            Spacer(Modifier.height((22 * scale).dp))
            Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState())
                .padding(horizontal = (16 * scale).dp).padding(bottom = (32 * scale).dp)) {
                CoorditText(stepLabels[step], CoorditTypography.gmarketBold(22f), Modifier.testTag("coordit-onboarding-title"))
                Spacer(Modifier.height(7.dp))
                CoorditText(stepDetails[step], CoorditTypography.gmarketMedium(12f).copy(color = AppColors.muted))
                Row(Modifier.padding(top = (24 * scale).dp).semantics(mergeDescendants = true) { contentDescription = "초기 설정 ${step + 1}단계, ${stepLabels[step]}" }, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    stepLabels.forEachIndexed { index, label ->
                        val color = if (index <= step) AppColors.ink else AppColors.muted
                        Column(Modifier.weight(1f)) {
                            CoorditText("0${index + 1}", CoorditTypography.gmarketMedium(9f).copy(color = color))
                            Spacer(Modifier.height(6.dp))
                            CoorditText(label, CoorditTypography.gmarketMedium(11f).copy(color = color))
                            Spacer(Modifier.height(12.dp))
                            Box(Modifier.fillMaxWidth().height(1.dp).background(if (index <= step) AppColors.ink else AppColors.line))
                        }
                    }
                }
                Crossfade(step, animationSpec = tween(200), label = "onboarding step", modifier = Modifier.padding(top = (22 * scale).dp)) { current ->
                    when (current) {
                        0 -> OnboardingCard(scale) {
                            Column(Modifier.padding(horizontal = (16 * scale).dp, vertical = (4 * scale).dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                    FieldLabel("이름 또는 별명", true)
                                    Entry(name, { name = it }, "이름 또는 별명", "예: 민아", "onboarding-display-name", !busy,
                                        modifier = Modifier.focusRequester(nameFocus), action = ImeAction.Next, onAction = ::advance)
                                }
                                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                    FieldLabel("성별")
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        listOf("female" to "여성", "male" to "남성", "prefer_not_to_say" to "응답하지 않음").forEach { (value, label) ->
                                            Action(label, { gender = value }, Modifier.weight(1f).testTag("onboarding-gender-$value").semantics { selected = gender == value }, !busy,
                                                primary = gender == value, field = gender != value, font = 12f, minHeight = 46f, outlined = true, bold = false)
                                        }
                                    }
                                }
                                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                    FieldLabel("생일")
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Entry(year, { year = it }, "생일 연도", "1998", "onboarding-birth-year", !busy, Modifier.weight(1f), "년", KeyboardType.Number, centered = true)
                                        Entry(month, { month = it }, "생일 월", "05", "onboarding-birth-month", !busy, Modifier.weight(1f), "월", KeyboardType.Number, centered = true)
                                        Entry(day, { day = it }, "생일 일", "17", "onboarding-birth-day", !busy, Modifier.weight(1f), "일", KeyboardType.Number, centered = true)
                                    }
                                }
                            }
                        }
                        1 -> OnboardingCard(scale) {
                            Column(Modifier.padding(horizontal = (16 * scale).dp, vertical = (4 * scale).dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        CoorditText("키", CoorditTypography.gmarketMedium(12f))
                                        Entry(height, { height = it }, "키", "170", "onboarding-measurement-height", !busy, unit = "cm", keyboard = KeyboardType.Decimal, font = 14f, minHeight = 50f)
                                    }
                                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        CoorditText("몸무게", CoorditTypography.gmarketMedium(12f))
                                        Entry(weight, { weight = it }, "몸무게", "58", "onboarding-measurement-weight", !busy, unit = "kg", keyboard = KeyboardType.Decimal, font = 14f, minHeight = 50f)
                                    }
                                }
                                CoorditText("선택 입력이에요. 나중에 마이페이지에서\n입력할 수 있어요.", CoorditTypography.gmarketMedium(11f).copy(color = AppColors.muted),
                                    Modifier.fillMaxWidth().background(AppColors.settingsField, ContinuousRoundedShape(7.dp)).padding((14 * scale).dp))
                            }
                        }
                        else -> Column(Modifier.fillMaxWidth().background(AppColors.panel, ContinuousRoundedShape(7.dp)).border(1.dp, AppColors.line, ContinuousRoundedShape(7.dp)).padding(horizontal = 16.dp)) {
                            ConsentRow("[필수] 서비스 이용약관", "계정 이용과 핏 추천 서비스의 기본 약관", terms, { terms = it }, "terms", !busy, { document = "terms" })
                            ConsentRow("[필수] 개인정보 처리방침", "프로필과 선택한 신체 정보의 처리 기준", privacy, { privacy = it }, "privacy", !busy, { document = "privacy" })
                            ConsentRow("[선택] 핏 데이터 개선", "추천 품질을 높이기 위한 비식별 분석", fitData, { fitData = it }, "fit-data", !busy)
                            ConsentRow("[선택] 마케팅 수신", "신상품과 혜택 소식 받기", marketing, { marketing = it }, "marketing", !busy, last = true)
                        }
                    }
                }
            }
            Column(Modifier.fillMaxWidth().background(AppColors.panel.copy(alpha = .97f)).padding(horizontal = (24 * scale).dp).padding(top = (10 * scale).dp, bottom = (12 * scale).dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                val message = validation ?: error ?: if (step == 2 && !(terms && privacy)) "필수 약관 2개에 동의해야 설정을 저장할 수 있어요." else null
                message?.let { CoorditText(it, CoorditTypography.gmarketMedium(11f).copy(color = if (validation != null || error != null) AppColors.danger else AppColors.muted), Modifier.semantics { liveRegion = LiveRegionMode.Polite }) }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(if (step == 1) 6.dp else 10.dp, Alignment.CenterHorizontally)) {
                    if (step != 0) Action("이전", ::back, Modifier.then(if (step == 1) Modifier.width((74 * scale).dp) else Modifier.weight(1f)).testTag("onboarding-back"), !busy)
                    if (step == 1) Action("나중에 입력하기", { move(2) }, Modifier.width((116 * scale).dp).testTag("onboarding-skip"), !busy, field = true, font = 13f)
                    Action(if (step == 2) "설정 저장" else "다음 단계", {
                        when (step) {
                            0 -> advance()
                            1 -> move(2)
                            else -> {
                                focus.clearFocus()
                                validation = null
                                onSubmit(OnboardingRequest(name.trim(), gender.ifEmpty { null }, onboardingBirthDate(year, month, day),
                                    OnboardingRequest.Measurements(onboardingMeasurement(height), onboardingMeasurement(weight)),
                                    mapOf("terms_of_service" to OnboardingRequest.Consent(terms, OnboardingConsentVersion),
                                        "privacy_policy" to OnboardingRequest.Consent(privacy, OnboardingConsentVersion),
                                        "fit_data_improvement" to OnboardingRequest.Consent(fitData, OnboardingConsentVersion),
                                        "marketing" to OnboardingRequest.Consent(marketing, OnboardingConsentVersion))))
                            }
                        }
                    }, Modifier.then(if (step == 1) Modifier.width((112 * scale).dp) else Modifier.weight(1f)).testTag(if (step == 2) "onboarding-save" else "onboarding-next")
                        .semantics { if (busy) stateDescription = "저장 중" }, !busy && (step != 2 || terms && privacy), primary = true)
                }
            }
        }
    }
    document?.let { LegalSheet(it, onClose = { document = null }) }
}

@Composable
private fun OnboardingHeader(scale: Float, busy: Boolean, onBack: () -> Unit) {
    Pressable(onBack, Modifier.padding(top = (20 * scale).dp).width((370 * scale).dp).testTag("coordit-settings-back")
        .semantics { contentDescription = "회원가입 뒤로가기" }, enabled = !busy, cornerRadius = 7 * scale) {
        Row(Modifier.fillMaxWidth().height((60 * scale).dp).background(AppColors.panel).padding(horizontal = (29 * scale).dp), verticalAlignment = Alignment.CenterVertically) {
            Canvas(Modifier.size((19 * scale).dp, (25 * scale).dp)) {
                drawLine(Color.Black, Offset(size.width * .67f, size.height * .12f), Offset(size.width * .16f, size.height * .5f), 3 * scale * density, StrokeCap.Round)
                drawLine(Color.Black, Offset(size.width * .16f, size.height * .5f), Offset(size.width * .67f, size.height * .88f), 3 * scale * density, StrokeCap.Round)
            }
            Spacer(Modifier.width((18 * scale).dp))
            CoorditText("회원가입", CoorditTypography.gmarketBold(22 * scale).copy(color = Color.Black, letterSpacing = (1.5 * scale).sp))
        }
    }
}

@Composable
private fun FieldLabel(title: String, required: Boolean = false) {
    Row(horizontalArrangement = Arrangement.spacedBy(7.dp), verticalAlignment = Alignment.CenterVertically) {
        CoorditText(title, CoorditTypography.gmarketMedium(13f))
        CoorditText(if (required) "필수" else "선택", CoorditTypography.gmarketMedium(10f).copy(color = if (required) AppColors.danger else AppColors.muted))
    }
}

@Composable
private fun Entry(value: String, onChange: (String) -> Unit, label: String, placeholder: String, tag: String, enabled: Boolean,
    modifier: Modifier = Modifier, unit: String? = null, keyboard: KeyboardType = KeyboardType.Text,
    action: ImeAction = ImeAction.Done, onAction: (() -> Unit)? = null, centered: Boolean = false, font: Float = 15f, minHeight: Float = 52f) {
    val focus = LocalFocusManager.current
    BasicTextField(value, onChange, modifier.fillMaxWidth().heightIn(min = minHeight.dp).testTag(tag)
        .background(AppColors.settingsField, ContinuousRoundedShape(7.dp)).border(1.dp, AppColors.line, ContinuousRoundedShape(7.dp)).padding(horizontal = if (unit == null) 15.dp else 10.dp, vertical = 12.dp)
        .semantics { contentDescription = label }, enabled = enabled, singleLine = true,
        textStyle = CoorditTypography.gmarketMedium(font).copy(textAlign = if (centered) TextAlign.Center else TextAlign.Start), cursorBrush = SolidColor(AppColors.ink),
        keyboardOptions = KeyboardOptions(keyboardType = keyboard, imeAction = action),
        keyboardActions = KeyboardActions(onDone = { onAction?.invoke() ?: focus.clearFocus() }, onNext = { onAction?.invoke() ?: focus.clearFocus() }),
        decorationBox = { inner -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            Box(Modifier.weight(1f), contentAlignment = if (centered) Alignment.Center else Alignment.CenterStart) {
                if (value.isEmpty()) CoorditText(placeholder, CoorditTypography.gmarketMedium(font).copy(color = Color(0xFFC4C4C6)))
                inner()
            }
            unit?.let { CoorditText(it, CoorditTypography.gmarketMedium(12f).copy(color = AppColors.muted)) }
        } })
}

@Composable
private fun Action(text: String, onClick: () -> Unit, modifier: Modifier, enabled: Boolean,
    primary: Boolean = false, field: Boolean = false, font: Float = 14f, minHeight: Float = 52f,
    outlined: Boolean = !primary && !field, bold: Boolean = primary) {
    val background = if (primary && enabled) AppColors.ink else if (field || primary) AppColors.settingsField else AppColors.panel
    val shape = ContinuousRoundedShape(7.dp)
    Box(modifier.clip(shape).clickable(enabled = enabled, role = Role.Button, onClick = onClick)
        .background(background).then(if (outlined) Modifier.border(1.dp, if (primary) AppColors.ink else AppColors.line, shape) else Modifier)
        .heightIn(min = minHeight.dp).padding(horizontal = 4.dp, vertical = 10.dp), contentAlignment = Alignment.Center) {
        CoorditText(text, (if (bold) CoorditTypography.gmarketBold(font) else CoorditTypography.gmarketMedium(font)).copy(
            color = if (primary && enabled) Color.White else if (field || primary) AppColors.muted else AppColors.ink, textAlign = TextAlign.Center, lineBreak = CoorditTypography.koreanParagraph, localeList = CoorditTypography.koreanLocale))
    }
}

@Composable
private fun OnboardingCard(scale: Float, content: @Composable ColumnScope.() -> Unit) {
    val shape = ContinuousRoundedShape((7 * scale).dp)
    Column(Modifier.fillMaxWidth().coorditShadow(Color.Black.copy(alpha = .035f), (9 * scale).dp, shape, (4 * scale).dp)
        .background(AppColors.panel, shape).border(1.dp, AppColors.line.copy(alpha = .7f), shape)
        .padding(vertical = (12 * scale).dp), content = content)
}

@Composable
private fun ConsentRow(title: String, detail: String, checked: Boolean, onChange: (Boolean) -> Unit, tag: String,
    enabled: Boolean, onView: (() -> Unit)? = null, last: Boolean = false) {
    Column {
        Row(Modifier.fillMaxWidth().padding(vertical = 17.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
            Pressable({ onChange(!checked) }, Modifier.width(63.dp).height(30.dp).padding(top = 2.dp).testTag("onboarding-consent-$tag").semantics {
                contentDescription = title; role = Role.Switch; toggleableState = if (checked) androidx.compose.ui.state.ToggleableState.On else androidx.compose.ui.state.ToggleableState.Off
            }, enabled = enabled) {
                Box(Modifier.size(63.dp, 28.dp).background(if (checked) AppColors.ink else Color(0xFFC4C4C6), RoundedCornerShape(20.dp)).padding(2.dp), contentAlignment = if (checked) Alignment.CenterEnd else Alignment.CenterStart) {
                    Box(Modifier.size(37.dp, 24.dp).background(Color.White, RoundedCornerShape(20.dp)))
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                CoorditText(title, CoorditTypography.gmarketMedium(13f))
                CoorditText(detail, CoorditTypography.gmarketMedium(10f).copy(color = AppColors.muted))
            }
            onView?.let { Pressable(it, Modifier.width((22 * LocalDensity.current.fontScale).dp).height(30.dp).testTag("onboarding-legal-$tag").semantics { contentDescription = "$title 보기" }, enabled = enabled) {
                CoorditText("보기", CoorditTypography.gmarketMedium(11f).copy(textDecoration = TextDecoration.Underline), Modifier.align(Alignment.TopCenter))
            } }
        }
        if (!last) Box(Modifier.fillMaxWidth().height(1.dp).background(AppColors.line))
    }
}

@Composable
private fun LegalSheet(document: String, onClose: () -> Unit) {
    val terms = document == "terms"
    val title = if (terms) "서비스 이용약관" else "개인정보 처리방침"
    val sections = if (terms) listOf(
        "서비스 이용" to "Coordit은 기준 의류와 제품 사이즈 정보를 비교해,\n핏 추천을 돕는 서비스입니다.",
        "추천의 성격" to "추천은 참고 정보이며 소재, 세탁 상태, 브랜드 설계와 개인 선호에 따라 실제 착용감은 달라질 수 있습니다.",
        "이용 제한" to "타인의 계정을 사용하거나 서비스의 정상 동작을 방해하는 행위는 허용되지 않습니다.",
    ) else listOf(
        "수집하는 정보" to "소셜 로그인 이메일, 프로필, 그리고 사용자가 직접 선택해 입력한 신체·의류 정보를 처리합니다.",
        "이용 목적" to "계정 식별, 개인 핏 프로필 구성, 저장한 의류·사이즈 정보 관리에 사용합니다.",
        "보관과 삭제" to "정보는 서비스 이용 기간 동안 보관하며, 사용자는 계정 설정에서 열람·수정·삭제를 요청할 수 있습니다.",
    )
    Dialog(onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            Column(Modifier.fillMaxWidth().fillMaxHeight(.94f).background(AppColors.appBackground, RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)).navigationBarsPadding().testTag("onboarding-legal-sheet")) {
                Pressable(onClose, Modifier.align(Alignment.End).padding(end = 16.dp).sizeIn(minWidth = 48.dp, minHeight = 64.dp).testTag("onboarding-legal-close")) {
                    CoorditText("닫기", CoorditTypography.gmarketMedium(14f))
                }
                Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 38.dp, vertical = 24.dp), verticalArrangement = Arrangement.spacedBy(26.dp)) {
                    CoorditText(title, CoorditTypography.gmarketMedium(27f))
                    sections.forEach { (heading, content) ->
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            CoorditText(heading, CoorditTypography.gmarketBold(15f))
                            CoorditText(content, CoorditTypography.gmarketMedium(13f).copy(color = AppColors.muted, lineHeight = 21.sp, lineBreak = CoorditTypography.koreanParagraph, localeList = CoorditTypography.koreanLocale))
                        }
                    }
                }
            }
        }
    }
}
