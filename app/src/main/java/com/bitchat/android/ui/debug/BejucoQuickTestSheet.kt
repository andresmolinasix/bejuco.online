package com.bitchat.android.ui.debug

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.bitchat.android.mesh.BluetoothMeshService
import com.bitchat.android.core.ui.component.sheet.BitchatBottomSheet
import com.bitchat.android.core.ui.component.sheet.BitchatSheetTopBar
import com.bitchat.android.core.ui.component.sheet.BitchatSheetTitle

/**
 * Demo-facing entry point for the DISTRESS test flow: just the Bejuco trigger and the mesh
 * topology, none of the developer-facing noise in [DebugSettingsSheet] (GATT roles, scan
 * results, packet relay graphs, sync tuning, debug console). Reuses
 * [BejucoEmergencyDebugSection] and [MeshTopologySection] as-is rather than duplicating their
 * logic - this is a trimmed presentation of the same underlying state, not a separate path.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BejucoQuickTestSheet(
    isPresented: Boolean,
    onDismiss: () -> Unit,
    meshService: BluetoothMeshService
) {
    if (!isPresented) return
    val context = LocalContext.current

    BitchatBottomSheet(onDismissRequest = onDismiss) {
        LaunchedEffect(Unit) { DebugSettingsManager.getInstance().setDebugSheetVisible(true) }
        DisposableEffect(Unit) {
            onDispose { DebugSettingsManager.getInstance().setDebugSheetVisible(false) }
        }
        Box(modifier = Modifier.fillMaxWidth()) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                contentPadding = PaddingValues(top = 80.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                item {
                    BejucoEmergencyDebugSection(isPresented = isPresented, context = context)
                }
                item {
                    MeshTopologySection(localPeerID = meshService.myPeerID)
                }
            }

            BitchatSheetTopBar(
                onClose = onDismiss,
                modifier = Modifier.align(Alignment.TopCenter),
                title = {
                    androidx.compose.foundation.layout.Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.BugReport,
                            contentDescription = null,
                            tint = Color(0xFFFF9500)
                        )
                        BitchatSheetTitle(text = "Comunicación de emergencia offline")
                    }
                }
            )
        }
    }
}
