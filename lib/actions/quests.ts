'use server';

import { getUserFromSession, getServerSupabaseClient, getAuthenticatedSupabaseClient } from '@/lib/supabase/server';
import { createQuestSchema } from '@/lib/validators/quests';
import { getQuestXpReward, getQuestGoldReward } from '@/lib/rpg/progression';
import { revalidatePath } from 'next/cache';
import { Difficulty } from '@/types';

/**
 * Create a new quest
 */
export async function createQuest(input: unknown) {
  const parsed = createQuestSchema.parse(input);
  const user = await getUserFromSession();

  if (!user) {
    throw new Error('Unauthorized');
  }

  const xpReward = getQuestXpReward(parsed.difficulty as Difficulty, 0);
  const goldReward = getQuestGoldReward(parsed.difficulty as Difficulty);

  const supabase = await getServerSupabaseClient();

  const { data, error } = await supabase.from('quests').insert({
    user_id: user.id,
    title: parsed.title,
    description: parsed.description,
    attribute: parsed.attribute,
    difficulty: parsed.difficulty,
    xp_reward: xpReward,
    gold_reward: goldReward,
  });

  if (error) {
    throw new Error(`Failed to create quest: ${error.message}`);
  }

  revalidatePath('/dashboard');
  revalidatePath('/quests');

  return data;
}

/**
 * Complete a quest and award rewards
 * Server-side calculation ensures security.
 * Uses a single RPC call for transaction safety.
 */
export async function completeQuest(questId: string) {
  const user = await getUserFromSession();

  if (!user) {
    throw new Error('Unauthorized');
  }

  const supabase = await getAuthenticatedSupabaseClient();

  // The database RPC is now the source of truth for rewards and security.
  // It relies on auth.uid() internally and calculates all rewards itself.
  const { data, error: rpcError } = await supabase.rpc('commit_quest_completion', {
    p_quest_id: questId,
  });

  if (rpcError) {
    throw new Error(`Failed to complete quest: ${rpcError.message}`);
  }

  revalidatePath('/dashboard');
  revalidatePath('/quests');

  return {
    xpEarned: data.xp_earned,
    goldEarned: data.gold_earned,
    attributeXpEarned: data.attribute_xp_earned,
  };
}

/**
 * Delete a quest (only if not completed)
 */
export async function deleteQuest(questId: string) {
  const user = await getUserFromSession();

  if (!user) {
    throw new Error('Unauthorized');
  }

  const supabase = await getServerSupabaseClient();

  const { data: quest, error: fetchError } = await supabase
    .from('quests')
    .select('*')
    .eq('id', questId)
    .eq('user_id', user.id)
    .single();

  if (fetchError || !quest) {
    throw new Error('Quest not found');
  }

  if (quest.is_completed) {
    throw new Error('Cannot delete completed quest');
  }

  const { error: deleteError } = await supabase.from('quests').delete().eq('id', questId);

  if (deleteError) {
    throw new Error('Failed to delete quest');
  }

  revalidatePath('/quests');

  return { success: true };
}
