-- SQL Scripts for Saver App Supabase Setup (Idempotent Migration)

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Create tables if they don't exist
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  role text check (role in ('user', 'saver')) not null,
  full_name text
);

create table if not exists public.transactions (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete restrict not null,
  amount numeric not null,
  type text check (type in ('deposit', 'withdraw')) not null,
  status text check (status in ('pending', 'approved', 'rejected')) not null default 'pending',
  note text,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

-- 2. Add new columns for the invite code update (safe to run anytime)
alter table public.profiles add column if not exists invite_code text unique;
alter table public.profiles add column if not exists admin_id uuid references public.profiles(id);

-- 3. Update realtime (Commented out: already added in original run!)
-- alter publication supabase_realtime add table public.transactions;

-- 4. Re-apply RLS
alter table public.profiles enable row level security;
alter table public.transactions enable row level security;

-- Drop old profile policies to avoid duplicates
drop policy if exists "Users can read all profiles" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;

-- Recreate profile policies
create policy "Users can read all profiles" on public.profiles for select using (true);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);

-- 5. Handle user registration trigger (idempotent)
create or replace function public.handle_new_user()
returns trigger as $$
declare
  gen_invite_code text := null;
  r_role text := coalesce(new.raw_user_meta_data->>'role', 'user');
  r_admin_id uuid := null;
begin
  if r_role = 'saver' then
    -- Generate simple 6 char random string for Admin
    gen_invite_code := upper(substring(md5(random()::text) from 1 for 6));
  else
    -- Try to parse admin_id securely
    begin
      r_admin_id := (new.raw_user_meta_data->>'admin_id')::uuid;
    exception when others then
      r_admin_id := null;
    end;
  end if;

  insert into public.profiles (id, full_name, role, invite_code, admin_id)
  values (
    new.id, 
    new.raw_user_meta_data->>'full_name', 
    r_role,
    gen_invite_code,
    r_admin_id
  );
  return new;
end;
$$ language plpgsql security definer;

-- Drop and recreate the trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 6. Update Transaction Policies
drop policy if exists "Select transactions" on public.transactions;
drop policy if exists "Insert transactions" on public.transactions;
drop policy if exists "Update transactions" on public.transactions;

-- Select: Savers see tx of users who have them as admin, Users see their own
create policy "Select transactions" on public.transactions 
for select using (
  auth.uid() = user_id or 
  exists (select 1 from public.profiles u where u.id = public.transactions.user_id and u.admin_id = auth.uid())
);

-- Insert: Users can insert their own pending transactions
create policy "Insert transactions" on public.transactions 
for insert with check (
  auth.uid() = user_id and status = 'pending'
);

-- Update: Savers can update transactions (to approve/reject) for their supervised users
create policy "Update transactions" on public.transactions 
for update using (
  exists (select 1 from public.profiles u where u.id = public.transactions.user_id and u.admin_id = auth.uid())
);
