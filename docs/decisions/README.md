# Decision Records

Architecture Decision Records (ADRs) for this repo, in [Nygard style](https://thinkrelevance.com/blog/2011/11/15/documenting-architecture-decisions).

Every decision that changes *how* this archive works (formats, tools, pipeline behaviour) gets a record here, so future-us knows **why**, not just **what**.

## Index

| #   | Title                                    | Status    | Date       | Supersedes |
|-----|------------------------------------------|-----------|------------|------------|
| 0001 | [Initial archive formats](0001-initial-archive-formats.md) | ⚠️ `partially-superseded` (images and video) | 2019-11 (rec. 2026-11-09) | none |
| 0002 | [Image format for the archive](0002-image-format-for-the-archive.md) | ✅ `accepted` | 2026-11-09 (accepted 2026-11-11) | ADR-0001's images part |
| 0004 | [Video format for the archive](0004-video-format-for-the-archive.md) | ✅ `accepted` | 2026-11-11 | ADR-0001's video part |

## Status values

Status field values (the `status` front-matter field) and their index icons:

| `status`  | Icon | Meaning |
|-----------|------|---------|
| `proposed` | 🕐 | Researched/recommended, not yet implemented or agreed; **the old decision still applies** |
| `accepted` | ✅ | Decision in effect |
| `rejected` | 🚫 | Proposed, but decided against; never was in effect. Rejected *options* inside a decided ADR stay in its "Options considered" table |
| `partially-superseded` | ⚠️ | Applies only to the areas not taken over by newer records (see `superseded-by`) |
| `superseded` | ~~title~~ | Replaced by a newer record (see `superseded-by`) |
| `deprecated` | 🗑️ | No longer recommended, but not replaced by a specific ADR |

## Conventions

- **One file per decision**, numbered: `NNNN-short-slug.md`. Numbering never gets reused. File names and titles use the bare number; prose and front-matter values refer to records as `ADR-NNNN`.
- **Title = the problem/decision area, not the solution.** E.g. "Image format for the archive", *not* "Use JPEG XL". A superseding decision answers the same question differently; the title stays valid.
- **English** titles, file names and records.
- **Records are immutable once Accepted.** To change a decision, write a new ADR, set the old one's `status` to `superseded` and add its `ADR-NNNN` ID to `superseded-by`. Research/reasoning may be appended as clearly dated snapshots, but the Decision section itself is never rewritten.
- **Copy [`template.md`](template.md)** for a new record, take the next number, add a row to the index.
- **Metadata lives in YAML front matter** at the top of each record: `status` (values: Status-values section), `date`, `deciders`, `supersedes`, `superseded-by`. Conditions and caveats stay prose in a blockquote below the title; keep the index row in sync by hand.
