-- 006_security_hardening.sql
-- Hardening Row Level Security (RLS) and database triggers for authoritative state integrity.
--
-- Why this migration exists:
--   Migration 001_init.sql defined overly permissive UPDATE policies:
--     1. characters: "Users can update their own character" allowed authenticated clients
--        to directly modify authoritative progression fields (level, total_xp, gold,
--        current_streak, longest_streak, last_active_date) via PostgREST.
--     2. quests: "Users can update their own quests" allowed authenticated clients
--        to modify authoritative completion and reward fields (is_completed, completed_at,
--        xp_reward, gold_reward, user_id).
--
-- Security model after 006:
--   - CHARACTERS: Direct client UPDATE is completely revoked. Character progression,
--     gold, level, and streaks can ONLY be modified through authorized SECURITY DEFINER
--     RPCs (commit_quest_completion, purchase_relic).
--   - QUESTS: Users can only update/delete their own ACTIVE (uncompleted) quests.
--     Direct client UPDATE cannot modify completion status (is_completed, completed_at),
--     ownership (user_id), or fabricate rewards (xp_reward, gold_reward). Quest completion
--     is strictly guarded and must occur through commit_quest_completion().
--   - PROFILES: UPDATE policy is hardened with explicit role and WITH CHECK constraints.
--   - RPC COMPATIBILITY: SECURITY DEFINER functions run with function owner privileges
--     and retain full authority to execute atomic progression and economy updates.

-- ============================================================
-- 1. CHARACTERS — Revoke direct client UPDATE
-- ============================================================

-- Drop the insecure update policy from 001
DROP POLICY IF EXISTS "Users can update their own character" ON characters;

-- Defense-in-depth trigger: Reject any direct client UPDATE on characters
CREATE OR REPLACE FUNCTION enforce_character_update_restrictions()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    RAISE EXCEPTION 'Direct client updates to character progression are forbidden. Progression is managed exclusively via authorized game actions.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_character_update_restrictions ON characters;
CREATE TRIGGER trg_enforce_character_update_restrictions
  BEFORE UPDATE ON characters
  FOR EACH ROW
  EXECUTE FUNCTION enforce_character_update_restrictions();

-- ============================================================
-- 2. QUESTS — Restrict INSERT, UPDATE, and DELETE policies & enforce triggers
-- ============================================================

-- Replace 001 INSERT policy with explicit authenticated role policy
DROP POLICY IF EXISTS "Users can create quests" ON quests;
DROP POLICY IF EXISTS "Users can create their own quests" ON quests;

CREATE POLICY "Users can create their own quests"
  ON quests FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Enforce authoritative reward calculation and initial state on direct client INSERT
CREATE OR REPLACE FUNCTION enforce_quest_insert_defaults()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    -- Ensure quests start active
    NEW.is_completed := false;
    NEW.completed_at := NULL;
    NEW.created_at := coalesce(NEW.created_at, now());

    -- Authoritatively assign rewards based on difficulty
    CASE NEW.difficulty
      WHEN 'trivial' THEN
        NEW.xp_reward := 25;
        NEW.gold_reward := 5;
      WHEN 'easy' THEN
        NEW.xp_reward := 50;
        NEW.gold_reward := 10;
      WHEN 'medium' THEN
        NEW.xp_reward := 100;
        NEW.gold_reward := 25;
      WHEN 'hard' THEN
        NEW.xp_reward := 200;
        NEW.gold_reward := 50;
      WHEN 'epic' THEN
        NEW.xp_reward := 500;
        NEW.gold_reward := 150;
      ELSE
        RAISE EXCEPTION 'Invalid quest difficulty: %', NEW.difficulty;
    END CASE;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_quest_insert_defaults ON quests;
CREATE TRIGGER trg_enforce_quest_insert_defaults
  BEFORE INSERT ON quests
  FOR EACH ROW
  EXECUTE FUNCTION enforce_quest_insert_defaults();

-- Replace 001 UPDATE policy with hardened active-quest update policy
DROP POLICY IF EXISTS "Users can update their own quests" ON quests;
DROP POLICY IF EXISTS "Users can update their own active quests" ON quests;

CREATE POLICY "Users can update their own active quests"
  ON quests FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id AND is_completed = false)
  WITH CHECK (auth.uid() = user_id AND is_completed = false);

-- Enforce update restrictions: protect authoritative completion and reward fields on client UPDATE
CREATE OR REPLACE FUNCTION enforce_quest_update_restrictions()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    -- Prevent changing ownership, id, or creation timestamp
    NEW.id := OLD.id;
    NEW.user_id := OLD.user_id;
    NEW.created_at := OLD.created_at;

    -- Prevent marking quest complete via direct client UPDATE
    -- (Completion must be executed via the commit_quest_completion RPC)
    NEW.is_completed := OLD.is_completed;
    NEW.completed_at := OLD.completed_at;

    -- Synchronize rewards if difficulty is updated, or preserve existing rewards
    IF NEW.difficulty IS DISTINCT FROM OLD.difficulty THEN
      CASE NEW.difficulty
        WHEN 'trivial' THEN
          NEW.xp_reward := 25;
          NEW.gold_reward := 5;
        WHEN 'easy' THEN
          NEW.xp_reward := 50;
          NEW.gold_reward := 10;
        WHEN 'medium' THEN
          NEW.xp_reward := 100;
          NEW.gold_reward := 25;
        WHEN 'hard' THEN
          NEW.xp_reward := 200;
          NEW.gold_reward := 50;
        WHEN 'epic' THEN
          NEW.xp_reward := 500;
          NEW.gold_reward := 150;
        ELSE
          RAISE EXCEPTION 'Invalid quest difficulty: %', NEW.difficulty;
      END CASE;
    ELSE
      NEW.xp_reward := OLD.xp_reward;
      NEW.gold_reward := OLD.gold_reward;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_quest_update_restrictions ON quests;
CREATE TRIGGER trg_enforce_quest_update_restrictions
  BEFORE UPDATE ON quests
  FOR EACH ROW
  EXECUTE FUNCTION enforce_quest_update_restrictions();

-- Replace 001 DELETE policy with active-quest delete policy
DROP POLICY IF EXISTS "Users can delete their own quests" ON quests;
DROP POLICY IF EXISTS "Users can delete their own active quests" ON quests;

CREATE POLICY "Users can delete their own active quests"
  ON quests FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id AND is_completed = false);

-- ============================================================
-- 3. PROFILES — Harden UPDATE policy with explicit role and WITH CHECK
-- ============================================================

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
