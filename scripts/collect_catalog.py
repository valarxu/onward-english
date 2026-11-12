"""Index public lesson titles and links only. Never store lesson texts or media."""
import concurrent.futures, json, re, time, urllib.parse, warnings
from pathlib import Path
warnings.filterwarnings('ignore')
import requests
BASE='https://learnenglish.britishcouncil.org'
CORE=[f'/free-resources/{s}/{l}' for s in ['listening','reading','writing'] for l in ['a1','a2','b1','b2','c1']]+[f'/free-resources/speaking/{l}' for l in ['a1','a2','b1','b2']]+[f'/free-resources/grammar/{l}' for l in ['a1-a2','b1-b2','c1']]+[f'/free-resources/vocabulary/{l}' for l in ['a1-a2','b1-b2']]
EXTRA=['/free-resources/business/english-emails','/free-resources/business/podcasts-professionals','/free-resources/business/youre-hired','/free-resources/general/audio-series','/free-resources/general/video-series','/free-resources/general/story-zone','/free-resources/general/audio-zone','/free-resources/general/video-zone','/free-resources/general/magazine-zone','/business-english/business-magazine']

def fetch(path):
    for attempt in range(2):
        try:
            r=requests.get('https://r.jina.ai/'+BASE+path, timeout=90)
            r.raise_for_status(); text=r.text
            # Only the content after the page's H1; omit global navigation/footer.
            main=re.split(r'\n# [^\n]+\n',text,maxsplit=1)
            main=main[1] if len(main)>1 else text
            links=[]
            for title,url in re.findall(r'^#{2,3} \[([^\]]+)\]\((https://learnenglish\.britishcouncil\.org/[^)\s]+)\)',main,re.M):
                u=urllib.parse.urlsplit(url); p=u.path.rstrip('/')
                if (p.startswith(path.rstrip('/')+'/') or (path.startswith('/free-resources/general/') and re.search(r'/general-english/|/free-resources/general/',p))) and not re.search(r'/user/|/online-courses/|corporate-solutions',p):
                    item={'title':title.strip(),'url':BASE+p}
                    if item not in links:links.append(item)
            pages=re.findall(r'\]\((https://learnenglish\.britishcouncil\.org[^)\s]*[?&]page=\d+[^)\s]*)',main)
            return {'path':path,'url':BASE+path,'lessons':links,'pagination':sorted(set(pages)),'checked':'2026-11-12'}
        except Exception as e:
            if attempt: return {'path':path,'url':BASE+path,'lessons':[],'error':str(e)}

def batch(paths):
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        fs={pool.submit(fetch,p):p for p in paths}
        for future in concurrent.futures.as_completed(fs):
            item=future.result();results.append(item)
            print(item['path'],len(item['lessons']),item.get('error',''),flush=True)
    return results

if __name__=='__main__':
    pages=batch(CORE+EXTRA)
    # Series overview pages point to finite, named courses. Follow only these directories.
    nested=[]
    for p in pages:
        if p['path'] in ['/free-resources/general/audio-series','/free-resources/general/video-series','/free-resources/general/story-zone']:
            nested += [urllib.parse.urlsplit(l['url']).path for l in p['lessons']]
    if nested:pages+=batch(sorted(set(nested)-set(CORE+EXTRA)))
    Path('research/catalog-pages.json').write_text(json.dumps(pages,ensure_ascii=False,indent=2))
    core=[l for p in pages if p['path'] in CORE for l in p['lessons']]
    print('DONE',len(pages),'pages;',len(core),'core lessons;',sum(len(p['lessons']) for p in pages),'total entries',flush=True)
