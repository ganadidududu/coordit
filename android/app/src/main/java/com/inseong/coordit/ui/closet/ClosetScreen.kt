package com.inseong.coordit.ui.closet

import android.graphics.Bitmap
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.inseong.coordit.R
import com.inseong.coordit.data.closet.*
import com.inseong.coordit.data.closet.ClosetScreen as ClosetScreenRoute
import com.inseong.coordit.data.home.HomeCategory
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*
import java.util.Locale

class ClosetPhotos {
    val images = mutableStateMapOf<String, Bitmap>()
    fun clear() = images.clear()
}

@Composable
fun ClosetScreen(model: ClosetViewModel, photos: ClosetPhotos, onHome: () -> Unit, onProfile: () -> Unit, onFitLab: () -> Unit) {
    val state by model.state.collectAsStateWithLifecycle()
    val focus = LocalFocusManager.current
    var upper by rememberSaveable { mutableStateOf(true) }
    var categoryName by rememberSaveable { mutableStateOf<String?>(null) }
    var search by rememberSaveable { mutableStateOf("") }
    var rename by remember { mutableStateOf<String?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    fun back() { focus.clearFocus(); if (!state.busy) { if (state.screen == ClosetScreenRoute.Overview) onHome() else model.back() } }
    BackHandler { back() }
    LaunchedEffect(state.screen, state.detail?.item?.id) {
        if (state.screen == ClosetScreenRoute.Overview) photos.images.remove("draft")
        if (state.screen == ClosetScreenRoute.Detail) {
            state.detail?.item?.let { item ->
                photos.images.remove("draft")?.let { photos.images[item.id] = it }
            }
        }
    }
    BoxWithConstraints(Modifier.fillMaxSize().testTag("closet-${state.screen.name.lowercase()}")) {
        val s = maxWidth.value / ClosetDesign.canvasWidth
        SharedAppBackground(s)
        Column(Modifier.fillMaxSize().imePadding().padding(top = (ClosetDesign.contentTop * s).dp)) {
            ClosetTitleBar(when (state.screen) {
                ClosetScreenRoute.Overview -> "CLOSET"
                ClosetScreenRoute.Method -> "ADD CLOTHES"
                ClosetScreenRoute.Manual -> "MANUAL INPUT"
                ClosetScreenRoute.Link -> "LINK INPUT"
                ClosetScreenRoute.Photo -> "PHOTO INPUT"
                ClosetScreenRoute.Saving -> "FIT CHECK"
                ClosetScreenRoute.Detail -> "FIT DETAIL"
            }, s, ::back, Modifier.align(Alignment.CenterHorizontally).testTag("closet-back"))
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState())
                .padding(horizontal = ((when (state.screen) { ClosetScreenRoute.Overview -> ClosetDesign.overviewInset; ClosetScreenRoute.Detail -> ClosetDesign.detailInset; else -> ClosetDesign.contentInset }) * s).dp)
                .padding(top = ((when (state.screen) { ClosetScreenRoute.Overview -> 28; ClosetScreenRoute.Method -> 24; ClosetScreenRoute.Detail -> 26; else -> 22 }) * s).dp, bottom = (120 * s).dp), verticalArrangement = Arrangement.spacedBy(((when (state.screen) { ClosetScreenRoute.Overview -> 22; ClosetScreenRoute.Detail -> 20; ClosetScreenRoute.Method -> 18; else -> 16 }) * s).dp)) {
                when (state.screen) {
                    ClosetScreenRoute.Overview -> {
                        Column(Modifier.fillMaxWidth().background(AppColors.panel,ContinuousRoundedShape((7*s).dp)).padding((ClosetDesign.cardPadding*s).dp),verticalArrangement=Arrangement.spacedBy((12*s).dp)) {
                            val profile = state.profiles[upper]
                            Column(verticalArrangement=Arrangement.spacedBy((4*s).dp)) {
                                CoorditText("${profile?.referenceCount ?: 0}개 기준 의류로 계산",CoorditTypography.mona12(11*s).copy(color=AppColors.ink.copy(alpha=ClosetDesign.secondaryOpacity)))
                                CoorditText("100점 핏 사이즈", CoorditTypography.climate2010(21 * s).copy(letterSpacing=(-.9f*s).sp))
                            }
                            ClosetSegment(upper, s) { upper = it; categoryName = null }
                            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy((7 * s).dp)) {
                                ClosetChip("전체", categoryName == null, s) { categoryName = null }
                                HomeCategory.entries.filter { it.upper == upper }.forEach { c -> ClosetChip(c.title, categoryName == c.name, s) { categoryName = c.name } }
                            }
                            MeasurementGrid(profile?.measurements.orEmpty(), upper, s)
                        }
                        ClosetAction("보유 의류 추가하기", s, "closet-add", enabled = !state.loading, font=11.5f, capsule=true) { photos.images.remove("draft"); model.startAdd() }
                        ClosetSearch(search, { search = it }, s)
                        if (state.loading) ClosetText("옷장을 불러오고 있어요.", 12f, s)
                        state.error?.let { ClosetError(it, s); ClosetAction("다시 시도", s, "closet-retry", secondary = true) { model.load() } }
                        val items = state.items.filter { it.category.upper == upper && (categoryName == null || it.category.name == categoryName) && it.name.contains(search, ignoreCase = true) }
                        Column(verticalArrangement=Arrangement.spacedBy((ClosetDesign.smallGap*s).dp)) { items.chunked(2).forEach { pair ->
                            Row(horizontalArrangement = Arrangement.spacedBy((10 * s).dp)) {
                                pair.forEach { item ->
                                    ClosetGarmentCard(item,photos.images[item.id],s,Modifier.weight(1f)) { model.openItem(item) }
                                }
                                if (pair.size == 1) Spacer(Modifier.weight(1f))
                            }
                        } }
                    }
                    ClosetScreenRoute.Method -> {
                        Column(Modifier.padding(horizontal=(5*s).dp),verticalArrangement=Arrangement.spacedBy((5*s).dp)) {
                            ClosetText("어떻게 추가할까요?", 20f, s, bold = true)
                            CoorditText("가지고 있는 정보에 맞는 방식을 선택해주세요.",CoorditTypography.gmarketMedium(11*s).copy(color=AppColors.ink.copy(alpha=.46f)))
                        }
                        Column(verticalArrangement=Arrangement.spacedBy((11*s).dp)) {
                            listOf(Triple(ClosetMethod.Link,"링크로 불러오기","상품 링크에서 사이즈 정보를 불러와요."), Triple(ClosetMethod.Photo,"사진으로 첨부하기","사이즈표 사진을 분석해요."), Triple(ClosetMethod.Manual,"직접 입력하기","실측 사이즈를 직접 입력해요.")).forEach { (method,title,description) ->
                                val shape=ContinuousRoundedShape((ClosetDesign.panelRadius*s).dp)
                                Pressable({ model.chooseMethod(method) }, Modifier.fillMaxWidth().shadow((ClosetDesign.smallGap*s).dp,shape,clip=false,ambientColor=Color.Black.copy(alpha=.06f),spotColor=Color.Black.copy(alpha=.06f)).testTag("closet-method-${method.name.lowercase()}"),cornerRadius=9*s) {
                                    Row(Modifier.fillMaxWidth().heightIn(min=(84*s).dp).background(AppColors.panel,shape).border((.8f*s).dp,AppColors.ink.copy(alpha=.08f),RoundedCornerShape((ClosetDesign.panelRadius*s).dp)).padding((13*s).dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy((ClosetDesign.cardPadding*s).dp)) {
                                        Box(Modifier.size((50*s).dp).background(AppColors.ink,ContinuousRoundedShape((ClosetDesign.panelRadius*s).dp)),contentAlignment=Alignment.Center) { MethodIcon(method,s) }
                                        Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy((5*s).dp)) {
                                            CoorditText(title,CoorditTypography.gmarketBold(ClosetDesign.sectionFont*s).copy(color=Color.Black))
                                            ClosetText(description,9f,s,muted=true)
                                        }
                                        Canvas(Modifier.size((ClosetDesign.panelRadius*s).dp,(16*s).dp)) {
                                            val path=Path().apply { moveTo(0f,0f);lineTo(size.width,size.height/2);lineTo(0f,size.height) }
                                            drawPath(path,AppColors.ink.copy(alpha=.34f),style=androidx.compose.ui.graphics.drawscope.Stroke((2*s).dp.toPx(),cap=StrokeCap.Round,join=StrokeJoin.Round))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ClosetScreenRoute.Manual, ClosetScreenRoute.Link, ClosetScreenRoute.Photo -> {
                        val draft = state.draft
                        ClosetPanel(s, if (state.screen == ClosetScreenRoute.Link) "옷 종류" else "기본 정보",
                            if (state.screen == ClosetScreenRoute.Link) "링크를 분석하기 전에 옷 종류를 선택해 주세요." else "옷장에 표시할 이름과 종류를 입력해주세요.") {
                            if (state.screen != ClosetScreenRoute.Link) ClosetEntry(draft.name, { value -> model.editDraft { it.copy(name = value) } }, "의류 이름", "closet-name", s, enabled = !state.busy)
                            ClosetSegment(draft.category.upper, s, !state.busy) { value -> model.editDraft { it.copy(category = if (value) HomeCategory.Tshirt else HomeCategory.Pants) } }
                            var selecting by remember { mutableStateOf(false) }
                            Pressable({ selecting = true }, Modifier.fillMaxWidth().testTag("closet-category"), enabled = !state.busy) {
                                Box(Modifier.fillMaxWidth().height((ClosetDesign.fieldHeight*s).dp).background(AppColors.closetField,ContinuousRoundedShape((ClosetDesign.fieldRadius*s).dp)).padding(horizontal=(25*s).dp),contentAlignment=Alignment.CenterStart) { Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy((ClosetDesign.smallGap*s).dp)) { ClosetText(draft.category.title,16f,s); CategoryChevrons(s) } }
                            }
                            if (selecting) Dialog(onDismissRequest = { selecting = false }) {
                                ClosetPanel(s) { HomeCategory.entries.filter { it.upper == draft.category.upper }.forEach { c ->
                                    ClosetAction(c.title, s, "closet-category-${c.wireName}", secondary = true) { model.editDraft { it.copy(category = c) }; selecting = false }
                                } }
                            }
                        }
                        if (state.screen == ClosetScreenRoute.Manual) ClosetPanel(s, "실측 사이즈", "단위는 cm로 입력해주세요.") {
                            val values = listOf(draft.measurement1,draft.measurement2,draft.measurement3,draft.measurement4)
                            Column(verticalArrangement = Arrangement.spacedBy((8 * s).dp)) { fields(draft.category.upper).chunked(2).forEachIndexed { row, pair ->
                                Row(horizontalArrangement = Arrangement.spacedBy((8 * s).dp)) { pair.forEachIndexed { col, field ->
                                    val i = row * 2 + col
                                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((5 * s).dp)) {
                                        ClosetText(when(field.first) { "chest_width" -> "가슴"; "waist_width" -> "허리"; "hip_width" -> "엉덩이"; "outseam" -> "아웃심"; else -> field.second }, 9f, s, muted = true)
                                        ClosetEntry(values[i], { value -> model.editDraft { when(i) { 0 -> it.copy(measurement1=value);1 -> it.copy(measurement2=value);2 -> it.copy(measurement3=value);else -> it.copy(measurement4=value) } } }, "0.0", "closet-measurement-$i", s, true, !state.busy, "cm")
                                    }
                                } }
                            }
                        }
                        }
                        if (state.screen == ClosetScreenRoute.Link) {
                            ClosetPanel(s,"상품 링크","사이즈 정보가 있는 상품 페이지 주소를 붙여넣어 주세요.") {
                                ClosetEntry(draft.productLink, { value -> model.editDraft { it.copy(productLink = value) } }, "https://", "closet-url", s, enabled = !state.busy, linkIcon=true)
                            }
                            state.error?.let { error -> ClosetPanel(s,"링크에서 표를 찾지 못했어요",error) {
                                Row(horizontalArrangement=Arrangement.spacedBy((ClosetDesign.smallGap*s).dp)) {
                                    CoorditButton("사진 OCR로 입력",{ model.chooseMethod(ClosetMethod.Photo) },Modifier.weight(1f).testTag("closet-switch-photo"),enabled=!state.busy,height=48*s,fontSize=12*s)
                                    CoorditButton("직접 입력",{ model.chooseMethod(ClosetMethod.Manual) },Modifier.weight(1f).testTag("closet-switch-manual"),secondary=true,enabled=!state.busy,height=48*s,fontSize=12*s)
                                }
                            } }
                            if (draft.sizeRows.isNotEmpty()) ClosetPanel(s,"불러온 상품","상품명은 링크에서 자동으로 가져왔어요.") {
                                Box(Modifier.fillMaxWidth().heightIn(min=(ClosetDesign.fieldHeight*s).dp).background(AppColors.closetField,ContinuousRoundedShape((ClosetDesign.fieldRadius*s).dp)).padding(horizontal=(13*s).dp),contentAlignment=Alignment.CenterStart) {
                                    CoorditText(draft.name,CoorditTypography.gmarketBold(ClosetDesign.measurementFont*s).copy(color=Color.Black))
                                }
                            }
                        }
                        if (state.screen == ClosetScreenRoute.Photo) {
                            ClosetPhotoInput(draft.category.upper, onRows = { rows ->
                                model.editDraft { it.copy(hasSizeChartImage = true) }
                                model.setSizeRows(rows.mapIndexed { i,row -> ClosetSizeRow(i.toString(), row.label, row.measurements) })
                            }, onGarment = { bitmap -> photos.images["draft"] = bitmap; model.editDraft { it.copy(hasGarmentImage = true) } }, enabled = !state.busy, scale = s)
                        }
                        if (draft.sizeRows.isNotEmpty() && state.screen != ClosetScreenRoute.Manual) ClosetPanel(s,"내 사이즈 선택","구매해서 보유 중인 사이즈 한 개를 선택해 주세요.") {
                            draft.sizeRows.forEach { row ->
                                Pressable({ model.selectSize(row.id) }, Modifier.fillMaxWidth().testTag("closet-size-${row.id}"), enabled = !state.busy) {
                                    Column(Modifier.fillMaxWidth().background(if (draft.selectedSizeRowId == row.id) AppColors.ink else AppColors.closetField).padding(12.dp)) {
                                        val color = if (draft.selectedSizeRowId == row.id) Color.White else AppColors.ink
                                        CoorditText(row.label,CoorditTypography.gmarketBold(ClosetDesign.measurementFont*s).copy(color=color))
                                        CoorditText(fields(draft.category.upper).mapNotNull { (key,label) -> row.measurements[key]?.let { "$label ${number(it)}" } }.joinToString("  "),CoorditTypography.gmarketMedium(10*s).copy(color=color))
                                    }
                                }
                            }
                        }
                        if(state.screen != ClosetScreenRoute.Link) state.error?.let { ClosetError(it,s) }
                        val manualReady = draft.name.isNotBlank() && listOf(draft.measurement1,draft.measurement2,draft.measurement3,draft.measurement4).all { it.toDoubleOrNull()?.let { v -> v.isFinite() && v > 0 } == true }
                        val ready = if (state.screen == ClosetScreenRoute.Manual) manualReady else if (state.screen == ClosetScreenRoute.Link && draft.sizeRows.isEmpty()) draft.productLink.isNotBlank() else draft.name.isNotBlank() && draft.selectedSizeRowId != null && (state.screen != ClosetScreenRoute.Photo || draft.hasSizeChartImage)
                        if(state.screen == ClosetScreenRoute.Link) Spacer(Modifier.height((1*s).dp))
                        ClosetAction(if (state.screen == ClosetScreenRoute.Link) { if(state.busy) "링크 분석 중…" else if(draft.sizeRows.isEmpty()) "링크 분석하기" else "선택한 사이즈로 등록" } else if(state.busy) "불러오고 있어요" else "보유 의류 등록하기",s,"closet-submit",enabled=ready && !state.busy,font=17f) {
                            focus.clearFocus()
                            if (state.screen == ClosetScreenRoute.Link && draft.sizeRows.isEmpty()) model.prefill() else model.save()
                        }
                        if (state.screen == ClosetScreenRoute.Photo) ClosetAction("직접 입력으로 계속하기",s,"closet-switch-manual",secondary=true,enabled=!state.busy) { model.chooseMethod(ClosetMethod.Manual) }
                    }
                    ClosetScreenRoute.Saving -> {
                        Spacer(Modifier.height((120*s).dp))
                        ClosetPanel(s) {
                            ClosetText(if (state.busy) "보유 의류를 등록하고 있어요" else "저장하지 못했어요",15f,s,bold=true)
                            ClosetText(if(state.busy) "선택한 사이즈와 실측 정보를 옷장에 저장하고 있어요." else "입력한 정보는 그대로예요. 다시 시도해 주세요.",9f,s,muted=true)
                            state.error?.let { ClosetError(it,s) }
                            if (!state.busy) ClosetAction("다시 시도",s,"closet-save-retry") { model.save() }
                        }
                    }
                    ClosetScreenRoute.Detail -> {
                        if (state.loading) ClosetText("상세 정보를 불러오고 있어요.",12f,s)
                        state.detail?.let { detail ->
                            Row(Modifier.padding(top=(18*s).dp),horizontalArrangement=Arrangement.spacedBy((13*s).dp)) {
                                GarmentArtwork(detail.item.category.upper,photos.images[detail.item.id],Modifier.size((126*s).dp,(168*s).dp),s)
                                Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy((ClosetDesign.smallGap*s).dp)) {
                                    Box(Modifier.heightIn(min=(ClosetDesign.fieldHeight*s).dp)) { CoorditText(detail.item.name,CoorditTypography.gmarketBold(19*s).copy(color=Color.Black)) }
                                    ClosetAction("옷 이름 수정하기",s,"closet-rename",secondary=true,font=10f,enabled=!state.busy) { rename=detail.item.name }
                                    ClosetGarmentPhotoPicker(onPhoto={ photos.images[detail.item.id]=it },enabled=!state.busy,compact=true,scale=s)
                                    ClosetAction("내 옷장에서 삭제하기",s,"closet-delete",secondary=true,font=10f,enabled=!state.busy) { confirmDelete=true }
                                }
                            }
                            detail.sizes.firstOrNull()?.let { row -> DetailSizeChart(row.label, row.measurements, detail.item.category.upper, s) }
                            ClosetMannequin(detail.item.category.upper, detail.comparison?.diff.orEmpty(), s)
                            ClosetFitScore(detail.comparison,detail.item.category.upper,s)
                            detail.analysisError?.let { ClosetError(it,s) }
                        }
                        state.error?.let { ClosetError(it,s); ClosetAction("다시 시도",s,"closet-detail-retry",secondary=true) { state.detail?.item?.let(model::openItem) } }
                    }
                }
            }
        }
        CoorditHeader(s,onProfile,Modifier.align(Alignment.TopCenter).padding(top=(55*s).dp))
        CoorditBottomNavigation(CoorditTab.Closet,s,{ tab -> if (!state.busy) when(tab) {
            CoorditTab.Home -> onHome()
            CoorditTab.FitLab -> onFitLab()
            CoorditTab.Closet -> if(state.screen != ClosetScreenRoute.Overview) model.back()
        } },Modifier.align(Alignment.BottomCenter))
        rename?.let { value -> Dialog(onDismissRequest={ if(!state.busy) rename=null }) { ClosetPanel(s,"옷 이름 수정하기","옷장에 표시할 이름을 입력해 주세요.") {
            ClosetEntry(value,{rename=it},"옷 이름","closet-rename-input",s,enabled=!state.busy)
            ClosetAction("저장",s,"closet-rename-save",enabled=value.isNotBlank()&&!state.busy) { model.rename(value); rename=null }
            ClosetAction("취소",s,"closet-rename-cancel",secondary=true) {rename=null}
        } } }
        if(confirmDelete) Dialog(onDismissRequest={if(!state.busy)confirmDelete=false}) { ClosetPanel(s,"옷장에서 삭제할까요?","의류와 저장된 사이즈 정보를 함께 삭제합니다.") {
            ClosetAction("삭제",s,"closet-delete-confirm",enabled=!state.busy) {model.delete();confirmDelete=false}
            ClosetAction("취소",s,"closet-delete-cancel",secondary=true) {confirmDelete=false}
        } }
    }
}

internal fun fields(upper:Boolean): List<Pair<String,String>> = if(upper) listOf("shoulder_width" to "어깨","chest_width" to "가슴단면","total_length" to "총장","sleeve_length" to "소매") else listOf("waist_width" to "허리단면","hip_width" to "엉덩이단면","rise" to "밑위","outseam" to "총장")
private fun number(value:Double)=String.format(Locale.US,"%.2f",value).trimEnd('0').trimEnd('.')

@Composable
internal fun ClosetText(text:String,font:Float,s:Float=1f,bold:Boolean=false,muted:Boolean=false) {
    CoorditText(text,(if(bold) CoorditTypography.gmarketBold(font*s) else CoorditTypography.gmarketMedium(font*s)).copy(color=if(muted) AppColors.ink.copy(alpha=ClosetDesign.secondaryOpacity) else AppColors.ink))
}
@Composable
internal fun ClosetPanel(s:Float=1f,title:String?=null,subtitle:String?=null,content:@Composable ColumnScope.()->Unit) {
    val shape=ContinuousRoundedShape((ClosetDesign.panelRadius*s).dp)
    Column(Modifier.fillMaxWidth().background(AppColors.panel,shape).border((ClosetDesign.panelBorderWidth*s).dp,AppColors.ink.copy(alpha=ClosetDesign.panelBorderOpacity),RoundedCornerShape((ClosetDesign.panelRadius*s).dp)).padding((ClosetDesign.cardPadding*s).dp),verticalArrangement=Arrangement.spacedBy((11*s).dp)) {
        if(title!=null) Column(verticalArrangement=Arrangement.spacedBy((4*s).dp)) { CoorditText(title,CoorditTypography.gmarketBold(ClosetDesign.sectionFont*s).copy(color=Color.Black));subtitle?.let{CoorditText(it,CoorditTypography.gmarketMedium(ClosetDesign.captionFont*s).copy(color=AppColors.ink.copy(alpha=ClosetDesign.formHintOpacity)))} }
        content()
    }
}
@Composable
internal fun ClosetAction(text:String,s:Float=1f,tag:String="",secondary:Boolean=false,enabled:Boolean=true,font:Float=12f,capsule:Boolean=false,onClick:()->Unit) {
    Pressable(onClick,Modifier.fillMaxWidth().testTag(tag),enabled,cornerRadius=if(capsule)30*s else 7*s) {
        Box(Modifier.fillMaxWidth().heightIn(min=(if(font>=17)ClosetDesign.primaryHeight*s else if(secondary && font==10f)ClosetDesign.detailActionHeight*s else ClosetDesign.capsuleHeight*s).dp)
            .background(if(secondary)AppColors.panel else AppColors.ink)
            .padding(horizontal=(10*s).dp,vertical=(ClosetDesign.smallGap*s).dp),contentAlignment=Alignment.Center) {
            CoorditText(text,(if(secondary && font==10f) CoorditTypography.gmarketMedium(font*s) else CoorditTypography.gmarketBold(font*s)).copy(color=if(secondary && font==10f)Color.Black else if(secondary)AppColors.ink else Color.White.copy(alpha=if(enabled)1f else .38f),textAlign=TextAlign.Center))
        }
    }
}
@Composable
internal fun ClosetError(message:String,s:Float) { CoorditText(message,CoorditTypography.gmarketMedium(11*s).copy(color=AppColors.danger),Modifier.semantics{liveRegion=LiveRegionMode.Polite}) }
@Composable
internal fun ClosetEntry(value:String,onChange:(String)->Unit,placeholder:String,tag:String,s:Float=1f,decimal:Boolean=false,enabled:Boolean=true,unit:String?=null,linkIcon:Boolean=false) {
    val focus=LocalFocusManager.current
    Row(Modifier.fillMaxWidth().heightIn(min=((if(decimal)ClosetDesign.measurementHeight else ClosetDesign.fieldHeight)*s).dp).background(AppColors.closetField,ContinuousRoundedShape(((if(decimal)7 else 8)*s).dp)).padding(horizontal=((if(decimal)10 else 13)*s).dp,vertical=(ClosetDesign.smallGap*s).dp),verticalAlignment=Alignment.CenterVertically) {
        if(linkIcon) { LinkGlyph(s,AppColors.ink.copy(alpha=.56f)); Spacer(Modifier.width((10*s).dp)) }
        BasicTextField(value,onChange,Modifier.weight(1f).testTag(tag),enabled=enabled,singleLine=true,textStyle=if(decimal)CoorditTypography.gmarketBold(ClosetDesign.measurementFont*s) else CoorditTypography.gmarketMedium(ClosetDesign.bodyFont*s),cursorBrush=SolidColor(AppColors.ink),keyboardOptions=KeyboardOptions(keyboardType=if(decimal)KeyboardType.Decimal else if(linkIcon)KeyboardType.Uri else KeyboardType.Text,imeAction=ImeAction.Done),keyboardActions=KeyboardActions(onDone={focus.clearFocus()}),decorationBox={inner->Box{if(value.isEmpty())CoorditText(placeholder,(if(decimal)CoorditTypography.gmarketBold(ClosetDesign.measurementFont*s) else CoorditTypography.gmarketMedium(ClosetDesign.bodyFont*s)).copy(color=ClosetDesign.placeholderColor));inner()}})
        unit?.let{CoorditText(it,CoorditTypography.gmarketMedium(ClosetDesign.captionFont*s).copy(color=AppColors.ink.copy(alpha=.36f)))}
    }
}
@Composable
private fun ClosetSegment(upper:Boolean,s:Float,enabled:Boolean=true,onChange:(Boolean)->Unit) {
    Row(Modifier.fillMaxWidth().background(AppColors.closetField,CircleShape).padding((5*s).dp),horizontalArrangement=Arrangement.spacedBy((7*s).dp)) {
        listOf(true,false).forEach{u->Pressable({onChange(u)},Modifier.weight(1f).testTag(if(u)"closet-top" else "closet-bottom"),enabled,cornerRadius=30f){Box(Modifier.fillMaxWidth().height((28*s).dp).background(if(upper==u)AppColors.ink else Color.White.copy(alpha=.65f)),contentAlignment=Alignment.Center){CoorditText(if(u)"상의" else "하의",CoorditTypography.gmarketMedium(11*s).copy(color=if(upper==u)Color.White else AppColors.ink))}}}
    }
}
@Composable
private fun ClosetChip(title:String,selected:Boolean,s:Float,onClick:()->Unit) {Pressable(onClick,cornerRadius=30f){Box(Modifier.background(if(selected)AppColors.ink else AppColors.closetField).heightIn(min=(28*s).dp).padding(horizontal=(10*s).dp),contentAlignment=Alignment.Center){CoorditText(title,CoorditTypography.gmarketMedium(10*s).copy(color=if(selected)Color.White else AppColors.ink))}}}
@Composable
private fun MeasurementGrid(values:Map<String,Double?>,upper:Boolean,s:Float,difference:Boolean=false) {
    Column(verticalArrangement=Arrangement.spacedBy((ClosetDesign.smallGap*s).dp)) { fields(upper).chunked(2).forEach{pair->Row(horizontalArrangement=Arrangement.spacedBy((ClosetDesign.smallGap*s).dp)){pair.forEach{(key,label)->Column(Modifier.weight(1f).heightIn(min=(51*s).dp).background(AppColors.closetField,ContinuousRoundedShape((ClosetDesign.fieldRadius*s).dp)).padding((ClosetDesign.metricTilePadding*s).dp),verticalArrangement=Arrangement.spacedBy((3*s).dp)) {
        val value=values[key]
        ClosetText(if(value==null)"-" else "${if(difference&&value>0)"+" else ""}${number(value)} cm",16f,s,bold=true);ClosetText(label,8f,s,muted=true)
    }}} } }
}
@Composable
private fun DetailSizeChart(label:String,values:Map<String,Double?>,upper:Boolean,s:Float) {
    Column(Modifier.fillMaxWidth().background(AppColors.panel,ContinuousRoundedShape((ClosetDesign.panelRadius*s).dp)).padding((ClosetDesign.cardPadding*s).dp),verticalArrangement=Arrangement.spacedBy((12*s).dp)) {
        Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
            ClosetText("등록 사이즈표",14f,s,bold=true)
            Spacer(Modifier.weight(1f))
            CoorditText(label.ifBlank { "단일 사이즈" },CoorditTypography.gmarketMedium(11*s).copy(color=AppColors.ink.copy(alpha=.62f)))
        }
        Column(verticalArrangement=Arrangement.spacedBy((ClosetDesign.smallGap*s).dp)) {
            fields(upper).chunked(2).forEach { pair ->
                Row(horizontalArrangement=Arrangement.spacedBy((ClosetDesign.smallGap*s).dp)) {
                    pair.forEach { (key,title) ->
                        Column(Modifier.weight(1f).background(Color.White.copy(alpha=.72f),ContinuousRoundedShape((7*s).dp)).padding((10*s).dp),verticalArrangement=Arrangement.spacedBy((3*s).dp)) {
                            CoorditText(title,CoorditTypography.gmarketLight(9*s).copy(color=AppColors.ink.copy(alpha=.55f)))
                            ClosetText(values[key]?.let { "${number(it)} cm" } ?: "—",13f,s,bold=true)
                        }
                    }
                }
            }
        }
    }
}
@Composable
private fun ClosetGarmentCard(item:ClosetItem,bitmap:Bitmap?,s:Float,modifier:Modifier=Modifier,onClick:()->Unit) {
    Pressable(onClick,modifier.testTag("closet-item-${item.id}"),cornerRadius=ClosetDesign.fieldRadius*s) {
        Column(Modifier.fillMaxWidth().background(AppColors.panel).padding((6*s).dp),verticalArrangement=Arrangement.spacedBy((3*s).dp)) {
            GarmentArtwork(item.category.upper,bitmap,Modifier.fillMaxWidth().aspectRatio(.75f),s)
            Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy((6*s).dp)) {
                Box(Modifier.background(if(item.category.upper)ClosetDesign.upperCategorySurface else AppColors.ink,CircleShape).heightIn(min=(13*s).dp).padding(horizontal=(6*s).dp),contentAlignment=Alignment.Center) {
                    CoorditText(item.category.title,CoorditTypography.gmarketMedium(6*s).copy(color=if(item.category.upper)AppColors.blue else Color.White))
                }
                androidx.compose.foundation.text.BasicText(item.name,Modifier.weight(1f),style=CoorditTypography.gmarketBold(ClosetDesign.bodyFont*s).copy(color=Color.Black),maxLines=1,overflow=androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            }
            Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy((4*s).dp)) {
                ClosetText("—",ClosetDesign.sectionFont,s,bold=true,muted=true)
                ClosetText("fit score",7.5f,s,muted=true)
            }
        }
    }
}
@Composable
private fun GarmentArtwork(upper:Boolean,bitmap:Bitmap?,modifier:Modifier,s:Float) {
    Box(modifier.clip(ContinuousRoundedShape((ClosetDesign.fieldRadius*s).dp)).background(Brush.verticalGradient(listOf(ClosetDesign.artworkTop,ClosetDesign.artworkBottom))).border((.7f*s).dp,ClosetDesign.artworkBorder,ContinuousRoundedShape((ClosetDesign.fieldRadius*s).dp)),contentAlignment=Alignment.Center) {
        if(bitmap!=null)Image(bitmap.asImageBitmap(),"의류 사진",Modifier.fillMaxSize(),contentScale=ContentScale.Crop)
        else Canvas(Modifier.size((28*s).dp).semantics{contentDescription=if(upper)"상의 사진 없음" else "하의 사진 없음"}) {
            val p=Path();val w=size.width;val h=size.height
            if(upper){p.moveTo(w*.3f,0f);p.lineTo(0f,h*.22f);p.lineTo(w*.15f,h*.45f);p.lineTo(w*.27f,h*.35f);p.lineTo(w*.27f,h);p.lineTo(w*.73f,h);p.lineTo(w*.73f,h*.35f);p.lineTo(w*.85f,h*.45f);p.lineTo(w,h*.22f);p.lineTo(w*.7f,0f)}
            else{p.moveTo(w*.2f,0f);p.lineTo(w*.8f,0f);p.lineTo(w,h);p.lineTo(w*.6f,h);p.lineTo(w*.5f,h*.4f);p.lineTo(w*.4f,h);p.lineTo(0f,h)}
            p.close();drawPath(p,AppColors.ink.copy(alpha=.18f))
        }
    }
}
@Composable
private fun MethodIcon(method:ClosetMethod,s:Float) {
    Canvas(Modifier.size((25*s).dp)) {
        val stroke=androidx.compose.ui.graphics.drawscope.Stroke(width=2.dp.toPx())
        if(method==ClosetMethod.Link){drawOval(Color.White,topLeft=androidx.compose.ui.geometry.Offset(0f,size.height*.2f),size=androidx.compose.ui.geometry.Size(size.width*.65f,size.height*.55f),style=stroke);drawOval(Color.White,topLeft=androidx.compose.ui.geometry.Offset(size.width*.35f,size.height*.2f),size=androidx.compose.ui.geometry.Size(size.width*.65f,size.height*.55f),style=stroke)}
        else{drawRect(Color.White,style=stroke);if(method==ClosetMethod.Manual){for(i in 1..4)drawLine(Color.White,androidx.compose.ui.geometry.Offset(size.width*i/5,0f),androidx.compose.ui.geometry.Offset(size.width*i/5,size.height*.4f),stroke.width)}else{drawCircle(Color.White,size.width*.12f,androidx.compose.ui.geometry.Offset(size.width*.7f,size.height*.3f));drawLine(Color.White,androidx.compose.ui.geometry.Offset(0f,size.height),androidx.compose.ui.geometry.Offset(size.width*.5f,size.height*.45f),stroke.width)}}
    }
}

