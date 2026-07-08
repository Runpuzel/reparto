-- Balanced, activity-based token rewards with idempotency and abuse limits.

alter table public.token_transactions add column if not exists event_key text;
create unique index if not exists token_event_once
  on public.token_transactions(user_id, event_key) where event_key is not null;

create or replace function public._award_tokens_once(
  p_user uuid, p_amount integer, p_reason text, p_event_key text)
returns void language plpgsql security definer set search_path = public as $$
declare v_campus uuid;
begin
  if p_amount <= 0 then return; end if;
  select campus_id into v_campus from public.users where user_id = p_user;
  insert into public.token_transactions
    (user_id, delta, reason, campus_id, expires_at, event_key)
  values (p_user, p_amount, p_reason, v_campus,
          now() + interval '6 months', p_event_key)
  on conflict (user_id, event_key) where event_key is not null do nothing;
end $$;

-- Signup is deliberately small; meaningful rewards require real activity.
do $$ declare d text;
begin
  select pg_get_functiondef('public.claim_referral(text)'::regprocedure) into d;
  d := replace(d, '_award_tokens(v_referrer, 5, ''Referral signup'')',
                   '_award_tokens(v_referrer, 2, ''Referral signup'')');
  d := replace(d, '_award_tokens(v_me, 2, ''Welcome bonus'')',
                   '_award_tokens(v_me, 1, ''Welcome bonus'')');
  execute d;
end $$;

create or replace function public.reward_first_transaction(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_ref record;
begin
  select * into v_ref from public.referrals
   where referred_id = p_user and first_txn_rewarded = false for update;
  if v_ref is null then return; end if;
  perform public._award_tokens_once(v_ref.referrer_id, 5,
    'Referral first purchase', 'referral-first:' || v_ref.referral_id);
  perform public._award_tokens_once(p_user, 2,
    'First purchase bonus', 'first-purchase:' || v_ref.referral_id);
  update public.referrals set first_txn_rewarded = true
   where referral_id = v_ref.referral_id;
end $$;

create or replace function public.reward_completed_order_tokens()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_reward integer; v_seller uuid; v_sales integer;
begin
  if new.order_status not in ('delivered','completed')
     or old.order_status in ('delivered','completed') then return new; end if;
  v_reward := least(5, floor(new.total_amount / 50.0)::integer);
  if v_reward > 0 then
    perform public._award_tokens_once(new.student_id, v_reward,
      'Completed purchase', 'purchase:' || new.order_id);
  end if;
  perform public.reward_first_transaction(new.student_id);
  select user_id into v_seller from public.vendors where vendor_id = new.vendor_id;
  select count(*) into v_sales from public.orders
   where vendor_id = new.vendor_id and order_status in ('delivered','completed');
  if v_sales = 1 then
    perform public._award_tokens_once(v_seller, 3, 'First successful sale',
      'seller-first-sale');
  end if;
  if v_sales > 0 and v_sales % 5 = 0 then
    perform public._award_tokens_once(v_seller, 5, 'Five-sale milestone',
      'seller-sales:' || v_sales);
  end if;
  return new;
end $$;

drop trigger if exists trg_reward_completed_order_tokens on public.orders;
create trigger trg_reward_completed_order_tokens
after update of order_status on public.orders for each row
execute function public.reward_completed_order_tokens();

create or replace function public.reward_verified_seller_tokens()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_verified = true and coalesce(old.is_verified, false) = false then
    perform public._award_tokens_once(new.user_id, 5, 'Verified seller bonus',
      'verified-seller');
  end if;
  return new;
end $$;
drop trigger if exists trg_reward_verified_seller_tokens on public.vendors;
create trigger trg_reward_verified_seller_tokens after update of is_verified
on public.vendors for each row execute function public.reward_verified_seller_tokens();

create or replace function public.reward_review_tokens()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.token_transactions
      where user_id = new.student_id and reason = 'Verified purchase review'
        and created_at >= date_trunc('week', now())) < 3 then
    perform public._award_tokens_once(new.student_id, 1,
      'Verified purchase review', 'review:' || new.review_id);
  end if;
  return new;
end $$;
drop trigger if exists trg_reward_review_tokens on public.reviews;
create trigger trg_reward_review_tokens after insert on public.reviews
for each row when (new.order_id is not null)
execute function public.reward_review_tokens();
