import Link from 'next/link';
import { Button } from '@/components/ui/button';

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-background text-foreground flex flex-col justify-between">
      {/* Navigation */}
      <header className="border-b border-border">
        <div className="container-safe flex h-14 items-center justify-between">
          <span className="text-base font-semibold">Life RPG</span>
          <div className="flex items-center gap-3">
            <Link href="/login">
              <Button variant="ghost" size="sm">Sign in</Button>
            </Link>
            <Link href="/signup">
              <Button size="sm">Get started</Button>
            </Link>
          </div>
        </div>
      </header>

      {/* Hero */}
      <main className="container-safe py-20 sm:py-28 max-w-2xl text-center">
        <p className="text-sm font-medium text-primary mb-3">Productivity meets progression</p>
        <h1 className="text-4xl sm:text-5xl font-bold tracking-tight text-foreground mb-4">
          Turn your daily tasks into experience points.
        </h1>
        <p className="text-base sm:text-lg text-muted-foreground mb-8 max-w-lg mx-auto">
          Create tasks, build streaks, and level up your character as you get things done in the real world.
        </p>
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <Link href="/signup">
            <Button size="lg" className="w-full sm:w-auto">Start today</Button>
          </Link>
          <Link href="/login">
            <Button size="lg" variant="outline" className="w-full sm:w-auto">Sign in</Button>
          </Link>
        </div>

        {/* Feature list */}
        <div className="mt-20 grid sm:grid-cols-3 gap-6 text-left border-t border-border pt-12">
          <div>
            <p className="text-sm font-semibold text-foreground mb-1">Quests</p>
            <p className="text-xs text-muted-foreground">Break goals into difficulty-rated tasks tied to real attributes.</p>
          </div>
          <div>
            <p className="text-sm font-semibold text-foreground mb-1">Progression</p>
            <p className="text-xs text-muted-foreground">Earn XP, level up on an escalating curve, and track streaks.</p>
          </div>
          <div>
            <p className="text-sm font-semibold text-foreground mb-1">Rewards</p>
            <p className="text-xs text-muted-foreground">Earn gold from completions to unlock relics in the shop.</p>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-border py-6 text-center text-xs text-muted-foreground">
        <p>Life RPG</p>
      </footer>
    </div>
  );
}
