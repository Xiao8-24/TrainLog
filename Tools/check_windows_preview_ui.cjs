/* DOM integration checks for our own local preview; no browser profile is used. */
const {JSDOM,VirtualConsole}=require('../.tools/windows-preview-test/node_modules/jsdom');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const url=fs.readFileSync(path.join(__dirname,'../artifacts/windows-preview/preview-url.txt'),'utf8').trim();
const key='trainlog.windows.preview.v1';
const failures=[];
async function load(snapshot){
  const console=new VirtualConsole();console.on('jsdomError',error=>{if(error.type==='unhandled-exception')failures.push(error.message);});
  const dom=await JSDOM.fromURL(url,{runScripts:'dangerously',resources:'usable',pretendToBeVisual:true,virtualConsole:console,beforeParse(w){w.matchMedia=()=>({matches:false,addEventListener(){},removeEventListener(){}});if(snapshot)w.localStorage.setItem(key,snapshot);}});
  await new Promise((resolve,reject)=>{if(dom.window.document.readyState==='complete')return resolve();const timeout=setTimeout(()=>reject(new Error('Preview scripts did not load')),10000);dom.window.addEventListener('load',()=>{clearTimeout(timeout);resolve();},{once:true});});
  assert.equal(dom.window.document.querySelector('#app-header h2')?.textContent,'概览');
  return dom;
}
function click(dom,selector){const node=dom.window.document.querySelector(selector);assert(node,`Missing ${selector}`);node.click();return node;}
function change(dom,selector,value){const node=dom.window.document.querySelector(selector);assert(node,`Missing ${selector}`);node.value=value;node.dispatchEvent(new dom.window.Event('change',{bubbles:true}));}
const read=dom=>JSON.parse(dom.window.localStorage.getItem(key));
(async()=>{
  let dom=await load();const initial=dom.window.localStorage.getItem(key);assert.equal(read(dom).sessions.length,8);assert.equal(dom.window.document.querySelectorAll('.body-region').length,40);
  click(dom,'#startWorkout');assert.equal(dom.window.document.querySelector('[role=dialog]').getAttribute('aria-label'),'正在训练');
  click(dom,'[data-action=library]');assert.equal(dom.window.document.querySelectorAll('.library-item').length,37);
  const search=dom.window.document.querySelector('#exercise-search');search.value='卧推';search.dispatchEvent(new dom.window.Event('input',{bubbles:true}));assert.equal(dom.window.document.querySelectorAll('.library-item').length,4);
  click(dom,'[data-action=choose-exercise][data-id="1"]');change(dom,'[data-set-field=weight][data-s="0"]','60');change(dom,'[data-set-field=reps][data-s="0"]','8');click(dom,'[data-action=set-done][data-s="0"]');assert.equal(read(dom).draft.exercises[0].sets[0].done,true);assert.match(dom.window.document.querySelector('#lock-activity').textContent,/已完成 1 个正式组/);
  click(dom,'[data-action=rest-menu]');click(dom,'[data-action=rest-start][data-seconds="90"]');assert(read(dom).draft.restDeadline>Date.now());assert.match(dom.window.document.querySelector('#lock-activity').textContent,/组间休息/);
  const darkState=read(dom);darkState.settings.theme='dark';fs.writeFileSync(path.join(__dirname,'../artifacts/windows-preview/dark-fixture.json'),JSON.stringify(darkState));
  click(dom,'[data-action=pause]');click(dom,'[data-action=rest-end]');assert.equal(read(dom).draft.runningSince,null);assert.match(dom.window.document.querySelector('#lock-activity').textContent,/计时已暂停/);
  const persisted=dom.window.localStorage.getItem(key),id=read(dom).draft.id;dom.window.close();dom=await load(persisted);assert.equal(read(dom).draft.id,id);assert.match(dom.window.document.querySelector('#startWorkout').textContent,/继续/);
  click(dom,'#startWorkout');click(dom,'[data-action=finish]');assert.equal(read(dom).draft,null);assert.equal(read(dom).sessions.length,9);assert.match(dom.window.document.querySelector('#widget-small').textContent,/1次/);assert.match(dom.window.document.querySelector('.summary-title').textContent,/胸部训练/);
  click(dom,'[data-action=summary-back]');click(dom,'#widget-medium [data-action=calendar]');assert.equal(dom.window.document.querySelector('[role=dialog]').getAttribute('aria-label'),'健身日历');change(dom,'[data-field=calendar-jump]','2040-02-29');assert.match(dom.window.document.querySelector('.selected-day-title').textContent,/2040/);assert.match(dom.window.document.querySelector('.sheet-scroll').textContent,/还没有训练记录/);click(dom,'[data-action=close]');click(dom,'#widget-medium [data-action=calendar]');assert.match(dom.window.document.querySelector('.selected-day-title').textContent,/2040/);click(dom,'[data-action=today]');assert.match(dom.window.document.querySelector('.record-copy strong').textContent,/胸部训练/);click(dom,'[data-action=close]');
  click(dom,'#tabbar [data-tab=workout]');click(dom,'[data-action=start-quick]');const muscle=dom.window.document.querySelector('path[data-muscle=chest]');muscle.dispatchEvent(new dom.window.MouseEvent('click',{bubbles:true}));change(dom,'[data-field=minutes]','20');click(dom,'[data-action=finish]');assert.equal(read(dom).sessions.length,10);assert.equal(read(dom).sessions.at(-1).mode,'quick');assert.equal(read(dom).sessions.at(-1).elapsed,1200);assert.match(dom.window.document.querySelector('#widget-small').textContent,/1 组/);
  click(dom,'[data-action=summary-back]');click(dom,'#app-header [data-action=settings]');change(dom,'[data-setting=theme]','dark');assert.equal(dom.window.document.documentElement.dataset.theme,'dark');change(dom,'[data-setting=unit]','lb');assert.equal(read(dom).settings.unit,'lb');
  click(dom,'[data-action=clear]');click(dom,'[data-action=cancel-confirm]');assert.equal(read(dom).sessions.length,10);click(dom,'[data-action=clear]');click(dom,'[data-action=confirm-yes]');assert.equal(read(dom).sessions.length,0);assert.equal(read(dom).draft,null);click(dom,'[data-action=close]');click(dom,'#tabbar [data-tab=strength]');assert.match(dom.window.document.querySelector('#app-content').textContent,/第一项进步/);
  click(dom,'#tabbar [data-tab=workout]');click(dom,'[data-action=template][data-key=push]');assert.equal(read(dom).draft.exercises.length,3);assert.equal(read(dom).draft.exercises[0].name,'杠铃卧推');
  assert.deepEqual(failures,[]);dom.window.close();fs.writeFileSync(path.join(__dirname,'../artifacts/windows-preview/light-fixture.json'),initial);
  console.log('PASS: catalog, 40 muscle regions, exercise search, completed sets, live states, rest timer, pause, persistent draft, finish, widgets, future calendar, quick record, themes, units, clear confirmation and templates.');
})().catch(error=>{console.error(error);process.exitCode=1;});
