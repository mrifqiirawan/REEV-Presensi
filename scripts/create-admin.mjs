import {createClient} from '@supabase/supabase-js';
import readline from 'node:readline/promises';
import {Writable} from 'node:stream';
import {teacherRow,usernameEmail} from '../src/domain.js';
let hidden=false;const out=new Writable({write(chunk,encoding,done){if(!hidden)process.stdout.write(chunk);done();}});
const rl=readline.createInterface({input:process.stdin,output:out,terminal:true});
try{const username=await rl.question('Username admin: ');const name=await rl.question('Nama admin: ');process.stdout.write('Password (12–128 karakter, input tersembunyi): ');hidden=true;const password=await rl.question('');hidden=false;process.stdout.write('\n');const r=teacherRow({username,name,password,phone:''});
 if(!process.env.SUPABASE_URL||!process.env.SUPABASE_SERVICE_ROLE_KEY)throw new Error('Isi .env.local terlebih dahulu');
 const db=createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY,{auth:{persistSession:false}});
 const {data,error}=await db.auth.admin.createUser({email:usernameEmail(r.username),password:r.password,email_confirm:true});if(error)throw error;
 const {error:pe}=await db.from('profiles').insert({id:data.user.id,username:r.username,name:r.name,phone:'',role:'ADMIN',active:true});if(pe){await db.auth.admin.deleteUser(data.user.id);throw pe;}
 console.log('Admin berhasil dibuat. Login dengan username yang Anda masukkan.');
}catch(e){console.error(e.message);process.exitCode=1;}finally{rl.close();}
