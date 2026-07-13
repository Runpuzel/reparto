-- Date-bound temporary closures and administrator announcements.

alter table public.vendors
  add column if not exists closed_today_date date;

update public.vendors
set closed_today_date = current_date
where is_closed_today = true
  and closed_today_date is null;

create table if not exists public.admin_broadcasts (
  broadcast_id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.users(user_id) on delete restrict,
  audience text not null check (audience in ('all', 'students', 'sellers')),
  title text not null check (char_length(title) between 3 and 60),
  body text not null check (char_length(body) between 3 and 280),
  recipient_count integer not null default 0 check (recipient_count >= 0),
  created_at timestamptz not null default now()
);

alter table public.admin_broadcasts enable row level security;

drop policy if exists admin_broadcasts_admin_read on public.admin_broadcasts;
create policy admin_broadcasts_admin_read on public.admin_broadcasts
for select using (public.is_admin());

create or replace function public.send_admin_broadcast(
  p_title text,
  p_body text,
  p_audience text default 'all'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_title text := trim(coalesce(p_title, ''));
  v_body text := trim(coalesce(p_body, ''));
  v_audience text := lower(trim(coalesce(p_audience, 'all')));
  v_broadcast uuid;
  v_count integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Administrator access required';
  end if;
  if char_length(v_title) not between 3 and 60 then
    raise exception 'Announcement title must be between 3 and 60 characters';
  end if;
  if char_length(v_body) not between 3 and 280 then
    raise exception 'Announcement message must be between 3 and 280 characters';
  end if;
  if v_audience not in ('all', 'students', 'sellers') then
    raise exception 'Choose a valid announcement audience';
  end if;

  insert into public.admin_broadcasts(admin_id, audience, title, body)
  values(v_admin, v_audience, v_title, v_body)
  returning broadcast_id into v_broadcast;

  insert into public.notifications(recipient_id, title, body)
  select user_id, v_title, v_body
  from public.users
  where is_suspended = false
    and (
      (v_audience = 'all' and role in ('student', 'vendor'))
      or (v_audience = 'students' and role = 'student')
      or (v_audience = 'sellers' and role = 'vendor')
    );

  get diagnostics v_count = row_count;

  update public.admin_broadcasts
  set recipient_count = v_count
  where broadcast_id = v_broadcast;

  return jsonb_build_object(
    'broadcast_id', v_broadcast,
    'recipient_count', v_count
  );
end;
$$;

revoke all on function public.send_admin_broadcast(text, text, text) from public;
grant execute on function public.send_admin_broadcast(text, text, text)
  to authenticated;
