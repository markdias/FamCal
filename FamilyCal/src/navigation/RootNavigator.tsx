import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useApp } from '@/context/AppContext';
import { useTheme } from '@/context/ThemeContext';
import linking from './LinkingConfiguration';

// Auth Screens
import LoginScreen from '@/screens/Auth/LoginScreen';
import SignupScreen from '@/screens/Auth/SignupScreen';
import ForgotPasswordScreen from '@/screens/Auth/ForgotPasswordScreen';

// Onboarding Screens
import OnboardingFlow from '@/screens/Onboarding/OnboardingFlow';
import PermissionsScreen from '@/screens/Onboarding/PermissionsScreen';
import FamilySetupScreen from '@/screens/Onboarding/FamilySetupScreen';

// Main App Screens (after auth/onboarding)
import TabNavigator from '@/screens/Tabs/TabNavigator';
import EventDetailScreen from '@/screens/Events/EventDetailScreen';
import AddEventScreen from '@/screens/Events/AddEventScreen';
import EditEventScreen from '@/screens/Events/EditEventScreen';
import FamilyMembersScreen from '@/screens/Family/FamilyMembersScreen';
import AddMemberScreen from '@/screens/Family/AddMemberScreen';
import EditMemberScreen from '@/screens/Family/EditMemberScreen';
import ChecklistDetailScreen from '@/screens/Checklists/ChecklistDetailScreen';
import AccountSettingsScreen from '@/screens/Settings/AccountSettingsScreen';
import NotificationSettingsScreen from '@/screens/Settings/NotificationSettingsScreen';
import UpgradeScreen from '@/screens/Settings/UpgradeScreen';

export type RootStackParamList = {
  Auth: {
    screen: 'Login' | 'Signup' | 'ForgotPassword';
  };
  Onboarding: {
    screen: 'OnboardingFlow' | 'Permissions' | 'FamilySetup';
  };
  Main: undefined;
  EventDetail: { eventId: string };
  AddEvent: undefined;
  EditEvent: { eventId: string };
  FamilyMembers: undefined;
  AddMember: undefined;
  EditMember: { memberId: string };
  ChecklistDetail: { checklistId: string };
  AccountSettings: undefined;
  NotificationSettings: undefined;
  WidgetSettings: undefined;
  Upgrade: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootNavigator() {
  const { authState } = useApp();
  const { colors } = useTheme();

  // Determine initial route based on auth state
  const initialRouteName = authState.isLoading
    ? undefined // Let the loading screen decide
    : !authState.isAuthenticated
      ? 'Auth'
      : 'Main';

  return (
    <NavigationContainer linking={linking} theme={{ colors: colors as any, dark: false }}>
      <Stack.Navigator
        initialRouteName={initialRouteName}
        screenOptions={{
          headerStyle: {
            backgroundColor: colors.background,
          },
          headerTintColor: colors.text,
          headerTitleStyle: {
            color: colors.text,
          },
          headerBackTitleVisible: false,
          gestureEnabled: true,
          fullScreenGestureEnabled: true,
        }}
      >
        {/* Auth Stack */}
        <Stack.Screen
          name="Auth"
          component={LoginScreen}
          options={{
            headerShown: false,
            gestureEnabled: false,
          }}
        />
        <Stack.Screen
          name="Auth/Signup"
          component={SignupScreen}
          options={{
            headerShown: true,
            title: 'Sign Up',
          }}
        />
        <Stack.Screen
          name="Auth/ForgotPassword"
          component={ForgotPasswordScreen}
          options={{
            headerShown: true,
            title: 'Reset Password',
          }}
        />

        {/* Onboarding Stack */}
        <Stack.Screen
          name="Onboarding"
          component={OnboardingFlow}
          options={{
            headerShown: false,
            gestureEnabled: false,
          }}
        />

        {/* Main App Stack */}
        <Stack.Screen
          name="Main"
          component={TabNavigator}
          options={{
            headerShown: false,
            gestureEnabled: false,
          }}
        />
        <Stack.Screen
          name="EventDetail"
          component={EventDetailScreen}
          options={{
            headerShown: true,
            title: 'Event Details',
          }}
        />
        <Stack.Screen
          name="AddEvent"
          component={AddEventScreen}
          options={{
            headerShown: true,
            title: 'Add Event',
          }}
        />
        <Stack.Screen
          name="EditEvent"
          component={EditEventScreen}
          options={{
            headerShown: true,
            title: 'Edit Event',
          }}
        />
        <Stack.Screen
          name="FamilyMembers"
          component={FamilyMembersScreen}
          options={{
            headerShown: true,
            title: 'Family Members',
          }}
        />
        <Stack.Screen
          name="AddMember"
          component={AddMemberScreen}
          options={{
            headerShown: true,
            title: 'Add Member',
          }}
        />
        <Stack.Screen
          name="EditMember"
          component={EditMemberScreen}
          options={{
            headerShown: true,
            title: 'Edit Member',
          }}
        />
        <Stack.Screen
          name="ChecklistDetail"
          component={ChecklistDetailScreen}
          options={{
            headerShown: true,
            title: 'Checklist',
          }}
        />
        <Stack.Screen
          name="AccountSettings"
          component={AccountSettingsScreen}
          options={{
            headerShown: true,
            title: 'Account',
          }}
        />
        <Stack.Screen
          name="NotificationSettings"
          component={NotificationSettingsScreen}
          options={{
            headerShown: true,
            title: 'Notifications',
          }}
        />
        <Stack.Screen
          name="Upgrade"
          component={UpgradeScreen}
          options={{
            headerShown: true,
            title: 'Upgrade to Pro',
          }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
