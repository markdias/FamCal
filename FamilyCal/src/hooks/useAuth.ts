import { useContext, useState, useEffect, useCallback } from 'react';
import { AuthState, LoginCredentials, SignupCredentials } from '@/types/auth';
import { AppContext } from '@/context/AppContext';

export function useAuth(): AuthState {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useAuth must be used within an AppProvider');
  }
  return context.authState;
}

export function useIsAuthenticated(): boolean {
  const { isAuthenticated } = useAuth();
  return isAuthenticated;
}

export function useIsGuest(): boolean {
  const { isGuest } = useAuth();
  return isGuest;
}

export function useCurrentUser() {
  const { user } = useAuth();
  return user;
}

export function useAuthLoading(): boolean {
  const { isLoading } = useAuth();
  return isLoading;
}

export function useLogin() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useLogin must be used within an AppProvider');
  }
  return context.login;
}

export function useSignup() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useSignup must be used within an AppProvider');
  }
  return context.signup;
}

export function useLogout() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useLogout must be used within an AppProvider');
  }
  return context.logout;
}

export function useResetPassword() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useResetPassword must be used within an AppProvider');
  }
  return context.resetPassword;
}

export function useUpdatePassword() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useUpdatePassword must be used within an AppProvider');
  }
  return context.updatePassword;
}

export function useInitGuestMode() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useInitGuestMode must be used within an AppProvider');
  }
  return context.initGuestMode;
}

export function useRefreshSession() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useRefreshSession must be used within an AppProvider');
  }
  return context.refreshSession;
}
