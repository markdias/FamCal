import AsyncStorage from '@react-native-async-storage/async-storage';
import supabaseDataService from './supabase/SupabaseDataService';
import { STORAGE_KEYS } from '@/utils/storageKeys';
import { AppSettings, UserSettings, NotificationSettings, DEFAULT_USER_SETTINGS, DEFAULT_NOTIFICATION_SETTINGS, ThemeMode, ProFeature } from '@/types/settings';
import { FAMILY_CONSTANTS } from '@/utils/constants';
import { debounce } from '@/utils/eventHelpers';

type SettingsChangeCallback = (settings: AppSettings) => void;

class AppSettingsService {
  private settings: AppSettings;
  private listeners: Set<SettingsChangeCallback> = new Set();
  private syncDebounced: () => Promise<void>;

  constructor() {
    this.settings = {
      id: '',
      userId: '',
      theme: 'system',
      isProUser: false,
      eventsPerPerson: 3,
      defaultAlertMinutes: 60,
      morningBriefEnabled: true,
      morningBriefTime: '07:00',
      theme: 'system',
    };

    // Debounced sync to cloud (1 second)
    this.syncDebounced = debounce(() => this.syncToCloud(), 1000);
  }

  // Initialize settings from storage
  async initialize(): Promise<void> {
    const storedSettings = await this.loadFromStorage();
    this.settings = { ...this.settings, ...storedSettings };

    // Check pro status
    await this.checkProStatus();
  }

  // Get current settings
  getSettings(): AppSettings {
    return { ...this.settings };
  }

  // Update a setting value
  async updateSetting<K extends keyof AppSettings>(key: K, value: AppSettings[K]): Promise<void> {
    (this.settings as any)[key] = value;
    
    // Persist to local storage
    await this.saveToStorage({ [key]: value });
    
    // Sync to cloud (debounced)
    this.syncDebounced();
    
    // Notify listeners
    this.notifyListeners();
  }

  // Update multiple settings at once
  async updateSettings(updates: Partial<AppSettings>): Promise<void> {
    this.settings = { ...this.settings, ...updates };
    
    // Persist to local storage
    await this.saveToStorage(updates);
    
    // Sync to cloud (debounced)
    this.syncDebounced();
    
    // Notify listeners
    this.notifyListeners();
  }

  // Get theme preference
  getTheme(): ThemeMode {
    return this.settings.theme;
  }

  // Set theme preference
  async setTheme(theme: ThemeMode): Promise<void> {
    await this.updateSetting('theme', theme);
  }

  // Check if pro features are enabled
  isFeatureEnabled(feature: ProFeature): boolean {
    if (!this.settings.isProUser) {
      return false;
    }

    // All pro features are enabled for pro users
    return true;
  }

  // Check pro status from storage and server
  async checkProStatus(): Promise<boolean> {
    const storedPro = await AsyncStorage.getItem(STORAGE_KEYS.PRO_ENABLED);
    const expiresAt = await AsyncStorage.getItem(STORAGE_KEYS.PRO_EXPIRES_AT);

    if (storedPro === 'true') {
      // Check if expired
      if (expiresAt && new Date(expiresAt) > new Date()) {
        this.settings.isProUser = true;
        return true;
      } else {
        // Pro expired, clear status
        await AsyncStorage.multiRemove([
          STORAGE_KEYS.PRO_ENABLED,
          STORAGE_KEYS.PRO_EXPIRES_AT,
        ]);
      }
    }

    this.settings.isProUser = false;
    return false;
  }

  // Enable pro features
  async enablePro(features: { expiresAt?: string }): Promise<void> {
    this.settings.isProUser = true;
    
    await AsyncStorage.setItem(STORAGE_KEYS.PRO_ENABLED, 'true');
    if (features.expiresAt) {
      await AsyncStorage.setItem(STORAGE_KEYS.PRO_EXPIRES_AT, features.expiresAt);
      this.settings.proExpiresAt = features.expiresAt;
    }
    
    this.notifyListeners();
  }

  // Disable pro features
  async disablePro(): Promise<void> {
    this.settings.isProUser = false;
    
    await AsyncStorage.multiRemove([
      STORAGE_KEYS.PRO_ENABLED,
      STORAGE_KEYS.PRO_EXPIRES_AT,
    ]);
    
    this.notifyListeners();
  }

