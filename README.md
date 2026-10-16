# Teamak Portal

Online application portal for the **Teamak Global Solution Limited Rider Ownership
Programme** (Ibadan & Environs). Riders apply for an Okada or Maruwa ownership
slot online and track it afterwards with their application number; staff review,
verify and approve applications from a dashboard.

- **Ride with Dignity. Own Your Future.**

## Repository layout

| Path | What it is |
|------|------------|
| `app/` | Flutter Web front end — public site, application wizard, applicant dashboard, staff dashboard. |
| `server/` | Dart Frog API — SQLite storage, bcrypt auth, staff-only review endpoints. |
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
`/auth` and `/contact` to the running API, streaming request and response bodies
through. One URL then carries the whole app, which suits a demo tunnel or a
reverse proxy in front of both.

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

Staff endpoints expect `Authorization: Bearer <token>`.

## Tests

```sh
cd server && dart test      # API and validation
cd app    && flutter test   # widget tests
```

The app suite walks the application wizard end to end and checks the payload it
submits against every field the API validates, then re-runs every route — public
pages, the applicant dashboard (form and loaded), staff screens — at 320, 360,
390, 414, 480, 768 and 1280 px, sweeping each one frame by frame for horizontal
layout overflow. **Any new screen belongs in that sweep** — see
`app/test/responsive_test.dart`.

## Known gaps

Tracked as work in progress rather than settled design:

- **No applicant document upload.** Section E files can only be attached by staff
  against an existing application; applicants answer the checklist (yes/no) in the
  wizard and bring the originals for verification.
- **Default admin credentials** are committed as defaults in `database.dart`.
- **No permanent hosting.** The demo runs behind an ephemeral cloudflare tunnel
  on the developer machine, so the public URL changes whenever the services
  restart. The app is a static bundle plus one API process, so it will move to
  any static host + small VM/container pairing unchanged.