@Composable
private fun ClosetTitleBar(title:String,s:Float,onBack:()->Unit,modifier:Modifier=Modifier) {
    Pressable(onBack,modifier,cornerRadius=7*s) {
        Row(Modifier.width((370*s).dp).height((60*s).dp).background(AppColors.panel)
            .padding(horizontal=(29*s).dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy((18*s).dp)) {
            Canvas(Modifier.size((19*s).dp,(25*s).dp)) {
                val p=Path().apply { moveTo(size.width*.66f,size.height*.13f);lineTo(size.width*.16f,size.height/2);lineTo(size.width*.66f,size.height*.87f) }
                drawPath(p,Color.Black,style=androidx.compose.ui.graphics.drawscope.Stroke(3.5.dp.toPx(),cap=StrokeCap.Round,join=StrokeJoin.Round))
            }
            CoorditText(title,CoorditTypography.gmarketBold(22*s).copy(color=Color.Black,letterSpacing=(1.5*s).sp))
        }
    }
}

@Composable
private fun CategoryChevrons(s:Float) {
    Canvas(Modifier.size((ClosetDesign.smallGap*s).dp,(ClosetDesign.cardPadding*s).dp)) {
        val path=Path().apply {
            moveTo(0f,size.height*.3f);lineTo(size.width/2,0f);lineTo(size.width,size.height*.3f)
            moveTo(0f,size.height*.7f);lineTo(size.width/2,size.height);lineTo(size.width,size.height*.7f)
        }
        drawPath(path,AppColors.ink,style=androidx.compose.ui.graphics.drawscope.Stroke((1.5f*s).dp.toPx(),cap=StrokeCap.Round,join=StrokeJoin.Round))
    }
}

@Composable
private fun ClosetSearch(value:String,onChange:(String)->Unit,s:Float) {
    Row(Modifier.fillMaxWidth().shadow((ClosetDesign.smallGap*s).dp,CircleShape,clip=false,ambientColor=Color.Black.copy(alpha=.08f),spotColor=Color.Black.copy(alpha=.08f)).background(AppColors.panel,CircleShape).heightIn(min=(36*s).dp).padding(horizontal=(ClosetDesign.cardPadding*s).dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy((10*s).dp)) {
        Canvas(Modifier.size((22*s).dp)) {
            val stroke=(2.2f*s).dp.toPx()
            drawCircle(Color.Black,radius=size.width*.32f,center=androidx.compose.ui.geometry.Offset(size.width*.39f,size.height*.39f),style=androidx.compose.ui.graphics.drawscope.Stroke(stroke))
            drawLine(Color.Black,androidx.compose.ui.geometry.Offset(size.width*.64f,size.height*.64f),androidx.compose.ui.geometry.Offset(size.width*.95f,size.height*.95f),stroke,StrokeCap.Round)
        }
        BasicTextField(value,onChange,Modifier.weight(1f).testTag("closet-search"),singleLine=true,textStyle=CoorditTypography.gmarketMedium(ClosetDesign.bodyFont*s),cursorBrush=SolidColor(AppColors.ink),decorationBox={ inner -> Box {
            if(value.isEmpty())CoorditText("보유 의류를 검색해보세요.",CoorditTypography.gmarketMedium(ClosetDesign.bodyFont*s).copy(color=ClosetDesign.placeholderColor))
            inner()
        } })
    }
}
@Composable
private fun LinkGlyph(s:Float,color:Color) {
    Canvas(Modifier.size((20*s).dp)) {
        val stroke=androidx.compose.ui.graphics.drawscope.Stroke((1.8f*s).dp.toPx(),cap=StrokeCap.Round)
        val path=Path().apply {
            moveTo(size.width*.44f,size.height*.25f);cubicTo(size.width*.79f,-size.height*.08f,size.width*1.1f,size.height*.28f,size.width*.8f,size.height*.58f)
            moveTo(size.width*.56f,size.height*.75f);cubicTo(size.width*.21f,size.height*1.08f,-size.width*.1f,size.height*.72f,size.width*.2f,size.height*.42f)
            moveTo(size.width*.35f,size.height*.65f);lineTo(size.width*.65f,size.height*.35f)
        }
        drawPath(path,color,style=stroke)
    }
}
