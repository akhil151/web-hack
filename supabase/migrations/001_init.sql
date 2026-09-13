-- Profiles (linked to auth.users)
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  created_at timestamp with time zone default now()
);

alter table profiles enable row level security;

create policy "Users can view their own profile"
  on profiles for select
  using (auth.uid() = id);

create policy "Users can update their own profile"
  on profiles for update
  using (auth.uid() = id);

-- Characters
create table characters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  level int default 1 check (level >= 1),
  total_xp int default 0 check (total_xp >= 0),
  gold int default 0 check (gold >= 0),
  current_streak int default 0,
  longest_streak int default 0,
  last_active_date date,
  created_at timestamp with time zone default now(),
  unique(user_id)
);

alter table characters enable row level security;

create policy "Users can view their own character"
  on characters for select
  using (auth.uid() = user_id);

create policy "Users can update their own character"
  on characters for update
  using (auth.uid() = user_id);

-- Character Attributes
create table character_attributes (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references characters(id) on delete cascade,
  attribute text not null check (attribute in ('intellect', 'strength', 'focus', 'vitality')),
  xp int default 0 check (xp >= 0),
  unique(character_id, attribute)
);

alter table character_attributes enable row level security;

create policy "Users can view their own attributes"
  on character_attributes for select
  using (auth.uid() = (select user_id from characters where id = character_id));

-- Quests
create table quests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  description text default '',
  attribute text not null check (attribute in ('intellect', 'strength', 'focus', 'vitality')),
  difficulty text not null check (difficulty in ('trivial', 'easy', 'medium', 'hard', 'epic')),
  xp_reward int not null,
  gold_reward int not null,
  is_completed boolean default false,
  created_at timestamp with time zone default now(),
  completed_at timestamp with time zone
);

alter table quests enable row level security;

create policy "Users can view their own quests"
  on quests for select
  using (auth.uid() = user_id);

create policy "Users can create quests"
  on quests for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own quests"
  on quests for update
  using (auth.uid() = user_id);

create policy "Users can delete their own quests"
  on quests for delete
  using (auth.uid() = user_id);

-- Quest Completions (audit trail)
create table quest_completions (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references quests(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  xp_earned int not null,
  gold_earned int not null,
  attribute_xp_earned int not null,
  completed_at timestamp with time zone default now()
);

alter table quest_completions enable row level security;

create policy "Users can view their own completions"
  on quest_completions for select
  using (auth.uid() = user_id);

-- Relics (rewards shop items)
create table relics (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  category text,
  cost int not null check (cost > 0),
  icon text,
  rarity text not null check (rarity in ('common', 'uncommon', 'rare', 'epic', 'legendary')),
  created_at timestamp with time zone default now()
);

alter table relics enable row level security;

create policy "Anyone can view relics"
  on relics for select
  using (true);

-- Inventory
create table inventory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  relic_id uuid not null references relics(id) on delete cascade,
  acquired_at timestamp with time zone default now()
);

alter table inventory enable row level security;

create policy "Users can view their own inventory"
  on inventory for select
  using (auth.uid() = user_id);

-- Daily Activity Tracking
create table daily_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  date date not null,
  unique(user_id, date)
);

alter table daily_activity enable row level security;

create policy "Users can view their own activity"
  on daily_activity for select
  using (auth.uid() = user_id);

-- Create indexes for performance
create index idx_characters_user_id on characters(user_id);
create index idx_quests_user_id on quests(user_id);
create index idx_quests_completed on quests(is_completed);
create index idx_character_attributes_character_id on character_attributes(character_id);
create index idx_quest_completions_user_id on quest_completions(user_id);
create index idx_inventory_user_id on inventory(user_id);
create index idx_daily_activity_user_id on daily_activity(user_id);
create index idx_daily_activity_date on daily_activity(date);
