package io.max.paperplay.ui.app

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Info
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarData
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.ModernSurfaceTier
import io.max.paperplay.ui.components.modernSurface
import io.max.paperplay.ui.theme.motionSpatialSpring
import kotlinx.coroutines.launch

/** The app's snackbars: coloured (the page [tint], else the theme's container colour) and swiped sideways to dismiss, like [StatusToast]. */
@Composable
fun AppSnackbarHost(state: SnackbarHostState, modifier: Modifier = Modifier, tint: Color? = null) {
    SnackbarHost(state, modifier) { data -> SwipeToast(data, tint) }
}

private val ToastShape = RoundedCornerShape(16.dp)

/** The toast body: a soft shadow for lift and a 1dp edge in the text colour at 10% (it stays when shadows are off), so it reads on any page colour. */
fun Modifier.toastSurface(bg: Color, fg: Color): Modifier =
    shadow(8.dp, ToastShape).clip(ToastShape).background(bg).border(1.dp, fg.copy(alpha = 0.10f), ToastShape)

@Composable
private fun SwipeToast(data: SnackbarData, tint: Color?) {
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    val bg = if (tint != null) lerp(tint, scheme.onSurface, 0.16f) else scheme.primaryContainer
    val fg = if (tokens.enabled) tokens.onGlass else if (bg.luminance() < 0.5f) Color.White else Color.Black
    val offset = remember(data) { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val snapBackSpec = motionSpatialSpring<Float>()
    val surfaceMod = if (tokens.enabled) {
        Modifier.modernSurface(ModernSurfaceTier.Overlay, ToastShape, LookGroup.Overlays)
    } else {
        Modifier.toastSurface(bg, fg)
    }
    Row(
        Modifier.padding(horizontal = 16.dp).widthIn(max = 440.dp)
            .graphicsLayer {
                translationX = offset.value
                alpha = (1f - kotlin.math.abs(offset.value) / 600f).coerceIn(0f, 1f)
            }
            .then(surfaceMod)
            .pointerInput(data) {
                detectHorizontalDragGestures(
                    onDragEnd = {
                        if (kotlin.math.abs(offset.value) > 80f) data.dismiss()
                        else scope.launch { offset.animateTo(0f, snapBackSpec) }
                    },
                    onDragCancel = { scope.launch { offset.animateTo(0f, snapBackSpec) } },
                ) { _, dx -> scope.launch { offset.snapTo(offset.value + dx) } }
            }
            .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.material3.Icon(Icons.Rounded.Info, null, Modifier.size(20.dp), tint = fg.copy(alpha = 0.8f))
        Text(data.visuals.message, Modifier.weight(1f).padding(start = 12.dp), color = fg, style = MaterialTheme.typography.bodyMedium)
        data.visuals.actionLabel?.let { label ->
            TextButton({ data.performAction() }) { Text(label, color = fg) }
        }
    }
}