  // Get events per person limit
  getEventsPerPerson(): number {
    return this.settings.eventsPerPerson;
  }

  // Set events per person
  async setEventsPerPerson(count: number): Promise<void> {
    const maxCount = this.settings.isProUser 
      ? FAMILY_CONSTANTS.PRO_MAX_MEMBERS 
      : FAMILY_CONSTANTS.DEFAULT_MAX_MEMBERS;
    
    if (count > maxCount && !this.settings.isProUser) {
      // Would exceed limit, could show upgrade prompt
    }
    
    await this.updateSetting('eventsPerPerson', count);
  }

  // Get default alert minutes
  getDefaultAlertMinutes(): number {
    return this.settings.defaultAlertMinutes;
  }

  // Set default alert minutes
  async setDefaultAlertMinutes(minutes: number): Promise<void> {
    await this.updateSetting('defaultAlertMinutes', minutes);
  }

  // Get morning brief settings
  getMorningBriefSettings(): { enabled: boolean; time: string } {
    return {
      enabled: this.settings.morningBriefEnabled,
      time: this.settings.morningBriefTime,
    };
  }

  // Set morning brief enabled
  async setMorningBriefEnabled(enabled: boolean): Promise<void> {
    await this.updateSetting('morningBriefEnabled', enabled);
  }

  // Set morning brief time
  async setMorningBriefTime(time: string): Promise<void> {
    await this.updateSetting('morningBriefTime', time);
  }

  // Check feature limits
  checkMemberLimit(currentCount: number): { allowed: boolean; current: number; max: number; upgradeRequired: boolean } {
    const maxMembers = this.settings.isProUser 
      ? FAMILY_CONSTANTS.PRO_MAX_MEMBERS 
      : FAMILY_CONSTANTS.DEFAULT_MAX_MEMBERS;
    
    return {
      allowed: currentCount < maxMembers,
      current: currentCount,
      max: maxMembers,
      upgradeRequired: !this.settings.isProUser && currentCount >= FAMILY_CONSTANTS.DEFAULT_MAX_MEMBERS,
    };
  }

  checkCalendarLimit(currentCount: number): { allowed: boolean; current: number; max: number; upgradeRequired: boolean } {
    const maxCalendars = this.settings.isProUser 
      ? FAMILY_CONSTANTS.PRO_MAX_CALENDARS 
      : FAMILY_CONSTANTS.DEFAULT_MAX_CALENDARS;
    
    return {
      allowed: currentCount < maxCalendars,
      current: currentCount,
      max: maxCalendars,
      upgradeRequired: !this.settings.isProUser && currentCount >= FAMILY_CONSTANTS.DEFAULT_MAX_CALENDARS,
    };
  }

  checkSharedCalendarLimit(currentCount: number): { allowed: boolean; current: number; max: number; upgradeRequired: boolean } {
    const maxShared = this.settings.isProUser 
      ? FAMILY_CONSTANTS.PRO_MAX_SHARED_CALENDARS 
      : FAMILY_CONSTANTS.DEFAULT_MAX_SHARED_CALENDARS;
    
    return {
      allowed: currentCount < maxShared,
      current: currentCount,
      max: maxShared,
      upgradeRequired: !this.settings.isProUser && currentCount >= FAMILY_CONSTANTS.DEFAULT_MAX_SHARED_CALENDARS,
    };
  }

  // Subscribe to settings changes
  subscribe(callback: SettingsChangeCallback): () => void {
    this.listeners.add(callback);
    return () => this.listeners.delete(callback);
  }

  // Notify all listeners
  private notifyListeners(): void {
    const currentSettings = this.getSettings();
    this.listeners.forEach(callback => {
      try {
        callback(currentSettings);
      } catch (error) {
        console.error('Settings listener error:', error);
      }
    });
  }

