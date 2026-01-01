// Authentication-related types

import { User } from './index';

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface SignupCredentials extends LoginCredentials {
  name?: string;
}

export interface AuthUser {
  id: string;
  email: string;
  email_confirmed_at: string | null;
  created_at: string;
  updated_at: string;
  user_metadata: Record<string, unknown>;
  app_metadata: Record<string, unknown>;
}

export interface AuthSession {
  user: AuthUser;
  access_token: string;
  refresh_token: string;
  expires_at: number;
}

export interface PasswordResetRequest {
  email: string;
}

export interface UpdatePasswordRequest {
  newPassword: string;
}

export interface GoogleOAuthConfig {
  clientId: string;
  redirectUri: string;
  scopes: string[];
}

export interface TokenRefreshResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
}

export interface AuthError {
  message: string;
  status: number;
  name: string;
}

export interface AuthState {
  user: AuthUser | null;
  session: AuthSession | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  error: AuthError | null;
}

export type AuthEventType = 
  | 'INITIAL_SESSION'
  | 'SIGNED_IN'
  | 'SIGNED_OUT'
  | 'TOKEN_REFRESHED'
  | 'USER_UPDATED'
  | 'PASSWORD_RECOVERY';

export interface AuthEvent {
  type: AuthEventType;
  payload?: unknown;
}

export interface GuestSession {
  id: string;
  createdAt: string;
  isActive: boolean;
}

export const AUTH_ERROR_CODES = {
  INVALID_EMAIL: 'invalid_email',
  INVALID_PASSWORD: 'invalid_password',
  USER_NOT_FOUND: 'user_not_found',
  EMAIL_NOT_CONFIRMED: 'email_not_confirmed',
  INVALID_REFRESH_TOKEN: 'invalid_refresh_token',
  SESSION_EXPIRED: 'session_expired',
  RATE_LIMIT_EXCEEDED: 'rate_limit_exceeded',
  SIGNUP_DISABLED: 'signup_disabled',
  GOOGLE_OAUTH_ERROR: 'google_oauth_error',
} as const;
