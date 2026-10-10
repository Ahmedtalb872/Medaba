-- جدول بيانات تطبيق طيبة في Supabase.
-- الصقه في Supabase: SQL Editor ← New query ← Run. تشغيله أكثر من مرة آمن.
--
-- كل مجموعة (الفواتير، العمال، المخزون...) تُحفظ في صف واحد:
-- key اسم المجموعة، و value قائمة JSON بعناصرها.

create table if not exists public.app_data (
  key text primary key,
  value jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

-- المفتاح العام (publishable) موجود داخل التطبيق ويستطيع أي أحد رؤيته،
-- لذلك لا يقرأ البيانات أو يكتبها إلا من سجّل الدخول بحساب أضافه المدير.
alter table public.app_data enable row level security;

drop policy if exists "app_data read" on public.app_data;
create policy "app_data read" on public.app_data
  for select to authenticated using (true);

drop policy if exists "app_data insert" on public.app_data;
create policy "app_data insert" on public.app_data
  for insert to authenticated with check (true);

drop policy if exists "app_data update" on public.app_data;
create policy "app_data update" on public.app_data
  for update to authenticated using (true) with check (true);

revoke all on public.app_data from anon;
grant select, insert, update on public.app_data to authenticated;
