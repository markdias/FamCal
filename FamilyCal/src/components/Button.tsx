import React from 'react';
import {
  TouchableOpacity,
  Text,
  StyleSheet,
  ActivityIndicator,
  ViewStyle,
  TextStyle,
  StyleProp,
} from 'react-native';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, typography, shadows } from '@/styles/designTokens';

export type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'ghost' | 'outline';
export type ButtonSize = 'small' | 'medium' | 'large';

interface ButtonProps {
  title: string;
  onPress: () => void;
  variant?: ButtonVariant;
  size?: ButtonSize;
  disabled?: boolean;
  loading?: boolean;
  fullWidth?: boolean;
  style?: StyleProp<ViewStyle>;
  textStyle?: StyleProp<TextStyle>;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

export default function Button({
  title,
  onPress,
  variant = 'primary',
  size = 'medium',
  disabled = false,
  loading = false,
  fullWidth = false,
  style,
  textStyle,
  leftIcon,
  rightIcon,
}: ButtonProps) {
  const { colors } = useTheme();

  const containerStyle = [
    styles.container,
    styles[`${variant}Container`] as ViewStyle,
    styles[`${size}Container`] as ViewStyle,
    fullWidth && styles.fullWidth,
    disabled && styles.disabledContainer,
    style,
  ];

  const textStyleArray = [
    styles.text,
    styles[`${variant}Text`] as TextStyle,
    styles[`${size}Text`] as TextStyle,
    textStyle,
  ];

  return (
    <TouchableOpacity
      style={containerStyle}
      onPress={onPress}
      disabled={disabled || loading}
      activeOpacity={0.7}
    >
      {loading ? (
        <ActivityIndicator
          color={variant === 'primary' ? '#FFFFFF' : colors.text}
          size="small"
        />
      ) : (
        <>
          {leftIcon && <>{leftIcon}</>}
          <Text style={textStyleArray}>{title}</Text>
          {rightIcon && <>{rightIcon}</>}
        </>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: borderRadius.m,
    ...shadows.medium,
  },

  // Variants
  primaryContainer: {
    backgroundColor: '#007AFF',
  },
  secondaryContainer: {
    backgroundColor: '#E5E5EA',
  },
  dangerContainer: {
    backgroundColor: '#FF3B30',
  },
  ghostContainer: {
    backgroundColor: 'transparent',
    ...shadows.none,
  },
  outlineContainer: {
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: '#007AFF',
    ...shadows.none,
  },

  // Sizes
  smallContainer: {
    paddingHorizontal: spacing.s,
    paddingVertical: spacing.xs,
    minHeight: 36,
  },
  mediumContainer: {
    paddingHorizontal: spacing.m,
    paddingVertical: spacing.s,
    minHeight: 44,
  },
  largeContainer: {
    paddingHorizontal: spacing.l,
    paddingVertical: spacing.m,
    minHeight: 52,
  },

  // Text styles
  text: {
    fontWeight: '600',
  },
  primaryText: {
    color: '#FFFFFF',
  },
  secondaryText: {
    color: '#000000',
  },
  dangerText: {
    color: '#FFFFFF',
  },
  ghostText: {
    color: '#007AFF',
  },
  outlineText: {
    color: '#007AFF',
  },

  // Text sizes
  smallText: {
    fontSize: 13,
  },
  mediumText: {
    fontSize: 15,
  },
  largeText: {
    fontSize: 17,
  },

  // Disabled state
  disabledContainer: {
    opacity: 0.5,
  },

  fullWidth: {
    width: '100%',
  },
});
