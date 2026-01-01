import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, typography } from '@/styles/designTokens';
import { Button } from '@/components';

interface IntroScreenProps {
  onComplete: () => void;
}

export default function IntroScreen({ onComplete }: IntroScreenProps) {
  const { colors } = useTheme();

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      <View style={styles.content}>
        {/* App Icon/Logo */}
        <View style={styles.logoContainer}>
          <View style={[styles.logo, { backgroundColor: colors.primaryAccent }]}>
            <Text style={styles.logoIcon}>📅</Text>
          </View>
        </View>

        {/* Title */}
        <View style={styles.textContainer}>
          <Text style={[styles.title, { color: colors.text }]}>FamilyCal</Text>
          <Text style={[styles.tagline, { color: colors.textSecondary }]}>
            The simple way to organize your family's schedule
          </Text>
        </View>

        {/* Features */}
        <View style={styles.features}>
          <View style={styles.feature}>
            <Text style={styles.featureIcon}>👨‍👩‍👧‍👦</Text>
            <Text style={[styles.featureText, { color: colors.text }]}>
              Add family members
            </Text>
          </View>
          <View style={styles.feature}>
            <Text style={styles.featureIcon}>📅</Text>
            <Text style={[styles.featureText, { color: colors.text }]}>
              Sync calendars
            </Text>
          </View>
          <View style={styles.feature}>
            <Text style={styles.featureIcon}>🔔</Text>
            <Text style={[styles.featureText, { color: colors.text }]}>
              Get event reminders
            </Text>
          </View>
        </View>

        {/* Spacer */}
        <View style={styles.spacer} />

        {/* Continue Button */}
        <Button title="Get Started" onPress={onComplete} fullWidth />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
    padding: spacing.l,
    justifyContent: 'center',
    alignItems: 'center',
  },
  logoContainer: {
    marginBottom: spacing.xxl,
  },
  logo: {
    width: 100,
    height: 100,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    ...{
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.2,
      shadowRadius: 8,
      elevation: 8,
    },
  },
  logoIcon: {
    fontSize: 48,
  },
  textContainer: {
    alignItems: 'center',
    marginBottom: spacing.xxl,
  },
  title: {
    fontSize: 42,
    fontWeight: '800',
    marginBottom: spacing.s,
    letterSpacing: -0.5,
  },
  tagline: {
    fontSize: 17,
    textAlign: 'center',
    maxWidth: 280,
  },
  features: {
    width: '100%',
    gap: spacing.m,
  },
  feature: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F2F2F7',
    padding: spacing.m,
    borderRadius: borderRadius.m,
  },
  featureIcon: {
    fontSize: 24,
    marginRight: spacing.m,
  },
  featureText: {
    fontSize: 17,
    fontWeight: '500',
  },
  spacer: {
    height: spacing.xxl,
  },
});
