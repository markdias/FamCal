import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { Appearance, ColorSchemeName } from 'react-native';
import { ThemeProvider as StyledThemeProvider } from 'styled-components/native';
import { colors, typography, spacing, borderRadius, shadows } from '@/styles/designTokens';
import { ThemeMode } from '@/types/settings';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from '@/utils/storageKeys';

type ThemeColors = typeof colors & {
  background: string;
  surface: string;
  surfaceSecondary: string;
  text: string;
  textSecondary: string;
  textTertiary: string;
  border: string;
  card: string;
  cardBackground: string;
};

interface ThemeContextType {
  theme: ThemeMode;
  colorScheme: ColorSchemeName;
  isDark: boolean;
  setTheme: (theme: ThemeMode) => void;
  colors: ThemeColors;
  typography: typeof typography;
  spacing: typeof spacing;
  borderRadius: typeof borderRadius;
  shadows: typeof shadows;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

interface ThemeProviderProps {
  children: ReactNode;
}

export function ThemeProvider({ children }: ThemeProviderProps) {
  const [theme, setThemeState] = useState<ThemeMode>('system');
  const [colorScheme, setColorScheme] = useState<ColorSchemeName>('light');

  // Load theme preference on mount
  useEffect(() => {
    const loadTheme = async () => {
      const storedTheme = await AsyncStorage.getItem(STORAGE_KEYS.THEME_PREFERENCE) as ThemeMode;
      if (storedTheme && ['light', 'dark', 'system'].includes(storedTheme)) {
        setThemeState(storedTheme);
        
        if (storedTheme === 'system') {
          setColorScheme(Appearance.getColorScheme() || 'light');
        } else {
          setColorScheme(storedTheme);
        }
      } else {
        // Default to system
        setColorScheme(Appearance.getColorScheme() || 'light');
      }
    };

    loadTheme();

    // Listen for system theme changes
    const subscription = Appearance.addChangeListener(({ colorScheme: newColorScheme }) => {
      setColorScheme(newColorScheme);
    });

    return () => subscription.remove();
  }, []);

  const isDark = colorScheme === 'dark';

  const setTheme = async (newTheme: ThemeMode) => {
    setThemeState(newTheme);
    await AsyncStorage.setItem(STORAGE_KEYS.THEME_PREFERENCE, newTheme);
    
    if (newTheme === 'system') {
      setColorScheme(Appearance.getColorScheme() || 'light');
    } else {
      setColorScheme(newTheme);
    }
  };

  const themeColors: ThemeColors = {
    ...colors,
    background: isDark ? colors.darkGray1 : colors.gray2,
    surface: isDark ? colors.darkGray2 : colors.gray2,
    surfaceSecondary: isDark ? colors.darkGray1 : colors.gray1,
    text: isDark ? colors.darkGray5 : colors.gray5,
    textSecondary: isDark ? colors.darkGray4 : colors.gray4,
    textTertiary: isDark ? colors.darkGray3 : colors.gray3,
    border: isDark ? colors.darkGray3 : colors.gray1,
    card: isDark ? colors.darkGray2 : colors.gray2,
    cardBackground: isDark ? colors.darkGray1 : colors.gray2,
  };

  return (
    <ThemeContext.Provider
      value={{
        theme,
        colorScheme,
        isDark,
        setTheme,
        colors: themeColors,
        typography,
        spacing,
        borderRadius,
        shadows,
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme(): ThemeContextType {
  const context = useContext(ThemeContext);
  if (context === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
}

export function useColorScheme(): ColorSchemeName {
  const { colorScheme } = useTheme();
  return colorScheme;
}

export function useIsDark(): boolean {
  const { isDark } = useTheme();
  return isDark;
}

export function useThemeColors(): ThemeColors {
  const { colors } = useTheme();
  return colors;
}

export function useThemeConstants() {
  const { typography: themeTypography, spacing: themeSpacing, borderRadius: themeBorderRadius, shadows: themeShadows } = useTheme();
  return { typography: themeTypography, spacing: themeSpacing, borderRadius: themeBorderRadius, shadows: themeShadows };
}

export default ThemeContext;
