const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../WindowsPreview/core.js');
const valid = {done:true,kind:'working',weight:60,reps:8};
const detail = sets => ({mode:'detailed',exercises:[{id:1,name:'卧推',loading:'total',estimate:true,sets}]});
test('only completed valid formal sets contribute to sets and volume',()=>{
  const s=detail([valid,{...valid,kind:'warmup'},{...valid,kind:'drop'},{...valid,kind:'failed'},{...valid,done:false},{...valid,reps:0},{...valid,weight:-1},{...valid,weight:NaN}]);
  assert.equal(C.workingSets(s),1);assert.equal(C.volume(s),480);
});
test('per-hand volume doubles external load; bodyweight does not invent load',()=>{
  const s=detail([valid]);s.exercises[0].loading='perHand';assert.equal(C.volume(s),960);
  s.exercises[0].loading='bodyweight';assert.equal(C.volume(s),0);
});
test('wall clock elapsed time freezes when paused and resumes after a restart',()=>{
  const s={mode:'detailed',elapsed:20,runningSince:10000};assert.equal(C.elapsed(s,15000),25);
  s.elapsed=C.elapsed(s,15000);s.runningSince=null;assert.equal(C.elapsed(s,90000),25);
  s.runningSince=100000;assert.equal(C.elapsed(JSON.parse(JSON.stringify(s)),110000),35);
});
test('rest moves to ready at its deadline and is not restarted by rendering',()=>{
  const s={mode:'detailed',runningSince:10,restDeadline:1000};assert.equal(C.phase(s,999),'resting');assert.equal(C.phase(s,1000),'ready');assert.equal(C.phase(s,3000),'ready');
  s.restDeadline=null;assert.equal(C.phase(s,4000),'training');s.runningSince=null;assert.equal(C.phase(s,4000),'paused');assert.equal(C.phase(null),'idle');
});
test('local dates survive year boundaries, leap years and early years',()=>{
  assert.equal(C.dayKey(C.addDays(C.parseDay('2024-02-28'),1)),'2024-02-29');
  assert.equal(C.dayKey(C.addDays(C.parseDay('2026-12-31'),1)),'2027-01-01');
  assert.equal(C.dayKey(C.parseDay('0042-01-02')),'0042-01-02');assert.equal(C.parseDay('2025-02-29'),null);
});
test('calendar weeks contain seven distinct local days across DST',()=>{
  for(const date of ['2026-03-08','2026-11-01']) {const days=C.weekDays(C.parseDay(date));assert.equal(days.length,7);assert.equal(new Set(days.map(C.dayKey)).size,7);assert.equal(days[0].getDay(),1);}
});
test('calendar and weekly totals exclude drafts and stale deleted records',()=>{
  const sessions=[{status:'completed',day:'2026-10-17'},{status:'draft',day:'2026-10-17'},{status:'completed',day:'2026-10-11'}];
  assert.equal(C.recordsOn(sessions,C.parseDay('2026-10-17')).length,1);assert.equal(C.recordsInWeek(sessions,C.parseDay('2026-10-17')).length,1);
  assert.equal(C.recordsOn(sessions.slice(1),C.parseDay('2026-10-17')).length,0);
});
test('strength estimates use eligible completed sets and ignore quick records',()=>{
  const s={...detail([valid,{...valid,reps:13}]),status:'completed',day:'2026-10-17'};
  assert.equal(C.bestEstimates([s])[0].value,76);assert.deepEqual(C.bestEstimates([{...s,status:'draft'}]),[]);
  s.exercises[0].estimate=false;assert.deepEqual(C.bestEstimates([s]),[]);
});
