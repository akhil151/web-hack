'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { supabase } from '@/lib/supabase/client';
import { cn } from '@/lib/utils';

const NAV_ITEMS = [
  { href: '/dashboard', label: 'Dashboard' },
  { href: '/quests', label: 'Quests' },
  { href: '/relics', label: 'Relics' },
  { href: '/character', label: 'Character' },
];

function TopNav() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-40 border-b border-border bg-card/80 backdrop-blur-sm">
      <div className="container-safe flex h-14 items-center justify-between">
        <div className="flex items-center gap-8">
          <Link href="/dashboard" className="text-base font-semibold text-foreground">
            Life RPG
          </Link>
          <nav className="hidden md:flex items-center gap-1">
            {NAV_ITEMS.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  'px-3 py-1.5 text-sm rounded-md transition-colors',
                  pathname === item.href
                    ? 'bg-accent text-accent-foreground font-medium'
                    : 'text-muted-foreground hover:text-foreground hover:bg-secondary'
                )}
              >
                {item.label}
              </Link>
            ))}
          </nav>
        </div>
        <button
          onClick={() => supabase.auth.signOut().then(() => window.location.href = '/login')}
          className="text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          Sign out
        </button>
      </div>
    </header>
  );
}

function BottomNav() {
  const pathname = usePathname();

  const items = [
    { href: '/dashboard', label: 'Home', icon: '⌂' },
    { href: '/quests', label: 'Quests', icon: '✦' },
    { href: '/relics', label: 'Relics', icon: '◆' },
    { href: '/character', label: 'Profile', icon: '●' },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 border-t border-border bg-card md:hidden">
      <div className="flex">
        {items.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              'flex-1 flex flex-col items-center gap-0.5 py-2 text-xs transition-colors',
              pathname === item.href
                ? 'text-primary font-medium'
                : 'text-muted-foreground'
            )}
          >
            <span className="text-base">{item.icon}</span>
            {item.label}
          </Link>
        ))}
      </div>
    </nav>
  );
}

export default function GameNavShell({ children }: { children: React.ReactNode }) {
  return (
    <>
      <TopNav />
      <main className="pb-20 md:pb-0">
        {children}
      </main>
      <BottomNav />
    </>
  );
}
