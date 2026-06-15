-- ============================================================================
-- Reparto :: Migration 0003 :: Row-Level Security
-- Implements campus isolation + role-based access from the spec.
-- ============================================================================

alter table public.campuses      enable row level security;
alter table public.users         enable row level security;
alter table public.vendors       enable row level security;
alter table public.categories    enable row level security;
alter table public.products      enable row level security;
alter table public.carts         enable row level security;
alter table public.cart_items    enable row level security;
alter table public.orders        enable row level security;
alter table public.order_items   enable row level security;
alter table public.reviews       enable row level security;
alter table public.notifications enable row level security;

-- ----------------------------------------------------------------------------
-- CAMPUSES : everyone can read active campuses (needed at registration);
--            only admins can write.
-- ----------------------------------------------------------------------------
drop policy if exists campuses_read on public.campuses;
create policy campuses_read on public.campuses
  for select using (status = 'active' or public.is_admin());

drop policy if exists campuses_admin_write on public.campuses;
create policy campuses_admin_write on public.campuses
  for all using (public.is_admin()) with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- USERS : a user can read/update their own row; admins can read/manage all;
--         vendors & students can read basic info of users on the same campus.
-- ----------------------------------------------------------------------------
drop policy if exists users_self_read on public.users;
create policy users_self_read on public.users
  for select using (
    user_id = auth.uid()
    or public.is_admin()
    or campus_id = public.current_campus()
  );

drop policy if exists users_self_update on public.users;
create policy users_self_update on public.users
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists users_admin_all on public.users;
create policy users_admin_all on public.users
  for all using (public.is_admin()) with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- VENDORS : public read within campus; vendor manages own row;
--           admins manage all.
-- ----------------------------------------------------------------------------
drop policy if exists vendors_read on public.vendors;
create policy vendors_read on public.vendors
  for select using (
    public.is_admin()
    or user_id = auth.uid()
    or (campus_id = public.current_campus())
  );

drop policy if exists vendors_self_insert on public.vendors;
create policy vendors_self_insert on public.vendors
  for insert with check (user_id = auth.uid());

drop policy if exists vendors_self_update on public.vendors;
create policy vendors_self_update on public.vendors
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid() and approval_status = approval_status);

drop policy if exists vendors_admin_all on public.vendors;
create policy vendors_admin_all on public.vendors
  for all using (public.is_admin()) with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- CATEGORIES : readable by all authenticated; writable by admin.
-- ----------------------------------------------------------------------------
drop policy if exists categories_read on public.categories;
create policy categories_read on public.categories
  for select using (auth.uid() is not null);

drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write on public.categories
  for all using (public.is_admin()) with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- PRODUCTS : students see available products from approved vendors on their
--            campus; vendors manage their own; admins all.
-- ----------------------------------------------------------------------------
drop policy if exists products_campus_read on public.products;
create policy products_campus_read on public.products
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.vendors v
      where v.vendor_id = products.vendor_id
        and (
          v.user_id = auth.uid()  -- owner sees all their own
          or (v.campus_id = public.current_campus() and v.approval_status = 'approved')
        )
    )
  );

drop policy if exists products_vendor_write on public.products;
create policy products_vendor_write on public.products
  for all using (
    exists (select 1 from public.vendors v
            where v.vendor_id = products.vendor_id and v.user_id = auth.uid())
  )
  with check (
    exists (select 1 from public.vendors v
            where v.vendor_id = products.vendor_id
              and v.user_id = auth.uid()
              and v.approval_status = 'approved')
  );

drop policy if exists products_admin_all on public.products;
create policy products_admin_all on public.products
  for all using (public.is_admin()) with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- CARTS / CART ITEMS : owned by the student only.
-- ----------------------------------------------------------------------------
drop policy if exists carts_owner on public.carts;
create policy carts_owner on public.carts
  for all using (student_id = auth.uid()) with check (student_id = auth.uid());

drop policy if exists cart_items_owner on public.cart_items;
create policy cart_items_owner on public.cart_items
  for all using (
    exists (select 1 from public.carts c
            where c.cart_id = cart_items.cart_id and c.student_id = auth.uid())
  )
  with check (
    exists (select 1 from public.carts c
            where c.cart_id = cart_items.cart_id and c.student_id = auth.uid())
  );

-- ----------------------------------------------------------------------------
-- ORDERS : student sees own; vendor sees orders for their business;
--          admins all. Vendors may update status of their own orders.
-- ----------------------------------------------------------------------------
drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders
  for select using (
    public.is_admin()
    or student_id = auth.uid()
    or exists (select 1 from public.vendors v
               where v.vendor_id = orders.vendor_id and v.user_id = auth.uid())
  );

drop policy if exists orders_student_insert on public.orders;
create policy orders_student_insert on public.orders
  for insert with check (student_id = auth.uid());

drop policy if exists orders_vendor_update on public.orders;
create policy orders_vendor_update on public.orders
  for update using (
    exists (select 1 from public.vendors v
            where v.vendor_id = orders.vendor_id and v.user_id = auth.uid())
    or student_id = auth.uid()
  )
  with check (
    exists (select 1 from public.vendors v
            where v.vendor_id = orders.vendor_id and v.user_id = auth.uid())
    or student_id = auth.uid()
  );

drop policy if exists orders_admin_all on public.orders;
create policy orders_admin_all on public.orders
  for all using (public.is_admin()) with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- ORDER ITEMS : visible to the order's student / vendor / admin.
-- ----------------------------------------------------------------------------
drop policy if exists order_items_read on public.order_items;
create policy order_items_read on public.order_items
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.orders o
      left join public.vendors v on v.vendor_id = o.vendor_id
      where o.order_id = order_items.order_id
        and (o.student_id = auth.uid() or v.user_id = auth.uid())
    )
  );

drop policy if exists order_items_insert on public.order_items;
create policy order_items_insert on public.order_items
  for insert with check (
    exists (select 1 from public.orders o
            where o.order_id = order_items.order_id and o.student_id = auth.uid())
  );

-- ----------------------------------------------------------------------------
-- REVIEWS : readable within campus; students write their own (validated by
--           trigger to require completed orders).
-- ----------------------------------------------------------------------------
drop policy if exists reviews_read on public.reviews;
create policy reviews_read on public.reviews
  for select using (
    public.is_admin()
    or exists (select 1 from public.vendors v
               where v.vendor_id = reviews.vendor_id
                 and (v.campus_id = public.current_campus() or v.user_id = auth.uid()))
  );

drop policy if exists reviews_student_write on public.reviews;
create policy reviews_student_write on public.reviews
  for insert with check (student_id = auth.uid());

-- ----------------------------------------------------------------------------
-- NOTIFICATIONS : recipient only (admins may read all).
-- ----------------------------------------------------------------------------
drop policy if exists notifications_owner on public.notifications;
create policy notifications_owner on public.notifications
  for select using (recipient_id = auth.uid() or public.is_admin());

drop policy if exists notifications_owner_update on public.notifications;
create policy notifications_owner_update on public.notifications
  for update using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
