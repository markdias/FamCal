import supabase, { withErrorHandling, getSession, refreshSession, subscribeToAuthChanges } from './SupabaseClient';
import { AuthSession, AuthUser, LoginCredentials, SignupCredentials, AuthError } from '@/types/auth';
import * as SecureStore from 'react-native-keychain';
import { STORAGE_KEYS, SECURE_STORAGE_KEYS } from '@/utils/storageKeys';
import AsyncStorage from '@react-native-async-storage/async-storage';

const AUTH_ERRORS: Record<string, string> = {
  'invalid_credentials': 'Invalid email or password',
  'email_not_confirmed': 'Please confirm your email address',
  'user_not_found': 'No account found with this email',
  'invalid_email': 'Please enter a valid email address',
  'weak_password': 'Password is too weak',
  'email_taken': 'An account with this email already exists',
  'session_expired': 'Your session has expired. Please log in again.',
  'rate_limit_exceeded': 'Too many attempts. Please try again later.',
};

export class SupabaseAuthService {
  // Login with email and password
  async login(credentials: LoginCredentials): Promise<{ session: AuthSession | null; error: AuthError | null }> {
    const { data, error } = await withErrorHandling(
      () => supabase.auth.signInWithPassword({
        email: credentials.email,
        password: credentials.password,
      }),
      'Login failed'
    );

    if (error || !data?.user) {
      return {
        session: null,
        error: this.parseAuthError(error),
      };
    }

    const session = this.mapSession(data.session);
    
    // Persist session to SecureStore
    await this.persistSession(session);

    return { session, error: null };
  }

  // Signup with email and password
  async signup(credentials: SignupCredentials): Promise<{ session: AuthSession | null; error: AuthError | null }> {
    const { data, error } = await withErrorHandling(
      () => supabase.auth.signUp({
        email: credentials.email,
        password: credentials.password,
        options: {
          data: {
            name: credentials.name,
          },
        },
      }),
      'Signup failed'
    );

    if (error || !data?.user) {
      return {
        session: null,
        error: this.parseAuthError(error),
      };
    }

    // If email confirmation is required, session may be null
    if (!data.session) {
      return {
        session: null,
        error: null,
      };
    }

    const session = this.mapSession(data.session);
    await this.persistSession(session);

    return { session, error: null };
  }

  // Logout
  async logout(): Promise<{ error: AuthError | null }> {
    const { error } = await withErrorHandling(
      () => supabase.auth.signOut(),
      'Logout failed'
    );

    // Clear stored credentials
    await this.clearSession();

    if (error) {
      return { error: this.parseAuthError(error) };
    }

    return { error: null };
  }

  // Reset password (send reset email)
  async resetPassword(email: string): Promise<{ error: AuthError | null }> {
    const { error } = await withErrorHandling(
      () => supabase.auth.resetPasswordForEmail(email, {
        redirectTo: 'famcal://reset-password',
      }),
      'Password reset failed'
    );

    if (error) {
      return { error: this.parseAuthError(error) };
    }

    return { error: null };
  }

  // Update password (after reset)
  async updatePassword(newPassword: string): Promise<{ error: AuthError | null }> {
    const { error } = await withErrorHandling(
      () => supabase.auth.updateUser({
        password: newPassword,
      }),
      'Password update failed'
    );

    if (error) {
      return { error: this.parseAuthError(error) };
    }

    return { error: null };
  }

