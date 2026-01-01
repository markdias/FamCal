import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius } from '@/styles/designTokens';
import { Button, Input, Card, LoadingSpinner } from '@/components';
import { useFamilyData } from '@/hooks/useFamilyData';
import { Ionicons } from '@expo/vector-icons';
import { getInitials, generateRandomColor } from '@/utils/eventHelpers';

const FAMILY_COLORS = [
  '#FF6B6B', '#007AFF', '#4ECDC4', '#FF9500', '#AF52DE',
  '#5856D6', '#FF2D55', '#00C7BE', '#FFD60A',
];

export default function AddMemberScreen({ navigation }: { navigation: any }) {
  const { colors } = useTheme();
  const { createMember, isLoading } = useFamilyData();
  const [name, setName] = useState('');
  const [selectedColor, setSelectedColor] = useState(FAMILY_COLORS[1]);
  const [error, setError] = useState('');
  const [isCreating, setIsCreating] = useState(false);

  const handleCreate = async () => {
    if (!name.trim()) {
      setError('Please enter a name');
      return;
    }

    setError('');
    setIsCreating(true);

    const result = await createMember({
      family_id: '', // Will be set by the service
      name: name.trim(),
      color_hex: selectedColor,
      avatar_initials: getInitials(name),
      is_driver: false,
      sort_order: 0,
      user_id: null,
      linked_calendar_id: null,
    });

    if (result) {
      navigation.goBack();
    } else {
      setError('Failed to add member. Please try again.');
    }

    setIsCreating(false);
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      <ScrollView
        style={styles.scrollContainer}
        contentContainerStyle={styles.scrollContent}
      >
        {/* Name Input */}
        <Input
          label="Name"
          value={name}
          onChangeText={setName}
          placeholder="Enter name"
          autoComplete="name"
          error={error}
        />

        {/* Color Picker */}
        <Text style={[styles.label, { color: colors.textSecondary }]}>
          Choose a color
        </Text>
        <View style={styles.colorPicker}>
          {FAMILY_COLORS.map(color => (
            <TouchableOpacity
              key={color}
              style={[
                styles.colorOption,
                { backgroundColor: color },
                selectedColor === color && styles.selectedColor,
              ]}
              onPress={() => setSelectedColor(color)}
            />
          ))}
        </View>

        {/* Preview */}
        <Card style={styles.previewCard}>
          <Text style={[styles.previewTitle, { color: colors.text }]}>Preview</Text>
          <View style={styles.previewRow}>
            <View
              style={[
                styles.previewAvatar,
                { backgroundColor: selectedColor },
              ]}
            >
              <Text style={styles.previewInitials}>
                {getInitials(name || 'AB')}
              </Text>
            </View>
            <View>
              <Text style={[styles.previewName, { color: colors.text }]}>
                {name || 'Name'}
              </Text>
              <Text style={[styles.previewLabel, { color: colors.textSecondary }]}>
                Family Member
              </Text>
            </View>
          </View>
        </Card>

        {/* Spacer */}
        <View style={styles.spacer} />

        {/* Actions */}
        <Button
          title="Add Member"
          onPress={handleCreate}
          loading={isCreating}
          disabled={isLoading || !name.trim()}
          fullWidth
        />
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
    width: 44,
    height: 44,
    borderRadius: 22,
  },
  selectedColor: {
    borderWidth: 3,
    borderColor: '#000000',
  },
  previewCard: {
    marginBottom: spacing.l,
  },
  previewTitle: {
    fontSize: 13,
    fontWeight: '500',
    marginBottom: spacing.m,
  },
  previewRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  previewAvatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.m,
  },
  previewInitials: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
  previewName: {
    fontSize: 17,
    fontWeight: '600',
  },
  previewLabel: {
    fontSize: 13,
  },
  spacer: {
    flex: 1,
    minHeight: spacing.l,
  },
});
