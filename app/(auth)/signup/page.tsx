'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { supabase } from '@/lib/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

export default function SignupPage() {
  const router = useRouter();
  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSignup(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const { data, error: signUpError } = await supabase.auth.signUp({
        email,
        password,
      });

      if (signUpError) {
        setError(signUpError.message);
        return;
      }

      if (!data.user) {
        setError('Failed to create account');
        return;
      }

      const { error: profileError } = await supabase.from('profiles').insert({
        id: data.user.id,
        display_name: displayName,
      });

      if (profileError) {
        setError('Failed to create profile');
        return;
      }

      const { data: charData, error: charError } = await supabase.from('characters').insert({
        user_id: data.user.id,
      }).select().single();

      if (charError || !charData) {
        setError('Failed to create character');
        return;
      }

      const attributes = ['intellect', 'strength', 'focus', 'vitality'];
      const { error: attrError } = await supabase.from('character_attributes').insert(
        attributes.map((attr) => ({
          character_id: charData.id,
          attribute: attr,
          xp: 0,
        }))
      );

      if (attrError) {
        setError('Failed to initialize character');
        return;
      }

      router.push('/dashboard');
    } catch {
      setError('An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Create account</CardTitle>
          <CardDescription>Start leveling up today</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSignup} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">Name</label>
              <input
                type="text"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="Your name"
                className="w-full h-9 rounded-md border border-input bg-card px-3 py-1 text-sm text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                required
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                className="w-full h-9 rounded-md border border-input bg-card px-3 py-1 text-sm text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                required
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full h-9 rounded-md border border-input bg-card px-3 py-1 text-sm text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                required
              />
            </div>
            {error && (
              <p className="text-xs text-destructive">{error}</p>
            )}
            <Button type="submit" disabled={loading} className="w-full">
              {loading ? 'Creating account…' : 'Create account'}
            </Button>
          </form>
          <p className="text-center text-xs text-muted-foreground mt-4">
            Already have an account?{' '}
            <Link href="/login" className="text-primary hover:underline">
              Sign in
            </Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
