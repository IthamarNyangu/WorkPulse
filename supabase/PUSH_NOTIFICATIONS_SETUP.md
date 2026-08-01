# WorkPulse Push Notification Setup

The app compiles without Firebase configuration. Push delivery becomes active after completing these steps.

## 1. Configure Firebase Android

1. Create a Firebase project in the Firebase console.
2. Add an Android app with package name `com.workpulsezm.workpulse`.
3. Download `google-services.json`.
4. Place it at `android/app/google-services.json`.
5. In Firebase Project settings > Service accounts, generate a new private key. Keep this JSON file outside the repository.

The Gradle build applies the Google Services plugin automatically when `google-services.json` exists.

## 2. Update Supabase

Run `supabase/sql/push_notifications_fcm.sql` in the Supabase SQL Editor.

## 3. Deploy the dispatcher

From the project root, after installing and signing in to the Supabase CLI:

```powershell
supabase link --project-ref qcbqvmxxjlwfjcjsjxzc
supabase secrets set WORKPULSE_CRON_SECRET="replace-with-a-long-random-value"
supabase secrets set FIREBASE_SERVICE_ACCOUNT="<the-entire-service-account-json-on-one-line>"
supabase functions deploy process-workpulse-notifications --no-verify-jwt
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are supplied automatically to hosted Edge Functions. Never put the Firebase service account or Supabase service-role key in the Flutter app.

## 4. Schedule delivery

In Supabase Dashboard > Integrations > Cron, create an HTTP job:

- Name: `process-workpulse-notifications`
- Schedule: `*/5 * * * *`
- Method: `POST`
- URL: `https://qcbqvmxxjlwfjcjsjxzc.supabase.co/functions/v1/process-workpulse-notifications`
- Header: `x-workpulse-cron-secret: <the same WORKPULSE_CRON_SECRET value>`
- Body: `{}`

The five-minute schedule generates server reminders and sends every pending notification. Approval-update notifications created by existing database triggers use the same dispatcher.

## 5. Test

1. Fully stop the app and run `flutter run --dart-define-from-file=env.json` so Firebase starts from a cold launch.
2. Sign in and accept notification permission. A row should appear in `public.device_tokens`.
3. Insert a test notification for that signed-in profile, or update a leave request status.
4. Run the Cron job manually from Supabase.
5. Confirm the Android notification appears while WorkPulse is backgrounded or closed.

Use this SQL for a direct test notification:

```sql
insert into public.notifications (
  user_id,
  event_key,
  type,
  title,
  message,
  action_label,
  navigation_target
)
select
  id,
  'push_test:' || extract(epoch from now())::bigint,
  'general_info',
  'WorkPulse Push Test',
  'Background push delivery is working.',
  null,
  null
from public.profiles
where email = 'williamnyanja@workpulsezm.com';
```
