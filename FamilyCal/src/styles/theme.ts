import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { Appearance, ColorSchemeName } from 'react-native';
import { colors } from './designTokens';

export type Theme = 'light' | 'dark' | 'system';

interface ThemeContextType {
  theme: Theme;
  colorScheme: ColorSchemeName;
  isDark: boolean;
  setTheme: (theme: Theme) => void;
  themeColors: typeof colors;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

interface ThemeProviderProps {
  children: ReactNode;
}

export function ThemeProvider({ children }: ThemeProviderProps) {
  const [theme, setThemeState] = useState<Theme>('system');
  const [colorScheme, setColorScheme] = useState<ColorSchemeName>('light');

  useEffect(() => {
    const subscription = Appearance.addChangeListener(({ colorScheme: newColorScheme }) => {
      setColorScheme(newColorScheme);
    });

    return () => subscription.remove();
  }, []);

  const setTheme = (newTheme: Theme) => {
    setThemeState(newTheme);
    if (newTheme === 'system') {
      setColorScheme(Appearance.getColorScheme());
    } else {
      setColorScheme(newTheme);
    }
  };

  const isDark = colorScheme === 'dark';

  const themeColors = {
    ...colors,
    background: isDark ? colors.darkGray1 : colors.gray2,
    surface: isDark ? colors.darkGray2 : colors.gray1,
    surfaceSecondary: isDark ? colors.darkGray1 : colors.gray2,
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
        themeColors,
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

export function useThemeColors() {
  const { themeColors, isDark } = useTheme();
  return { themeColors, isDark };
}
