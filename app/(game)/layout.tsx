import { redirect } from 'next/navigation';
import { getUserFromSession, initializeUserProfile } from '@/lib/supabase/server';
import GameNavShell from '@/components/game/nav-shell';

export const dynamic = 'force-dynamic';

export default async function GameLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await getUserFromSession();

  if (!user) {
    redirect('/login');
  }

  // Ensure the authenticated user has all required onboarding data
  // (profiles, characters, character_attributes).
  // Idempotent; safe to call on every request.
  // If initialization fails, log it but don't block the user—
  // the game pages will handle missing data gracefully.
  await initializeUserProfile();

  return <GameNavShell>{children}</GameNavShell>;
}
