-- v2.0.2. Run after 003. No operational data is deleted by this migration.
begin;
create or replace function public.default_notice_template() returns text
language sql immutable set search_path=public as $$select E'{aplikasi}\nInformasi presensi\nNama: {nama}\nKelas: {kelas}\nSesi: {sesi}\nStatus: {status}\nWaktu: {waktu} ({zona_waktu})'$$;
alter table public.settings add column if not exists wa_message_template text not null default public.default_notice_template();
alter table public.settings drop constraint if exists settings_wa_message_template_check;
alter table public.settings add constraint settings_wa_message_template_check check(length(trim(wa_message_template)) between 1 and 3000);
-- Single pass: tokens inside a student's name are not interpreted again.
create or replace function public.render_notice_template(p_template text,p_values jsonb) returns text
language plpgsql immutable set search_path=public as $$
declare part text[];output text:='';token text;
begin
 for part in select regexp_matches(p_template,'(\{[^{}]*\}|[^{}]+|[{}])','g') loop
  token:=substring(part[1] from 2 for greatest(length(part[1])-2,0));
  output:=output||case when left(part[1],1)='{' and right(part[1],1)='}' and p_values ? token then coalesce(p_values->>token,'') else part[1] end;
 end loop;
 return output;
end$$;
create or replace function public.reset_operations(p_receipt uuid) returns void language plpgsql security definer set search_path=public as $$begin
 perform pg_advisory_xact_lock(8120);perform check_receipt(p_receipt);
 if exists(select 1 from outbox where attempted_at>clock_timestamp()-interval '30 seconds') then raise exception 'Tunggu 30 detik setelah pemrosesan WhatsApp sebelum reset/pemulihan, lalu buat backup baru bila data berubah';end if;
 delete from attendance where id is not null;
 insert into audit(actor,action) values(auth.uid(),'RESET_OPERATIONS');
end$$;
create or replace function public.restore_backup(p_receipt uuid,p_data jsonb) returns void language plpgsql security definer set search_path=public as $$begin
 perform pg_advisory_xact_lock(8120);perform check_receipt(p_receipt);
 if exists(select 1 from outbox where attempted_at>clock_timestamp()-interval '30 seconds') then raise exception 'Tunggu 30 detik setelah pemrosesan WhatsApp sebelum reset/pemulihan, lalu buat backup baru bila data berubah';end if;
 if p_data->>'format' is distinct from 'REEV-2' or octet_length(p_data::text)>3000000 then raise exception 'Format/ukuran backup tidak valid';end if;
 if jsonb_typeof(p_data->'terms') is distinct from 'array' or jsonb_typeof(p_data->'classes') is distinct from 'array' or jsonb_typeof(p_data->'students') is distinct from 'array' or jsonb_typeof(p_data->'attendance') is distinct from 'array' or jsonb_typeof(p_data->'outbox') is distinct from 'array' or jsonb_typeof(p_data->'settings') is distinct from 'object' then raise exception 'Backup tidak lengkap';end if;
 -- Same-project restore: auth accounts are retained; foreign keys validate their IDs.
 delete from attendance where id is not null;delete from students where id is not null;delete from classes where id is not null;update settings set active_term=null where id=1;delete from terms where id is not null;
 insert into terms select * from jsonb_populate_recordset(null::terms,p_data->'terms');
 insert into classes select * from jsonb_populate_recordset(null::classes,p_data->'classes');
 insert into students select * from jsonb_populate_recordset(null::students,p_data->'students');
 delete from settings where id is not null;insert into settings select * from jsonb_populate_record(null::settings,jsonb_build_object('wa_message_template',public.default_notice_template())||(p_data->'settings'));
 insert into attendance select * from jsonb_populate_recordset(null::attendance,p_data->'attendance');
 insert into outbox select * from jsonb_populate_recordset(null::outbox,p_data->'outbox');
 update outbox set status='CANCELLED',error='Dibatalkan saat pemulihan; tidak dikirim ulang' where id is not null;
 update settings set wa_paused=true where id=1;
 insert into audit(actor,action) values(auth.uid(),'RESTORE_BACKUP');
end$$;
create or replace function public.record_attendance(p_qr text default null,p_student uuid default null,p_status text default 'HADIR') returns jsonb language plpgsql security definer set search_path=public as $$
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
 insert into outbox(attendance_id,phone,message) values(a.id,recipient.phone,public.render_notice_template(s.wa_message_template,jsonb_build_object('aplikasi',s.name,'sekolah',s.school,'nama',st.name,'kelas',c.name,'sesi',sl,'status',p_status,'waktu',to_char(now() at time zone s.timezone,'DD-MM-YYYY HH24:MI'),'zona_waktu',s.timezone,'orang_tua',st.parent_name)));
 end loop;
 insert into audit(actor,action,detail) values(auth.uid(),'ATTENDANCE',a.id::text);
 end if;
 return jsonb_build_object('duplicate',dup,'record',to_jsonb(a));
end$$;
-- Fire after commit through pg_net; network failures never undo attendance.
create or replace function public.wake_notice_worker() returns trigger
language plpgsql security definer set search_path=public as $$
declare worker_url text;worker_secret text;
begin
 if not exists(select 1 from new_notices where status='PENDING') then return null;end if;
 if (select wa_paused from settings where id=1) then return null;end if;
 begin
  execute 'select decrypted_secret from vault.decrypted_secrets where name=$1' into worker_url using 'reev_worker_url';
  execute 'select decrypted_secret from vault.decrypted_secrets where name=$1' into worker_secret using 'reev_cron_secret';
  if coalesce(worker_url,'')='' or coalesce(worker_secret,'')='' then
   insert into audit(actor,action,detail) values(auth.uid(),'WA_AUTO_CONFIG','Isi Vault reev_worker_url dan reev_cron_secret; pesan tetap PENDING.');
   return null;
  end if;
  if worker_url !~ '^https://[^/?#]+/api/wa-worker$' then raise exception 'Invalid worker URL';end if;
  execute 'select net.http_get(url := $1, headers := $2, timeout_milliseconds := 25000)'
   using worker_url,jsonb_build_object('Authorization','Bearer '||worker_secret);
 exception when others then
  insert into audit(actor,action,detail) values(auth.uid(),'WA_AUTO_UNAVAILABLE','Pemicu otomatis belum tersedia. Periksa pg_net dan Vault; pesan tetap PENDING.');
 end;
 return null;
end$$;
drop trigger if exists outbox_wake_worker on public.outbox;
create trigger outbox_wake_worker after insert on public.outbox referencing new table as new_notices for each statement execute function public.wake_notice_worker();
revoke all on function public.wake_notice_worker(),public.render_notice_template(text,jsonb),public.default_notice_template() from public,anon,authenticated;
grant execute on function public.default_notice_template() to authenticated,service_role;
-- Existing record/reset/restore grants are preserved by CREATE OR REPLACE.
commit;
