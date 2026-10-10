-- قاعدة بيانات تطبيق طيبة في Supabase — بدون بريد إلكتروني.
-- الصقه في Supabase: SQL Editor ← New query ← Run. تشغيله أكثر من مرة آمن.
--
-- * app_data: كل مجموعة (الفواتير، العمال، المخزون...) في صف واحد.
-- * app_users: أسماء المستخدمين وكلمات مرورها (مشفّرة).
-- لا أحد يقرأ الجدولين مباشرة؛ التطبيق يمر عبر دوال تتحقق من اسم المستخدم
-- وكلمة المرور في كل طلب.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.app_data (
  key text primary key,
  value jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_users (
  username text primary key,
  password_hash text not null
);

-- RLS بدون سياسات = لا قراءة ولا كتابة مباشرة بالمفتاح العام.
alter table public.app_data enable row level security;
alter table public.app_users enable row level security;
drop policy if exists "app_data read" on public.app_data;
drop policy if exists "app_data insert" on public.app_data;
drop policy if exists "app_data update" on public.app_data;
revoke all on public.app_data from anon, authenticated;
revoke all on public.app_users from anon, authenticated;

-- هل اسم المستخدم وكلمة المرور صحيحان؟
create or replace function public.app_login(p_user text, p_pass text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from app_users
    where username = p_user and password_hash = crypt(p_pass, password_hash)
  );
$$;

-- كل البيانات، لمن يملك اسم مستخدم وكلمة مرور صحيحين.
create or replace function public.app_fetch(p_user text, p_pass text)
returns table (key text, value jsonb)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not app_login(p_user, p_pass) then
    raise exception 'invalid login' using errcode = '28P01';
  end if;
  return query select d.key, d.value from app_data d;
end;
$$;

-- يحفظ مجموعة واحدة كاملة.
create or replace function public.app_put(
  p_user text, p_pass text, p_key text, p_value jsonb
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not app_login(p_user, p_pass) then
    raise exception 'invalid login' using errcode = '28P01';
  end if;
  insert into app_data (key, value, updated_at)
  values (p_key, p_value, now())
  on conflict (key) do update
    set value = excluded.value, updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.app_login(text, text) from public;
revoke all on function public.app_fetch(text, text) from public;
revoke all on function public.app_put(text, text, text, jsonb) from public;
grant execute on function public.app_login(text, text) to anon, authenticated;
grant execute on function public.app_fetch(text, text) to anon, authenticated;
grant execute on function public.app_put(text, text, text, jsonb) to anon, authenticated;

-- حساب الدخول. لتغيير كلمة المرور: غيّر الرقم الثاني وشغّل هذا السطر وحده.
-- ولإضافة مستخدم آخر: انسخ السطر واكتب اسمه وكلمة مروره.
insert into public.app_users (username, password_hash)
values ('36933636', extensions.crypt('36933636', extensions.gen_salt('bf')))
on conflict (username) do update set password_hash = excluded.password_hash;
