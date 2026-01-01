import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, KeyboardAvoidingView, Platform } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, typography } from '@/styles/designTokens';
import { Button, Input } from '@/components';
import { useApp } from '@/context/AppContext';

export default function ForgotPasswordScreen() {
  const { colors } = useTheme();
  const { resetPassword } = useApp();
  
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const handleResetPassword = async () => {
    setError('');
    setIsLoading(true);
    setSuccess(false);

    const result = await resetPassword(email);
    
    if (result.error) {
      setError(result.error);
    } else {
      setSuccess(true);
    }
    
    setIsLoading(false);
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      <KeyboardAvoidingView
        style={styles.keyboardAvoid}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <View style={styles.content}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={[styles.title, { color: colors.text }]}>Reset Password</Text>
            <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
              {success
                ? 'Check your email for reset instructions'
                : 'Enter your email to receive reset instructions'}
            </Text>
          </View>

          {/* Success State */}
          {success ? (
            <View style={styles.successContainer}>
              <Text style={[styles.successIcon, { color: colors.success }]}>✓</Text>
              <Text style={[styles.successText, { color: colors.text }]}>
                We've sent password reset instructions to {email}
              </Text>
              <Text style={[styles.successSubtext, { color: colors.textSecondary }]}>
                Please check your inbox and follow the link to reset your password.
              </Text>
            </View>
          ) : (
            /* Form */
            <View style={styles.form}>
              <Input
                label="Email"
                value={email}
                onChangeText={setEmail}
                placeholder="Enter your email"
                keyboardType="email-address"
                autoCapitalize="none"
                autoComplete="email"
              />

              {error ? (
                <Text style={[styles.errorText, { color: colors.error }]}>{error}</Text>
              ) : null}

              <Button
                title="Send Reset Link"
                onPress={handleResetPassword}
                loading={isLoading}
                disabled={!email}
                fullWidth
              />
            </View>
          )}

          {/* Footer */}
          <View style={styles.footer}>
            <Text style={[styles.footerText, { color: colors.textSecondary }]}>
              Remember your password?{' '}
            </Text>
            <TouchableOpacity onPress={() => {}}>
              <Text style={[styles.linkText, { color: colors.primaryAccent }]}>
                Sign In
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  keyboardAvoid: {
    flex: 1,
  },
  content: {
    flex: 1,
    padding: spacing.l,
    justifyContent: 'center',
  },
  header: {
    marginBottom: spacing.xxl,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    marginBottom: spacing.xs,
  },
  subtitle: {
    fontSize: 17,
  },
  form: {
    marginBottom: spacing.m,
  },
  errorText: {
    fontSize: 14,
    marginBottom: spacing.s,
  },
  successContainer: {
    alignItems: 'center',
    paddingVertical: spacing.xxl,
  },
  successIcon: {
    fontSize: 48,
    marginBottom: spacing.m,
  },
  successText: {
    fontSize: 20,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: spacing.s,
  },
  successSubtext: {
    fontSize: 15,
    textAlign: 'center',
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: spacing.xxl,
  },
  footerText: {
    fontSize: 15,
  },
  linkText: {
    fontSize: 15,
    fontWeight: '500',
  },
});
