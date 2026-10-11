-- v2.0.1: run AFTER 003_upgrade_v2_0_1.sql and Vercel deployment.
-- Enable pg_cron and pg_net. Supabase must support seconds schedules.
-- Vault: reev_worker_url=https://YOUR-APP.vercel.app/api/wa-worker
--        reev_cron_secret=the CRON_SECRET configured in Vercel
-- Use ONE scheduler. Same name replaces the old once-per-minute schedule.
-- Keep net/vault outside exposed Data API schemas. Never use service_role here.
select cron.schedule(
 'reev-wa-worker',
 '5 seconds',
 $job$
 select net.http_get(
   url := (select decrypted_secret from vault.decrypted_secrets where name='reev_worker_url'),
   headers := jsonb_build_object('Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='reev_cron_secret')),
   timeout_milliseconds := 25000
 )
 from public.settings s join public.wa_state w on w.id=s.id
 where s.id=1 and not s.wa_paused and w.blocked=''
   and (now() at time zone s.timezone)::time between s.wa_start and s.wa_end
   and (w.day is distinct from (now() at time zone s.timezone)::date or w.attempts<s.wa_daily_limit)
   and (w.last_at is null or w.last_at<=now()-make_interval(secs=>s.wa_min_seconds))
   and exists(select 1 from public.outbox o where o.status='PENDING');
 $job$
);
-- Pause through Cron Dashboard.
-- Inspect cron.job_run_details and net._http_response. Cron success is NOT HTTP success.
-- Manual invocation on WhatsApp page shows the precise queue reason.
