import {createClient} from '@supabase/supabase-js';
export const configured=!!(import.meta.env.VITE_SUPABASE_URL&&import.meta.env.VITE_SUPABASE_ANON_KEY);
export const db=configured?createClient(import.meta.env.VITE_SUPABASE_URL,import.meta.env.VITE_SUPABASE_ANON_KEY):null;
export async function result(q){const {data,error}=await q;if(error)throw new Error(error.message);return data;}
export const rpc=(name,args={})=>result(db.rpc(name,args));
export async function server(path,body={}){const {data}=await db.auth.getSession();if(!data.session)throw new Error('Silakan login kembali');const r=await fetch('/api/'+path,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+data.session.access_token},body:JSON.stringify(body)});const j=await r.json();if(!r.ok)throw new Error(j.error||'Permintaan gagal');return j;}
export function download(name,content,type='application/json'){const u=URL.createObjectURL(new Blob([content],{type}));const a=document.createElement('a');a.href=u;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(u),20000);}
export function localDate(tz='Asia/Makassar'){const p=new Intl.DateTimeFormat('en-CA',{timeZone:tz,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());const value=k=>p.find(x=>x.type===k).value;return `${value('year')}-${value('month')}-${value('day')}`;}
