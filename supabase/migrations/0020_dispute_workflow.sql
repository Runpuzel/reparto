-- Harden the admin dispute workflow and add an explicit review transition.

alter table public.disputes
  add column if not exists resolution_outcome text
  check (resolution_outcome in ('refund_buyer', 'release_seller'));

create or replace function public.review_dispute(p_dispute uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can review disputes';
  end if;

  update public.disputes
     set status = 'under_review'
   where dispute_id = p_dispute
     and status = 'open';

  if not found then
    if exists (select 1 from public.disputes where dispute_id = p_dispute) then
      raise exception 'Only open disputes can enter review';
    end if;
    raise exception 'Dispute not found';
  end if;
end;
$$;

create or replace function public.resolve_dispute(
  p_dispute uuid,
  p_outcome text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare r_d record;
begin
  if not public.is_admin() then
    raise exception 'Only admins can resolve disputes';
  end if;
  if p_outcome not in ('refund_buyer', 'release_seller') then
    raise exception 'Unsupported dispute outcome';
  end if;
  if char_length(coalesce(trim(p_note), '')) < 10 then
    raise exception 'A ruling note of at least 10 characters is required';
  end if;

  select * into r_d
    from public.disputes
   where dispute_id = p_dispute
   for update;
  if r_d is null then raise exception 'Dispute not found'; end if;
  if r_d.status = 'resolved' then raise exception 'Dispute is already resolved'; end if;

  update public.disputes
     set status = 'resolved',
         resolution_outcome = p_outcome,
         resolution = trim(p_note),
         resolved_at = now()
   where dispute_id = p_dispute;

  update public.orders
     set order_status = case
           when p_outcome = 'release_seller' then 'completed'
           else 'cancelled' end,
         completed_at = case
           when p_outcome = 'release_seller' then now() else completed_at end
   where order_id = r_d.order_id;

  insert into public.notifications (recipient_id, title, body)
  values (r_d.student_id, 'Dispute resolved', trim(p_note));
end;
$$;

grant execute on function public.review_dispute(uuid) to authenticated;
grant execute on function public.resolve_dispute(uuid, text, text) to authenticated;
