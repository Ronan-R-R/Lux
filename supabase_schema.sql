-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Table: companies
create table public.companies (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table: stores
create table public.stores (
  id uuid primary key default uuid_generate_v4(),
  company_id uuid references public.companies(id) on delete cascade not null,
  name text not null,
  commission_rate numeric(5,2) not null default 18.00, -- e.g., 18.00 %
  rent numeric(10,2) not null default 221.50, -- e.g., R221.50
  sheet_id text, -- ID of the external Google Sheet
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table: inventory
create table public.inventory (
  id uuid primary key default uuid_generate_v4(),
  store_id uuid references public.stores(id) on delete cascade not null,
  item_code text not null, 
  item_name text not null,
  cost_price numeric(10,2) not null default 0.00,
  sell_price numeric(10,2) not null default 0.00,
  quantity_sold integer not null default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(store_id, item_code)
);

-- RLS setup (Assuming we use Supabase Auth and users table is linked by app_metadata or simply custom user fields)
-- For simplicity, let's assume users log in and have a 'company_id' stored in their auth.users metadata, 
-- or we use a separate 'profiles' table. Let's create a profiles table.

create table public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  company_id uuid references public.companies(id) on delete restrict,
  full_name text
);

-- Turn on RLS
alter table public.companies enable row level security;
alter table public.stores enable row level security;
alter table public.inventory enable row level security;
alter table public.profiles enable row level security;

-- Policies for profiles
create policy "Users can view their own profile."
  on profiles for select
  using ( auth.uid() = id );

create policy "Users can update their own profile."
  on profiles for update
  using ( auth.uid() = id );

-- Policies for companies
create policy "Users can view their own company."
  on companies for select
  using ( id = (select company_id from profiles where profiles.id = auth.uid()) );

-- Policies for stores
create policy "Users can view stores in their company."
  on stores for select
  using ( company_id = (select company_id from profiles where profiles.id = auth.uid()) );

create policy "Users can insert stores in their company."
  on stores for insert
  with check ( company_id = (select company_id from profiles where profiles.id = auth.uid()) );

create policy "Users can update stores in their company."
  on stores for update
  using ( company_id = (select company_id from profiles where profiles.id = auth.uid()) );

create policy "Users can delete stores in their company."
  on stores for delete
  using ( company_id = (select company_id from profiles where profiles.id = auth.uid()) );

-- Policies for inventory
create policy "Users can view inventory for stores in their company."
  on inventory for select
  using ( store_id in (select id from stores where company_id = (select company_id from profiles where profiles.id = auth.uid())) );

create policy "Users can insert inventory for stores in their company."
  on inventory for insert
  with check ( store_id in (select id from stores where company_id = (select company_id from profiles where profiles.id = auth.uid())) );

create policy "Users can update inventory for stores in their company."
  on inventory for update
  using ( store_id in (select id from stores where company_id = (select company_id from profiles where profiles.id = auth.uid())) );

create policy "Users can delete inventory for stores in their company."
  on inventory for delete
  using ( store_id in (select id from stores where company_id = (select company_id from profiles where profiles.id = auth.uid())) );
