-- Supabase Database Schema for Zipper Multiplayer Collaborative Game

-- 1. Create Profiles Table (extends auth.users)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  display_name text,
  avatar_url text,
  is_guest boolean default false,
  created_at timestamptz default now()
);

-- Enable RLS on Profiles
alter table public.profiles enable row level security;

-- Open policies for profile editing
create policy "Allow public read access to profiles" on public.profiles
  for select using (true);

create policy "Allow users to update their own profile" on public.profiles
  for update using (auth.uid() = id);

create policy "Allow insert on profiles" on public.profiles
  for insert with check (true);

-- Automatic Profile Creation Trigger
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name, avatar_url, is_guest)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'display_name',
      'Player_' || substring(new.id::text from 1 for 4)
    ),
    new.raw_user_meta_data->>'avatar_url',
    coalesce((new.raw_user_meta_data->>'is_guest')::boolean, false)
  );
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2. Create Rooms Table
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz default now(),
  expires_at timestamptz not null,
  creator_id uuid not null,
  opponent_id uuid,
  grid_size int default 5,
  current_seed int not null,
  status text default 'waiting', -- 'waiting', 'playing', 'abandoned'
  creator_solved boolean default false,
  opponent_solved boolean default false,
  creator_solved_time int, -- time in seconds
  opponent_solved_time int, -- time in seconds
  winner_id uuid references public.profiles(id),
  
  constraint rooms_creator_id_fkey foreign key (creator_id) references public.profiles(id) on delete cascade,
  constraint rooms_opponent_id_fkey foreign key (opponent_id) references public.profiles(id) on delete set null
);

-- Enable RLS on Rooms
alter table public.rooms enable row level security;

create policy "Allow public access to rooms" on public.rooms
  for all using (true) with check (true);


-- 3. Create Chat Messages Table
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references public.rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  text text not null,
  created_at timestamptz default now()
);

-- Enable RLS on Messages
alter table public.messages enable row level security;

create policy "Allow public access to messages" on public.messages
  for all using (true) with check (true);


-- 4. Create WebRTC Signaling Table
create table if not exists public.webrtc_signaling (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references public.rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  type text not null, -- 'offer', 'answer', 'candidate'
  payload jsonb not null,
  created_at timestamptz default now()
);

-- Enable RLS on Signaling
alter table public.webrtc_signaling enable row level security;

create policy "Allow public access to signaling" on public.webrtc_signaling
  for all using (true) with check (true);


-- 5. Enable Realtime Publications for Realtime Updates
begin;
  -- remove the tables if they exist in publication first to prevent errors
  alter publication supabase_realtime drop table if exists public.rooms;
  alter publication supabase_realtime drop table if exists public.messages;
  alter publication supabase_realtime drop table if exists public.webrtc_signaling;
  
  -- add tables to publication
  alter publication supabase_realtime add table public.rooms;
  alter publication supabase_realtime add table public.messages;
  alter publication supabase_realtime add table public.webrtc_signaling;
commit;
