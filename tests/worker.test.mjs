import {test} from 'node:test';import assert from 'node:assert/strict';
import handler from '../api/wa-worker.js';
function response(){return {statusCode:200,body:null,setHeader(){},status(n){this.statusCode=n;return this},json(b){this.body=b;return this}}}
test('WA endpoint rejects unauthenticated calls before database access',async()=>{const r=response();await handler({method:'GET',headers:{}},r);assert.equal(r.statusCode,401)});
test('WA endpoint handles success, 429 block, timeout, and missing config without duplicate retry',async()=>{
 Object.assign(process.env,{SUPABASE_URL:'https://unit.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'unit-key',CRON_SECRET:'unit-cron-secret',REEV_GATEWAY_URL:'https://gateway.test',REEV_API_KEY:'unit-api-key'});
 const original=globalThis.fetch;let mode='success',claimed=0,finish=[],sent=0;
 globalThis.fetch=async(input,options={})=>{const url=String(input);if(url.includes('/rpc/reserve_notice_v201')){claimed++;return new Response(JSON.stringify({code:'CLAIMED',job:{id:'notice-id',phone:'628123456789',message:'Hadir'}}),{headers:{'Content-Type':'application/json'}})}if(url.includes('/rpc/finish_notice')){finish.push(JSON.parse(options.body));return new Response(null,{status:204})}if(url==='https://gateway.test/api/messages/send'){sent++;assert.equal(options.headers['Idempotency-Key'],'notice-id');assert.equal(options.redirect,'error');assert.equal(JSON.parse(options.body).recipient,'628123456789');if(mode==='timeout')throw new Error('timeout');return new Response(JSON.stringify({success:mode==='success'}),{status:mode==='blocked'?429:200})}throw new Error('Unexpected fetch '+url)};
 try{for(const m of ['success','blocked','timeout']){mode=m;const r=response();await handler({method:'GET',headers:{authorization:'Bearer unit-cron-secret'}},r);assert.equal(r.statusCode,200);assert.equal(r.body.processed,1)}assert.equal(sent,3);assert.deepEqual(finish.map(f=>f.p_status),['SENT','FAILED','UNKNOWN']);assert.equal(finish[1].p_block,'HTTP 429');
 delete process.env.REEV_API_KEY;const r=response();await handler({method:'GET',headers:{authorization:'Bearer unit-cron-secret'}},r);assert.equal(r.body.processed,0);assert.equal(claimed,3,'Missing config must not consume a reservation');
 }finally{globalThis.fetch=original}
});
