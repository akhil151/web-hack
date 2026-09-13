-- 007_initialize_user_onboarding.sql
-- Idempotent server-authoritative user onboarding initializer.
--
-- Why this migration exists:
--   The application's onboarding flow currently requires that profiles, characters,
--   and character_attributes be created during signup (/signup page). However:
--   1. Supabase Auth email sending has rate limits, blocking signup flows.
--   2. Users created outside /signup (e.g., via Dashboard) cannot use the application
--      because the game pages expect these records to exist and hang indefinitely.
--   3. We need a robust, idempotent initializer that auto-provisions missing data
--      for any authenticated user, without overwriting existing state.
--
-- Security model:
--   - The RPC uses SECURITY DEFINER to bypass RLS during initialization.
--   - It derives user identity exclusively from auth.uid() — no client-provided user_id.
--   - It includes explicit auth.uid() IS NULL rejection to prevent execution by
--     unauthenticated roles.
--   - Execution is restricted to the authenticated role only.
--   - Fixed search_path = public prevents schema injection.
--   - Idempotent: all INSERT operations use ON CONFLICT DO NOTHING to avoid duplicates.
--
-- Behavior:
--   For the authenticated user (auth.uid()):
--   1. Ensure a profiles row exists with a display name (default "Adventurer" if not provided).
--   2. Ensure a characters row exists with legitimate schema defaults.
--   3. Ensure all four character_attributes rows exist (intellect, strength, focus, vitality).
--   All operations are idempotent; existing correct data is never modified.

-- ============================================================
-- Create the initialize_user_profile() RPC
-- ============================================================

CREATE OR REPLACE FUNCTION initialize_user_profile(p_display_name text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_display_name text;
  v_character_id uuid;
  v_result json;
BEGIN
  -- Explicitly reject unauthenticated execution
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated access denied. Call this function only as an authenticated user.';
  END IF;

  -- Sanitize and default the display name
  v_display_name := COALESCE(
    NULLIF(TRIM(p_display_name), ''),
    'Adventurer'
  );

  -- Ensure display name is reasonably short (max 50 chars for safety)
  IF LENGTH(v_display_name) > 50 THEN
    v_display_name := SUBSTRING(v_display_name FROM 1 FOR 50);
  END IF;

  -- 1. Idempotently ensure a profiles row exists
  INSERT INTO profiles (id, display_name, created_at)
  VALUES (v_user_id, v_display_name, now())
  ON CONFLICT (id) DO NOTHING;

  -- 2. Idempotently ensure a characters row exists
  INSERT INTO characters (id, user_id, level, total_xp, gold, current_streak, longest_streak, last_active_date, created_at)
  VALUES (gen_random_uuid(), v_user_id, 1, 0, 0, 0, 0, NULL, now())
  ON CONFLICT (user_id) DO NOTHING;

  -- Fetch the character ID for the next step (it may have been created now or existed already)
  SELECT id INTO v_character_id FROM characters WHERE user_id = v_user_id;

  -- 3. Idempotently ensure all four character_attributes rows exist
  INSERT INTO character_attributes (id, character_id, attribute, xp)
  VALUES
    (gen_random_uuid(), v_character_id, 'intellect', 0),
    (gen_random_uuid(), v_character_id, 'strength', 0),
    (gen_random_uuid(), v_character_id, 'focus', 0),
    (gen_random_uuid(), v_character_id, 'vitality', 0)
  ON CONFLICT (character_id, attribute) DO NOTHING;

  -- Return success
  v_result := json_build_object(
    'success', true,
    'user_id', v_user_id,
    'display_name', v_display_name,
    'character_id', v_character_id
  );

  RETURN v_result;
END;
$$;

-- ============================================================
-- Grant execution to authenticated role only
-- ============================================================

-- Revoke default PUBLIC execution
REVOKE EXECUTE ON FUNCTION initialize_user_profile(text) FROM PUBLIC;

-- Grant only to authenticated users
GRANT EXECUTE ON FUNCTION initialize_user_profile(text) TO authenticated;
