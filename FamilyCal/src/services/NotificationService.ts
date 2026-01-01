import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import Constants from 'expo-constants';
import { addMinutes, format } from 'date-fns';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from '@/utils/storageKeys';
import { NOTIFICATION_CONSTANTS } from '@/utils/constants';

type NotificationHandler = (event: Notifications.Notification) => void;

class NotificationService {
  private isInitialized = false;
  private notificationListener: any = null;
  private responseListener: any = null;
  private handlers: Map<string, NotificationHandler> = new Map();

  // Initialize notification service
  async initialize(): Promise<boolean> {
    try {
      if (!Device.isDevice) {
        console.log('Notifications require a physical device');
        return false;
      }

      // Request permissions
      const permissionStatus = await this.requestPermissions();
      if (!permissionStatus) {
        console.log('Notification permissions not granted');
        return false;
      }

      // Set up notification categories (iOS)
      if (Platform.OS === 'ios') {
        await this.setupNotificationCategories();
      }

      // Set up notification channels (Android)
      if (Platform.OS === 'android') {
        await this.setupNotificationChannels();
      }

      // Get Expo push token for remote notifications
      const pushToken = await this.getPushToken();
      console.log('Push token:', pushToken);

      // Set up notification listeners
      this.setupNotificationListeners();

      this.isInitialized = true;
      return true;
    } catch (error) {
      console.error('Failed to initialize notification service:', error);
      return false;
    }
  }

  // Request notification permissions
  async requestPermissions(): Promise<boolean> {
    try {
      const { status: existingStatus } = await Notifications.getPermissionsAsync();
      
      if (existingStatus !== 'granted') {
        const { status } = await Notifications.requestPermissionsAsync();
        return status === 'granted';
      }
      
      return true;
    } catch (error) {
      console.error('Failed to request notification permissions:', error);
      return false;
    }
  }

  // Check notification permissions
  async checkPermissions(): Promise<boolean> {
    try {
      const { status } = await Notifications.getPermissionsAsync();
      return status === 'granted';
    } catch (error) {
      console.error('Failed to check notification permissions:', error);
      return false;
    }
  }

  // Get Expo push token
  async getPushToken(): Promise<string | null> {
    try {
      const projectId = Constants.expoConfig?.extra?.eas?.projectId;
      if (!projectId) {
        console.warn('EAS project ID not configured');
        return null;
      }

      const { data: token } = await Notifications.getExpoPushTokenAsync({
        projectId,
      });

      return token;
    } catch (error) {
      console.error('Failed to get push token:', error);
      return null;
    }
  }

  // Set up notification categories (iOS)
  private async setupNotificationCategories(): Promise<void> {
    await Notifications.setNotificationCategoryAsync(NOTIFICATION_CONSTANTS.EVENT_NOTIFICATION_CATEGORY, [
      {
        identifier: NOTIFICATION_CONSTANTS.ACTION_VIEW,
        buttonTitle: 'View Event',
        options: {
          opensApp: true,
          isDestructive: false,
        },
      },
      {
        identifier: NOTIFICATION_CONSTANTS.ACTION_DISMISS,
        buttonTitle: 'Dismiss',
        options: {
          opensApp: false,
          isDestructive: false,
        },
      },
    ]);

    await Notifications.setNotificationCategoryAsync(NOTIFICATION_CONSTANTS.MORNING_BRIEF_CATEGORY, [
      {
        identifier: NOTIFICATION_CONSTANTS.ACTION_VIEW,
        buttonTitle: 'View Day',
        options: {
          opensApp: true,
          isDestructive: false,
        },
      },
      {
        identifier: NOTIFICATION_CONSTANTS.ACTION_DISMISS,
        buttonTitle: 'Dismiss',
        options: {
          opensApp: false,
          isDestructive: false,
        },
      },
    ]);
  }

