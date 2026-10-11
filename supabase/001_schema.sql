-- REEV Presensi 2.0.0. Run ONCE on a NEW Supabase project in SQL Editor.
begin;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check(username ~ '^[a-z0-9_.-]{3,40}$'),
 name text not null check(length(name) between 1 and 120),
 role text not null default 'GURU' check(role in ('ADMIN','GURU')),
 phone text not null default '', active boolean not null default true
);
create table public.terms (id uuid primary key default gen_random_uuid(), year text not null, name text not null check(name in ('Ganjil','Genap')), unique(year,name));
create table public.classes (id uuid primary key default gen_random_uuid(),name text not null,term_id uuid not null references public.terms(id),teacher_id uuid references public.profiles(id),active boolean not null default true,unique(term_id,name));
create table public.students (
 id uuid primary key default gen_random_uuid(), nisn text not null unique check(nisn ~ '^[0-9]{10}$'),
 name text not null check(length(name) between 1 and 120),class_id uuid not null references public.classes(id),
 birth_date date, address text not null default '',parent_name text not null default '',
 parent_phone text not null default '' check(parent_phone='' or parent_phone ~ '^[1-9][0-9]{7,14}$'),
 qr text not null unique default gen_random_uuid()::text check(length(qr) between 1 and 1000), active boolean not null default true
);
create table public.settings (
 id integer primary key default 1 check(id=1),name text not null default 'REEV Presensi',school text not null default 'MTsN 3 Sidrap',creator text not null default 'M. Rifqi Irawan, S.Pd.',
 logo text not null default '',primary_color text not null default '#123c45' check(primary_color ~ '^#[0-9a-fA-F]{6}$'),accent_color text not null default '#c9953a' check(accent_color ~ '^#[0-9a-fA-F]{6}$'),
 timezone text not null default 'Asia/Makassar' check(timezone in ('Asia/Jakarta','Asia/Makassar','Asia/Jayapura')),
 active_term uuid references public.terms(id),morning_start time not null default '06:00',morning_end time not null default '08:00',lesson_start time not null default '08:01',lesson_end time not null default '15:00',afternoon_start time not null default '15:01',afternoon_end time not null default '16:00',
 notify_parents boolean not null default true,notify_teacher boolean not null default false,
 wa_paused boolean not null default true,wa_min_seconds int not null default 60 check(wa_min_seconds>=60),wa_daily_limit int not null default 300 check(wa_daily_limit between 1 and 5000),wa_recipient_minutes int not null default 30 check(wa_recipient_minutes>=1),wa_start time not null default '06:00',wa_end time not null default '20:00',wa_expiry_hours int not null default 12 check(wa_expiry_hours between 1 and 48),
 check(morning_start<morning_end and morning_end<lesson_start and lesson_start<lesson_end and lesson_end<afternoon_start and afternoon_start<afternoon_end),check(wa_start<wa_end)
);
insert into public.settings(id) values(1);
create table public.attendance (
 id uuid primary key default gen_random_uuid(),student_id uuid not null references public.students(id),term_id uuid not null references public.terms(id),class_id uuid not null references public.classes(id),
 student_name text not null,nisn text not null,class_name text not null,day date not null,slot text not null check(slot in ('PAGI','PELAJARAN','SORE')),status text not null check(status in ('HADIR','SAKIT','IZIN','ALPA')),
 at timestamptz not null default now(),actor uuid references public.profiles(id),method text not null check(method in ('QR','MANUAL')),unique(student_id,term_id,day,slot)
);
create index attendance_day_idx on public.attendance(day desc,at desc);
create index student_class_idx on public.students(class_id,name);
create table public.outbox (
 id uuid primary key default gen_random_uuid(),attendance_id uuid not null references public.attendance(id) on delete cascade,phone text not null,message text not null,
 status text not null default 'PENDING' check(status in ('PENDING','SENT','UNKNOWN','FAILED','EXPIRED','CANCELLED')),
 attempts int not null default 0,created_at timestamptz not null default now(),attempted_at timestamptz,error text not null default '', unique(attendance_id,phone)
);
create index outbox_pending_idx on public.outbox(created_at) where status='PENDING';
create index outbox_phone_idx on public.outbox(phone,attempted_at desc);
create table public.wa_state (id int primary key check(id=1),day date,attempts int not null default 0,last_at timestamptz,blocked text not null default '');
insert into public.wa_state(id) values(1);
create table public.audit (id bigint generated always as identity primary key,at timestamptz not null default now(),actor uuid,action text not null,detail text not null default '');
create table public.backup_receipts (id uuid primary key default gen_random_uuid(),actor uuid not null, fingerprint text not null,expires_at timestamptz not null default now()+interval '30 minutes',used boolean not null default false);

