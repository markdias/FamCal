import React from 'react';
import {
  View,
  StyleSheet,
  StyleProp,
  ViewStyle,
  TouchableOpacity,
} from 'react-native';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, shadows } from '@/styles/designTokens';

interface CardProps {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  onPress?: () => void;
  variant?: 'default' | 'elevated' | 'outlined';
}

export default function Card({
  children,
  style,
  onPress,
  variant = 'elevated',
}: CardProps) {
  const { colors, isDark } = useTheme();

  const cardStyle = [
    styles.card,
    variant === 'default' && {
      backgroundColor: colors.card,
    },
    variant === 'elevated' && {
      backgroundColor: colors.card,
      ...shadows.medium,
    },
    variant === 'outlined' && {
      backgroundColor: colors.card,
      borderWidth: 1,
      borderColor: colors.border,
      ...shadows.none,
    },
    style,
  ];

  const content = <View style={cardStyle}>{children}</View>;

  if (onPress) {
    return (
      <TouchableOpacity
        style={cardStyle}
        onPress={onPress}
        activeOpacity={0.8}
      >
        {children}
      </TouchableOpacity>
    );
  }

  return content;
}

// Event-specific card with colored border
interface EventCardProps {
  children: React.ReactNode;
  color?: string;
  style?: StyleProp<ViewStyle>;
  onPress?: () => void;
}

export function EventCard({ children, color, style, onPress }: EventCardProps) {
  const { colors } = useTheme();

  const cardStyle = [
    styles.card,
    styles.eventCard,
    {
      backgroundColor: colors.card,
      borderLeftColor: color || colors.primaryAccent,
      borderLeftWidth: 4,
    },
    style,
  ];

  if (onPress) {
    return (
      <TouchableOpacity style={cardStyle} onPress={onPress} activeOpacity={0.8}>
        {children}
      </TouchableOpacity>
    );
  }

  return <View style={cardStyle}>{children}</View>;
}

// Loading card placeholder
interface LoadingCardProps {
  style?: StyleProp<ViewStyle>;
}

export function LoadingCard({ style }: LoadingCardProps) {
  const { colors } = useTheme();

  return (
    <View style={[styles.card, styles.loadingCard, { backgroundColor: colors.surface }, style]}>
      <View style={[styles.loadingLine, { backgroundColor: colors.border }]} />
      <View style={[styles.loadingLineShort, { backgroundColor: colors.border }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: borderRadius.m,
    padding: spacing.m,
  },
  eventCard: {
    borderRadius: borderRadius.m,
    padding: spacing.s,
    paddingLeft: spacing.m + 4, // Account for colored border
  },
  loadingCard: {
    minHeight: 80,
  },
  loadingLine: {
    height: 12,
    borderRadius: 6,
    marginBottom: spacing.s,
  },
  loadingLineShort: {
    height: 12,
    borderRadius: 6,
    width: '60%',
  },
});
