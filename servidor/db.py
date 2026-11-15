"""Conexión a Supabase (Postgres) o al SQLite local si todavía no hay clave."""

from __future__ import annotations

import os
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "datos" / "nube.db"


def supabase_url() -> str:
    url = os.environ.get("SUPABASE_DB_URL", "").strip() or os.environ.get("DATABASE_URL", "").strip()
    if not url or "tu_clave" in url or "tu_url" in url:
        return ""
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://") :]
    return url


def usa_supabase() -> bool:
    return bool(supabase_url())


class _Resultado:
    def __init__(self, filas: list[dict], lastrowid: int | None = None):
        self._filas = filas
        self.lastrowid = lastrowid

    def fetchone(self) -> dict | None:
        if not self._filas:
            return None
        return self._filas[0]

    def fetchall(self) -> list[dict]:
        return list(self._filas)


class ConexionSupabase:
    def __init__(self, url: str):
        import psycopg
        from psycopg.rows import dict_row

        self._dict_row = dict_row
        self._conn = psycopg.connect(url, prepare_threshold=None)

    def __enter__(self) -> ConexionSupabase:
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        try:
            if exc_type is None:
                self._conn.commit()
            else:
                self._conn.rollback()
        finally:
            self._conn.close()

    def execute(self, sql: str, params: tuple | list = ()) -> _Resultado:
        statement = " ".join(sql.split()).replace("?", "%s")
        upper = statement.upper()
        devolver_id = upper.startswith("INSERT") and "INTO USERS" in upper and "RETURNING" not in upper
        if devolver_id:
            statement = statement.rstrip(";") + " RETURNING id"
        cursor = self._conn.cursor(row_factory=self._dict_row)
        cursor.execute(statement, params)
        if devolver_id:
            fila = cursor.fetchone()
            return _Resultado([], None if fila is None else fila["id"])
        if cursor.description is None:
            return _Resultado([])
        return _Resultado(list(cursor.fetchall()))

    def executescript(self, script: str) -> None:
        # No usa execute(): ese método aplasta los saltos de línea y un
        # comentario -- se comería el resto de la sentencia.
        for sentencia in _sentencias_sql(script):
            cursor = self._conn.cursor(row_factory=self._dict_row)
            cursor.execute(sentencia)


def connect():
    url = supabase_url()
    if url:
        return ConexionSupabase(url)
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def _tiene_sql(texto: str) -> bool:
    i = 0
    n = len(texto)
    while i < n:
        if texto[i].isspace():
            i += 1
            continue
        if texto.startswith("--", i):
            fin = texto.find("\n", i)
            i = n if fin == -1 else fin + 1
            continue
        if texto.startswith("/*", i):
            fin = texto.find("*/", i + 2)
            i = n if fin == -1 else fin + 2
            continue
        return True
    return False


def _sentencias_sql(script: str) -> list[str]:
    """Parte el script sin cortar textos, comentarios ni cuerpos de función."""
    sentencias: list[str] = []
    buf: list[str] = []
    i = 0
    n = len(script)
    while i < n:
        ch = script[i]
        if ch == "-" and i + 1 < n and script[i + 1] == "-":
            fin = script.find("\n", i)
            if fin == -1:
                buf.append(script[i:])
                break
            buf.append(script[i : fin + 1])
            i = fin + 1
            continue
        if ch == "/" and i + 1 < n and script[i + 1] == "*":
            fin = script.find("*/", i + 2)
            if fin == -1:
                buf.append(script[i:])
                break
            buf.append(script[i : fin + 2])
            i = fin + 2
            continue
        if ch == "'":
            buf.append(ch)
            i += 1
            while i < n:
                buf.append(script[i])
                if script[i] == "'":
                    if i + 1 < n and script[i + 1] == "'":
                        buf.append(script[i + 1])
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
            continue
        if ch == "$":
            j = i + 1
            while j < n and (script[j].isalnum() or script[j] == "_"):
                j += 1
            if j < n and script[j] == "$":
                etiqueta = script[i : j + 1]
                cierre = script.find(etiqueta, j + 1)
                if cierre == -1:
                    buf.append(script[i:])
                    break
                fin = cierre + len(etiqueta)
                buf.append(script[i:fin])
                i = fin
                continue
        if ch == ";":
            texto = "".join(buf).strip()
            if texto and _tiene_sql(texto):
                sentencias.append(texto)
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    resto = "".join(buf).strip()
    if resto and _tiene_sql(resto):
        sentencias.append(resto)
    return sentencias


ESQUEMA_SUPABASE = """-- TravelEquality. Cuentas, códigos OTP y datos del viaje.
-- Solo las usa el servidor. La clave pública de Supabase no puede leerlas.

create table if not exists public.users (
  id integer generated by default as identity primary key,
  name text not null,
  email text not null,
  password_hash text not null,
  phone text,
  photo text,
  verified integer not null default 0,
  provider text not null default 'password'
);

alter table public.users add column if not exists provider text not null default 'password';

alter table public.users drop constraint if exists users_email_unica;
alter table public.users add constraint users_email_unica unique (email);

alter table public.users drop constraint if exists users_verified_ok;
alter table public.users add constraint users_verified_ok check (verified in (0, 1));

alter table public.users drop constraint if exists users_provider_ok;
alter table public.users add constraint users_provider_ok check (provider in ('password', 'google'));

create table if not exists public.tokens (
  token text primary key,
  user_id integer not null references public.users (id) on delete cascade,
  kind text not null,
  expires_at text not null
);

alter table public.tokens drop constraint if exists tokens_kind_ok;
alter table public.tokens add constraint tokens_kind_ok
  check (kind in ('verify', 'reset', 'login', 'session'));

create unique index if not exists tokens_un_codigo_por_uso
  on public.tokens (user_id, kind);

create table if not exists public.user_data (
  user_id integer primary key references public.users (id) on delete cascade,
  lists_json text not null,
  trips_json text not null
);

-- verify: código al crear la cuenta
-- reset: código al recuperar la contraseña
-- login: código para entrar por correo
-- session: sesión, solo si la cuenta ya está verificada

create or replace function public.sesion_solo_cuenta_verificada()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.kind = 'session' and not exists (
    select 1
    from public.users
    where id = new.user_id
      and verified = 1
  ) then
    raise exception 'La cuenta no está verificada';
  end if;
  return new;
end;
$$;

drop trigger if exists sesion_solo_cuenta_verificada on public.tokens;
create trigger sesion_solo_cuenta_verificada
  before insert on public.tokens
  for each row
  execute function public.sesion_solo_cuenta_verificada();

create or replace function public.cuenta_google_verificada()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.provider = 'google' then
    new.verified := 1;
  end if;
  return new;
end;
$$;

drop trigger if exists cuenta_google_verificada on public.users;
create trigger cuenta_google_verificada
  before insert or update of provider on public.users
  for each row
  execute function public.cuenta_google_verificada();

alter table public.users enable row level security;
alter table public.tokens enable row level security;
alter table public.user_data enable row level security;

revoke all on table public.users from anon, authenticated;
revoke all on table public.tokens from anon, authenticated;
revoke all on table public.user_data from anon, authenticated;

revoke all on function public.sesion_solo_cuenta_verificada() from public, anon, authenticated;
revoke all on function public.cuenta_google_verificada() from public, anon, authenticated;
"""


def iniciar_supabase(connection: ConexionSupabase) -> None:
    connection.executescript(ESQUEMA_SUPABASE)
