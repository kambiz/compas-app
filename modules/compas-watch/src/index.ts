import { Platform } from 'react-native';
import { requireOptionalNativeModule } from 'expo-modules-core';

interface CompasWatchNativeModule {
  setPlayer(address: string, pin: string | null): void;
  clearPlayer(): void;
}

// iOS only: Android has no Apple Watch, and tests run without native modules.
const native = Platform.OS === 'ios' ? requireOptionalNativeModule<CompasWatchNativeModule>('CompasWatch') : null;

/** Lets the Apple Watch app control this Wi-Fi player through the phone. The PIN stays on the phone. */
export function shareWifiPlayerWithWatch(address: string, pin: string | null): void {
  try {
    native?.setPlayer(address, pin);
  } catch {
    // The watch link is optional; never let it break connecting.
  }
}

/** Forgets the player after an explicit disconnect, so the watch stops controlling it. */
export function clearWatchPlayer(): void {
  try {
    native?.clearPlayer();
  } catch {
    // Optional, as above.
  }
}
