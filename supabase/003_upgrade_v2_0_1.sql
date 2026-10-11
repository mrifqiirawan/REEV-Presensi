-- Existing v2.0.0: run ONLY this migration, then deploy v2.0.1 and update scheduler.
-- Fresh install: run 001, then 003, then optional 002. No operational data deleted.
begin;
alter table public.settings drop constraint if exists settings_wa_min_seconds_check;
alter table public.settings add constraint settings_wa_min_seconds_check check(wa_min_seconds>=5);
alter table public.settings alter column wa_min_seconds set default 5;
alter table public.settings drop constraint if exists settings_wa_recipient_minutes_check;
alter table public.settings add constraint settings_wa_recipient_minutes_check check(wa_recipient_minutes>=0);
alter table public.settings alter column wa_recipient_minutes set default 0;
-- Requested 5-second global interval. Same recipient may follow after the global interval.
update public.settings set wa_min_seconds=5,wa_recipient_minutes=0 where id=1;

create or replace function public.reserve_notice_v201() returns jsonb
language plpgsql security definer set search_path=public as $$
declare s settings;w wa_state;n outbox;d date;tm time;at_now timestamptz;wait_seconds int;
begin
 perform pg_advisory_xact_lock(8120);
 at_now:=clock_timestamp();
 select * into s from settings where id=1;
 select * into w from wa_state where id=1 for update;
 if s.id is null or w.id is null then raise exception 'Pengaturan WhatsApp tidak lengkap';end if;
 d:=(at_now at time zone s.timezone)::date;tm:=(at_now at time zone s.timezone)::time;
 if s.wa_paused then return jsonb_build_object('code','PAUSED','reason','Pengiriman dijeda. Klik Aktifkan pengiriman di halaman WhatsApp.');end if;
 if w.blocked<>'' then return jsonb_build_object('code','BLOCKED','reason','Pengiriman diblokir: '||w.blocked||'. Periksa gateway lalu klik Buka blokir & aktifkan.');end if;
 update outbox set status='EXPIRED',error='Masa berlaku pesan telah habis' where status='PENDING' and created_at<at_now-make_interval(hours=>s.wa_expiry_hours);
 if not exists(select 1 from outbox where status='PENDING') then
  return jsonb_build_object('code','EMPTY','reason','Tidak ada pesan PENDING. Periksa filter status, nomor orang tua, dan pengaturan notifikasi. Scan duplikat tidak membuat pesan baru.');
 end if;
 if tm<s.wa_start or tm>s.wa_end then return jsonb_build_object('code','OUTSIDE_HOURS','reason','Di luar jam pengiriman '||s.wa_start::text||' sampai '||s.wa_end::text||' ('||s.timezone||').');end if;
 if w.day is distinct from d then w.day:=d;w.attempts:=0;end if;
 if w.attempts>=s.wa_daily_limit then return jsonb_build_object('code','DAILY_LIMIT','reason','Batas harian '||s.wa_daily_limit||' percobaan tercapai. Ubah batas di Pengaturan atau tunggu tanggal berikutnya.');end if;
 if w.last_at>at_now-make_interval(secs=>s.wa_min_seconds) then
  wait_seconds:=greatest(1,ceil(extract(epoch from w.last_at+make_interval(secs=>s.wa_min_seconds)-at_now))::int);
  return jsonb_build_object('code','COOLDOWN','reason','Menunggu jeda global. Coba lagi dalam '||wait_seconds||' detik.','retry_after_seconds',wait_seconds);
 end if;
 select * into n from outbox o where o.status='PENDING' and
  (s.wa_recipient_minutes=0 or not exists(select 1 from outbox x where x.phone=o.phone and x.attempted_at>at_now-make_interval(mins=>s.wa_recipient_minutes)))
  order by created_at,id limit 1 for update skip locked;
 if n.id is null then return jsonb_build_object('code','RECIPIENT_COOLDOWN','reason','Pesan menunggu jeda penerima sama ('||s.wa_recipient_minutes||' menit) atau sedang diklaim. Isi 0 menit untuk memakai jeda global saja.');end if;
 update wa_state set day=d,attempts=w.attempts+1,last_at=at_now where id=1;
 update outbox set status='UNKNOWN',attempted_at=at_now,attempts=attempts+1,error='Sedang diproses. Jika status menetap, periksa log gateway sebelum mengulang.' where id=n.id returning * into n;
 return jsonb_build_object('code','CLAIMED','job',to_jsonb(n));
end$$;

-- Preserve v2.0.0 contract for a safe code rollout/rollback.
create or replace function public.claim_notice() returns jsonb
language sql security definer set search_path=public as $$select public.reserve_notice_v201()->'job'$$;

create or replace function public.resume_wa() returns void
language plpgsql security definer set search_path=public as $$begin
 if not public.is_admin() then raise exception 'Akses ditolak';end if;
 perform pg_advisory_xact_lock(8120);
 update wa_state set blocked='' where id=1;
 update settings set wa_paused=false where id=1;
 insert into audit(actor,action) values(auth.uid(),'RESUME_WA');
end$$;
revoke all on function public.reserve_notice_v201() from public,anon,authenticated;
grant execute on function public.reserve_notice_v201() to service_role;
revoke all on function public.claim_notice() from public,anon,authenticated;
grant execute on function public.claim_notice() to service_role;
revoke all on function public.resume_wa() from public,anon;
grant execute on function public.resume_wa() to authenticated;
commit;
