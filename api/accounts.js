import {adminRequest,fail} from '../server/shared.js';
import {teacherRow,phone,usernameEmail} from '../src/domain.js';
export default async function handler(req,res){res.setHeader('Cache-Control','no-store');try{const {db,actor}=await adminRequest(req);const b=typeof req.body==='string'?JSON.parse(req.body):req.body;
 if(b.action==='create'){
 const r=teacherRow(b.user),role=b.user.role==='ADMIN'?'ADMIN':'GURU';
 const {data,error}=await db.auth.admin.createUser({email:usernameEmail(r.username),password:r.password,email_confirm:true});if(error)throw error;
 const {error:pe}=await db.from('profiles').insert({id:data.user.id,username:r.username,name:r.name,phone:r.phone,role,active:true});
 if(pe){await db.auth.admin.deleteUser(data.user.id);throw pe;}await db.from('audit').insert({actor:actor.id,action:'ACCOUNT_CREATE',detail:data.user.id});return res.json({ok:true,id:data.user.id});
 }
 if(b.action==='update'){
 if(!b.id)throw new Error('ID akun wajib');
 const {data:old,error:oe}=await db.from('profiles').select('*').eq('id',b.id).single();if(oe)throw oe;
 const patch={};if(b.name!==undefined){if(!b.name.trim()||b.name.length>120)throw new Error('Nama tidak valid');patch.name=b.name.trim();}if(b.phone!==undefined)patch.phone=phone(b.phone);
 if(b.role!==undefined){if(!['ADMIN','GURU'].includes(b.role))throw new Error('Peran tidak valid');patch.role=b.role;}if(b.active!==undefined){if(typeof b.active!=='boolean')throw new Error('Status tidak valid');patch.active=b.active;}
 if(b.id===actor.id&&((patch.active===false)||(patch.role&&patch.role!=='ADMIN')))throw new Error('Gunakan admin lain untuk mengubah akses akun sendiri');
 if(b.password&&(typeof b.password!=='string'||b.password.length<12||b.password.length>128))throw new Error('Password 12–128 karakter');
 // DB trigger serializes last-admin checks. Profile gate applies even to old JWTs.
 const {error}=await db.from('profiles').update(patch).eq('id',old.id);if(error)throw error;
 if(b.password){const {error:ae}=await db.auth.admin.updateUserById(old.id,{password:b.password});if(ae)throw ae;}
 await db.from('audit').insert({actor:actor.id,action:'ACCOUNT_UPDATE',detail:old.id});return res.json({ok:true});
 }
 throw new Error('Aksi akun tidak valid');
 }catch(e){return fail(res,e);}}
