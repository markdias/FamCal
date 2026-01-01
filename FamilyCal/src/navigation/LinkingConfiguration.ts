import { LinkingOptions } from '@react-navigation/native';
import { RootStackParamList } from './RootNavigator';

export const linking: LinkingOptions<RootStackParamList> = {
  prefixes: ['famcal://', 'https://famcal.app'],
  config: {
    screens: {
      Auth: {
        screens: {
          Login: 'login',
          Signup: 'signup',
          ForgotPassword: 'forgot-password',
        },
      },
      Onboarding: {
        screens: {
          OnboardingFlow: 'onboarding',
          Permissions: 'permissions',
          FamilySetup: 'family-setup',
        },
      },
      Main: {
        screens: {
          TabNavigator: {
            screens: {
              Calendar: 'calendar',
              Family: 'family',
              Events: 'events',
              Checklists: 'checklists',
              Settings: 'settings',
            },
          },
          EventDetail: 'event/:eventId',
          AddEvent: 'add-event',
          EditEvent: 'edit-event/:eventId',
          FamilyMembers: 'family-members',
          AddMember: 'add-member',
          EditMember: 'edit-member/:memberId',
          ChecklistDetail: 'checklist/:checklistId',
          AccountSettings: 'account-settings',
          NotificationSettings: 'notification-settings',
          WidgetSettings: 'widget-settings',
          Upgrade: 'upgrade',
        },
      },
    },
  },
  async getInitialURL() {
    // Handle initial URL
    const url = await Linking.getInitialURL();
    if (url) {
      return url;
    }
    return null;
  },
  subscribe(listener) {
    const subscription = Linking.addEventListener('url', ({ url }) => {
      listener(url);
    });

    return () => {
      subscription.remove();
    };
  },
};

export default linking;