  // Set up notification channels (Android)
  private async setupNotificationChannels(): Promise<void> {
    await Notifications.setNotificationChannelAsync(NOTIFICATION_CONSTANTS.CHANNEL_ID, {
      name: NOTIFICATION_CONSTANTS.CHANNEL_NAME,
      importance: Notifications.AndroidImportance.HIGH,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: '#FF6B6B',
      enableLights: true,
      enableVibration: true,
      showBadge: true,
    });

    // Morning brief channel
    await Notifications.setNotificationChannelAsync('morning_brief', {
      name: 'Morning Brief',
      importance: Notifications.AndroidImportance.DEFAULT,
      vibrationPattern: [0, 100],
      lightColor: '#007AFF',
    });

    // Reminder channel
    await Notifications.setNotificationChannelAsync('reminders', {
      name: 'Event Reminders',
      importance: Notifications.AndroidImportance.HIGH,
      vibrationPattern: [0, 250],
    });
  }

  // Set up notification listeners
  private setupNotificationListeners(): void {
    // Notification received while app is foregrounded
    this.notificationListener = Notifications.addNotificationReceivedListener(
      (notification) => {
        this.handleNotification(notification);
      }
    );

    // User interacted with notification
    this.responseListener = Notifications.addNotificationResponseReceivedListener(
      (response) => {
        this.handleNotificationResponse(response);
      }
    );
  }

  // Handle incoming notification
  private handleNotification(notification: Notifications.Notification): void {
    const { identifier, request } = notification;
    const data = request.content.data as Record<string, unknown> | undefined;

    console.log('Notification received:', identifier);
    console.log('Notification data:', data);

    // Dispatch to registered handlers
    const handler = this.handlers.get('default');
    if (handler) {
      handler(notification);
    }

    // Dispatch to category-specific handlers
    const categoryHandler = this.handlers.get(data?.category || 'default');
    if (categoryHandler) {
      categoryHandler(notification);
    }
  }

  // Handle notification response (user tapped notification)
  private handleNotificationResponse(response: Notifications.NotificationResponse): void {
    const { notification, actionIdentifier } = response;
    const data = notification.request.content.data as Record<string, unknown> | undefined;

    console.log('Notification action:', actionIdentifier);
    console.log('Notification data:', data);

    // Handle specific actions
    if (actionIdentifier === NOTIFICATION_CONSTANTS.ACTION_VIEW) {
      // Navigate to event screen
      const eventId = data?.eventId as string | undefined;
      if (eventId) {
        this.handleNavigateToEvent(eventId);
      }
    } else if (actionIdentifier === NOTIFICATION_CONSTANTS.ACTION_DISMISS) {
      // Just dismiss
    } else {
      // Default tap behavior
      const eventId = data?.eventId as string | undefined;
      if (eventId) {
        this.handleNavigateToEvent(eventId);
      }
    }
  }

  // Handle navigation to event
  private handleNavigateToEvent(eventId: string): void {
    // This will be implemented by the navigation system
    // For now, store the pending navigation
    AsyncStorage.setItem(STORAGE_KEYS.PENDING_DEEP_LINK, JSON.stringify({
      type: 'event',
      eventId,
    }));
  }

  // Schedule a local notification
  async scheduleNotification(options: {
    title: string;
    body: string;
    data?: Record<string, unknown>;
    trigger?: Notifications.NotificationTriggerInput;
    categoryId?: string;
    identifier?: string;
  }): Promise<string | null> {
    try {
      const identifier = await Notifications.scheduleNotificationAsync({
        content: {
          title: options.title,
          body: options.body,
          data: options.data || {},
          sound: true,
          categoryId: options.categoryId || NOTIFICATION_CONSTANTS.EVENT_NOTIFICATION_CATEGORY,
          priority: Notifications.AndroidPriority.HIGH,
          interruptionLevel: 'timeSensitive' as any,
        },
        trigger: options.trigger || null,
      });

      return identifier;
    } catch (error) {
      console.error('Failed to schedule notification:', error);
      return null;
    }
  }

