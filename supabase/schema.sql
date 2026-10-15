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

-- الدور: admin (المدير، كل البيانات) أو stock (عامل المخزون: المخزون فقط).
alter table public.app_users
  add column if not exists role text not null default 'admin';

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

-- دور المستخدم، أو null إذا كان الدخول خاطئاً.
create or replace function public.app_role(p_user text, p_pass text)
returns text
language sql
security definer
set search_path = public, extensions
as $$
  select role from app_users
  where username = p_user and password_hash = crypt(p_pass, password_hash);
$$;

-- المجموعات التي يراها ويعدّلها عامل المخزون.
create or replace function public.app_stock_keys()
returns text[]
language sql
immutable
as $$ select array['warehouses', 'products', 'stock_moves']; $$;

-- البيانات المسموحة للمستخدم: المدير يرى كل شيء، وعامل المخزون المخزون فقط.
create or replace function public.app_fetch(p_user text, p_pass text)
returns table (key text, value jsonb)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  r text := app_role(p_user, p_pass);
begin
  if r is null then
    raise exception 'invalid login' using errcode = '28P01';
  end if;
  return query
    select d.key, d.value from app_data d
    where r = 'admin' or d.key = 'company' or d.key = any(app_stock_keys());
end;
$$;

-- يحفظ مجموعة واحدة كاملة. ما لا يحق لعامل المخزون تعديله يُتجاهل.
create or replace function public.app_put(
  p_user text, p_pass text, p_key text, p_value jsonb
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  r text := app_role(p_user, p_pass);
begin
  if r is null then
    raise exception 'invalid login' using errcode = '28P01';
  end if;
  if r <> 'admin' and not (p_key = any(app_stock_keys())) then
    return;
  end if;
  insert into app_data (key, value, updated_at)
  values (p_key, p_value, now())
  on conflict (key) do update
    set value = excluded.value, updated_at = excluded.updated_at;
end;
$$;

-- حسابات العمال (للمدير فقط): القائمة، الإضافة أو تغيير كلمة المرور، الحذف.
create or replace function public.app_users_list(p_user text, p_pass text)
returns table (username text, role text)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if app_role(p_user, p_pass) is distinct from 'admin' then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query select u.username, u.role from app_users u order by u.username;
end;
$$;

create or replace function public.app_user_save(
  p_user text, p_pass text, p_name text, p_password text, p_role text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if app_role(p_user, p_pass) is distinct from 'admin' then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_role not in ('admin', 'stock') or length(trim(p_name)) = 0
     or length(p_password) < 4 or trim(p_name) = p_user then
    raise exception 'invalid user' using errcode = '22023';
  end if;
  insert into app_users (username, password_hash, role)
  values (trim(p_name), crypt(p_password, gen_salt('bf')), p_role)
  on conflict (username) do update
    set password_hash = excluded.password_hash, role = excluded.role;
end;
$$;

create or replace function public.app_user_delete(
  p_user text, p_pass text, p_name text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if app_role(p_user, p_pass) is distinct from 'admin' or p_name = p_user then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from app_users where username = p_name;
end;
$$;

-- يغيّر المستخدم كلمة مروره بنفسه (من التطبيق: الإعدادات ← تغيير كلمة المرور).
create or replace function public.app_change_password(
  p_user text, p_pass text, p_new text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if app_role(p_user, p_pass) is null then
    raise exception 'invalid login' using errcode = '28P01';
  end if;
  if length(p_new) < 4 then
    raise exception 'invalid password' using errcode = '22023';
  end if;
  update app_users set password_hash = crypt(p_new, gen_salt('bf'))
  where username = p_user;
end;
$$;

revoke all on function public.app_login(text, text) from public;
revoke all on function public.app_fetch(text, text) from public;
revoke all on function public.app_put(text, text, text, jsonb) from public;
revoke all on function public.app_role(text, text) from public;
revoke all on function public.app_users_list(text, text) from public;
revoke all on function public.app_user_save(text, text, text, text, text) from public;
revoke all on function public.app_user_delete(text, text, text) from public;
revoke all on function public.app_change_password(text, text, text) from public;
grant execute on function public.app_login(text, text) to anon, authenticated;
grant execute on function public.app_fetch(text, text) to anon, authenticated;
grant execute on function public.app_put(text, text, text, jsonb) to anon, authenticated;
grant execute on function public.app_role(text, text) to anon, authenticated;
grant execute on function public.app_users_list(text, text) to anon, authenticated;
grant execute on function public.app_user_save(text, text, text, text, text) to anon, authenticated;
grant execute on function public.app_user_delete(text, text, text) to anon, authenticated;
grant execute on function public.app_change_password(text, text, text) to anon, authenticated;

-- حساب المدير (أول مرة فقط). كلمة المرور تُغيَّر من التطبيق:
-- الإعدادات ← تغيير كلمة المرور. إعادة تشغيل الملف لا تعيدها إلى الرقم الأول.
insert into public.app_users (username, password_hash, role)
values ('36933636', extensions.crypt('36933636', extensions.gen_salt('bf')), 'admin')
on conflict (username) do update set role = 'admin';
