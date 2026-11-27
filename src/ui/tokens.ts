import { TextStyle } from 'react-native';

export const Space = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
} as const;

export const Radius = {
  sm: 6,
  md: 12,
  lg: 18,
  xl: 24,
  full: 9999,
} as const;

export const Size = {
  icon: 22,
  iconStroke: 1.7,
  controlSm: 36,
  controlMd: 44,
  controlLg: 60,
  bar: 60,
  hitTarget: 48,
  rowArtwork: 44,
  gutter: 16,
  // Content column on wide screens (iPad); App.tsx centres every tab inside it.
  readableWidth: 720,
  // iOS accessibility text sizes go past 3x; the fixed-height rows and buttons can't grow that far.
  // 1.35x matches the largest regular text size, which lays out fully; beyond it fixed-height rows clip.
  maxFontScale: 1.35,
  // Tab labels share a narrow bar, so they grow less.
  maxTabLabelScale: 1.15,
} as const;

export const Type = {
  title: { fontSize: 20, lineHeight: 26, fontWeight: '700' },
  headline: { fontSize: 18, lineHeight: 22, fontWeight: '700' },
  bodyStrong: { fontSize: 15, lineHeight: 20, fontWeight: '600' },
  body: { fontSize: 14, lineHeight: 20, fontWeight: '400' },
  caption: { fontSize: 12, lineHeight: 16, fontWeight: '400' },
  eyebrow: { fontSize: 10, lineHeight: 14, fontWeight: '700', letterSpacing: 1, textTransform: 'uppercase' },
  micro: { fontSize: 10, lineHeight: 14, fontWeight: '500' },
} as const satisfies Record<string, TextStyle>;

export type TypeVariant = keyof typeof Type;

export const TabularNumbers: TextStyle = { fontVariant: ['tabular-nums'] };

export const Motion = {
  fast: 160,
  standard: 240,
  slow: 320,
} as const;
