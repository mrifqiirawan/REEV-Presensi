import {timingSafeEqual} from 'node:crypto';
import {service,adminRequest,fail} from '../server/shared.js';
export const config={maxDuration:30};
export default async function handler(req,res){res.setHeader('Cache-Control','no-store');try{
 let db;const expected=process.env.CRON_SECRET;const sent=(req.headers.authorization||'').replace(/^Bearer /,'');const valid=expected&&sent.length===expected.length&&timingSafeEqual(Buffer.from(sent),Buffer.from(expected));
 if(req.method==='GET'&&valid)db=service();else if(req.method==='POST')({db}=await adminRequest(req));else return res.status(401).json({error:'Unauthorized'});
 const origin=process.env.REEV_GATEWAY_URL,key=process.env.REEV_API_KEY;
 if(!origin||!key)return res.json({processed:0,reason:'Konfigurasi gateway belum lengkap'});
 const u=new URL(origin);if(u.protocol!=='https:'||u.username||u.password||u.pathname!=='/'||u.search||u.hash)throw new Error('Gateway wajib origin HTTPS tanpa path');
 const {data:n,error}=await db.rpc('claim_notice');if(error)throw error;if(!n)return res.json({processed:0,reason:'Antrean kosong, dijeda, atau terkena batas pengiriman'});
 let status='UNKNOWN',message='',block='';
 try{const r=await fetch(u.origin+'/api/messages/send',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${key}`,'Idempotency-Key':n.id},body:JSON.stringify({recipient:n.phone,message:n.message,deviceId:process.env.REEV_DEVICE_ID||'device_primary'}),signal:AbortSignal.timeout(15000),redirect:'error'});
 if([401,403,429].includes(r.status))block='HTTP '+r.status;
 let body={};try{body=await r.json();}catch{}
 status=r.ok&&body.success===true?'SENT':r.status>=400&&r.status<500?'FAILED':'UNKNOWN';message=status==='SENT'?'':`Gateway HTTP ${r.status}. Periksa log sebelum mengulang.`;
 }catch{message='Hasil belum pasti (timeout/koneksi). Periksa gateway sebelum mengulang.';}
 const {error:fe}=await db.rpc('finish_notice',{p_id:n.id,p_status:status,p_error:message,p_block:block});if(fe)throw fe;
 return res.json({processed:1,status});
 }catch(e){return fail(res,e);}}
