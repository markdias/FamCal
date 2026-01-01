import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, shadows } from '@/styles/designTokens';
import { EventWithDetails, GroupedEvent } from '@/types';
import { format, parseISO } from 'date-fns';
import { EventCard } from './Card';

interface EventCardProps {
  event: GroupedEvent;
  memberColor?: string;
  onPress?: () => void;
}

export default function EventCardComponent({ event, memberColor = '#007AFF', onPress }: EventCardProps) {
  const { colors } = useTheme();

  const formatTime = (dateStr: string) => {
    return format(parseISO(dateStr), 'h:mm a');
  };

  const formatDate = (dateStr: string) => {
    return format(parseISO(dateStr), 'EEE d MMM');
  };

  return (
    <EventCard color={memberColor} onPress={onPress}>
      <View style={styles.container}>
        {/* Date box on the left */}
        <View style={styles.dateBox}>
          <Text style={[styles.dateText, { color: memberColor }]}>
            {formatDate(event.startDate)}
          </Text>
        </View>

        {/* Content on the right */}
        <View style={styles.content}>
          <Text style={[styles.title, { color: colors.text }]} numberOfLines={1}>
            {event.title}
          </Text>

          <View style={styles.row}>
            {event.timeRange && (
              <Text style={[styles.time, { color: colors.textSecondary }]}>
                {event.timeRange}
              </Text>
            )}
            {event.location && (
              <Text style={[styles.location, { color: colors.textTertiary }]} numberOfLines={1}>
                {event.location}
              </Text>
            )}
          </View>

          {/* Member names */}
          {event.memberNames.length > 0 && (
            <View style={styles.membersRow}>
              {event.memberNames.slice(0, 3).map((name, index) => (
                <View key={index} style={[styles.memberDot, { backgroundColor: memberColor }]}>
                  <Text style={styles.memberInitial}>{name.charAt(0)}</Text>
                </View>
              ))}
              {event.memberNames.length > 3 && (
                <Text style={[styles.moreMembers, { color: colors.textTertiary }]}>
                  +{event.memberNames.length - 3}
                </Text>
              )}
            </View>
          )}

          {/* Recurrence chips */}
          {event.recurrenceChips.length > 0 && (
            <View style={styles.chipsContainer}>
              {event.recurrenceChips.slice(0, 4).map((chip) => (
                <View key={chip.id} style={[styles.chip, { borderColor: memberColor }]}>
                  <Text style={[styles.chipText, { color: memberColor }]}>
                    {chip.label}
                  </Text>
                </View>
              ))}
              {event.recurrenceChips.length > 4 && (
                <Text style={[styles.moreChips, { color: colors.textTertiary }]}>
                  +{event.recurrenceChips.length - 4} more
                </Text>
              )}
            </View>
          )}
        </View>
      </View>
    </EventCard>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  dateBox: {
    width: 60,
    padding: spacing.xs,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dateText: {
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
  },
  content: {
    flex: 1,
    paddingLeft: spacing.s,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 2,
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    flex: 1,
  },
  time: {
    fontSize: 13,
    marginRight: spacing.s,
  },
  location: {
    fontSize: 13,
    flex: 1,
  },
  membersRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: spacing.xs,
  },
  memberDot: {
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.xxs,
  },
  memberInitial: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '600',
  },
  moreMembers: {
    fontSize: 12,
    marginLeft: spacing.xxs,
  },
  chipsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginTop: spacing.xs,
    gap: spacing.xxs,
  },
  chip: {
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    borderRadius: borderRadius.xs,
    borderWidth: 1,
  },
  chipText: {
    fontSize: 11,
    fontWeight: '500',
  },
  moreChips: {
    fontSize: 11,
    marginLeft: spacing.xxs,
  },
});
