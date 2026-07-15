-- Restore anonymous product browsing after migration 0025 tightened the
-- catalogue policy. Guests have no campus, so comparing a seller's campus to
-- current_campus() filters every product out for the anon role.

drop policy if exists products_campus_read on public.products;
create policy products_campus_read on public.products
for select using (
  public.is_admin()
  or exists (
    select 1
    from public.vendors v
    where v.vendor_id = products.vendor_id
      and (
        v.user_id = auth.uid()
        or (
          auth.uid() is not null
          and v.campus_id = public.current_campus()
          and v.approval_status not in ('suspended', 'rejected')
        )
        or (
          auth.uid() is null
          and v.approval_status = 'approved'
        )
      )
  )
);
