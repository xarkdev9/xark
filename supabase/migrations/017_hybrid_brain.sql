-- 017_hybrid_brain.sql
-- Three-Tier Hybrid Brain: space_ledger for admin audit trail

-- Space ledger: Layer 3, unencrypted administrative audit trail
create table if not exists space_ledger (
  id uuid primary key default gen_random_uuid(),
  space_id text not null references spaces(id) on delete cascade,
  actor_id text not null,
  actor_name text,
  action text not null,
  payload jsonb default '{}',
  previous jsonb default '{}',
  revert_target_id uuid,
  created_at timestamptz default now()
);

create index idx_ledger_space_created
  on space_ledger(space_id, created_at desc);

alter table space_ledger enable row level security;

create policy "members_read_ledger" on space_ledger
  for select using (space_id = any(auth_user_space_ids()));

create policy "members_write_ledger" on space_ledger
  for insert with check (
    space_id = any(auth_user_space_ids())
    and actor_id = auth.jwt()->>'sub'
  );

-- Publish to Realtime for live pill rendering
alter publication supabase_realtime add table space_ledger;

-- Note: auth_user_space_ids() is already declared STABLE in migration 20260313212810.
-- No ALTER needed. Verified: function signature includes LANGUAGE sql SECURITY DEFINER STABLE.
