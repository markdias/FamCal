import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, typography } from '@/styles/designTokens';
import { ModalOverlay, ConfirmDialog } from './ModalOverlay';

interface UpgradePromptProps {
  visible: boolean;
  onClose: () => void;
  featureName: string;
  featureDescription?: string;
  onUpgrade: () => void;
}

export default function UpgradePrompt({
  visible,
  onClose,
  featureName,
  featureDescription,
  onUpgrade,
}: UpgradePromptProps) {
  const { colors } = useTheme();

  return (
    <ModalOverlay visible={visible} onClose={onClose} presentationStyle="overFullScreen">
      <View style={styles.container}>
        {/* Header with icon */}
        <View style={styles.header}>
          <View style={[styles.iconContainer, { backgroundColor: colors.primaryAccent }]}>
            <Text style={styles.iconText}>★</Text>
          </View>
          <Text style={[styles.title, { color: colors.text }]}>Upgrade to Pro</Text>
        </View>

        {/* Feature info */}
        <Text style={[styles.featureName, { color: colors.text }]}>{featureName}</Text>
        {featureDescription && (
          <Text style={[styles.description, { color: colors.textSecondary }]}>
            {featureDescription}
          </Text>
        )}

        {/* Pro benefits */}
        <View style={styles.benefitsContainer}>
          <Text style={[styles.benefitsTitle, { color: colors.text }]}>Pro includes:</Text>
          {[
            'Unlimited family members',
            'Unlimited calendars',
            'Advanced reminders',
            'Morning brief',
            'Priority support',
          ].map((benefit, index) => (
            <View key={index} style={styles.benefitItem}>
              <Text style={styles.checkmark}>✓</Text>
              <Text style={[styles.benefitText, { color: colors.textSecondary }]}>
                {benefit}
              </Text>
            </View>
          ))}
        </View>

        {/* Actions */}
        <View style={styles.actions}>
          <TouchableOpacity
            style={[styles.upgradeButton, { backgroundColor: colors.primaryAccent }]}
            onPress={onUpgrade}
          >
            <Text style={styles.upgradeButtonText}>Upgrade Now</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.notNowButton} onPress={onClose}>
            <Text style={[styles.notNowText, { color: colors.textSecondary }]}>
              Maybe Later
            </Text>
          </TouchableOpacity>
        </View>
      </View>
    </ModalOverlay>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: spacing.l,
    alignItems: 'center',
  },
  header: {
    alignItems: 'center',
    marginBottom: spacing.m,
  },
  iconContainer: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.s,
  },
  iconText: {
    fontSize: 32,
    color: '#FFFFFF',
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
  },
  featureName: {
    fontSize: 18,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: spacing.xs,
  },
  description: {
    fontSize: 14,
    textAlign: 'center',
    marginBottom: spacing.l,
  },
  benefitsContainer: {
    width: '100%',
    marginBottom: spacing.l,
  },
  benefitsTitle: {
    fontSize: 15,
    fontWeight: '600',
    marginBottom: spacing.s,
  },
  benefitItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  checkmark: {
    fontSize: 14,
    color: '#34C759',
    marginRight: spacing.xs,
  },
  benefitText: {
    fontSize: 14,
  },
  actions: {
    width: '100%',
    gap: spacing.s,
  },
  upgradeButton: {
    width: '100%',
    paddingVertical: spacing.m,
    borderRadius: borderRadius.m,
    alignItems: 'center',
  },
  upgradeButtonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },
  notNowButton: {
    width: '100%',
    paddingVertical: spacing.s,
    alignItems: 'center',
  },
  notNowText: {
    fontSize: 15,
  },
});

// Pro badge component
interface ProBadgeProps {
  size?: 'small' | 'medium';
}

export function ProBadge({ size = 'small' }: ProBadgeProps) {
  const { colors } = useTheme();

  return (
    <View style={[styles.badge, { backgroundColor: colors.primaryAccent }]}>
      <Text style={[styles.badgeText, size === 'small' && styles.badgeTextSmall]}>
        PRO
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    borderRadius: borderRadius.xs,
  },
  badgeText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '700',
  },
  badgeTextSmall: {
    fontSize: 9,
  },
});
