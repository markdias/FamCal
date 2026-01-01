import React, { useState } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Switch } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, shadows } from '@/styles/designTokens';
import { Card, Button, Input } from '@/components';
import { useApp } from '@/context/AppContext';
import { Ionicons } from '@expo/vector-icons';

interface SettingsItem {
  id: string;
  title: string;
  subtitle?: string;
  icon: string;
  onPress: () => void;
  rightElement?: React.ReactNode;
}

export default function SettingsScreen({ navigation }: { navigation: any }) {
  const { colors } = useTheme();
  const { logout, authState } = useApp();

  const settingsItems: SettingsItem[] = [
    {
      id: 'account',
      title: 'Account',
      subtitle: authState.user?.email || 'Not signed in',
      icon: 'person-outline',
      onPress: () => navigation.navigate('AccountSettings'),
    },
    {
      id: 'notifications',
      title: 'Notifications',
      subtitle: 'Manage notification preferences',
      icon: 'notifications-outline',
      onPress: () => navigation.navigate('NotificationSettings'),
    },
    {
      id: 'appearance',
      title: 'Appearance',
      subtitle: 'Theme, colors',
      icon: 'color-palette-outline',
      onPress: () => {},
    },
    {
      id: 'family',
      title: 'Family Members',
      subtitle: 'Manage family members',
      icon: 'people-outline',
      onPress: () => navigation.navigate('FamilyMembers'),
    },
    {
      id: 'calendars',
      title: 'Calendars',
      subtitle: 'Manage linked calendars',
      icon: 'calendar-outline',
      onPress: () => {},
    },
    {
      id: 'widgets',
      title: 'Widget Settings',
      subtitle: 'Customize home screen widget',
      icon: 'grid-outline',
      onPress: () => {},
    },
    {
      id: 'help',
      title: 'Help & Support',
      subtitle: 'FAQ, contact us',
      icon: 'help-circle-outline',
      onPress: () => {},
    },
    {
      id: 'about',
      title: 'About',
      subtitle: 'Version 1.0.0',
      icon: 'information-circle-outline',
      onPress: () => {},
    },
  ];

  const renderSettingsItem = ({ item }: { item: SettingsItem }) => (
    <TouchableOpacity
      style={[styles.settingsItem, { backgroundColor: colors.card }]}
      onPress={item.onPress}
    >
      <View style={styles.itemLeft}>
        <View style={[styles.iconContainer, { backgroundColor: colors.surface }]}>
          <Ionicons name={item.icon as any} size={22} color={colors.primaryAccent} />
        </View>
        <View style={styles.itemText}>
          <Text style={[styles.itemTitle, { color: colors.text }]}>{item.title}</Text>
          {item.subtitle && (
            <Text style={[styles.itemSubtitle, { color: colors.textSecondary }]}>
              {item.subtitle}
            </Text>
          )}
        </View>
      </View>
      <Ionicons name="chevron-forward" size={20} color={colors.textTertiary} />
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={[styles.title, { color: colors.text }]}>Settings</Text>
      </View>

      {/* Settings List */}
      <FlatList
        data={settingsItems}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContent}
        renderItem={renderSettingsItem}
        ItemSeparatorComponent={() => (
          <View style={[styles.separator, { backgroundColor: colors.border }]} />
        )}
      />

      {/* Logout Button */}
      <View style={styles.footer}>
        <Button
          title="Log Out"
          variant="outline"
          onPress={logout}
          fullWidth
        />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: spacing.l,
    paddingVertical: spacing.m,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
  },
  title: {
    fontSize: 34,
    fontWeight: '700',
  },
  listContent: {
    padding: spacing.m,
    paddingBottom: spacing.xxl,
  },
  settingsItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: spacing.m,
    borderRadius: borderRadius.m,
    ...shadows.small,
  },
  itemLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  iconContainer: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  itemText: {
    marginLeft: spacing.m,
    flex: 1,
  },
  itemTitle: {
    fontSize: 17,
    fontWeight: '500',
  },
  itemSubtitle: {
    fontSize: 13,
    marginTop: 2,
  },
  separator: {
    height: 1,
    marginLeft: 72,
  },
  footer: {
    padding: spacing.m,
    borderTopWidth: 1,
    borderTopColor: '#E5E5EA',
  },
});
