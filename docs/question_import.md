# Importing questions

## ⚠️ Copyright first

**Do not scrape, copy or import official ÖSYM exam questions.** ÖSYM questions
are copyrighted; publishing them without a licence is a legal risk and a Google
Play policy risk.

The bundled bank under `assets/seed/questions.json` is **original demo content
written for this app**. Replace or extend it with:

- questions you wrote yourself,
- questions you licensed from a publisher (keep the licence on file),
- questions contributed under an agreement that lets you distribute them.

Every row carries a `source_type` column. Use `demo` for the sample bank and
`licensed` for content you own the rights to, so you can always tell them apart
in the database.

---

## Format

Both CSV and JSON are supported.

### Columns

| Column | Required | Notes |
| --- | --- | --- |
| `id` | no | Your stable identifier. Stored as `external_id` and used for idempotent re-imports. Strongly recommended. |
| `exam_type` | **yes** | `TYT` or `AYT` |
| `subject` | **yes** | Subject **code**, e.g. `tyt_matematik` (see `assets/seed/catalog.json`) |
| `topic` | no | Topic **code**, e.g. `uslu_sayilar` |
| `year` | no | Integer |
| `question_text` | **yes** | Plain text. Use `\n` for paragraph breaks in JSON. |
| `question_image_url` | no | Public URL (Supabase Storage or a CDN) |
| `option_a` | **yes** | |
| `option_b` | **yes** | |
| `option_c` | **yes** | |
| `option_d` | **yes** | |
| `option_e` | no | Leave empty for 4-option questions |
| `correct_option` | **yes** | `A`–`E`. Must not be `E` when `option_e` is empty. |
| `explanation` | no | Shown after answering |
| `difficulty` | no | `easy`, `medium` or `hard` (default `medium`) |
| `source_type` | no | Defaults to `licensed` for imports |

### CSV example

```csv
id,exam_type,subject,topic,year,question_text,option_a,option_b,option_c,option_d,option_e,correct_option,explanation,difficulty
own-mat-001,TYT,tyt_matematik,uslu_sayilar,,2³ · 2⁵ işleminin sonucu kaçtır?,16,64,128,256,1024,D,Tabanlar aynı olduğu için üsler toplanır.,easy
```

### JSON example

```json
{
  "questions": [
    {
      "id": "own-mat-001",
      "exam_type": "TYT",
      "subject": "tyt_matematik",
      "topic": "uslu_sayilar",
      "question_text": "2³ · 2⁵ işleminin sonucu kaçtır?",
      "option_a": "16",
      "option_b": "64",
      "option_c": "128",
      "option_d": "256",
      "option_e": "1024",
      "correct_option": "D",
      "explanation": "Tabanlar aynı olduğu için üsler toplanır.",
      "difficulty": "easy"
    }
  ]
}
```

---

## Running the importer

The importer validates every row **before** touching the database and fails on
the first problem, so a bad file never lands half-imported.

### 1. Generate SQL (recommended, no credentials needed)

```bash
python3 scripts/import_questions.py --input my_questions.csv --sql out.sql
```

Then paste `out.sql` into the Supabase dashboard → SQL Editor → Run.

### 2. Upload directly over the REST API

Requires the **service role** key. Never put this key in the app, in `.env`, or
in git.

```bash
export SUPABASE_URL="https://YOUR-PROJECT.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOi..."
python3 scripts/import_questions.py --input my_questions.csv --upload
```

Re-running with the same `id` values is safe: rows conflict on `external_id`
and are skipped.

### Prerequisites

Subjects and topics must exist before questions can reference them:

```bash
psql "$DATABASE_URL" -f supabase/seed.sql
```

or paste `supabase/seed.sql` into the SQL Editor.

---

## Regenerating the bundled demo bank

`assets/seed/*.json` is the source of truth for the offline content. After
editing it, regenerate the SQL seed so the database matches:

```bash
python3 scripts/generate_seed.py
```

This rewrites `supabase/seed.sql` with the catalogue, daily quests,
achievements, daily facts and the demo question bank.

---

## Adding a new subject or topic

1. Add it to `assets/seed/catalog.json` (`code` must be ASCII and stable).
2. If it needs a new icon, add the mapping in
   `L10nMaps.subjectIcon` (`lib/core/l10n_maps.dart`) — icons are referenced by
   name so the catalogue can live in the database.
3. Run `python3 scripts/generate_seed.py` and apply `supabase/seed.sql`.
4. Set `"is_active": false` to show a subject as **Yakında** (coming soon)
   without any content.
