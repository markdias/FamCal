import React, { useState } from 'react';
import { View, Text, StyleSheet, Animated } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, typography } from '@/styles/designTokens';
import PermissionsScreen from './PermissionsScreen';
import FamilySetupScreen from './FamilySetupScreen';
import IntroScreen from './IntroScreen';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from '@/utils/storageKeys';
import { useApp } from '@/context/AppContext';

type OnboardingStep = 'intro' | 'permissions' | 'familySetup' | 'complete';

export default function OnboardingFlow() {
  const { colors } = useTheme();
  const { setCurrentFamilyId } = useApp();
  const [currentStep, setCurrentStep] = useState<OnboardingStep>('intro');

  const handleIntroComplete = () => {
    setCurrentStep('permissions');
  };

  const handlePermissionsComplete = async () => {
    setCurrentStep('familySetup');
  };

  const handleFamilySetupComplete = async () => {
    // Mark onboarding as complete
    await AsyncStorage.setItem(STORAGE_KEYS.HAS_COMPLETED_ONBOARDING, 'true');
    setCurrentStep('complete');
  };

  const renderStep = () => {
    switch (currentStep) {
      case 'intro':
        return <IntroScreen onComplete={handleIntroComplete} />;
      case 'permissions':
        return <PermissionsScreen onComplete={handlePermissionsComplete} />;
      case 'familySetup':
        return <FamilySetupScreen onComplete={handleFamilySetupComplete} />;
      case 'complete':
        return null;
      default:
        return null;
    }
  };

  // If complete, return null (parent will navigate away)
  if (currentStep === 'complete') {
    return null;
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      <View style={styles.progressContainer}>
        <View style={styles.progressBar}>
          <Animated.View
            style={[
              styles.progressFill,
              {
                width:
                  currentStep === 'intro'
                    ? '33%'
                    : currentStep === 'permissions'
                    ? '66%'
                    : '100%',
                backgroundColor: colors.primaryAccent,
              },
            ]}
          />
        </View>
        <Text style={[styles.stepIndicator, { color: colors.textSecondary }]}>
          {currentStep === 'intro'
            ? 'Step 1 of 3'
            : currentStep === 'permissions'
            ? 'Step 2 of 3'
            : 'Step 3 of 3'}
        </Text>
      </View>
      {renderStep()}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  progressContainer: {
    paddingHorizontal: spacing.l,
    paddingVertical: spacing.m,
  },
  progressBar: {
    height: 4,
    backgroundColor: '#E5E5EA',
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 2,
  },
  stepIndicator: {
    fontSize: 13,
    marginTop: spacing.xs,
    textAlign: 'center',
  },
});
