# N. Marie Wilson — Mobile App

Flutter app for iOS and Android, built to match the web portal
([n-marie-wilson-connect](https://github.com/adityasanthanam/n-marie-wilson-connect)).
Citizens can file and track grievances, read news and find helplines. Office staff
sign in to manage cases.

## Setup

1. Install Flutter (stable), Xcode with CocoaPods for iOS, and Android Studio for Android.
2. Copy `config/env.example.json` to `config/env.json` and fill it in. Git ignores this file.
   - `SITE_URL`: the published web origin, e.g. `https://example.com`. The app calls
     `/api/submit-grievance`, `/api/intake`, `/api/chat` and the gateway at `/api/public/v1`.
   - `CITIZEN_API_KEY`: a key with the **citizen** scope only, created at `/tech → API keys`.
     Anyone can extract a key from an app binary, and gateway keys bypass row-level
     security, so never put a `read` or `write` key here.
   - `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`: the same public values the website uses.
3. Run:

```sh
flutter pub get
flutter run --dart-define-from-file=config/env.json
flutter test
```

Release builds take the same flag:
`flutter build ipa --dart-define-from-file=config/env.json` and `flutter build appbundle --dart-define-from-file=config/env.json`.

## How it talks to the backend

| Area | Transport |
|---|---|
| File a grievance (fields, map pin, attachments, public opt-in) | `POST /api/submit-grievance`, the same multipart call the web form makes |
| AI form-fill and assistant chat | `POST /api/intake`, `POST /api/chat` (streamed) |
| News, tracking by reference | Public gateway, `X-API-Key` with citizen scope |
| News view counter | Supabase RPC `increment_news_view` |
| Staff sign-in and all case work | Supabase email/password plus RLS, the same queries as the web admin |

Staff never use API keys. Each staff member signs in, so the database rules (constituency
scope, role capabilities, read-only roles) and the audit trail apply exactly as on the web.
Access is re-checked every 30 seconds and whenever the app resumes.

## Screens and layout

Navigation and layout depend on the window width, not the device model:

- **Phones** (iPhone SE to Pro Max, Android 360–412dp) get a single column and a bottom navigation bar.
- **Wide windows** (unfolded foldables, tablets, landscape) get a navigation rail. The staff case
  list and case detail sit side by side.
- **Dual-screen and foldable devices:** the two panes split exactly on the hinge
  (`TwoPane` in `lib/core/adaptive.dart`).
- Content stays inside safe areas (notches, Dynamic Island, gesture bars). Text scaling is
  honoured, up to 1.6× on phones.

`test/adaptive_layout_test.dart` renders the main screens at nine device sizes, and in
Tamil with large text, and fails on any layout overflow.

## Feature parity with the web

Done:
- Citizen: home, file a grievance (AI assistant, constituency and ward, GPS/map pin, up to 5
  attachments, camera, public opt-in, flooding preset), track by reference, news feed
  (trending, YouTube/Instagram), assistant chat with hand-off to the filing form, helplines
  (call and WhatsApp), About, Ministry, Constituency, Initiatives, Contact, English/Tamil.
- Staff: sign-in, role and capability gating, case list (status tiles, concern toggles,
  queues, search, filters, sort, open by ID), case detail (status with a required remark when
  resolving or closing, group, assignee, assign to me, department and its contacts, replies
  and internal notes with attachments, report abuse and block, public approval, location map,
  timeline), dashboard (KPIs, breakdowns, drill-down lists), map view, blocked citizens,
  departments, News Feed CMS.

Needs new endpoints on the web app (today these are TanStack server functions, which
non-browser clients can't call):
- `GET /api/staff/team-names` and `GET /api/staff/assignees?grievance_id=`. The app already
  calls them and, until they exist, shows "Team member" instead of names.
- Contact-centre intake and editing (`saveStaffGrievance`, `draftFromCall`, `linkCallRecording`).
- Translation, the admin AI assistant and the team analyst.
- Team administration (create, grant, revoke, reset password), the roles editor and the groups editor.
- `POST /api/staff/password-reset-request` for "Forgot password".

Not yet built: voice assistant (ElevenLabs), citizen OTP login and a "My grievances" list
(both are switched off on the web today too), and CSV export.
