import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, RefreshControl } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, shadows } from '@/styles/designTokens';
import { Card, Button, MemberCard, EventCard, LoadingSpinner } from '@/components';
import { useFamilyData, useEvents } from '@/hooks/useFamilyData';
import { NativeCalendarEvent } from '@/types';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';

export default function FamilyDashboard() {
  const { colors } = useTheme();
  const navigation = useNavigation<any>();
  const { members, isLoading, loadFamily } = useFamilyData();
  const { groupedEvents, getNextEvents, isLoading: eventsLoading } = useEvents();
  const [refreshing, setRefreshing] = useState(false);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadFamily();
    setRefreshing(false);
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={[styles.greeting, { color: colors.textSecondary }]}>
            Good morning
          </Text>
          <Text style={[styles.title, { color: colors.text }]}>Family Dashboard</Text>
        </View>
        <TouchableOpacity
          style={[styles.settingsButton, { backgroundColor: colors.surface }]}
          onPress={() => navigation.navigate('Settings')}
        >
          <Ionicons name="settings-outline" size={24} color={colors.text} />
        </TouchableOpacity>
      </View>

      {/* Content */}
      <FlatList
        data={members}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContent}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        ListHeaderComponent={
          <>
            {/* Next Events Section */}
            {groupedEvents.length > 0 && (
              <View style={styles.section}>
                <Text style={[styles.sectionTitle, { color: colors.text }]}>
                  Up Next
                </Text>
                <View style={styles.nextEventsGrid}>
                  {groupedEvents.slice(0, 4).map(group => (
                    <TouchableOpacity
                      key={group.id}
                      style={[styles.nextEventCard, { backgroundColor: colors.card }]}
                      onPress={() => {}}
                    >
                      <View
                        style={[
                          styles.memberDot,
                          { backgroundColor: group.memberColor },
                        ]}
                      >
                        <Text style={styles.memberInitial}>
                          {group.memberName.charAt(0)}
                        </Text>
                      </View>
                      <Text
                        style={[styles.memberName, { color: colors.text }]}
                        numberOfLines={1}
                      >
                        {group.memberName}
                      </Text>
                      {group.nextEvent ? (
                        <Text
                          style={[
                            styles.nextEventTitle,
                            { color: colors.textSecondary },
                          ]}
                          numberOfLines={1}
                        >
                          {group.nextEvent.title}
                        </Text>
                      ) : (
                        <Text
                          style={[
                            styles.noEvent,
                            { color: colors.textTertiary },
                          ]}
                        >
                          No upcoming events
                        </Text>
                      )}
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            )}

            {/* Family Members Section */}
            <View style={styles.section}>
              <View style={styles.sectionHeader}>
                <Text style={[styles.sectionTitle, { color: colors.text }]}>
                  Family Members
                </Text>
                <TouchableOpacity
                  onPress={() => navigation.navigate('AddMember')}
                >
                  <Ionicons name="add" size={24} color={colors.primaryAccent} />
                </TouchableOpacity>
              </View>
              <Text
                style={[styles.sectionSubtitle, { color: colors.textSecondary }]}
              >
                {members.length} {members.length === 1 ? 'member' : 'members'}
              </Text>
            </View>
          </>
        }
        renderItem={({ item }) => (
          <MemberCard
            member={item}
            eventCount={0}
            onPress={() => navigation.navigate('EditMember', { memberId: item.id })}
          />
        )}
        ListEmptyComponent={
          <Card style={styles.emptyCard}>
            <Text style={[styles.emptyTitle, { color: colors.text }]}>
              No Family Members Yet
            </Text>
            <Text
              style={[styles.emptyText, { color: colors.textSecondary }]}
            >
              Add your first family member to get started
            </Text>
            <Button
              title="Add Member"
              onPress={() => navigation.navigate('AddMember')}
              style={styles.emptyButton}
            />
          </Card>
        }
      />

      {/* Add Button */}
      <TouchableOpacity
        style={[styles.fab, { backgroundColor: colors.primaryAccent }]}
        onPress={() => navigation.navigate('AddMember')}
      >
        <Ionicons name="add" size={32} color="#FFFFFF" />
      </TouchableOpacity>
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
  greeting: {
    fontSize: 13,
    marginBottom: 2,
  },
  title: {
    fontSize: 34,
    fontWeight: '700',
  },
  settingsButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    ...shadows.small,
  },
  listContent: {
    padding: spacing.m,
    paddingBottom: 100,
  },
  section: {
    marginBottom: spacing.xl,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: '600',
  },
  sectionSubtitle: {
    fontSize: 13,
  },
  nextEventsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.s,
    marginTop: spacing.s,
  },
  nextEventCard: {
    width: '48%',
    aspectRatio: 0.8,
    borderRadius: borderRadius.m,
    padding: spacing.m,
    justifyContent: 'center',
    ...shadows.small,
  },
  memberDot: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.s,
  },
  memberInitial: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  memberName: {
    fontSize: 15,
    fontWeight: '600',
    marginBottom: 2,
  },
  nextEventTitle: {
    fontSize: 13,
  },
  noEvent: {
    fontSize: 12,
    fontStyle: 'italic',
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
  fab: {
    position: 'absolute',
    right: spacing.l,
    bottom: spacing.xxl,
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    ...shadows.large,
  },
});