  // Google OAuth (web/native)
  async signInWithGoogle(): Promise<{ error: AuthError | null }> {
    const { error } = await withErrorHandling(
      () => supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: 'famcal://auth-callback',
          scopes: ['openid', 'email', 'profile'],
        },
      }),
      'Google sign in failed'
    );

    if (error) {
      return { error: this.parseAuthError(error) };
    }

    return { error: null };
  }

  // Initialize guest mode
  async initGuestMode(): Promise<AuthSession | null> {
    const guestId = `guest_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    
    await AsyncStorage.setItem(STORAGE_KEYS.IS_GUEST_MODE, 'true');
    await AsyncStorage.setItem(STORAGE_KEYS.GUEST_SESSION_ID, guestId);

    return {
      user: {
        id: guestId,
        email: 'guest@famcal.app',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        email_confirmed_at: null,
        user_metadata: {},
        app_metadata: {},
      },
      accessToken: '',
      refreshToken: '',
      expiresAt: 0,
    };
  }

  // Check if session is valid
  async checkSession(): Promise<AuthSession | null> {
    const session = await getSession();
    
    if (!session) {
      // Try to restore from SecureStore
      return await this.restoreSession();
    }

    return this.mapSession(session);
  }

  // Refresh token if needed
  async refreshTokenIfNeeded(): Promise<AuthSession | null> {
    const session = await getSession();
    
    if (!session) return null;

    // Check if token expires within 5 minutes
    const expiresAt = session.expires_at ? session.expires_at * 1000 : 0;
    const now = Date.now();
    
    if (expiresAt - now < 5 * 60 * 1000) {
      return await refreshSession();
    }

    return this.mapSession(session);
  }

  // Subscribe to auth state changes
  subscribe(callback: (event: 'SIGNED_IN' | 'SIGNED_OUT', session: AuthSession | null) => void): () => void {
    return subscribeToAuthChanges((event, session) => {
      if (event === 'SIGNED_IN') {
        callback('SIGNED_IN', session ? this.mapSession(session) : null);
      } else if (event === 'SIGNED_OUT') {
        callback('SIGNED_OUT', null);
      }
    });
  }

  // Persist session to SecureStore
  private async persistSession(session: AuthSession): Promise<void> {
    try {
      await SecureStore.setItemAsync(SECURE_STORAGE_KEYS.AUTH_TOKEN, session.accessToken, {
        accessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
      });
      
      await SecureStore.setItemAsync(SECURE_STORAGE_KEYS.AUTH_REFRESH_TOKEN, session.refreshToken, {
        accessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
      });

      await AsyncStorage.setItem(STORAGE_KEYS.AUTH_TOKEN_EXPIRY, String(session.expiresAt));
      await AsyncStorage.setItem(STORAGE_KEYS.USER_ID, session.user.id);
      await AsyncStorage.setItem(STORAGE_KEYS.USER_EMAIL, session.user.email);
    } catch (error) {
      console.error('Failed to persist session:', error);
    }
  }

  // Restore session from SecureStore
  private async restoreSession(): Promise<AuthSession | null> {
    try {
      const accessToken = await SecureStore.getItemAsync(SECURE_STORAGE_KEYS.AUTH_TOKEN);
      const refreshToken = await SecureStore.getItemAsync(SECURE_STORAGE_KEYS.AUTH_REFRESH_TOKEN);
      
      if (!accessToken || !refreshToken) {
        return null;
      }

      const userId = await AsyncStorage.getItem(STORAGE_KEYS.USER_ID);
      const userEmail = await AsyncStorage.getItem(STORAGE_KEYS.USER_EMAIL);
      const expiresAt = await AsyncStorage.getItem(STORAGE_KEYS.AUTH_TOKEN_EXPIRY);

      return {
        user: {
          id: userId || '',
          email: userEmail || '',
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          email_confirmed_at: null,
          user_metadata: {},
          app_metadata: {},
        },
        accessToken,
        refreshToken,
        expiresAt: expiresAt ? parseInt(expiresAt, 10) : 0,
      };
    } catch (error) {
      console.error('Failed to restore session:', error);
      return null;
    }
  }

  // Clear session from storage
  private async clearSession(): Promise<void> {
    try {
      await SecureStore.deleteItemAsync(SECURE_STORAGE_KEYS.AUTH_TOKEN);
      await SecureStore.deleteItemAsync(SECURE_STORAGE_KEYS.AUTH_REFRESH_TOKEN);
      
      await AsyncStorage.multiRemove([
        STORAGE_KEYS.AUTH_TOKEN_EXPIRY,
        STORAGE_KEYS.USER_ID,
        STORAGE_KEYS.USER_EMAIL,
        STORAGE_KEYS.IS_GUEST_MODE,
        STORAGE_KEYS.GUEST_SESSION_ID,
      ]);
    } catch (error) {
      console.error('Failed to clear session:', error);
    }
  }

  // Map Supabase session to AuthSession
  private mapSession(session: any): AuthSession {
    return {
      user: session.user,
      accessToken: session.access_token,
      refreshToken: session.refresh_token,
      expiresAt: session.expires_at ? session.expires_at * 1000 : 0,
    };
  }

  // Parse auth error
  private parseAuthError(error: any): AuthError {
    if (!error) {
      return { message: 'An unknown error occurred', status: 500, name: 'UnknownError' };
    }

    const message = AUTH_ERRORS[error.message] || error.message || 'An error occurred';
    const status = error.status || 400;
    const name = error.name || 'AuthError';

    return { message, status, name };
  }
}

export const supabaseAuthService = new SupabaseAuthService();
export default supabaseAuthService;
