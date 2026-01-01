import React, { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import { User } from '@/types';
import { AuthSession, AuthState, LoginCredentials, SignupCredentials } from '@/types/auth';
import supabaseAuthService from '@/services/supabase/SupabaseAuthService';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from '@/utils/storageKeys';

interface AppContextType {
  // Auth state
  authState: AuthState;
  login: (credentials: LoginCredentials) => Promise<{ success: boolean; error?: string }>;
  signup: (credentials: SignupCredentials) => Promise<{ success: boolean; error?: string }>;
  logout: () => Promise<void>;
  resetPassword: (email: string) => Promise<{ success: boolean; error?: string }>;
  updatePassword: (newPassword: string) => Promise<{ success: boolean; error?: string }>;
  initGuestMode: () => Promise<void>;
  refreshSession: () => Promise<void>;

  // Family state
  currentFamilyId: string | null;
  setCurrentFamilyId: (familyId: string | null) => Promise<void>;
  
  // Loading state
  isLoading: boolean;
  setIsLoading: (loading: boolean) => void;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

interface AppProviderProps {
  children: ReactNode;
}

export function AppProvider({ children }: AppProviderProps) {
  // Auth state
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    isLoading: true,
    user: null,
    accessToken: null,
    isGuest: false,
  });

  // Family state
  const [currentFamilyId, setCurrentFamilyIdState] = useState<string | null>(null);

  // Loading state
  const [isLoading, setIsLoading] = useState(false);

  // Initialize app on mount
  useEffect(() => {
    initializeApp();
  }, []);

  // Subscribe to auth changes
  useEffect(() => {
    const unsubscribe = supabaseAuthService.subscribe((event, session) => {
      if (event === 'SIGNED_OUT') {
        setAuthState(prev => ({
          ...prev,
          isAuthenticated: false,
          isLoading: false,
          user: null,
          accessToken: null,
        }));
      } else if (event === 'SIGNED_IN' && session) {
        setAuthState(prev => ({
          ...prev,
          isAuthenticated: true,
          isLoading: false,
          user: session.user,
          accessToken: session.accessToken,
          isGuest: false,
        }));
      }
    });

    return () => unsubscribe();
  }, []);

  // Initialize app
  const initializeApp = async () => {
    try {
      setAuthState(prev => ({ ...prev, isLoading: true }));

      // Check for existing session
      const session = await supabaseAuthService.checkSession();

      if (session) {
        // Check if it's a guest session
        const isGuest = await AsyncStorage.getItem(STORAGE_KEYS.IS_GUEST_MODE);
        
        setAuthState({
          isAuthenticated: true,
          isLoading: false,
          user: session.user,
          accessToken: session.accessToken,
          isGuest: isGuest === 'true',
        });
      } else {
        // No session found
        setAuthState({
          isAuthenticated: false,
          isLoading: false,
          user: null,
          accessToken: null,
          isGuest: false,
        });
      }

      // Load family ID
      const familyId = await AsyncStorage.getItem(STORAGE_KEYS.FAMILY_ID);
      setCurrentFamilyIdState(familyId);
    } catch (error) {
      console.error('Failed to initialize app:', error);
      setAuthState(prev => ({
        ...prev,
        isLoading: false,
      }));
    }
  };

  // Login
  const login = useCallback(async (credentials: LoginCredentials) => {
    try {
      setIsLoading(true);
      const { session, error } = await supabaseAuthService.login(credentials);

      if (error) {
        return { success: false, error: error.message };
      }

      if (session) {
        setAuthState({
          isAuthenticated: true,
          isLoading: false,
          user: session.user,
          accessToken: session.accessToken,
          isGuest: false,
        });
        return { success: true };
      }

      return { success: false, error: 'No session returned' };
    } catch (error) {
      console.error('Login error:', error);
      return { success: false, error: 'An unexpected error occurred' };
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Signup
  const signup = useCallback(async (credentials: SignupCredentials) => {
    try {
      setIsLoading(true);
      const { session, error } = await supabaseAuthService.signup(credentials);

      if (error) {
        return { success: false, error: error.message };
      }

      // If no session (email confirmation required), return success
      if (!session) {
        setIsLoading(false);
        return { success: true, error: 'Please check your email to confirm your account' };
      }

      setAuthState({
        isAuthenticated: true,
        isLoading: false,
        user: session.user,
        accessToken: session.accessToken,
        isGuest: false,
      });

      return { success: true };
    } catch (error) {
      console.error('Signup error:', error);
      return { success: false, error: 'An unexpected error occurred' };
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Logout
  const logout = useCallback(async () => {
    try {
      setIsLoading(true);
      await supabaseAuthService.logout();
      
      setAuthState({
        isAuthenticated: false,
        isLoading: false,
        user: null,
        accessToken: null,
        isGuest: false,
      });
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Reset password
  const resetPassword = useCallback(async (email: string) => {
    try {
      setIsLoading(true);
      const { error } = await supabaseAuthService.resetPassword(email);

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true };
    } catch (error) {
      console.error('Reset password error:', error);
      return { success: false, error: 'An unexpected error occurred' };
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Update password
  const updatePassword = useCallback(async (newPassword: string) => {
    try {
      setIsLoading(true);
      const { error } = await supabaseAuthService.updatePassword(newPassword);

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true };
    } catch (error) {
      console.error('Update password error:', error);
      return { success: false, error: 'An unexpected error occurred' };
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Initialize guest mode
  const initGuestMode = useCallback(async () => {
    try {
      setIsLoading(true);
      await supabaseAuthService.initGuestMode();

      setAuthState({
        isAuthenticated: true,
        isLoading: false,
        user: {
          id: 'guest',
          email: 'guest@famcal.app',
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          email_confirmed_at: null,
          user_metadata: {},
          app_metadata: {},
        },
        accessToken: '',
        isGuest: true,
      });
    } catch (error) {
      console.error('Guest mode error:', error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Refresh session
  const refreshSession = useCallback(async () => {
    try {
      await supabaseAuthService.refreshTokenIfNeeded();
    } catch (error) {
      console.error('Refresh session error:', error);
    }
  }, []);

  // Set current family ID
  const setCurrentFamilyId = useCallback(async (familyId: string | null) => {
    setCurrentFamilyIdState(familyId);
    
    if (familyId) {
      await AsyncStorage.setItem(STORAGE_KEYS.FAMILY_ID, familyId);
    } else {
      await AsyncStorage.removeItem(STORAGE_KEYS.FAMILY_ID);
    }
  }, []);

  return (
    <AppContext.Provider
      value={{
        authState,
        login,
        signup,
        logout,
        resetPassword,
        updatePassword,
        initGuestMode,
        refreshSession,
        currentFamilyId,
        setCurrentFamilyId,
        isLoading,
        setIsLoading,
      }}
    >
      {children}
    </AppContext.Provider>
  );
}

export function useApp(): AppContextType {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
}

export function useAuth(): AuthState {
  const { authState } = useApp();
  return authState;
}

export function useIsAuthenticated(): boolean {
  const { authState } = useApp();
  return authState.isAuthenticated;
}

export function useIsGuest(): boolean {
  const { authState } = useApp();
  return authState.isGuest;
}

export function useCurrentUser(): User | null {
  const { authState } = useApp();
  return authState.user;
}

export default AppContext;
