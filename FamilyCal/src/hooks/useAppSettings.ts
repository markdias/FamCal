import { useState, useEffect, useCallback } from 'react';
import appSettingsService from '@/services/AppSettingsService';
import { AppSettings, ThemeMode, ProFeature } from '@/types/settings';

export function useAppSettings() {
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const loadSettings = async () => {
      try {
        await appSettingsService.initialize();
        const currentSettings = appSettingsService.getSettings();
        setSettings(currentSettings);

        // Subscribe to changes
        const unsubscribe = appSettingsService.subscribe((newSettings) => {
          setSettings(newSettings);
        });

        return () => unsubscribe();
      } catch (err) {
        setError(err as Error);
      } finally {
        setIsLoading(false);
      }
    };

    loadSettings();
  }, []);

  return { settings, isLoading, error };
}

export function useThemeMode(): ThemeMode {
  const { settings } = useAppSettings();
  return settings?.theme || 'system';
}

export function useIsProUser(): boolean {
  const { settings } = useAppSettings();
  return settings?.isProUser || false;
}

export function useEventsPerPerson(): number {
  const { settings } = useAppSettings();
  return settings?.eventsPerPerson || 3;
}

export function useUpdateSettings() {
  const { settings, setSettings } = useAppSettings();

  const update = useCallback(async (updates: Partial<AppSettings>) => {
    await appSettingsService.updateSettings(updates);
    const newSettings = appSettingsService.getSettings();
    setSettings(newSettings);
  }, [setSettings]);

  return update;
}

export function useSetTheme() {
  const { settings, setSettings } = useAppSettings();

  const setThemeMode = useCallback(async (theme: ThemeMode) => {
    await appSettingsService.setTheme(theme);
    const newSettings = appSettingsService.getSettings();
    setSettings(newSettings);
  }, [setSettings]);

  return setThemeMode;
}

export function useCheckFeatureLimit() {
  const { settings } = useAppSettings();

  const checkMemberLimit = useCallback((currentCount: number) => {
    return appSettingsService.checkMemberLimit(currentCount);
  }, []);

  const checkCalendarLimit = useCallback((currentCount: number) => {
    return appSettingsService.checkCalendarLimit(currentCount);
  }, []);

  const checkSharedCalendarLimit = useCallback((currentCount: number) => {
    return appSettingsService.checkSharedCalendarLimit(currentCount);
  }, []);

  return { checkMemberLimit, checkCalendarLimit, checkSharedCalendarLimit };
}

export function useIsFeatureEnabled() {
  const isProUser = useIsProUser();

  const isEnabled = useCallback((feature: ProFeature) => {
    return appSettingsService.isFeatureEnabled(feature);
  }, []);

  return { isEnabled, isProUser };
}

export function useMorningBriefSettings() {
  const { settings } = useAppSettings();

  const getSettings = useCallback(() => {
    if (!settings) {
      return { enabled: true, time: '07:00' };
    }
    return {
      enabled: settings.morningBriefEnabled,
      time: settings.morningBriefTime,
    };
  }, [settings]);

  return getSettings;
}
