import React, { useState, useCallback } from 'react';
import {
  View,
  TextInput,
  Text,
  StyleSheet,
  StyleProp,
  TextStyle,
  ViewStyle,
  TextInputProps,
  TouchableOpacity,
} from 'react-native';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, typography } from '@/styles/designTokens';

interface InputProps extends Omit<TextInputProps, 'style'> {
  label?: string;
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  error?: string;
  secureTextEntry?: boolean;
  style?: StyleProp<ViewStyle>;
  inputStyle?: StyleProp<TextStyle>;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  onRightIconPress?: () => void;
  disabled?: boolean;
  multiline?: boolean;
  maxLength?: number;
  keyboardType?: TextInputProps['keyboardType'];
  autoCapitalize?: TextInputProps['autoCapitalize'];
  autoComplete?: TextInputProps['autoComplete'];
}

export default function Input({
  label,
  value,
  onChangeText,
  placeholder,
  error,
  secureTextEntry = false,
  style,
  inputStyle,
  leftIcon,
  rightIcon,
  onRightIconPress,
  disabled = false,
  multiline = false,
  maxLength,
  keyboardType,
  autoCapitalize = 'none',
  autoComplete,
}: InputProps) {
  const { colors } = useTheme();
  const [isFocused, setIsFocused] = useState(false);
  const [showPassword, setShowPassword] = useState(secureTextEntry);

  const handleFocus = useCallback(() => setIsFocused(true), []);
  const handleBlur = useCallback(() => setIsFocused(false), []);

  const containerStyle = [
    styles.container,
    isFocused && styles.focusedContainer,
    error && styles.errorContainer,
    disabled && styles.disabledContainer,
    style,
  ];

  const inputContainerStyle = [
    styles.inputContainer,
    leftIcon && styles.inputWithIcon,
    (rightIcon || secureTextEntry) && styles.inputWithIcon,
    multiline && styles.multilineInput,
  ];

  const inputStyleText = [
    styles.input,
    { color: colors.text },
    disabled && { color: colors.textTertiary },
    inputStyle,
  ];

  return (
    <View style={containerStyle}>
      {label && (
        <Text style={[styles.label, { color: colors.textSecondary }]}>
          {label}
        </Text>
      )}
      
      <View style={inputContainerStyle}>
        {leftIcon && <View style={styles.iconLeft}>{leftIcon}</View>}
        
        <TextInput
          style={inputStyleText}
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={colors.textTertiary}
          secureTextEntry={showPassword}
          onFocus={handleFocus}
          onBlur={handleBlur}
          disabled={disabled}
          multiline={multiline}
          maxLength={maxLength}
          keyboardType={keyboardType}
          autoCapitalize={autoCapitalize}
          autoComplete={autoComplete}
        />

        {(rightIcon || secureTextEntry) && (
          <TouchableOpacity
            style={styles.iconRight}
            onPress={secureTextEntry ? () => setShowPassword(!showPassword) : onRightIconPress}
            disabled={!secureTextEntry && !onRightIconPress}
          >
            {secureTextEntry ? (
              <Text style={{ color: colors.textSecondary }}>
                {showPassword ? 'Hide' : 'Show'}
              </Text>
            ) : (
              rightIcon
            )}
          </TouchableOpacity>
        )}
      </View>

      {error && (
        <Text style={[styles.errorText, { color: colors.error }]}>
          {error}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginBottom: spacing.m,
  },
  focusedContainer: {
    // Could add focus ring style here
  },
  errorContainer: {
    // Could add error border style here
  },
  disabledContainer: {
    opacity: 0.6,
  },
  label: {
    fontSize: 13,
    fontWeight: '500',
    marginBottom: spacing.xs,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F2F2F7',
    borderRadius: borderRadius.m,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  inputWithIcon: {
    paddingLeft: spacing.s,
  },
  multilineInput: {
    minHeight: 100,
    textAlignVertical: 'top',
    paddingTop: spacing.s,
  },
  input: {
    flex: 1,
    paddingHorizontal: spacing.m,
    paddingVertical: spacing.s,
    fontSize: 17,
    ...typography.body,
  },
  iconLeft: {
    paddingLeft: spacing.m,
  },
  iconRight: {
    paddingRight: spacing.m,
  },
  errorText: {
    fontSize: 12,
    marginTop: spacing.xxs,
    marginLeft: spacing.xs,
  },
});