  // Load settings from local storage
  private async loadFromStorage(): Promise<Partial<AppSettings>> {
    try {
      const settingsJson = await AsyncStorage.getMultiGet([
        STORAGE_KEYS.THEME_PREFERENCE,
        STORAGE_KEYS.EVENTS_PER_PERSON,
        STORAGE_KEYS.DEFAULT_ALERT_MINUTES,
        STORAGE_KEYS.MORNING_BRIEF_ENABLED,
        STORAGE_KEYS.MORNING_BRIEF_TIME,
      ]);

      const settings: Partial<AppSettings> = {};
      
      settingsJson.forEach(([key, value]) => {
        if (value !== null) {
          switch (key) {
            case STORAGE_KEYS.THEME_PREFERENCE:
              settings.theme = value as ThemeMode;
              break;
            case STORAGE_KEYS.EVENTS_PER_PERSON:
              settings.eventsPerPerson = parseInt(value, 10) || 3;
              break;
            case STORAGE_KEYS.DEFAULT_ALERT_MINUTES:
              settings.defaultAlertMinutes = parseInt(value, 10) || 60;
              break;
            case STORAGE_KEYS.MORNING_BRIEF_ENABLED:
              settings.morningBriefEnabled = value === 'true';
              break;
            case STORAGE_KEYS.MORNING_BRIEF_TIME:
              settings.morningBriefTime = value || '07:00';
              break;
          }
        }
      });

      return settings;
    } catch (error) {
      console.error('Failed to load settings:', error);
      return {};
    }
  }

  // Save settings to local storage
  private async saveToStorage(settings: Partial<AppSettings>): Promise<void> {
    try {
      const entries: [string, string][] = [];
      
      if (settings.theme !== undefined) {
        entries.push([STORAGE_KEYS.THEME_PREFERENCE, settings.theme]);
      }
      if (settings.eventsPerPerson !== undefined) {
        entries.push([STORAGE_KEYS.EVENTS_PER_PERSON, String(settings.eventsPerPerson)]);
      }
      if (settings.defaultAlertMinutes !== undefined) {
        entries.push([STORAGE_KEYS.DEFAULT_ALERT_MINUTES, String(settings.defaultAlertMinutes)]);
      }
      if (settings.morningBriefEnabled !== undefined) {
        entries.push([STORAGE_KEYS.MORNING_BRIEF_ENABLED, String(settings.morningBriefEnabled)]);
      }
      if (settings.morningBriefTime !== undefined) {
        entries.push([STORAGE_KEYS.MORNING_BRIEF_TIME, settings.morningBriefTime]);
      }

      if (entries.length > 0) {
        await AsyncStorage.multiSet(entries);
      }
    } catch (error) {
      console.error('Failed to save settings:', error);
    }
  }

  // Sync settings to Supabase cloud
  private async syncToCloud(): Promise<void> {
    try {
      const userId = await AsyncStorage.getItem(STORAGE_KEYS.USER_ID);
      if (!userId) return;

      await supabaseDataService.upsertUserSettings({
        id: this.settings.id,
        user_id: userId,
        theme: this.settings.theme,
        is_pro_user: this.settings.isProUser,
        events_per_person: this.settings.eventsPerPerson,
        default_alert_minutes: this.settings.defaultAlertMinutes,
        morning_brief_enabled: this.settings.morningBriefEnabled,
        morning_brief_time: this.settings.morningBriefTime,
      });
    } catch (error) {
      console.error('Failed to sync settings to cloud:', error);
    }
  }

  // Reset all settings to defaults
  async resetToDefaults(): Promise<void> {
    this.settings = {
      id: '',
      userId: this.settings.userId,
      theme: 'system',
      isProUser: this.settings.isProUser,
      eventsPerPerson: DEFAULT_USER_SETTINGS.eventsPerPerson,
      defaultAlertMinutes: DEFAULT_USER_SETTINGS.defaultAlertMinutes,
      morningBriefEnabled: DEFAULT_USER_SETTINGS.morningBriefEnabled,
      morningBriefTime: DEFAULT_USER_SETTINGS.morningBriefTime,
    };

    await AsyncStorage.multiRemove([
      STORAGE_KEYS.THEME_PREFERENCE,
      STORAGE_KEYS.EVENTS_PER_PERSON,
      STORAGE_KEYS.DEFAULT_ALERT_MINUTES,
      STORAGE_KEYS.MORNING_BRIEF_ENABLED,
      STORAGE_KEYS.MORNING_BRIEF_TIME,
    ]);

    this.notifyListeners();
  }
}

export const appSettingsService = new AppSettingsService();
export default appSettingsService;
