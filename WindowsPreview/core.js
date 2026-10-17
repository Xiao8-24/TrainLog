(function (root, factory) {
  const value = factory();
  if (typeof module === 'object' && module.exports) module.exports = value;
  else root.TrainLogCore = value;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const localDate = (year, month, day) => { const d = new Date(0); d.setFullYear(year, month, day); d.setHours(0, 0, 0, 0); return d; };
  const dayKey = value => { const d = new Date(value); return `${String(d.getFullYear()).padStart(4, '0')}-${String(d.getMonth()+1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };
  const parseDay = value => { if (!/^\d{4}-\d{2}-\d{2}$/.test(value || '')) return null; const [y,m,d] = value.split('-').map(Number); const result=localDate(y,m-1,d); return dayKey(result) === value ? result : null; };
  const addDays = (value, amount) => { const d = new Date(value); d.setDate(d.getDate()+amount); return d; };
  const weekDays = value => { const d = parseDay(dayKey(value)); d.setDate(d.getDate()-(d.getDay()+6)%7); return Array.from({length:7},(_,i)=>addDays(d,i)); };
  const elapsed = (session, now=Date.now()) => Math.max(0, Number(session?.elapsed || 0)+(session?.runningSince ? (now-session.runningSince)/1000 : 0));
  const validWorkingSet = set => set.done && set.kind === 'working' && Number.isFinite(set.reps) && set.reps > 0 && Number.isFinite(set.weight) && set.weight >= 0;
  const workingSets = session => session?.mode === 'detailed' ? (session.exercises || []).reduce((n,e)=>n+e.sets.filter(validWorkingSet).length,0) : 0;
  const volume = session => (session.exercises || []).reduce((n,e)=>n+e.sets.filter(validWorkingSet).reduce((v,s)=>v+(e.loading === 'total' || e.loading === 'perHand' ? s.weight*s.reps*(e.loading === 'perHand' ? 2 : 1) : 0),0),0);
  const completed = sessions => sessions.filter(s=>s.status === 'completed');
  const recordsOn = (sessions, day) => completed(sessions).filter(s=>s.day === dayKey(day));
  const recordsInWeek = (sessions, date) => { const keys = new Set(weekDays(date).map(dayKey)); return completed(sessions).filter(s=>keys.has(s.day)); };
  const phase = (draft, now=Date.now()) => { if (!draft || draft.mode !== 'detailed') return 'idle'; if (draft.restDeadline) return draft.restDeadline > now ? 'resting' : 'ready'; return draft.runningSince ? 'training' : 'paused'; };
  const clock = seconds => { const n=Math.max(0,Math.floor(seconds)); return n>=3600 ? `${Math.floor(n/3600)}:${String(Math.floor(n/60)%60).padStart(2,'0')}:${String(n%60).padStart(2,'0')}` : `${Math.floor(n/60)}:${String(n%60).padStart(2,'0')}`; };
  const bestEstimates = sessions => { const best = new Map(); for(const s of completed(sessions)) for(const e of s.exercises || []) { if(!e.estimate) continue; for(const set of e.sets.filter(validWorkingSet)) { if(set.reps > 12 || set.weight <= 0) continue; const estimate=set.weight*(1+set.reps/30); if(!best.has(e.id) || estimate>best.get(e.id).value) best.set(e.id,{name:e.name,value:estimate,weight:set.weight,reps:set.reps,day:s.day}); } } return [...best.values()].sort((a,b)=>b.value-a.value); };
  return {localDate,dayKey,parseDay,addDays,weekDays,elapsed,validWorkingSet,workingSets,volume,completed,recordsOn,recordsInWeek,phase,clock,bestEstimates};
});
