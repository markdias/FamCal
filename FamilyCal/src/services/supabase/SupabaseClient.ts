import { createClient, SupabaseClient, Session, User } from '@supabase/supabase-js';
import Constants from 'expo-constants';

// Supabase configuration
const SUPABASE_URL = Constants.expoConfig?.extra?.supabaseUrl || process.env.SUPABASE_URL || '';
const SUPABASE_ANON_KEY = Constants.expoConfig?.extra?.supabaseAnonKey || process.env.SUPABASE_ANON_KEY || '';

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.warn('Supabase URL or Anon Key not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY in your environment.');
}

// Create Supabase client
export const supabase: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
    storage: typeof window !== 'undefined' ? window.localStorage : undefined,
  },
});

// Session management utilities
export async function getSession(): Promise<Session | null> {
  const { data: { session } } = await supabase.auth.getSession();
  return session;
}

export async function getUser(): Promise<User | null> {
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

export async function refreshSession(): Promise<Session | null> {
  const { data: { session }, error } = await supabase.auth.refreshSession();
  if (error) {
    console.error('Failed to refresh session:', error);
    return null;
  }
  return session;
}

// Auth state subscription
export function subscribeToAuthChanges(
  callback: (event: 'SIGNED_IN' | 'SIGNED_OUT' | 'TOKEN_REFRESHED', session: Session | null) => void
): () => void {
  const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN') {
      callback('SIGNED_IN', session);
    } else if (event === 'SIGNED_OUT') {
      callback('SIGNED_OUT', session);
    } else if (event === 'TOKEN_REFRESHED') {
      callback('TOKEN_REFRESHED', session);
    }
  });

  return () => subscription.unsubscribe();
}

// Error handling wrapper
export async function withErrorHandling<T>(
  operation: () => Promise<T>,
  errorMessage: string = 'An error occurred'
): Promise<{ data: T | null; error: Error | null }> {
  try {
    const result = await operation();
    return { data: result, error: null };
  } catch (error) {
    console.error(errorMessage, error);
    return { data: null, error: error as Error };
  }
}

export default supabase;
