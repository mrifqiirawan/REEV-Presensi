-- OPTIONAL. Enable pg_cron and pg_net in Supabase Database > Extensions first.
-- Create two secrets through Supabase Vault UI:
-- reev_worker_url  = https://YOUR-APP.vercel.app/api/wa-worker
-- reev_cron_secret = exactly the CRON_SECRET configured in Vercel
-- Only use a secret scoped to this worker. NEVER store service_role in this header.
-- Keep net and vault outside exposed Data API schemas.
-- Run after deployment succeeds; job runs once a minute.
select cron.schedule(
 'reev-wa-worker',
 '* * * * *',
 $job$
 select net.http_get(
   url := (select decrypted_secret from vault.decrypted_secrets where name='reev_worker_url'),
   headers := jsonb_build_object('Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='reev_cron_secret')),
   timeout_milliseconds := 25000
 );
 $job$
);
-- To stop: select cron.unschedule('reev-wa-worker');
-- Inspect job history in Supabase Cron. HTTP results: net._http_response.
