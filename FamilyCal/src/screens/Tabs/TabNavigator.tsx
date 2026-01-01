import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius } from '@/styles/designTokens';
import { Ionicons } from '@expo/vector-icons';

// Placeholder screens for each tab
const CalendarScreen = () => (
  <View style={styles.placeholderContainer}>
    <Text style={styles.placeholderText}>Calendar Screen</Text>
  </View>
);

const FamilyScreen = () => (
  <View style={styles.placeholderContainer}>
    <Text style={styles.placeholderText}>Family Screen</Text>
  </View>
);

const EventsScreen = () => (
  <View style={styles.placeholderContainer}>
    <Text style={styles.placeholderText}>Events Screen</Text>
  </View>
);

const ChecklistsScreen = () => (
  <View style={styles.placeholderContainer}>
    <Text style={styles.placeholderText}>Checklists Screen</Text>
  </View>
);

const SettingsScreen = () => (
  <View style={styles.placeholderContainer}>
    <Text style={styles.placeholderText}>Settings Screen</Text>
  </View>
);

const Tab = createBottomTabNavigator();

export default function TabNavigator() {
  const { colors } = useTheme();

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarStyle: {
          backgroundColor: colors.card,
          borderTopColor: colors.border,
          borderTopWidth: 1,
          height: 68 + spacing.xxl, // Include safe area
          paddingBottom: spacing.xxl,
          paddingTop: spacing.s,
        },
        tabBarActiveTintColor: colors.primaryAccent,
        tabBarInactiveTintColor: colors.textTertiary,
        tabBarLabelStyle: {
          fontSize: 11,
          fontWeight: '500',
        },
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: keyof typeof Ionicons.glyphMap;

          switch (route.name) {
            case 'Calendar':
              iconName = focused ? 'calendar' : 'calendar-outline';
              break;
            case 'Family':
              iconName = focused ? 'people' : 'people-outline';
              break;
            case 'Events':
              iconName = focused ? 'list' : 'list-outline';
              break;
            case 'Checklists':
              iconName = focused ? 'checkbox' : 'checkbox-outline';
              break;
            case 'Settings':
              iconName = focused ? 'settings' : 'settings-outline';
              break;
            default:
              iconName = 'help-outline';
          }

          return <Ionicons name={iconName} size={size} color={color} />;
        },
      })}
    >
      <Tab.Screen
        name="Calendar"
        component={CalendarScreen}
        options={{ title: 'Calendar' }}
      />
      <Tab.Screen
        name="Family"
        component={FamilyScreen}
        options={{ title: 'Family' }}
      />
      <Tab.Screen
        name="Events"
        component={EventsScreen}
        options={{ title: 'Events' }}
      />
      <Tab.Screen
        name="Checklists"
        component={ChecklistsScreen}
        options={{ title: 'Checklists' }}
      />
      <Tab.Screen
        name="Settings"
        component={SettingsScreen}
        options={{ title: 'Settings' }}
      />
    </Tab.Navigator>
  );
}

const styles = StyleSheet.create({
  placeholderContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderText: {
    fontSize: 17,
    color: '#8E8E93',
  },
});