create function public.is_active() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.profiles where id=auth.uid() and active)$$;
create function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.profiles where id=auth.uid() and active and role='ADMIN')$$;

alter table public.profiles enable row level security;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
-- Profile writes ONLY through the authenticated admin API with service role.
do $$declare t text;begin
 foreach t in array array['terms','classes','students','settings'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy read_active on public.%I for select to authenticated using(public.is_active())',t);
 execute format('create policy write_admin on public.%I for all to authenticated using(public.is_admin()) with check(public.is_admin())',t);
 end loop;
 foreach t in array array['attendance','outbox','wa_state','audit','backup_receipts'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy read_admin on public.%I for select to authenticated using(public.is_admin())',t);
 end loop;
end$$;
grant usage on schema public to authenticated,service_role;
grant select on all tables in schema public to authenticated;
grant insert,update,delete on public.terms,public.classes,public.students,public.settings to authenticated;
grant all on all tables in schema public to service_role;
grant usage,select on all sequences in schema public to service_role;

create function public.protect_admin() returns trigger language plpgsql security definer set search_path=public as $$begin
 perform pg_advisory_xact_lock(8121);
 if old.active and old.role='ADMIN' and (tg_op='DELETE' or not new.active or new.role<>'ADMIN') and not exists(select 1 from profiles where id<>old.id and active and role='ADMIN') then raise exception 'Admin aktif terakhir tidak dapat dihapus/dinonaktifkan';end if;
 if tg_op='DELETE' then return old;end if;return new;
end$$;
create trigger guard_admin before update or delete on public.profiles for each row execute function public.protect_admin();
create function public.audit_master() returns trigger language plpgsql security definer set search_path=public as $$begin
 insert into audit(actor,action,detail) values(auth.uid(),tg_table_name||':'||tg_op,coalesce(new.id::text,old.id::text));
 if tg_op='DELETE' then return old;end if;return new;
end$$;
do $$declare t text;begin foreach t in array array['profiles','terms','classes','students','settings'] loop execute format('create trigger audit_change after insert or update or delete on public.%I for each row execute function public.audit_master()',t);end loop;end$$;

create function public.record_attendance(p_qr text default null,p_student uuid default null,p_status text default 'HADIR') returns jsonb language plpgsql security definer set search_path=public as $$
declare s settings; st students; c classes; a attendance; sl text; d date; tm time; recipient record; teacher profiles; dup boolean:=false;
begin
 if not public.is_active() then raise exception 'Akses ditolak';end if;
 perform pg_advisory_xact_lock(8120);
 select * into s from settings where id=1;
 if s.active_term is null then raise exception 'Admin perlu memilih semester aktif';end if;
 d:=(now() at time zone s.timezone)::date;tm:=(now() at time zone s.timezone)::time;
 sl:=case when tm between s.morning_start and s.morning_end then 'PAGI' when tm between s.lesson_start and s.lesson_end then 'PELAJARAN' when tm between s.afternoon_start and s.afternoon_end then 'SORE' end;
 if sl is null then raise exception 'Di luar jadwal presensi';end if;
 if p_qr is not null then select * into st from students where qr=p_qr and active;p_status:='HADIR';else select * into st from students where id=p_student and active;end if;
 if st.id is null then raise exception 'Siswa/QR tidak ditemukan atau nonaktif';end if;
 select * into c from classes where id=st.class_id and active and term_id=s.active_term;
 if c.id is null then raise exception 'Kelas bukan semester aktif';end if;
 if p_status not in ('HADIR','SAKIT','IZIN','ALPA') or p_status is null then raise exception 'Status tidak valid';end if;
 insert into attendance(student_id,term_id,class_id,student_name,nisn,class_name,day,slot,status,actor,method)
 values(st.id,s.active_term,c.id,st.name,st.nisn,c.name,d,sl,p_status,auth.uid(),case when p_qr is null then 'MANUAL' else 'QR' end)
 on conflict(student_id,term_id,day,slot) do nothing returning * into a;
 if a.id is null then select * into a from attendance where student_id=st.id and term_id=s.active_term and day=d and slot=sl;dup:=true;
 else
 select * into teacher from profiles where id=c.teacher_id and active;
 for recipient in select distinct phone from (select st.parent_phone phone where s.notify_parents union select teacher.phone where s.notify_teacher) p where phone is not null and phone<>'' loop
 insert into outbox(attendance_id,phone,message) values(a.id,recipient.phone,s.name||E'\nInformasi presensi\nNama: '||st.name||E'\nKelas: '||c.name||E'\nSesi: '||sl||E'\nStatus: '||p_status||E'\nWaktu: '||to_char(now() at time zone s.timezone,'DD-MM-YYYY HH24:MI')||' ('||s.timezone||')');
 end loop;
 insert into audit(actor,action,detail) values(auth.uid(),'ATTENDANCE',a.id::text);
 end if;
 return jsonb_build_object('duplicate',dup,'record',to_jsonb(a));
end$$;

create function public.dashboard() returns jsonb language plpgsql stable security definer set search_path=public as $$declare d date;begin
 if not public.is_admin() then raise exception 'Akses ditolak';end if;
 select (now() at time zone timezone)::date into d from settings where id=1;
 return jsonb_build_object('day',d,'students',(select count(*) from students where active),'classes',(select count(*) from classes where active),'today',(select count(*) from attendance where day=d),'pending',(select count(*) from outbox where status='PENDING'),'statuses',(select coalesce(jsonb_object_agg(status,n),'{}') from(select status,count(*) n from attendance where day=d group by status)x));
end$$;

-- Reservation commits before the HTTP request. UNKNOWN is never retried automatically.
create function public.claim_notice() returns jsonb language plpgsql security definer set search_path=public as $$
declare s settings;w wa_state;n outbox;d date;tm time;
begin
 perform pg_advisory_xact_lock(8120);
 select * into s from settings where id=1;select * into w from wa_state where id=1 for update;
 d:=(now() at time zone s.timezone)::date;tm:=(now() at time zone s.timezone)::time;
 if s.wa_paused or w.blocked<>'' then return null;end if;
 if w.day is distinct from d then w.day:=d;w.attempts:=0;end if;
 if tm<s.wa_start or tm>s.wa_end or w.attempts>=s.wa_daily_limit or w.last_at>now()-make_interval(secs=>s.wa_min_seconds) then return null;end if;
 update outbox set status='EXPIRED' where status='PENDING' and created_at<now()-make_interval(hours=>s.wa_expiry_hours);
 select * into n from outbox o where o.status='PENDING' and not exists(select 1 from outbox x where x.phone=o.phone and x.attempted_at>now()-make_interval(mins=>s.wa_recipient_minutes)) order by created_at,id limit 1 for update skip locked;
 if n.id is null then return null;end if;
 update wa_state set day=d,attempts=w.attempts+1,last_at=now() where id=1;
 update outbox set status='UNKNOWN',attempted_at=now(),attempts=attempts+1 where id=n.id;
 return to_jsonb(n);
end$$;
create function public.finish_notice(p_id uuid,p_status text,p_error text,p_block text default '') returns void language plpgsql security definer set search_path=public as $$begin
 perform pg_advisory_xact_lock(8120);
 if p_status not in ('SENT','FAILED','UNKNOWN') then raise exception 'Invalid status';end if;
 update outbox set status=p_status,error=left(p_error,300) where id=p_id and status='UNKNOWN';
 if p_block<>'' then update wa_state set blocked=p_block where id=1;end if;
end$$;
create function public.retry_notice(p_id uuid) returns void language plpgsql security definer set search_path=public as $$begin
 if not public.is_admin() then raise exception 'Akses ditolak';end if;perform pg_advisory_xact_lock(8120);
 update outbox set status='PENDING',error='' where id=p_id and status in('FAILED','UNKNOWN') and attempts<3 and created_at>now()-make_interval(hours=>(select wa_expiry_hours from settings where id=1));
 if not found then raise exception 'Pesan kedaluwarsa, tidak sesuai status, atau batas 3 percobaan';end if;
 insert into audit(actor,action,detail) values(auth.uid(),'RETRY_NOTICE',p_id::text);
end$$;
create function public.resume_wa() returns void language plpgsql security definer set search_path=public as $$begin
 if not public.is_admin() then raise exception 'Akses ditolak';end if;
 update wa_state set blocked='' where id=1;insert into audit(actor,action) values(auth.uid(),'RESUME_WA');
end$$;

create function public.backup_payload() returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('format','REEV-2','exported_at',now(),'terms',(select coalesce(jsonb_agg(t order by id),'[]') from terms t),'classes',(select coalesce(jsonb_agg(t order by id),'[]') from classes t),'students',(select coalesce(jsonb_agg(t order by id),'[]') from students t),'settings',(select to_jsonb(t) from settings t where id=1),'attendance',(select coalesce(jsonb_agg(t order by id),'[]') from attendance t),'outbox',(select coalesce(jsonb_agg(t order by id),'[]') from outbox t),'profiles_info',(select coalesce(jsonb_agg(t order by id),'[]') from profiles t));
$$;
create function public.operational_fingerprint() returns text language sql stable security definer set search_path=public as $$select md5(coalesce((select jsonb_agg(a order by id)::text from attendance a),'[]')||coalesce((select jsonb_agg(o order by id)::text from outbox o),'[]'))$$;
create function public.create_backup() returns jsonb language plpgsql security definer set search_path=public as $$declare b jsonb;receipt uuid;begin
 if not public.is_admin() then raise exception 'Akses ditolak';end if;perform pg_advisory_xact_lock(8120);
 b:=backup_payload(); if octet_length(b::text)>3000000 then raise exception 'Backup >3 MB. Gunakan pg_dump Supabase; reset aplikasi diblokir';end if;
 delete from backup_receipts where expires_at<now();
 insert into backup_receipts(actor,fingerprint) values(auth.uid(),operational_fingerprint()) returning id into receipt;
 return jsonb_build_object('payload',b,'receipt',receipt);
end$$;
create function public.check_receipt(p_receipt uuid) returns void language plpgsql security definer set search_path=public as $$begin
 if not public.is_admin() then raise exception 'Akses ditolak';end if;
 if not exists(select 1 from backup_receipts where id=p_receipt and actor=auth.uid() and not used and expires_at>now() and fingerprint=operational_fingerprint()) then raise exception 'Unduh backup baru: data berubah atau bukti backup kedaluwarsa';end if;
 update backup_receipts set used=true where id=p_receipt;
end$$;
create function public.reset_operations(p_receipt uuid) returns void language plpgsql security definer set search_path=public as $$begin
 perform pg_advisory_xact_lock(8120);perform check_receipt(p_receipt);
 delete from attendance;update settings set wa_paused=true where id=1;
 insert into audit(actor,action) values(auth.uid(),'RESET_OPERATIONS');
end$$;
create function public.restore_backup(p_receipt uuid,p_data jsonb) returns void language plpgsql security definer set search_path=public as $$begin
 perform pg_advisory_xact_lock(8120);perform check_receipt(p_receipt);
 if p_data->>'format' is distinct from 'REEV-2' or octet_length(p_data::text)>3000000 then raise exception 'Format/ukuran backup tidak valid';end if;
 if jsonb_typeof(p_data->'terms') is distinct from 'array' or jsonb_typeof(p_data->'classes') is distinct from 'array' or jsonb_typeof(p_data->'students') is distinct from 'array' or jsonb_typeof(p_data->'attendance') is distinct from 'array' or jsonb_typeof(p_data->'outbox') is distinct from 'array' or jsonb_typeof(p_data->'settings') is distinct from 'object' then raise exception 'Backup tidak lengkap';end if;
 -- Same-project restore: auth accounts are retained; foreign keys validate their IDs.
 delete from attendance;delete from students;delete from classes;update settings set active_term=null;delete from terms;
 insert into terms select * from jsonb_populate_recordset(null::terms,p_data->'terms');
 insert into classes select * from jsonb_populate_recordset(null::classes,p_data->'classes');
 insert into students select * from jsonb_populate_recordset(null::students,p_data->'students');
 delete from settings;insert into settings select * from jsonb_populate_record(null::settings,p_data->'settings');
 insert into attendance select * from jsonb_populate_recordset(null::attendance,p_data->'attendance');
 insert into outbox select * from jsonb_populate_recordset(null::outbox,p_data->'outbox');
 update outbox set status='CANCELLED',error='Dibatalkan saat pemulihan; tidak dikirim ulang';
 update settings set wa_paused=true;
 insert into audit(actor,action) values(auth.uid(),'RESTORE_BACKUP');
end$$;

-- PostgreSQL grants EXECUTE to PUBLIC by default. Explicit allowlist only.
revoke all on all functions in schema public from public,anon,authenticated;
grant execute on function public.is_active(),public.is_admin(),public.record_attendance(text,uuid,text),public.dashboard(),public.retry_notice(uuid),public.resume_wa(),public.create_backup(),public.reset_operations(uuid),public.restore_backup(uuid,jsonb) to authenticated;
grant execute on function public.claim_notice(),public.finish_notice(uuid,text,text,text) to service_role;
commit;
