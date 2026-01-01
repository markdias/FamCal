import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, shadows } from '@/styles/designTokens';
import { FamilyMember } from '@/types';
import { getInitials } from '@/utils/eventHelpers';
import { Card } from './Card';

interface MemberCardProps {
  member: FamilyMember;
  eventCount?: number;
  onPress?: () => void;
  onEdit?: () => void;
  onDelete?: () => void;
}

export default function MemberCard({
  member,
  eventCount,
  onPress,
  onEdit,
  onDelete,
}: MemberCardProps) {
  const { colors } = useTheme();

  const initials = getInitials(member.name || '?');

  return (
    <Card variant="elevated" onPress={onPress}>
      <View style={styles.container}>
        {/* Avatar */}
        <View style={[styles.avatar, { backgroundColor: member.colorHex || '#007AFF' }]}>
          <Text style={styles.initials}>{initials}</Text>
        </View>

        {/* Info */}
        <View style={styles.info}>
          <Text style={[styles.name, { color: colors.text }]} numberOfLines={1}>
            {member.name || 'Unnamed'}
          </Text>
          
          {eventCount !== undefined && (
            <Text style={[styles.eventCount, { color: colors.textSecondary }]}>
              {eventCount} {eventCount === 1 ? 'event' : 'events'}
            </Text>
          )}

          {/* Status indicators */}
          <View style={styles.statusRow}>
            {member.isDriver && (
              <View style={[styles.badge, { backgroundColor: colors.warning }]}>
                <Text style={styles.badgeText}>Driver</Text>
              </View>
            )}
          </View>
        </View>

        {/* Calendar link indicator */}
        <View style={styles.indicator}>
          {member.linkedCalendarId ? (
            <View style={[styles.connectedDot, { backgroundColor: colors.success }]} />
          ) : (
            <View style={[styles.connectedDot, { backgroundColor: colors.warning }]} />
          )}
          <Text style={[styles.connectedText, { color: colors.textSecondary }]}>
            {member.linkedCalendarId ? 'Linked' : 'Not linked'}
          </Text>
        </View>
      </View>
    </Card>
  );
}

// Compact version for lists
interface MemberCardCompactProps {
  member: FamilyMember;
  onPress?: () => void;
}

export function MemberCardCompact({ member, onPress }: MemberCardCompactProps) {
  const { colors } = useTheme();

  const initials = getInitials(member.name || '?');

  return (
    <TouchableOpacity style={styles.compactContainer} onPress={onPress} activeOpacity={0.7}>
      <View style={[styles.avatarSmall, { backgroundColor: member.colorHex || '#007AFF' }]}>
        <Text style={styles.initialsSmall}>{initials}</Text>
      </View>
      <View style={styles.compactInfo}>
        <Text style={[styles.nameCompact, { color: colors.text }]} numberOfLines={1}>
          {member.name || 'Unnamed'}
        </Text>
        {member.linkedCalendarId && (
          <Text style={[styles.linkedText, { color: colors.textSecondary }]} numberOfLines={1}>
            Calendar linked
          </Text>
        )}
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.s,
  },
  avatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  initials: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
  avatarSmall: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  initialsSmall: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  info: {
    flex: 1,
    marginLeft: spacing.m,
  },
  name: {
    fontSize: 17,
    fontWeight: '600',
  },
  eventCount: {
    fontSize: 13,
    marginTop: 2,
  },
  statusRow: {
    flexDirection: 'row',
    marginTop: spacing.xxs,
  },
  badge: {
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    borderRadius: borderRadius.xs,
  },
  badgeText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '500',
  },
  indicator: {
    alignItems: 'center',
  },
  connectedDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginBottom: 2,
  },
  connectedText: {
    fontSize: 11,
  },
  compactContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.s,
  },
  compactInfo: {
    flex: 1,
    marginLeft: spacing.s,
  },
  nameCompact: {
    fontSize: 15,
    fontWeight: '500',
  },
  linkedText: {
    fontSize: 12,
  },
});
