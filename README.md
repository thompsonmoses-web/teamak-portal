# Teamak Portal

Online application portal for the **Teamak Global Solution Limited Rider Ownership
Programme** (Ibadan & Environs). Riders apply for an Okada or Maruwa ownership
slot online, follow their application on a personal dashboard (status timeline,
what to bring for verification, WhatsApp contact), and reach it again with their
application number; staff review, verify and approve applications, and
administrators manage which accounts can sign in.

- **Ride with Dignity. Own Your Future.**

## Repository layout

| Path | What it is |
|------|------------|
| `app/` | Flutter Web front end — public site, application wizard, applicant dashboard, staff dashboard, admin team management. |
| `server/` | Dart Frog API — SQLite storage, bcrypt auth, staff-only review and team endpoints. |
| `docs/` | Product specs derived from the original paper application form. |
| `app/build/`, `*.db`, `uploads/` | Generated. Git-ignored. |

Read [`docs/form-spec.md`](docs/form-spec.md) before touching validation rules —
it is the authoritative field-by-field reference for the form, transcribed from
the signed-off DOCX.

## Prerequisites

- Dart SDK `^3.11.0` (server) and Flutter with Dart `^3.13.5` (app)
- The [Dart Frog CLI](https://dart-frog.dev): `dart pub global activate dart_frog_cli`
- A native `sqlite3` library on your PATH (bundled on most platforms; on Linux
  install `libsqlite3-dev`)

## Running the API

```sh
cd server
dart pub get
dart_frog dev          # serves on http://localhost:8080
```

On first run the server creates `server/teamak.db`, applies the schema and seeds
a staff administrator.

## Running the web app

In a second terminal:

```sh
cd app
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

`API_BASE` defaults to `http://localhost:8080`, so the `--dart-define` is only
needed to point at another host. CORS is open in development, so the app and API
may run on different origins.

For a production web build: `flutter build web --release`.

### Serving a built app behind one origin

`API_BASE` is baked in at build time. Building with an empty value instead makes
the app resolve every request against the page it was loaded from, so the app
and API can be served from a single host with no CORS involved:

```sh
flutter build web --release --dart-define=API_BASE= -o build/web
dart run tool/static_server.dart build/web 8889 http://127.0.0.1:8080
```

The optional third argument proxies `/programmes`, `/applications`, `/track`,
`/auth`, `/contact` and `/staff` to the running API, streaming request and
response bodies through. `/contact` and `/staff` are also frontend pages, so
for those two the `Accept` header breaks the tie: browser navigations asking
for `text/html` get the static build (SPA fallback included), while the app's
JSON fetches — no `Accept`, maybe a bearer token — go to the API. Without that
rule a refresh of `/contact` or a deep link to `/staff/team` would render an
API response instead of the page. One URL then carries the whole app, which
suits a demo tunnel or a reverse proxy in front of both.

## Staff sign-in

A default administrator is seeded on first run:

- **Username:** `admin`
- **Password:** `admin123`

Change or remove these before deploying:

```sh
export TEAMAK_ADMIN_USER=...
export TEAMAK_ADMIN_PASSWORD=...
```

Visit `/staff/login` in the app.

### Team management

Administrators get a **Team** entry in the staff dashboard's quick actions
(`/staff/team`): list every account with its role, add new members, promote a
reviewer to administrator or demote one back, and reset a password (which ends
that account's sessions on the spot). Reviewers never see the entry, and the
API refuses the same requests if the URL is reached directly.

## Environment variables

All optional; sensible defaults are used when unset.

| Variable | Default | Purpose |
|----------|---------|---------|
| `TEAMAK_DB` | `teamak.db` | SQLite database file path. |
| `TEAMAK_ADMIN_USER` | `admin` | Seeded administrator username. |
| `TEAMAK_ADMIN_PASSWORD` | `admin123` | Seeded administrator password. |
| `TEAMAK_UPLOADS` | `uploads` | Directory for stored documents. |
| `CONTACT_EMAIL` | `Teamakgloblsolution33@gmail.com` | Inbox for contact-form mail. |
| `CONTACT_APP_PASSWORD` | *(unset)* | Gmail App Password. Without it, contact messages are saved but not emailed. |

## API

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/` | — | Service metadata and health check. |
| `GET` | `/programmes` | — | The three ownership tiers. |
| `POST` | `/auth/login` | — | Exchange credentials for a session token. |
| `GET` | `/auth/me` | staff | The signed-in staff member. |
| `POST` | `/auth/logout` | staff | End the session server-side; safe to repeat. |
| `POST` | `/applications` | — | Submit an application; returns its `TRP-YYYY-NNNN` number. |
| `GET` | `/applications` | staff | List, search (`q`) and filter (`status`). |
| `GET` | `/applications/:id` | staff | Full application with its event history. |
| `PATCH` | `/applications/:id/status` | staff | Update status and Section I fields. |
| `GET` | `/applications/:id/documents` | staff | List uploaded documents. |
| `POST` | `/applications/:id/documents` | staff | Upload a base64-encoded document. |
| `POST` | `/track` | — | Applicant lookup: number + submitted phone returns their own view (status, timeline, outcomes) with staff notes stripped. |
| `POST` | `/contact` | — | Store a contact message, optionally email it. |
| `GET` | `/staff` | admin | Every staff account, without credentials. |
| `POST` | `/staff` | admin | Create a staff account (`username`, `fullName`, `password`, `role`). |
| `PATCH` | `/staff/:id` | admin | Change a staff account's name, role or password; a password change ends its sessions server-side. |

Staff endpoints expect `Authorization: Bearer <token>`.
`/staff` additionally requires `role: admin` — a reviewer is refused with 403,
and the last administrator cannot be demoted (400), so the door can never be
locked behind everyone.

## Tests

```sh
cd server && dart test      # API and validation
cd app    && flutter test   # widget tests
```

The app suite walks the application wizard end to end and checks the payload it
submits against every field the API validates, then re-runs every route — public
pages, the applicant dashboard (form and loaded), staff screens (dashboard,
messages, review, admin team) — at 320, 360, 390, 414, 480, 768 and 1280 px,
sweeping each one frame by frame for horizontal layout overflow. **Any new
screen belongs in that sweep** — see `app/test/responsive_test.dart`.

## Permanent preview link (GitHub Pages)

**https://thompsonmoses-web.github.io/teamak-portal/** — a link that never
changes, needs no server, and survives restarts: the same pattern used for
the Home of Hymns app.

GitHub Pages hosts static files only, so this build (`API_BASE=demo`)
answers every API call from an in-browser demo backend
(`app/lib/api/demo_backend.dart`): applying, tracking, the staff area and
team management all work, stored in the visitor's own browser. A gold
banner on every screen and a sign-in hint on the staff login page say so —
nothing there reaches a Teamak server. The real deployment (local, tunnelled
or hosted) is unaffected: it talks to the Dart Frog API and never loads the
demo backend.

Republish after changing the app:

```sh
cd app
flutter build web --release --no-wasm-dry-run \
  --dart-define=API_BASE=demo --base-href /teamak-portal/ -o build/pages
# add an empty .nojekyll and a 404.html copy of index.html (deep links),
# then replace the gh-pages branch content with build/pages and force-push
# (the branch is generated output, so history never needs preserving);
# Pages rebuilds the site from it automatically.
```

## Known gaps

Tracked as work in progress rather than settled design:

- **No applicant document upload.** Section E files can only be attached by staff
  against an existing application; applicants answer the checklist (yes/no) in the
  wizard and bring the originals for verification.
- **Default admin credentials** are committed as defaults in `database.dart`.
- **Hosting is split.** The permanent preview on GitHub Pages (above) runs a
  browser-only demo backend, so applications there stay in the visitor's
  browser and never reach a real database. The full stack — real API, shared
  SQLite file — still runs on the developer machine behind a tunnel whose URL
  changes on restart; it will move to any static host + small VM/container
  pairing unchanged.
