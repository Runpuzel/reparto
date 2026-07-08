-- Keep the notification screen and push delivery strictly one-to-one.
-- Every new notification row queues exactly one push dispatch request.
create or replace function public.dispatch_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_config record;
  v_request_id bigint;
begin
  select * into v_config from public.push_dispatch_config
   where id = true and enabled = true;
  if v_config is null then
    insert into public.push_dispatch_log
      (notification_id, recipient_id, status, detail)
    values (new.notification_id, new.recipient_id, 'not_configured',
      'Push dispatch configuration is missing or disabled');
    return new;
  end if;

  select net.http_post(
    url := v_config.function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_config.function_secret),
    body := jsonb_build_object(
      'notification_id', new.notification_id,
      'recipient_id', new.recipient_id,
      'title', new.title,
      'body', coalesce(new.body, ''))
  ) into v_request_id;

  insert into public.push_dispatch_log
    (notification_id, recipient_id, request_id, status)
  values (new.notification_id, new.recipient_id, v_request_id, 'queued');
  return new;
exception when others then
  insert into public.push_dispatch_log
    (notification_id, recipient_id, status, detail)
  values (new.notification_id, new.recipient_id, 'error', sqlerrm);
  return new;
end;
$$;

drop trigger if exists trg_dispatch_push on public.notifications;
create trigger trg_dispatch_push after insert on public.notifications
for each row execute function public.dispatch_push();
