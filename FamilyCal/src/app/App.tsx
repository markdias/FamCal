import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { LogBox } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { ThemeProvider } from '@/context/ThemeContext';
import { AppProvider, useApp } from '@/context/AppContext';
import { RootNavigator } from '@/navigation/RootNavigator';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from '@/utils/storageKeys';
import { LoadingSpinner } from '@/components';
import { View, StyleSheet } from 'react-native';

// Ignore specific warnings
LogBox.ignoreLogs([
  'AsyncStorage has been extracted from react-native',
  'Animated: `useNativeDriver` was not specified',
  'Setting a timer',
]);

// Initial loading screen component
function AppLoader() {
  const { colors } = useTheme();

  return (
    <View style={[styles.loaderContainer, { backgroundColor: colors.background }]}>
      <LoadingSpinner size="large" />
    </View>
  );
}

// Main app content
function AppContent() {
  const { authState } = useApp();
  const [hasCompletedOnboarding, setHasCompletedOnboarding] = useState<boolean | null>(null);

  // Check onboarding status
  useEffect(() => {
    const checkOnboarding = async () => {
      const completed = await AsyncStorage.getItem(STORAGE_KEYS.HAS_COMPLETED_ONBOARDING);
      setHasCompletedOnboarding(completed === 'true');
    };
    checkOnboarding();
  }, []);

  // Show loading while checking
  if (hasCompletedOnboarding === null) {
    return <AppLoader />;
  }

  return <RootNavigator />;
}

// Root app component
export default function App() {
  return (
    <SafeAreaProvider>
      <ThemeProvider>
        <AppProvider>
          <AppContent />
          <StatusBar style="auto" />
        </AppProvider>
      </ThemeProvider>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  loaderContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
