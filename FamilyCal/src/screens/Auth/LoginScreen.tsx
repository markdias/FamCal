import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, KeyboardAvoidingView, Platform } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, typography } from '@/styles/designTokens';
import { Button, Input } from '@/components';
import { useApp } from '@/context/AppContext';

export default function LoginScreen() {
  const { colors } = useTheme();
  const { login } = useApp();
  
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleLogin = async () => {
    setError('');
    setIsLoading(true);

    const result = await login({ email, password });
    
    if (result.error) {
      setError(result.error);
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
            <Text style={[styles.title, { color: colors.text }]}>Welcome Back</Text>
            <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
              Sign in to continue
            </Text>
          </View>

          {/* Form */}
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

            <Input
              label="Password"
              value={password}
              onChangeText={setPassword}
              placeholder="Enter your password"
              secureTextEntry
            />

            {error ? (
              <Text style={[styles.errorText, { color: colors.error }]}>{error}</Text>
            ) : null}

            <TouchableOpacity style={styles.forgotPassword}>
              <Text style={[styles.linkText, { color: colors.primaryAccent }]}>
                Forgot Password?
              </Text>
            </TouchableOpacity>

            <Button
              title="Sign In"
              onPress={handleLogin}
              loading={isLoading}
              disabled={!email || !password}
              fullWidth
            />
          </View>

          {/* Footer */}
          <View style={styles.footer}>
            <Text style={[styles.footerText, { color: colors.textSecondary }]}>
              Don't have an account?{' '}
            </Text>
            <TouchableOpacity onPress={() => {}}>
              <Text style={[styles.linkText, { color: colors.primaryAccent }]}>
                Sign Up
              </Text>
            </TouchableOpacity>
          </View>

          {/* Divider */}
          <View style={styles.divider}>
            <View style={[styles.dividerLine, { backgroundColor: colors.border }]} />
            <Text style={[styles.dividerText, { color: colors.textTertiary }]}>or</Text>
            <View style={[styles.dividerLine, { backgroundColor: colors.border }]} />
          </View>

          {/* Social Login */}
          <View style={styles.socialButtons}>
            <Button
              title="Continue with Google"
              variant="outline"
              fullWidth
              onPress={() => {}}
            />
          </View>

          {/* Guest Mode */}
            <TouchableOpacity style={styles.guestMode} onPress={() => {}}>
              <Text style={[styles.guestText, { color: colors.textSecondary }]}>
                Continue as Guest
              </Text>
            </TouchableOpacity>
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
    marginBottom: spacing.l,
  },
  errorText: {
    fontSize: 14,
    marginBottom: spacing.s,
  },
  forgotPassword: {
    alignSelf: 'flex-end',
    marginBottom: spacing.l,
  },
  linkText: {
    fontSize: 14,
    fontWeight: '500',
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: spacing.m,
  },
  footerText: {
    fontSize: 15,
  },
  divider: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: spacing.l,
  },
  dividerLine: {
    flex: 1,
    height: 1,
  },
  dividerText: {
    paddingHorizontal: spacing.m,
    fontSize: 14,
  },
  socialButtons: {
    gap: spacing.s,
  },
  guestMode: {
    marginTop: spacing.l,
    alignItems: 'center',
  },
  guestText: {
    fontSize: 14,
    textDecorationLine: 'underline',
  },
});
