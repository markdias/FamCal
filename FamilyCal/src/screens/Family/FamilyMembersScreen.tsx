import React, { useState } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing } from '@/styles/designTokens';
import { Card, Button, MemberCard, LoadingSpinner, ModalOverlay, ConfirmDialog } from '@/components';
import { useFamilyData } from '@/hooks/useFamilyData';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';

export default function FamilyMembersScreen() {
  const { colors } = useTheme();
  const navigation = useNavigation<any>();
  const { members, isLoading, deleteMember } = useFamilyData();
  const [memberToDelete, setMemberToDelete] = useState<string | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  const handleDeleteMember = async () => {
    if (!memberToDelete) return;

    setIsDeleting(true);
    await deleteMember(memberToDelete);
    setMemberToDelete(null);
    setIsDeleting(false);
  };

  if (isLoading) {
    return (
      <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
        <LoadingSpinner fullScreen />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={[styles.title, { color: colors.text }]}>Family Members</Text>
        <TouchableOpacity onPress={() => navigation.navigate('AddMember')}>
          <Ionicons name="add" size={28} color={colors.primaryAccent} />
        </TouchableOpacity>
      </View>

      {/* Content */}
      <FlatList
        data={members}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          <Card style={styles.emptyCard}>
            <Text style={[styles.emptyTitle, { color: colors.text }]}>
              No Family Members Yet
            </Text>
            <Text style={[styles.emptyText, { color: colors.textSecondary }]}>
              Add your first family member to get started
            </Text>
            <Button
              title="Add Member"
              onPress={() => navigation.navigate('AddMember')}
              style={styles.emptyButton}
            />
          </Card>
        }
        renderItem={({ item }) => (
          <MemberCard
            member={item}
            onPress={() => navigation.navigate('EditMember', { memberId: item.id })}
            onEdit={() => navigation.navigate('EditMember', { memberId: item.id })}
            onDelete={() => setMemberToDelete(item.id)}
          />
        )}
      />

      {/* Delete Confirmation Dialog */}
      <ConfirmDialog
        visible={memberToDelete !== null}
        onClose={() => setMemberToDelete(null)}
        onConfirm={handleDeleteMember}
        title="Remove Family Member"
        message="Are you sure you want to remove this family member? Their events will not be deleted."
        confirmText="Remove"
        isDestructive
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.l,
    paddingVertical: spacing.m,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
  },
  listContent: {
    padding: spacing.m,
    paddingBottom: spacing.xxl,
  },
  emptyCard: {
    padding: spacing.xl,
    alignItems: 'center',
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '600',
    marginBottom: spacing.xs,
  },
  emptyText: {
    fontSize: 15,
    textAlign: 'center',
    marginBottom: spacing.m,
  },
  emptyButton: {
    marginTop: spacing.s,
  },
});
