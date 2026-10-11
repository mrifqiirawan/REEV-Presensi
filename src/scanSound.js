import {useEffect,useState} from 'react';
let context=null,installed=false,resuming=false;
const listeners=new Set();
const state=()=>context?.state==='running';
const publish=()=>listeners.forEach(fn=>fn(state()));
export function unlockScanAudio(){
 try{
  const Audio=window.AudioContext||window.webkitAudioContext;
  if(!Audio)return;
  if(!context||context.state==='closed'){
   context=new Audio();context.onstatechange=publish;
  }
  if(context.state!=='running'&&!resuming){
   resuming=true;
   context.resume().then(publish).catch(()=>{}).finally(()=>{resuming=false});
   // Allow a subsequent genuine user gesture even if autoplay resume stays pending.
   setTimeout(()=>{resuming=false},500);
  }
  publish();
 }catch{/* Visual feedback remains available. */}
}
export function installScanAudio(){
 if(installed)return;installed=true;
 for(const event of ['pointerdown','touchend','keydown','click'])document.addEventListener(event,unlockScanAudio,{capture:true,passive:true});
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)unlockScanAudio()});
 // Automatic when the browser permits it; login/navigation gestures unlock otherwise.
 unlockScanAudio();
}
function play(){
 unlockScanAudio();
 if(!state())return;
 try{
  const c=context,start=c.currentTime;
  [880,1174].forEach((frequency,i)=>{
   const osc=c.createOscillator(),gain=c.createGain(),at=start+i*0.13;
   osc.type='sine';osc.frequency.value=frequency;
   gain.gain.setValueAtTime(0,at);gain.gain.linearRampToValueAtTime(0.18,at+0.015);
   gain.gain.exponentialRampToValueAtTime(0.001,at+0.16);
   osc.connect(gain);gain.connect(c.destination);osc.start(at);osc.stop(at+0.18);
   osc.onended=()=>{osc.disconnect();gain.disconnect()};
  });
 }catch{}
}
export function useScanSound(){
 const [ready,setReady]=useState(state);
 useEffect(()=>{listeners.add(setReady);unlockScanAudio();return()=>listeners.delete(setReady)},[]);
 return {ready,play,message:ready?'Suara scan aktif otomatis.':'Jika browser membatasi suara, sentuh bagian mana saja pada halaman. Tidak perlu tombol aktivasi khusus.'};
}
