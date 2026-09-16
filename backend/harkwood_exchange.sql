-- Harkwood online exchange MVP
-- Run in the Supabase SQL editor for the dedicated Harkwood project.
-- Anonymous Auth must also be enabled in Supabase Auth settings.

create extension if not exists pgcrypto;

create table if not exists public.hark_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  gold integer not null default 0 check (gold >= 0 and gold <= 100000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.hark_market_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  buyer_id uuid references auth.users(id) on delete set null,
  item jsonb not null,
  price integer not null check (price between 1 and 1000000),
  status text not null default 'active' check (status in ('active', 'sold', 'cancelled')),
  created_at timestamptz not null default now(),
  sold_at timestamptz,
  cancelled_at timestamptz
);

create index if not exists hark_market_active_created_idx
  on public.hark_market_listings (status, created_at desc);
create index if not exists hark_market_seller_status_idx
  on public.hark_market_listings (seller_id, status);

alter table public.hark_profiles enable row level security;
alter table public.hark_market_listings enable row level security;

revoke all on public.hark_profiles from anon, authenticated;
revoke all on public.hark_market_listings from anon, authenticated;
grant select on public.hark_profiles to authenticated;
grant select on public.hark_market_listings to authenticated;

drop policy if exists "players can read own profile" on public.hark_profiles;
create policy "players can read own profile"
  on public.hark_profiles for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "players can browse active or own listings" on public.hark_market_listings;
create policy "players can browse active or own listings"
  on public.hark_market_listings for select to authenticated
  using (status = 'active' or seller_id = auth.uid());

create or replace function public.hark_ensure_profile(p_initial_gold integer)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  inserted_count integer := 0;
  current_gold integer;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;
  if p_initial_gold < 0 or p_initial_gold > 100000000 then
    raise exception 'Invalid initial wallet';
  end if;

  insert into public.hark_profiles(user_id, gold)
  values (uid, p_initial_gold)
  on conflict (user_id) do nothing;
  get diagnostics inserted_count = row_count;

  select gold into current_gold
  from public.hark_profiles
  where user_id = uid;

  return jsonb_build_object(
    'gold', current_gold,
    'created', inserted_count = 1
  );
end;
$$;

create or replace function public.hark_wallet()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  current_gold integer;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;
  select gold into current_gold from public.hark_profiles where user_id = uid;
  if current_gold is null then
    raise exception 'Profile does not exist';
  end if;
  return jsonb_build_object('gold', current_gold);
end;
$$;

create or replace function public.hark_apply_wallet_delta(p_delta integer)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  current_gold integer;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;
  if p_delta < -100000 or p_delta > 100000 then
    raise exception 'Wallet delta outside prototype limit';
  end if;

  update public.hark_profiles
  set gold = greatest(0, least(100000000, gold + p_delta)), updated_at = now()
  where user_id = uid
  returning gold into current_gold;

  if current_gold is null then
    raise exception 'Profile does not exist';
  end if;
  return jsonb_build_object('gold', current_gold);
end;
$$;

create or replace function public.hark_create_listing(p_item jsonb, p_price integer)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  listing_id uuid;
  guide integer;
  active_count integer;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;
  if p_item is null
     or jsonb_typeof(p_item) <> 'object'
     or coalesce(p_item->>'uid', '') = ''
     or coalesce(p_item->>'id', '') = ''
     or jsonb_typeof(p_item->'affixes') <> 'array' then
    raise exception 'Invalid item payload';
  end if;
  if coalesce(p_item->>'guide_price', '') !~ '^[0-9]+$' then
    raise exception 'Missing guide price';
  end if;
  guide := (p_item->>'guide_price')::integer;
  if guide < 1 or guide > 1000000 or p_price < 1 or p_price > guide * 3 then
    raise exception 'Invalid listing price';
  end if;

  select count(*) into active_count
  from public.hark_market_listings
  where seller_id = uid and status = 'active';
  if active_count >= 8 then
    raise exception 'Listing limit reached';
  end if;

  insert into public.hark_market_listings(seller_id, item, price)
  values (uid, p_item, p_price)
  returning id into listing_id;

  return jsonb_build_object('id', listing_id, 'price', p_price);
end;
$$;

create or replace function public.hark_buy_listing(p_listing uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  sale public.hark_market_listings%rowtype;
  buyer_gold integer;
  seller_net integer;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;

  select * into sale
  from public.hark_market_listings
  where id = p_listing
  for update;

  if sale.id is null or sale.status <> 'active' then
    raise exception 'Listing is no longer available';
  end if;
  if sale.seller_id = uid then
    raise exception 'You cannot buy your own listing';
  end if;

  select gold into buyer_gold
  from public.hark_profiles
  where user_id = uid
  for update;

  if buyer_gold is null then
    raise exception 'Buyer profile does not exist';
  end if;
  if buyer_gold < sale.price then
    raise exception 'Not enough gold';
  end if;

  seller_net := sale.price - ceil(sale.price * 0.05)::integer;

  update public.hark_profiles
  set gold = gold - sale.price, updated_at = now()
  where user_id = uid
  returning gold into buyer_gold;

  update public.hark_profiles
  set gold = least(100000000, gold + seller_net), updated_at = now()
  where user_id = sale.seller_id;

  update public.hark_market_listings
  set status = 'sold', buyer_id = uid, sold_at = now()
  where id = sale.id;

  return jsonb_build_object(
    'item', sale.item,
    'gold', buyer_gold,
    'price', sale.price
  );
end;
$$;

create or replace function public.hark_cancel_listing(p_listing uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  sale public.hark_market_listings%rowtype;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;

  select * into sale
  from public.hark_market_listings
  where id = p_listing and seller_id = uid
  for update;

  if sale.id is null or sale.status <> 'active' then
    raise exception 'Listing is no longer active';
  end if;

  update public.hark_market_listings
  set status = 'cancelled', cancelled_at = now()
  where id = sale.id;

  return jsonb_build_object('item', sale.item);
end;
$$;

revoke all on function public.hark_ensure_profile(integer) from public, anon;
revoke all on function public.hark_wallet() from public, anon;
revoke all on function public.hark_apply_wallet_delta(integer) from public, anon;
revoke all on function public.hark_create_listing(jsonb, integer) from public, anon;
revoke all on function public.hark_buy_listing(uuid) from public, anon;
revoke all on function public.hark_cancel_listing(uuid) from public, anon;

grant execute on function public.hark_ensure_profile(integer) to authenticated;
grant execute on function public.hark_wallet() to authenticated;
grant execute on function public.hark_apply_wallet_delta(integer) to authenticated;
grant execute on function public.hark_create_listing(jsonb, integer) to authenticated;
grant execute on function public.hark_buy_listing(uuid) to authenticated;
grant execute on function public.hark_cancel_listing(uuid) to authenticated;
