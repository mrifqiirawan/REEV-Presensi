import {useEffect,useRef,useState} from 'react';

// One AudioContext per mounted scanner. Unlock it with a user gesture.
export function useScanSound(){
 const context=useRef(null),[ready,setReady]=useState(false),[message,setMessage]=useState('Ketuk Aktifkan suara sekali sebelum memindai.');
 function play(){
  const c=context.current;
  if(!c||c.state!=='running')return;
  try{
   const start=c.currentTime;
   [880,1174].forEach((frequency,i)=>{
    const osc=c.createOscillator(),gain=c.createGain(),at=start+i*0.13;
    osc.type='sine';osc.frequency.value=frequency;
    gain.gain.setValueAtTime(0,at);gain.gain.linearRampToValueAtTime(0.18,at+0.015);
    gain.gain.exponentialRampToValueAtTime(0.001,at+0.16);
    osc.connect(gain);gain.connect(c.destination);osc.start(at);osc.stop(at+0.18);
    osc.onended=()=>{osc.disconnect();gain.disconnect()};
   });
  }catch{/* Audio must never turn a saved attendance into an error. */}
 }
 async function enable(){
  try{
   const Audio=window.AudioContext||window.webkitAudioContext;
   if(!Audio)throw new Error('Browser ini belum mendukung suara scan.');
   if(!context.current||context.current.state==='closed'){
    const c=new Audio();context.current=c;
    c.onstatechange=()=>{setReady(c.state==='running');if(c.state!=='running')setMessage('Ketuk Aktifkan suara untuk melanjutkan bunyi scan.')};
   }
   await context.current.resume();
   const enabled=context.current.state==='running';setReady(enabled);
   setMessage(enabled?'Bunyi aktif untuk presensi baru yang berhasil tersimpan.':'Ketuk kembali Aktifkan suara.');
   if(enabled)play();
  }catch(e){setReady(false);setMessage(e.message||'Suara belum aktif. Ketuk kembali tombol suara.')}
 }
 useEffect(()=>()=>{const c=context.current;context.current=null;if(c){c.onstatechange=null;c.close().catch(()=>{})}},[]);
 return {ready,message,enable,play};
}
