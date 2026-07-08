-- Business approval and identity verification are separate states.
-- Every seller can start selling immediately, but receives no verified badge or
-- prepaid-payment privileges until KYC is approved.

alter table public.vendors
  alter column approval_status set default 'approved';

create or replace function public.auto_approve_new_seller()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.approval_status := 'approved';
  new.is_verified := false;
  new.verification_status := 'unverified';
  new.verification_approved_at := null;
  return new;
end;
$$;

drop trigger if exists trg_auto_approve_new_seller on public.vendors;
create trigger trg_auto_approve_new_seller
before insert on public.vendors
for each row execute function public.auto_approve_new_seller();

-- Sellers still awaiting only business approval should gain seller access now.
-- Their KYC state is deliberately left untouched.
update public.vendors
set approval_status = 'approved'
where approval_status = 'pending';

