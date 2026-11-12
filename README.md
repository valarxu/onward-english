# Onward · 英语学习路线

A buildless personal study navigator for British Council LearnEnglish free resources. UI is in Chinese; original lesson titles remain in English. Official course material opens on British Council in a new tab.

## Run locally

```sh
python3 -m http.server 4173 --directory dist
```

Open http://localhost:4173. No installation or server-side account is required.

## What is included

- 316 unique core lesson links across 24 official CEFR/skill directories.
- 182 extra lessons from workplace, audio and video series, including the three Big City Small World series.
- A1–C1 suggested routes that distribute skill practice across the level. Shared A1–A2 and B1–B2 materials retain their source labels and share completion state.
- Sequential lesson navigation, optional study checklists, bookmarks, notes, review intervals and daily goals.
- Browser-local progress, JSON export and additive import. There is no server-side progress or cross-device account sync.
- Responsive layout, keyboard controls, native modal dialogs and reduced-motion support.

## Sources and boundaries

`research/catalog-pages.json` records directory URLs, titles, links, retrieval date and any failed source queries. It stores no lesson bodies, transcripts, media or exercise answers. `scripts/collect_catalog.py` extracts index metadata from publicly available official pages using the Jina Reader transport; it does not ingest lesson content. `scripts/build_catalog.py` builds the deployable metadata file.

The finite skills directories form the core curriculum. Extensions are a selected verified subset; continuously updated magazine, story and community/event collections are not fully indexed. Course links may change after the recorded date.

The suggested order, checklists, time estimates and review schedule are original navigation aids. They are not an official British Council syllabus, and completing a route is not a CEFR qualification. Course exercises and scores stay on the original site and do not sync here.

A1–C1 refer to the levels in the source directories, not guaranteed assessment outcomes. Durations are suggested study budgets, not timers. Goal progress uses suggested duration of manually completed lessons.

## Validation

Browser QA covered first lesson -> second lesson, notes saved across reload, search and level filters, extension-series progression, bookmarks, JSON export, additive import, due-review rescheduling, and a 390px mobile viewport without horizontal overflow. `scripts/validate.mjs` validates catalogue structure, counts, identifiers, domains and source consistency; Node syntax checks cover application code.

## Self-hosting

Public source: https://github.com/valarxu/onward-english

Production: https://english.blackmstone.site

See [deployment instructions](deploy/README.md) for the Tencent Cloud / Ubuntu / Nginx setup, HTTPS renewal, updates, rollback and moving learning records from another origin.

The public repository contains the application and lesson-link metadata. It excludes the original hosting service's project configuration, browser test records, credentials and certificate private keys. Official lesson material still opens on British Council.
