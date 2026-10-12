import {test} from 'node:test';
import assert from 'node:assert/strict';
import Papa from 'papaparse';
import {parseImportCsv} from '../src/csvImport.js';
const base={nisn:'0012345670',name:'Siswa Contoh',birthDate:'2/8/2014',contact:'081234567800',address:'Alamat, contoh\nBaris kedua',parentName:'Wali "Contoh"',qr:''};
const parse=(rows, options={})=>parseImportCsv('\ufeff'+Papa.unparse(rows,options),{classId:'kelas-uji'});
test('Quoted NISN and WA retain zeros; CSV delimiters, BOM, multiline and names survive',()=>{
 for(const delimiter of [',',';']) for(const quoted of [true,false]) {
  const r={...base,nisn:quoted?'"'+base.nisn+'"':base.nisn,contact:quoted?'"'+base.contact+'"':base.contact};
  const out=parse([r],{delimiter}); assert.deepEqual(out.errors,[]);
  assert.equal(out.rows[0].nisn,'0012345670');assert.equal(out.rows[0].parent_phone,'6281234567800');
  assert.equal(out.rows[0].birth_date,'2014-02-08');assert.equal(out.rows[0].address,base.address);
  assert.equal(out.rows[0].parent_name,base.parentName);assert.equal('qr' in out.rows[0],false);
 }
});
test('ISO dates, leap days, empty optional values and aliases',()=>{
 for(const [input,expected] of [['11/30/2013','2013-11-30'],['2/29/2012','2012-02-29'],['2014-02-08','2014-02-08'],['',null]]) {
  const out=parse([{...base,birthDate:input,contact:'"6281234567800"'}]);assert.deepEqual(out.errors,[]);
  assert.equal(out.rows[0].birth_date,expected);assert.equal(out.rows[0].parent_phone,'6281234567800');
 }
 const out=parse([{nisn:base.nisn,name:base.name,birth_date:'2014-02-08',parent_phone:'"081234567800"'}]);
 assert.equal(out.rows[0].parent_phone,'6281234567800');assert.equal(out.rows[0].birth_date,'2014-02-08');
 assert.equal(parse([{...base,contact:''}]).rows[0].parent_phone,'');
});
test('Invalid identifiers, formulas and impossible dates remain rejected atomically',()=>{
 for(const patch of [{nisn:'"123456789"'},{nisn:'"00123a5670"'},{nisn:'="0012345670"'},{nisn:'"0012345670'},{contact:'"62abc12345678"'},{contact:'=1+2'},{birthDate:'2/29/2013'},{birthDate:'4/31/2014'},{birthDate:'30/11/2013'}]) {
  const out=parse([{...base,...patch}]);assert.equal(out.rows.length,0);assert.ok(out.errors.length);assert.match(out.errors[0],/Baris 2/);
 }
});
test('Duplicate identifiers are detected after normalization',()=>{
 const out=parse([base,{...base,nisn:'"'+base.nisn+'"'}]);assert.deepEqual(out.rows,[]);assert.match(out.errors.join(),/berulang/);
});
test('Teachers accept quoted phone but preserve password and role rules',()=>{
 const out=parseImportCsv(Papa.unparse([{username:'guru.uji',name:'Guru Uji',password:'"password-panjang"',phone:'"081234567800"',role:'ADMIN'}]),{students:false});
 assert.deepEqual(out.errors,[]);assert.equal(out.rows[0].phone,'6281234567800');assert.equal(out.rows[0].password,'"password-panjang"');assert.equal(out.rows[0].role,'GURU');
});