  // Schedule event reminder
  async scheduleEventReminder(eventId: string, title: string, startDate: Date, alertMinutes: number): Promise<string | null> {
    const triggerDate = addMinutes(startDate, -alertMinutes);
    
    // Only schedule if trigger date is in the future
    if (triggerDate <= new Date()) {
      return null;
    }

    const notificationId = await this.scheduleNotification({
      title: `Upcoming: ${title}`,
      body: `Starting in ${alertMinutes} minutes`,
      data: {
        eventId,
        type: 'eventReminder',
      },
      trigger: {
        date: triggerDate,
      },
      categoryId: NOTIFICATION_CONSTANTS.EVENT_NOTIFICATION_CATEGORY,
      identifier: `event_reminder_${eventId}`,
    });

    return notificationId;
  }

  // Cancel event reminder
  async cancelEventReminder(eventId: string): Promise<void> {
    await Notifications.cancelScheduledNotificationAsync(`event_reminder_${eventId}`);
  }

  // Schedule morning brief notification
  async scheduleMorningBrief(events: Array<{ title: string; time: string; memberName: string }>): Promise<void> {
    const settingsJson = await AsyncStorage.getItem(STORAGE_KEYS.NOTIFICATION_SETTINGS);
    const settings = settingsJson ? JSON.parse(settingsJson) : null;
    
    if (!settings?.morningBriefEnabled) {
      return;
    }

    const morningBriefTime = await AsyncStorage.getItem(STORAGE_KEYS.MORNING_BRIEF_TIME) || '07:00';
    const [hours, minutes] = morningBriefTime.split(':').map(Number);

    // Build notification body
    let body = 'Your family events today:';
    events.slice(0, 3).forEach(event => {
      body += `\n• ${event.time} - ${event.title} (${event.memberName})`;
    });

    if (events.length > 3) {
      body += `\n• And ${events.length - 3} more...`;
    }

    // Schedule for tomorrow (and each day)
    const now = new Date();
    const targetDate = new Date(now);
    targetDate.setHours(hours, minutes, 0, 0);

    // If time has passed today, schedule for tomorrow
    if (targetDate <= now) {
      targetDate.setDate(targetDate.getDate() + 1);
    }

    await this.scheduleNotification({
      title: 'Good Morning! 🌅',
      body,
      data: {
        type: 'morningBrief',
      },
      trigger: {
        date: targetDate,
        repeats: true,
      },
      categoryId: NOTIFICATION_CONSTANTS.MORNING_BRIEF_CATEGORY,
      identifier: 'morning_brief',
    });
  }

  // Cancel all notifications
  async cancelAllNotifications(): Promise<void> {
    await Notifications.cancelAllScheduledNotificationsAsync();
  }

  // Cancel notification by identifier
  async cancelNotification(identifier: string): Promise<void> {
    await Notifications.cancelScheduledNotificationAsync(identifier);
  }

  // Get all scheduled notifications
  async getScheduledNotifications(): Promise<Notifications.NotificationRequest[]> {
    return Notifications.getAllScheduledNotificationsAsync();
  }

  // Get badge count
  async getBadgeCount(): Promise<number> {
    return Notifications.getBadgeCountAsync();
  }

  // Set badge count
  async setBadgeCount(count: number): Promise<void> {
    await Notifications.setBadgeCountAsync(count);
  }

  // Clear badge
  async clearBadge(): Promise<void> {
    await Notifications.setBadgeCountAsync(0);
  }

  // Register notification handler
  registerHandler(category: string, handler: NotificationHandler): () => void {
    this.handlers.set(category, handler);
    return () => this.handlers.delete(category);
  }

  // Clean up listeners
  dispose(): void {
    if (this.notificationListener) {
      this.notificationListener.remove();
    }
    if (this.responseListener) {
      this.responseListener.remove();
    }
    this.handlers.clear();
    this.isInitialized = false;
  }

  // Check if service is initialized
  isReady(): boolean {
    return this.isInitialized;
  }
}

export const notificationService = new NotificationService();
export default notificationService;
