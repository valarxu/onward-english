import json,re
from pathlib import Path
pages=json.loads(Path('research/catalog-pages.json').read_text())
lessons=[];sources=[]
names={'english-emails':'职场邮件 · English for emails','podcasts-professionals':'职场听力 · Podcasts for professionals','youre-hired':'求职面试 · You’re Hired','writing-home':'Writing home','britain-great':'Britain is GREAT','shakespeare':'Shakespeare','starting-out':'Starting Out','word-street':'Word on the Street','audio-zone':'Audio zone','s1':'Big City Small World · 1','s2':'Big City Small World · 2','s3':'Big City Small World · 3'}
skills=['listening','reading','speaking','writing','grammar','vocabulary']
for page in pages:
 p=page['path'];parts=p.strip('/').split('/');core=len(parts)==3 and parts[1] in skills
 key=parts[-1]
 if not core and key not in names:continue
 sources.append({'url':page['url'],'count':len(page['lessons']),'checked':page.get('checked'),'error':bool(page.get('error'))})
 for i,x in enumerate(page['lessons']):
  if core:
   skill=parts[1];level=parts[2].upper().split('-');series=None
  else:
   skill='writing' if key=='english-emails' else 'listening';level=[];series=names[key]
  if len(x['title'])>110 and 'application form' in x['title']:x['title']='An application form'
  lessons.append(dict(id=x['url'].replace('https://learnenglish.britishcouncil.org/',''),title=x['title'],url=x['url'],skill=skill,levels=level,collection=series,source=page['url'],order=i,minutes={'listening':20,'reading':20,'speaking':20,'writing':25,'grammar':15,'vocabulary':15}[skill]))
seen=set();lessons=[x for x in lessons if not(x['id'] in seen or seen.add(x['id']))]
metadata={'checked':'2026-11-12','coreCount':sum(not x['collection'] for x in lessons),'extraCount':sum(bool(x['collection']) for x in lessons),'sources':sources}
Path('dist/catalog.js').write_text('window.ONWARD_CATALOG='+json.dumps({'meta':metadata,'lessons':lessons},ensure_ascii=False,separators=(',',':'))+';\n')
print(metadata['coreCount'],'core,',metadata['extraCount'],'extra,',len(lessons),'unique lessons')
