import {timingSafeEqual} from 'node:crypto';
import {service,adminRequest,fail} from '../server/shared.js';
export const config={maxDuration:30};
function connectionMessage(e){
 const code=e?.cause?.code||e?.code||'';
 if(/CERT|TLS|SSL|SELF_SIGNED|UNABLE_TO_VERIFY/.test(code))return 'Sertifikat HTTPS gateway tidak valid atau tidak cocok dengan alamat host/IP. Pasang sertifikat tepercaya yang sesuai. Verifikasi TLS tetap aktif.';
 if(code==='ECONNREFUSED')return 'Koneksi gateway ditolak. Periksa layanan gateway dan akses port 3000 dari Vercel.';
 if(code==='ENOTFOUND'||code==='EAI_AGAIN')return 'Nama host gateway tidak ditemukan. Periksa REEV_GATEWAY_URL dan DNS.';
 return 'Hasil belum pasti (timeout/koneksi). Periksa log gateway sebelum mengulang agar pesan tidak ganda.';
}
export default async function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 try{
  let db;
  const expected=Buffer.from(process.env.CRON_SECRET||''),sent=Buffer.from((req.headers.authorization||'').replace(/^Bearer /,''));
  const valid=expected.length>0&&sent.length===expected.length&&timingSafeEqual(sent,expected);
  if(req.method==='GET'&&valid)db=service();
  else if(req.method==='POST')({db}=await adminRequest(req));
  else return res.status(401).json({error:'Unauthorized'});
  const origin=(process.env.REEV_GATEWAY_URL||'').trim(),key=(process.env.REEV_API_KEY||'').trim();
  if(!origin||!key)return res.json({processed:0,code:'CONFIG_MISSING',reason:'Isi REEV_GATEWAY_URL dan REEV_API_KEY pada environment Vercel, lalu redeploy.'});
  const u=new URL(origin);
  if(u.protocol!=='https:'||u.username||u.password||u.pathname!=='/'||u.search||u.hash)throw new Error('Gateway wajib origin HTTPS tanpa path, contoh https://103.253.244.29:3000');
  const {data:claim,error}=await db.rpc('reserve_notice_v201');
  if(error){if(error.code==='PGRST202'||error.code==='42883')throw new Error('Jalankan supabase/003_upgrade_v2_0_1.sql terlebih dahulu.');throw error;}
  if(!claim?.job)return res.json({processed:0,code:claim?.code||'NO_CLAIM',reason:claim?.reason||'Tidak ada pesan yang dapat diklaim.',retry_after_seconds:claim?.retry_after_seconds});
  const n=claim.job;
  let status='UNKNOWN',message='',block='';
  try{
   const r=await fetch(u.origin+'/api/messages/send',{
    method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${key}`,'Idempotency-Key':n.id},
    body:JSON.stringify({recipient:n.phone,message:n.message,deviceId:process.env.REEV_DEVICE_ID||'device_primary'}),
    signal:AbortSignal.timeout(15000),redirect:'error'
   });
   if([401,403,429].includes(r.status))block='HTTP '+r.status;
   let body=null;try{body=await r.json();}catch{}
   status=r.ok&&body?.success===true?'SENT':r.status>=400&&r.status<500&&r.status!==408?'FAILED':'UNKNOWN';
   if(status==='SENT')message='';
   else if([401,403].includes(r.status))message=`Gateway HTTP ${r.status}. Periksa API key, izin perangkat, dan REEV_DEVICE_ID; lalu buka blokir.`;
   else if(r.status===429)message='Gateway HTTP 429. Batas dari gateway tercapai. Tunggu sesuai kebijakan gateway lalu buka blokir.';
   else if(r.status===404)message='Gateway HTTP 404. Endpoint /api/messages/send tidak ditemukan. Cocokkan kontrak API gateway.';
   else if(r.ok)message='Gateway merespons tanpa success:true. Status UNKNOWN; cocokkan kontrak API dan periksa log sebelum mengulang.';
   else message=`Gateway HTTP ${r.status}. Periksa perangkat WhatsApp dan log gateway sebelum mengulang.`;
  }catch(e){message=connectionMessage(e);}
  const {error:finishError}=await db.rpc('finish_notice',{p_id:n.id,p_status:status,p_error:message,p_block:block});
  if(finishError)throw new Error('Hasil gateway belum dapat disimpan. Periksa status UNKNOWN dan log gateway sebelum mengulang.');
  return res.json({processed:1,status,reason:status==='SENT'?'Pesan diterima gateway.':message});
 }catch(e){return fail(res,e);}
}
