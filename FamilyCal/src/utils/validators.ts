// Validation utilities for form inputs

import { VALIDATION } from './constants';

export interface ValidationResult {
  isValid: boolean;
  error?: string;
}

export function validateEmail(email: string): ValidationResult {
  if (!email || email.trim().length === 0) {
    return { isValid: false, error: 'Email is required' };
  }
  
  if (!VALIDATION.EMAIL_REGEX.test(email)) {
    return { isValid: false, error: 'Please enter a valid email address' };
  }
  
  return { isValid: true };
}

export function validatePassword(password: string): ValidationResult {
  if (!password || password.length === 0) {
    return { isValid: false, error: 'Password is required' };
  }
  
  if (password.length < VALIDATION.PASSWORD_MIN_LENGTH) {
    return { isValid: false, error: `Password must be at least ${VALIDATION.PASSWORD_MIN_LENGTH} characters` };
  }
  
  return { isValid: true };
}

export function validateNewPassword(password: string): ValidationResult {
  if (!password || password.length === 0) {
    return { isValid: false, error: 'Password is required' };
  }
  
  if (password.length < VALIDATION.PASSWORD_MIN_LENGTH) {
    return { isValid: false, error: `Password must be at least ${VALIDATION.PASSWORD_MIN_LENGTH} characters` };
  }
  
  const hasUpperCase = /[A-Z]/.test(password);
  const hasLowerCase = /[a-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  
  if (!hasUpperCase || !hasLowerCase || !hasNumber) {
    return {
      isValid: false,
      error: 'Password must contain uppercase, lowercase, and numbers',
    };
  }
  
  return { isValid: true };
}

export function validateConfirmPassword(password: string, confirmPassword: string): ValidationResult {
  if (!confirmPassword || confirmPassword.length === 0) {
    return { isValid: false, error: 'Please confirm your password' };
  }
  
  if (password !== confirmPassword) {
    return { isValid: false, error: 'Passwords do not match' };
  }
  
  return { isValid: true };
}

export function validateName(name: string, fieldName: string = 'Name'): ValidationResult {
  if (!name || name.trim().length === 0) {
    return { isValid: false, error: `${fieldName} is required` };
  }
  
  if (name.trim().length < VALIDATION.NAME_MIN_LENGTH) {
    return { isValid: false, error: `${fieldName} must be at least ${VALIDATION.NAME_MIN_LENGTH} character(s)` };
  }
  
  if (name.trim().length > VALIDATION.NAME_MAX_LENGTH) {
    return { isValid: false, error: `${fieldName} cannot exceed ${VALIDATION.NAME_MAX_LENGTH} characters` };
  }
  
  return { isValid: true };
}

export function validateTitle(title: string): ValidationResult {
  if (!title || title.trim().length === 0) {
    return { isValid: false, error: 'Title is required' };
  }
  
  if (title.trim().length > 100) {
    return { isValid: false, error: 'Title cannot exceed 100 characters' };
  }
  
  return { isValid: true };
}

export function validateRequired(value: unknown, fieldName: string): ValidationResult {
  if (value === null || value === undefined || value === '') {
    return { isValid: false, error: `${fieldName} is required` };
  }
  
  if (typeof value === 'string' && value.trim().length === 0) {
    return { isValid: false, error: `${fieldName} is required` };
  }
  
  return { isValid: true };
}

export function validateDateRange(startDate: Date, endDate: Date): ValidationResult {
  if (startDate > endDate) {
    return { isValid: false, error: 'End date must be after start date' };
  }
  
  return { isValid: true };
}

export function validateArrayNotEmpty(array: unknown[], fieldName: string): ValidationResult {
  if (!array || array.length === 0) {
    return { isValid: false, error: `At least one ${fieldName.toLowerCase()} is required` };
  }
  
  return { isValid: true };
}

export function validateUrl(url: string): ValidationResult {
  if (!url || url.trim().length === 0) {
    return { isValid: false, error: 'URL is required' };
  }
  
  try {
    new URL(url);
    return { isValid: true };
  } catch {
    return { isValid: false, error: 'Please enter a valid URL' };
  }
}

export function validatePhone(phone: string): ValidationResult {
  if (!phone || phone.trim().length === 0) {
    return { isValid: false, error: 'Phone number is required' };
  }
  
  const phoneRegex = /^[+]?[(]?[0-9]{1,3}[)]?[-\s.]?[(]?[0-9]{1,4}[)]?[-\s.]?[0-9]{1,4}[-\s.]?[0-9]{1,9}$/;
  if (!phoneRegex.test(phone.trim())) {
    return { isValid: false, error: 'Please enter a valid phone number' };
  }
  
  return { isValid: true };
}

export function combineValidators(
  ...validators: Array<() => ValidationResult>
): ValidationResult {
  for (const validator of validators) {
    const result = validator();
    if (!result.isValid) {
      return result;
    }
  }
  return { isValid: true };
}

export function sanitizeInput(input: string): string {
  return input
    .trim()
    .replace(/[<>]/g, '')
    .substring(0, 1000);
}

export function sanitizeSearchQuery(query: string): string {
  return query
    .trim()
    .replace(/[<>\\\/]/g, '')
    .substring(0, 200);
}
