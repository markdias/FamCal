import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius } from '@/styles/designTokens';
import { Button, Input, Card, LoadingSpinner } from '@/components';
import { useFamilyData } from '@/hooks/useFamilyData';
import { getInitials } from '@/utils/eventHelpers';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '@/navigation/RootNavigator';

const FAMILY_COLORS = [
  '#FF6B6B', '#007AFF', '#4ECDC4', '#FF9500', '#AF52DE',
  '#5856D6', '#FF2D55', '#00C7BE', '#FFD60A',
];

type EditMemberScreenRouteProp = RouteProp<RootStackParamList, 'EditMember'>;

interface EditMemberScreenProps {
  route: EditMemberScreenRouteProp;
  navigation: any;
}

export default function EditMemberScreen({ route, navigation }: EditMemberScreenProps) {
  const { colors } = useTheme();
  const { memberId } = route.params;
  const { getMember, updateMember, deleteMember, isLoading } = useFamilyData();
  const [member, setMember] = useState<any>(null);
  const [name, setName] = useState('');
  const [selectedColor, setSelectedColor] = useState(FAMILY_COLORS[1]);
  const [error, setError] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    const loadMember = async () => {
      const data = await getMember(memberId);
      if (data) {
        setMember(data);
        setName(data.name || '');
        setSelectedColor(data.colorHex || FAMILY_COLORS[1]);
      }
    };
    loadMember();
  }, [memberId]);

  const handleSave = async () => {
    if (!name.trim()) {
      setError('Please enter a name');
      return;
    }

    setError('');
    setIsSaving(true);

    const result = await updateMember(memberId, {
      name: name.trim(),
      color_hex: selectedColor,
      avatar_initials: getInitials(name),
    });

    if (result) {
      navigation.goBack();
    } else {
      setError('Failed to save changes. Please try again.');
    }

    setIsSaving(false);
  };

  const handleDelete = async () => {
    await deleteMember(memberId);
    navigation.goBack();
  };

  if (isLoading && !member) {
    return (
      <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
        <LoadingSpinner fullScreen />
      </SafeAreaView>
    );
  }

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

        {/* Spacer */}
        <View style={styles.spacer} />

        {/* Actions */}
        <Button
          title="Save Changes"
          onPress={handleSave}
          loading={isSaving}
          disabled={isLoading || !name.trim()}
          fullWidth
        />

        <Button
          title="Delete Member"
          variant="danger"
          onPress={handleDelete}
          disabled={isLoading}
          fullWidth
          style={styles.deleteButton}
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
  spacer: {
    flex: 1,
    minHeight: spacing.l,
  },
  deleteButton: {
    marginTop: spacing.s,
  },
});
