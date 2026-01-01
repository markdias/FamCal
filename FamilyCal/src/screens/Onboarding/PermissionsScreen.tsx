import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, typography } from '@/styles/designTokens';
import { Button, Card, LoadingSpinner } from '@/components';
import * as Calendar from 'expo-calendar';
import * as Notifications from 'expo-notifications';
import * as Contacts from 'expo-contacts';

interface PermissionsScreenProps {
  onComplete: () => void;
}

interface PermissionItem {
  id: string;
  title: string;
  description: string;
  required: boolean;
  status: 'pending' | 'granted' | 'denied';
  icon: string;
}

export default function PermissionsScreen({ onComplete }: PermissionsScreenProps) {
  const { colors } = useTheme();
  const [isLoading, setIsLoading] = useState(false);
  const [permissions, setPermissions] = useState<PermissionItem[]>([
    {
      id: 'calendar',
      title: 'Calendar',
      description: 'Needed to sync and display family events',
      required: true,
      status: 'pending',
      icon: '📅',
    },
    {
      id: 'notifications',
      title: 'Notifications',
      description: 'To receive event reminders and alerts',
      required: true,
      status: 'pending',
      icon: '🔔',
    },
    {
      id: 'contacts',
      title: 'Contacts',
      description: 'Optional - to help find and invite family members',
      required: false,
      status: 'pending',
      icon: '👥',
    },
  ]);

  // Check initial permission status
  useEffect(() => {
    checkAllPermissions();
  }, []);

  const checkAllPermissions = async () => {
    // Check calendar
    const calendarStatus = await Calendar.getCalendarPermissionsAsync();
    updatePermission('calendar', calendarStatus.status === 'granted');

    // Check notifications
    const notificationStatus = await Notifications.getPermissionsAsync();
    updatePermission('notifications', notificationStatus.status === 'granted');

    // Check contacts
    const contactStatus = await Contacts.getPermissionsAsync();
    updatePermission('contacts', contactStatus.status === 'granted');
  };

  const updatePermission = (id: string, granted: boolean) => {
    setPermissions(prev =>
      prev.map(p =>
        p.id === id ? { ...p, status: granted ? 'granted' : 'pending' } : p
      )
    );
  };

  const requestPermission = async (id: string) => {
    setIsLoading(true);

    switch (id) {
      case 'calendar':
        const calendarResult = await Calendar.requestCalendarPermissionsAsync();
        updatePermission('calendar', calendarResult.status === 'granted');
        break;

      case 'notifications':
        const notificationResult = await Notifications.requestPermissionsAsync();
        updatePermission('notifications', notificationResult.status === 'granted');
        break;

      case 'contacts':
        const contactResult = await Contacts.requestContactsAsync();
        updatePermission('contacts', contactResult.status === 'granted');
        break;
    }

    setIsLoading(false);
  };

  const canProceed = () => {
    // Check all required permissions are granted
    const requiredPermissions = permissions.filter(p => p.required);
    return requiredPermissions.every(p => p.status === 'granted');
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      <ScrollView
        style={styles.scrollContainer}
        contentContainerStyle={styles.scrollContent}
      >
        {/* Header */}
        <View style={styles.header}>
          <Text style={[styles.title, { color: colors.text }]}>Permissions</Text>
          <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
            FamilyCal needs a few permissions to work properly
          </Text>
        </View>

        {/* Permissions List */}
        <View style={styles.permissionsList}>
          {permissions.map(permission => (
            <Card key={permission.id} style={styles.permissionCard}>
              <View style={styles.permissionRow}>
                <View style={styles.permissionIcon}>
                  <Text style={styles.iconText}>{permission.icon}</Text>
                </View>
                <View style={styles.permissionInfo}>
                  <View style={styles.permissionTitleRow}>
                    <Text style={[styles.permissionTitle, { color: colors.text }]}>
                      {permission.title}
                    </Text>
                    {permission.required && (
                      <View style={[styles.requiredBadge, { backgroundColor: colors.error }]}>
                        <Text style={styles.requiredBadgeText}>Required</Text>
                      </View>
                    )}
                  </View>
                  <Text style={[styles.permissionDescription, { color: colors.textSecondary }]}>
                    {permission.description}
                  </Text>
                </View>
                <View style={styles.permissionStatus}>
                  {permission.status === 'granted' ? (
                    <View style={[styles.statusIcon, { backgroundColor: colors.success }]}>
                      <Text style={styles.statusIconText}>✓</Text>
                    </View>
                  ) : permission.status === 'denied' ? (
                    <View style={[styles.statusIcon, { backgroundColor: colors.error }]}>
                      <Text style={styles.statusIconText}>✗</Text>
                    </View>
                  ) : null}
                </View>
              </View>

              {permission.status !== 'granted' && (
                <Button
                  title={permission.status === 'denied' ? 'Open Settings' : 'Allow'}
                  variant={permission.required ? 'primary' : 'outline'}
                  size="small"
                  onPress={() => requestPermission(permission.id)}
                  disabled={isLoading}
                  style={styles.permissionButton}
                />
              )}
            </Card>
          ))}
        </View>

        {/* Spacer */}
        <View style={styles.spacer} />

        {/* Continue Button */}
        <Button
          title="Continue"
          onPress={onComplete}
          disabled={!canProceed()}
          fullWidth
        />

        {/* Info */}
        <Text style={[styles.infoText, { color: colors.textTertiary }]}>
          You can change these permissions later in Settings
        </Text>
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
  permissionsList: {
    gap: spacing.s,
  },
  permissionCard: {
    marginBottom: spacing.s,
  },
  permissionRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  permissionIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#F2F2F7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconText: {
    fontSize: 24,
  },
  permissionInfo: {
    flex: 1,
    marginLeft: spacing.m,
  },
  permissionTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  permissionTitle: {
    fontSize: 17,
    fontWeight: '600',
    marginRight: spacing.xs,
  },
  requiredBadge: {
    paddingHorizontal: spacing.xs,
    paddingVertical: 2,
    borderRadius: borderRadius.xs,
  },
  requiredBadgeText: {
    color: '#FFFFFF',
    fontSize: 10,
    fontWeight: '600',
  },
  permissionDescription: {
    fontSize: 13,
  },
  permissionStatus: {
    marginLeft: spacing.s,
  },
  statusIcon: {
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  statusIconText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '700',
  },
  permissionButton: {
    marginTop: spacing.s,
  },
  spacer: {
    flex: 1,
    minHeight: spacing.l,
  },
  infoText: {
    fontSize: 13,
    textAlign: 'center',
    marginTop: spacing.m,
  },
});
