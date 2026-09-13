import { createClient } from '@supabase/supabase-js';
import { cookies } from 'next/headers';

export async function getServerSupabaseClient() {
  const cookieStore = await cookies();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error('Missing Supabase server credentials');
  }

  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      persistSession: false,
    },
  });
}

/**
 * Create a Supabase client that carries the authenticated user's session.
 * Uses the anon key + cookie forwarding so that PostgreSQL auth.uid()
 * resolves to the logged-in user — required for RPC functions that
 * rely on auth.uid() internally (e.g. commit_quest_completion).
 */
export async function getAuthenticatedSupabaseClient() {
  const cookieStore = await cookies();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error('Missing Supabase credentials');
  }

  return createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        cookie: cookieStore.toString(),
      },
    },
  });
}

export async function getUserFromSession() {
  const cookieStore = await cookies();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    return null;
  }

  try {
    const client = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          cookie: cookieStore.toString(),
        },
      },
    });

    const {
      data: { user },
    } = await client.auth.getUser();

    return user;
  } catch {
    return null;
  }
}

/**
 * Call the initialize_user_profile RPC to ensure the authenticated user has
 * all required onboarding data (profiles, characters, character_attributes).
 * Idempotent — safe to call repeatedly; existing data is never overwritten.
 * Returns success/failure and the initialized character ID.
 * Must be called as an authenticated user (auth.uid() is derived server-side).
 */
export async function initializeUserProfile(displayName?: string) {
  try {
    const client = await getAuthenticatedSupabaseClient();
    const { data, error } = await client.rpc('initialize_user_profile', {
      p_display_name: displayName || null,
    });

    if (error) {
      console.error('Failed to initialize user profile:', error);
      return { success: false, error: error.message };
    }

    return { success: true, data };
  } catch (err: any) {
    console.error('Unexpected error initializing user profile:', err);
    return { success: false, error: err.message || 'Unknown error' };
  }
}
