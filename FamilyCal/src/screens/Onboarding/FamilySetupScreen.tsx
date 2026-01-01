import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, typography } from '@/styles/designTokens';
import { Button, Input, Card, LoadingSpinner } from '@/components';
import { useFamilyData } from '@/hooks/useFamilyData';

interface FamilySetupScreenProps {
  onComplete: () => void;
}

export default function FamilySetupScreen({ onComplete }: FamilySetupScreenProps) {
  const { colors } = useTheme();
  const { createFamily, createMember, isLoading } = useFamilyData();
  const [familyName, setFamilyName] = useState('');
  const [memberName, setMemberName] = useState('');
  const [error, setError] = useState('');
  const [isCreating, setIsCreating] = useState(false);

  const handleCreate = async () => {
    if (!familyName.trim()) {
      setError('Please enter a family name');
      return;
    }
    if (!memberName.trim()) {
      setError('Please enter your name');
      return;
    }

    setError('');
    setIsCreating(true);

    try {
      // Create the family
      const family = await createFamily(familyName.trim());
      
      if (family) {
        // Add the current user as a family member
        await createMember({
          family_id: family.id,
          name: memberName.trim(),
          color_hex: '#007AFF',
          avatar_initials: memberName.trim().substring(0, 2).toUpperCase(),
          is_driver: false,
          sort_order: 0,
          user_id: null,
          linked_calendar_id: null,
        });

        onComplete();
      } else {
        setError('Failed to create family. Please try again.');
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      <ScrollView
        style={styles.scrollContainer}
        contentContainerStyle={styles.scrollContent}
      >
        {/* Header */}
        <View style={styles.header}>
          <Text style={[styles.title, { color: colors.text }]}>Set Up Your Family</Text>
          <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
            Let's create your family calendar
          </Text>
        </View>

        {/* Form */}
        <View style={styles.form}>
          <Input
            label="Family Name"
            value={familyName}
            onChangeText={setFamilyName}
            placeholder="e.g., The Smiths"
            autoComplete="name"
          />

          <Input
            label="Your Name"
            value={memberName}
            onChangeText={setMemberName}
            placeholder="e.g., John"
            autoComplete="name"
          />

          {/* Color Picker */}
          <Text style={[styles.label, { color: colors.textSecondary }]}>
            Choose a color for your profile
          </Text>
          <View style={styles.colorPicker}>
            {[
              '#FF6B6B',
              '#007AFF',
              '#4ECDC4',
              '#FF9500',
              '#AF52DE',
              '#5856D6',
              '#FF2D55',
              '#00C7BE',
              '#FFD60A',
            ].map(color => (
              <TouchableOpacity
                key={color}
                style={[
                  styles.colorOption,
                  { backgroundColor: color },
                  memberName &&
                    color ===
                      '#007AFF' && { borderWidth: 3, borderColor: '#000' },
                ]}
                onPress={() => {}}
              />
            ))}
          </View>

          {error ? (
            <Text style={[styles.errorText, { color: colors.error }]}>{error}</Text>
          ) : null}

          <Button
            title="Create Family"
            onPress={handleCreate}
            loading={isCreating}
            disabled={isLoading || !familyName.trim() || !memberName.trim()}
            fullWidth
          />
        </View>

        {/* Info Card */}
        <Card variant="outlined" style={styles.infoCard}>
          <Text style={[styles.infoTitle, { color: colors.text }]}>
            What's Next?
          </Text>
          <View style={styles.infoList}>
            <View style={styles.infoItem}>
              <Text style={styles.infoBullet}>•</Text>
              <Text style={[styles.infoText, { color: colors.textSecondary }]}>
                Add more family members to share the calendar
              </Text>
            </View>
            <View style={styles.infoItem}>
              <Text style={styles.infoBullet}>•</Text>
              <Text style={[styles.infoText, { color: colors.textSecondary }]}>
                Link your personal calendars for event sync
              </Text>
            </View>
            <View style={styles.infoItem}>
              <Text style={styles.infoBullet}>•</Text>
              <Text style={[styles.infoText, { color: colors.textSecondary }]}>
                Start adding and managing family events
              </Text>
            </View>
          </View>
        </Card>

        {/* Skip Button */}
        <TouchableOpacity style={styles.skipButton} onPress={onComplete}>
          <Text style={[styles.skipText, { color: colors.textTertiary }]}>
            Skip for now
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollContainer: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    padding: spacing.l,
  },
  header: {
    marginBottom: spacing.xl,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    marginBottom: spacing.xs,
  },
  subtitle: {
    fontSize: 17,
  },
  form: {
    marginBottom: spacing.l,
  },
  label: {
    fontSize: 13,
    fontWeight: '500',
    marginBottom: spacing.s,
  },
  colorPicker: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.s,
    marginBottom: spacing.l,
  },
  colorOption: {
    width: 40,
    height: 40,
    borderRadius: 20,
  },
  errorText: {
    fontSize: 14,
    marginBottom: spacing.s,
  },
  infoCard: {
    marginBottom: spacing.l,
  },
  infoTitle: {
    fontSize: 17,
    fontWeight: '600',
    marginBottom: spacing.s,
  },
  infoList: {
    gap: spacing.xs,
  },
  infoItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  infoBullet: {
    fontSize: 15,
    marginRight: spacing.xs,
    color: colors.textSecondary,
  },
  infoText: {
    fontSize: 15,
    flex: 1,
  },
  skipButton: {
    alignItems: 'center',
    paddingVertical: spacing.s,
  },
  skipText: {
    fontSize: 15,
    textDecorationLine: 'underline',
  },
});
