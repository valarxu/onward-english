import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const ctx={window:{}};vm.runInNewContext(fs.readFileSync('dist/catalog.js','utf8'),ctx);
const {meta,lessons}=ctx.window.ONWARD_CATALOG;
assert.equal(new Set(lessons.map(l=>l.id)).size,lessons.length,'duplicate lesson IDs');
assert.equal(meta.coreCount,lessons.filter(l=>!l.collection).length);
assert.equal(meta.extraCount,lessons.filter(l=>l.collection).length);
const skills=new Set(['listening','reading','speaking','writing','grammar','vocabulary']);
for(const l of lessons){
 const u=new URL(l.url);assert.equal(u.origin,'https://learnenglish.britishcouncil.org');
 assert.equal(l.id,u.pathname.slice(1));assert.ok(l.title.trim());assert.ok(skills.has(l.skill));
 assert.ok(l.minutes>0&&l.minutes<=45);assert.ok(Number.isInteger(l.order));
 assert.ok(!u.search&&!u.hash);assert.ok(!/online-courses|user\/|ielts-preparation/.test(l.id));
 if(!l.collection){assert.ok(l.levels.length);for(const level of l.levels)assert.ok(['A1','A2','B1','B2','C1'].includes(level));}
 assert.ok(meta.sources.some(s=>s.url===l.source));
}
for(const level of ['A1','A2','B1','B2','C1']){assert.ok(lessons.some(l=>l.levels.includes(level)));}
for(const source of meta.sources){assert.equal(source.count,lessons.filter(l=>l.source===source.url).length);}
console.log(`Verified ${lessons.length} unique official lesson links (${meta.coreCount} core / ${meta.extraCount} extension), ${meta.sources.length} source directories.`);
