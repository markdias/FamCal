import React from 'react';
import { View, ActivityIndicator, Text, StyleSheet, StyleProp, ViewStyle } from 'react-native';
import { useTheme } from '@/context/ThemeContext';
import { spacing } from '@/styles/designTokens';

interface LoadingSpinnerProps {
  size?: 'small' | 'large';
  color?: string;
  fullScreen?: boolean;
  style?: StyleProp<ViewStyle>;
}

export default function LoadingSpinner({
  size = 'large',
  color,
  fullScreen = false,
  style,
}: LoadingSpinnerProps) {
  const { colors } = useTheme();

  const spinnerColor = color || colors.primaryAccent;

  const containerStyle = fullScreen
    ? [styles.fullScreenContainer, style]
    : [styles.container, style];

  return (
    <View style={containerStyle}>
      <ActivityIndicator size={size} color={spinnerColor} />
    </View>
  );
}

// Full screen loading overlay
interface LoadingOverlayProps {
  visible: boolean;
  message?: string;
}

export function LoadingOverlay({ visible, message }: LoadingOverlayProps) {
  const { colors } = useTheme();

  if (!visible) return null;

  return (
    <View style={styles.overlayContainer}>
      <View style={[styles.overlay, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.primaryAccent} />
        {message && (
          <View style={styles.messageContainer}>
            <Text style={{ color: colors.textSecondary }}>{message}</Text>
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: spacing.m,
    alignItems: 'center',
    justifyContent: 'center',
  },
  fullScreenContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  overlayContainer: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 1000,
  },
  overlay: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  messageContainer: {
    marginTop: spacing.m,
  },
});
