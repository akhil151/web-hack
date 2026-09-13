-- 005_signup_onboarding_rls.sql
-- Add narrowly scoped INSERT RLS policies for onboarding tables
-- so newly authenticated users can create their initial profile,
-- character, and character_attributes records.
--
-- Security design:
--   - Only authenticated users (not anon/public) can insert.
--   - Each policy enforces auth.uid() ownership — a user cannot
--     create records belonging to another user.
--   - BEFORE INSERT triggers on `characters` and `character_attributes`
--     force RPG progression fields to safe defaults when the insert
--     originates from a direct client request (role = 'authenticated').
--     SECURITY DEFINER functions (e.g. commit_quest_completion) run as
--     the function owner role, so the triggers do not interfere with
--     server-authoritative RPCs.
--   - Existing SELECT/UPDATE/DELETE policies are not modified.

-- ============================================================
-- 1. PROFILES — INSERT policy
-- ============================================================
-- The profile id must match auth.uid(). A user can only create
-- their own profile row (id = their auth user id).
CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- ============================================================
-- 2. CHARACTERS — INSERT policy + BEFORE INSERT trigger
-- ============================================================
-- The character's user_id must match auth.uid(). A user can only
-- create a character belonging to themselves.
CREATE POLICY "Users can insert their own character"
  ON characters FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Force safe defaults on RPG progression fields during INSERT.
-- Only applies when current_user is 'authenticated' (direct client
-- request via PostgREST). SECURITY DEFINER functions run as the
-- function owner (e.g. postgres), so this trigger passes through
-- their values unchanged — critical for commit_quest_completion
-- which never inserts characters but guards against future changes.
CREATE OR REPLACE FUNCTION enforce_character_defaults()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    NEW.level := 1;
    NEW.total_xp := 0;
    NEW.gold := 0;
    NEW.current_streak := 0;
    NEW.longest_streak := 0;
    NEW.last_active_date := NULL;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_character_defaults
  BEFORE INSERT ON characters
  FOR EACH ROW
  EXECUTE FUNCTION enforce_character_defaults();

-- ============================================================
-- 3. CHARACTER_ATTRIBUTES — INSERT policy + BEFORE INSERT trigger
-- ============================================================
-- A user can only insert attributes for a character they own.
-- The subquery verifies the character's user_id matches auth.uid().
CREATE POLICY "Users can insert attributes for their own character"
  ON character_attributes FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = (SELECT user_id FROM characters WHERE id = character_id)
  );

-- Force xp = 0 on initial attribute creation from client requests.
-- Only applies when current_user is 'authenticated' (direct client
-- request via PostgREST). SECURITY DEFINER functions like
-- commit_quest_completion run as the function owner and may insert
-- with computed xp values via ON CONFLICT upserts — those must
-- pass through unmodified.
CREATE OR REPLACE FUNCTION enforce_attribute_defaults()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    NEW.xp := 0;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_attribute_defaults
  BEFORE INSERT ON character_attributes
  FOR EACH ROW
  EXECUTE FUNCTION enforce_attribute_defaults();
