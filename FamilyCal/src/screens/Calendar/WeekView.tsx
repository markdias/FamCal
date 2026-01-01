import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing } from '@/styles/designTokens';

export default function WeekView() {
  const { colors } = useTheme();

  return (
    <View style={styles.container}>
      <Text style={{ color: colors.text }}>Week View</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
