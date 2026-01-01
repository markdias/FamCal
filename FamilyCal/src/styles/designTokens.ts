// Design System Tokens - Colors, Typography, Spacing
// Sourced from DESIGN_SYSTEM.md specifications

export const colors = {
  // Primary
  primaryAccent: '#FF6B6B', // Coral Red - "Everyone" events
  systemBlue: '#007AFF',

  // Semantic
  success: '#34C759',
  warning: '#FF9500',
  error: '#FF3B30',

  // Grayscale (light mode)
  gray1: '#F2F2F7',
  gray2: '#FFFFFF',
  gray3: '#8E8E93',
  gray4: '#3C3C43',
  gray5: '#000000',

  // Grayscale (dark mode)
  darkGray1: '#000000',
  darkGray2: '#1C1C1E',
  darkGray3: '#8E8E93',
  darkGray4: '#EBEBF5',
  darkGray5: '#FFFFFF',

  // Family member colors
  familyColors: [
    '#FF6B6B', // Coral Red
    '#007AFF', // System Blue
    '#4ECDC4', // Teal
    '#FF9500', // Orange
    '#AF52DE', // Purple
    '#5856D6', // Indigo
    '#FF2D55', // Pink
    '#00C7BE', // Mint
    '#FFD60A', // Yellow
  ],

  // Calendar colors (iOS-inspired)
  calendarRed: '#FF3B30',
  calendarOrange: '#FF9500',
  calendarYellow: '#FFCC00',
  calendarGreen: '#34C759',
  calendarBlue: '#007AFF',
  calendarPurple: '#AF52DE',
};

export const typography = {
  title1: { fontSize: 34, fontWeight: '700' as const, lineHeight: 41 },
  title2: { fontSize: 28, fontWeight: '700' as const, lineHeight: 34 },
  title3: { fontSize: 22, fontWeight: '600' as const, lineHeight: 28 },
  headline: { fontSize: 17, fontWeight: '600' as const, lineHeight: 22 },
  body: { fontSize: 17, fontWeight: '400' as const, lineHeight: 22 },
  subheadline: { fontSize: 15, fontWeight: '400' as const, lineHeight: 20 },
  callout: { fontSize: 16, fontWeight: '400' as const, lineHeight: 21 },
  caption: { fontSize: 13, fontWeight: '400' as const, lineHeight: 16 },
  caption2: { fontSize: 11, fontWeight: '400' as const, lineHeight: 14 },
};

export const spacing = {
  xxxs: 2,
  xxs: 4,
  xs: 8,
  s: 12,
  m: 16,
  l: 24,
  xl: 32,
  xxl: 48,
};

export const borderRadius = {
  none: 0,
  xs: 4,
  s: 8,
  m: 12,
  l: 16,
  xl: 24,
  full: 9999,
};

export const touchTargets = {
  minimum: 44,
  comfortable: 48,
};

export const shadows = {
  none: {
    shadowColor: 'transparent',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0,
    shadowRadius: 0,
    elevation: 0,
  },
  small: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  medium: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 4,
  },
  large: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 8,
  },
};

export const animation = {
  duration: {
    fast: 150,
    normal: 250,
    slow: 400,
  },
  easing: {
    easeIn: 'cubic-bezier(0.4, 0, 1, 1)',
    easeOut: 'cubic-bezier(0, 0, 0.2, 1)',
    easeInOut: 'cubic-bezier(0.4, 0, 0.2, 1)',
  },
};
