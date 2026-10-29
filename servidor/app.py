from __future__ import annotations

"""Servidor de TravelEquality: cuentas, listas y viaje."""

# ==========================================
# 1. IMPORTACIONES Y CONFIGURACIÓN INICIAL
# ==========================================
import hashlib
import json
import os
import secrets
import smtplib
import sqlite3
import threading
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from pathlib import Path
from fastapi import FastAPI, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "datos" / "nube.db"
_LOCK = threading.Lock()

app = FastAPI(title="TravelEquality")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_methods=["*"],
    allow_headers=["*"],
)

_ATTEMPTS: dict[str, list[datetime]] = {}
_WINDOW = timedelta(minutes=10)
_MAX_ATTEMPTS = 8
_MISMO_AVISO = "Si el correo está registrado, el código queda listo."


def client_key(request: Request, action: str) -> str:
    forwarded = request.headers.get("cf-connecting-ip") or request.headers.get("x-forwarded-for") or ""
    ip = forwarded.split(",")[0].strip()
    if not ip and request.client is not None:
        ip = request.client.host
    return f"{action}:{ip or 'local'}"


def _recent(request: Request, action: str) -> tuple[str, list[datetime]]:
    key = client_key(request, action)
    moment = now()
    recent = [item for item in _ATTEMPTS.get(key, []) if moment - item < _WINDOW]
    return key, recent


def blocked(request: Request, action: str) -> bool:
    key, recent = _recent(request, action)
    _ATTEMPTS[key] = recent
    return len(recent) >= _MAX_ATTEMPTS


def note_attempt(request: Request, action: str) -> None:
    key, recent = _recent(request, action)
    recent.append(now())
    _ATTEMPTS[key] = recent


def limited(request: Request, action: str) -> bool:
    if blocked(request, action):
        return True
    note_attempt(request, action)
    return False


# ==========================================
# 2. UTILIDADES DE TIEMPO Y FECHAS
# ==========================================
def now() -> datetime:
    return datetime.now(timezone.utc)


def stamp(moment: datetime) -> str:
    return moment.isoformat()


# ==========================================
# 3. CONEXIÓN E INICIALIZACIÓN DE LA BASE DE DATOS
# ==========================================
def connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def init_db() -> None:
    with _LOCK, connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              email TEXT UNIQUE NOT NULL,
              password_hash TEXT NOT NULL,
              phone TEXT,
              photo TEXT,
              verified INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS tokens (
              token TEXT PRIMARY KEY,
              user_id INTEGER NOT NULL,
              kind TEXT NOT NULL,
              expires_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS user_data (
              user_id INTEGER PRIMARY KEY,
              lists_json TEXT NOT NULL,
              trips_json TEXT NOT NULL
            );
            """
        )


# ==========================================
# 4. UTILIDADES DE SEGURIDAD Y VALIDACIONES
# ==========================================
def fail(status: int, message: str) -> JSONResponse:
    return JSONResponse({"error": message}, status_code=status)


def looks_like_email(email: str) -> bool:
    if "@" not in email or " " in email:
        return False
    name, _, domain = email.partition("@")
    return bool(name) and "." in domain and not domain.startswith(".") and not domain.endswith(".")


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
    return f"{salt.hex()}:{digest.hex()}"


def check_password(password: str, stored: str) -> bool:
    salt_hex, _, digest_hex = stored.partition(":")
    if not salt_hex or not digest_hex:
        return False
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt_hex), 100_000)
    return secrets.compare_digest(digest.hex(), digest_hex)


def public_user(row: sqlite3.Row) -> dict:
    return {
        "name": row["name"],
        "email": row["email"],
        "phone": row["phone"] or "",
        "photo": row["photo"],
    }


# ==========================================
# 5. GESTIÓN DE TOKENS DE SESIÓN
# ==========================================
def issue_token(connection: sqlite3.Connection, user_id: int, kind: str, hours: int) -> str:
    connection.execute("DELETE FROM tokens WHERE user_id = ? AND kind = ?", (user_id, kind))
    token = secrets.token_urlsafe(9)
    expires = stamp(now() + timedelta(hours=hours))
    connection.execute(
        "INSERT INTO tokens (token, user_id, kind, expires_at) VALUES (?, ?, ?, ?)",
        (token, user_id, kind, expires),
    )
    return token


def take_token(connection: sqlite3.Connection, token: str, kind: str) -> sqlite3.Row | None:
    row = connection.execute(
        """
        SELECT tokens.token, tokens.expires_at, users.id, users.email
        FROM tokens
        JOIN users ON users.id = tokens.user_id
        WHERE tokens.token = ? AND tokens.kind = ?
        """,
        (token, kind),
    ).fetchone()
    if row is None:
        return None
    expires = datetime.fromisoformat(row["expires_at"])
    if expires < now():
        connection.execute("DELETE FROM tokens WHERE token = ?", (token,))
        return None
    return row


def user_from_header(authorization: str | None) -> sqlite3.Row | None:
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        return None
    with _LOCK, connect() as connection:
        row = take_token(connection, token, "session")
        if row is None:
            return None
        found = connection.execute("SELECT * FROM users WHERE id = ?", (row["id"],)).fetchone()
        return None if found is None else dict(found)


# ==========================================
# 6. MODELOS DE PYDANTIC (ESQUEMAS DE ENTRADA)
# ==========================================
class RegistroIn(BaseModel):
    name: str
    email: str
    password: str


class EntrarIn(BaseModel):
    email: str
    password: str


class TokenIn(BaseModel):
    token: str


class RestablecerIn(BaseModel):
    token: str
    password: str


class CambiarIn(BaseModel):
    actual: str
    nueva: str


class PerfilIn(BaseModel):
    name: str | None = None
    phone: str | None = None


class FotoIn(BaseModel):
    photo: str | None = None


class CorreoIn(BaseModel):
    email: str = ""
    correo: str = ""

    def direccion(self) -> str:
        return (self.correo or self.email).strip().lower()


class DatosIn(BaseModel):
    listas: list
    viajes: list


# ==========================================
# 7. EVENTO DE INICIO Y RUTA DE SALUD
# ==========================================
@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/")
def inicio() -> dict:
    return {
        "ok": True,
        "mensaje": "Servidor de TravelEquality en marcha.",
        "salud": "/salud",
        "docs": "/docs",
    }


@app.get("/salud")
def salud() -> dict:
    return {"ok": True}


# ==========================================
# 8. RUTAS DE AUTENTICACIÓN Y GESTIÓN DE CUENTAS
# ==========================================
@app.post("/auth/registro")
def registro(body: RegistroIn, request: Request):
    if limited(request, "registro"):
        return fail(429, "Demasiados intentos. Espera unos minutos.")
    name = body.name.strip()
    email = body.email.strip().lower()
    if not name:
        return fail(400, "Escribe tu nombre.")
    if not looks_like_email(email):
        return fail(400, "Escribe un correo válido.")
    if len(body.password) < 6:
        return fail(400, "La contraseña necesita al menos 6 caracteres.")

    with _LOCK, connect() as connection:
        existing = connection.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()
        if existing is not None:
            return fail(400, "Ese correo ya tiene una cuenta.")
        cursor = connection.execute(
            "INSERT INTO users (name, email, password_hash, verified) VALUES (?, ?, ?, 0)",
            (name, email, hash_password(body.password)),
        )
        token = issue_token(connection, cursor.lastrowid, "verify", 24)
    if not enviar_codigo(email, token, minutos=24 * 60):
        with _LOCK, connect() as connection:
            connection.execute("DELETE FROM tokens WHERE token = ?", (token,))
            connection.execute("DELETE FROM users WHERE email = ?", (email,))
        return fail(400, "No se pudo enviar el correo de confirmación.")
    return {"ok": True, "mensaje": "Revisa tu correo para confirmar la cuenta."}


@app.post("/auth/confirmar")
def confirmar(body: TokenIn):
    with _LOCK, connect() as connection:
        row = take_token(connection, body.token.strip(), "verify")
        if row is None:
            return fail(400, "Ese código ya no sirve. Crea la cuenta de nuevo.")
        connection.execute("UPDATE users SET verified = 1 WHERE id = ?", (row["id"],))
        connection.execute("DELETE FROM tokens WHERE token = ?", (body.token.strip(),))
    return {"ok": True}


@app.post("/auth/entrar")
def entrar(body: EntrarIn, request: Request):
    if blocked(request, "entrar"):
        return fail(429, "Demasiados intentos. Espera unos minutos.")
    email = body.email.strip().lower()
    if not looks_like_email(email):
        return fail(400, "Escribe un correo válido.")
    with _LOCK, connect() as connection:
        row = connection.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
        if row is None or not check_password(body.password, row["password_hash"]):
            note_attempt(request, "entrar")
            return fail(400, "Correo o contraseña incorrectos.")
        if not row["verified"]:
            return fail(400, "Confirma tu correo antes de entrar.")
        token = issue_token(connection, row["id"], "session", 24 * 30)
    return {"token": token, **public_user(row)}


@app.get("/auth/yo")
def yo(authorization: str | None = Header(default=None)):
    row = user_from_header(authorization)
    if row is None:
        return fail(401, "La sesión expiró.")
    return public_user(row)


@app.patch("/auth/perfil")
def perfil(body: PerfilIn, authorization: str | None = Header(default=None)):
    row = user_from_header(authorization)
    if row is None:
        return fail(401, "La sesión expiró.")
    fields = body.model_fields_set
    name = row["name"]
    phone = row["phone"]
    if "name" in fields:
        name = (body.name or "").strip()
        if not name:
            return fail(400, "Escribe tu nombre.")
    if "phone" in fields:
        phone = (body.phone or "").strip()
        digits = "".join(char for char in phone if char.isdigit())
        if phone and len(digits) < 8:
            return fail(400, "Escribe un teléfono válido.")
        phone = phone or None
    with _LOCK, connect() as connection:
        connection.execute(
            "UPDATE users SET name = ?, phone = ? WHERE id = ?",
            (name, phone, row["id"]),
        )
        updated = connection.execute("SELECT * FROM users WHERE id = ?", (row["id"],)).fetchone()
    return public_user(updated)


@app.put("/auth/foto")
def foto(body: FotoIn, authorization: str | None = Header(default=None)):
    row = user_from_header(authorization)
    if row is None:
        return fail(401, "La sesión expiró.")
    photo = body.photo
    if photo is not None and len(photo) > 1_600_000:
        return fail(400, "Esa foto es muy pesada. Elige una más pequeña.")
    if photo == "":
        photo = None
    with _LOCK, connect() as connection:
        connection.execute("UPDATE users SET photo = ? WHERE id = ?", (photo, row["id"]))
    return {"ok": True}


@app.post("/auth/cambiar")
def cambiar(body: CambiarIn, authorization: str | None = Header(default=None)):
    row = user_from_header(authorization)
    if row is None:
        return fail(401, "La sesión expiró.")
    if len(body.nueva) < 6:
        return fail(400, "La contraseña necesita al menos 6 caracteres.")
    if not check_password(body.actual, row["password_hash"]):
        return fail(400, "La contraseña actual no es correcta.")
    with _LOCK, connect() as connection:
        connection.execute(
            "UPDATE users SET password_hash = ? WHERE id = ?",
            (hash_password(body.nueva), row["id"]),
        )
    return {"ok": True}


@app.post("/auth/recuperar")
def recuperar(body: CorreoIn, request: Request):
    if limited(request, "recuperar"):
        return fail(429, "Demasiados intentos. Espera unos minutos.")
    email = body.direccion()
    if not looks_like_email(email):
        return fail(400, "Escribe un correo válido.")
    token = None
    with _LOCK, connect() as connection:
        row = connection.execute("SELECT id, verified FROM users WHERE email = ?", (email,)).fetchone()
        if row is not None and row["verified"]:
            token = issue_token(connection, row["id"], "reset", 1)
    if token is not None and not enviar_codigo(email, token, minutos=60):
        with _LOCK, connect() as connection:
            connection.execute("DELETE FROM tokens WHERE token = ?", (token,))
    return {"ok": True, "mensaje": _MISMO_AVISO}


@app.post("/auth/restablecer")
def restablecer(body: RestablecerIn):
    if len(body.password) < 6:
        return fail(400, "La contraseña necesita al menos 6 caracteres.")
    with _LOCK, connect() as connection:
        row = take_token(connection, body.token.strip(), "reset")
        if row is None:
            return fail(400, "Ese código ya no sirve. Pide uno nuevo.")
        connection.execute(
            "UPDATE users SET password_hash = ? WHERE id = ?",
            (hash_password(body.password), row["id"]),
        )
        connection.execute("DELETE FROM tokens WHERE token = ?", (body.token.strip(),))
    return {"ok": True}


class VerificarIngresoIn(BaseModel):
    correo: str
    codigo: str


def mail_listo() -> bool:
    user = os.environ.get("MAIL_USERNAME", "").strip()
    password = os.environ.get("MAIL_PASSWORD", "").strip()
    return bool(user and password and "tu_correo" not in user)


def enviar_codigo(destinatario: str, codigo: str, minutos: int = 15) -> bool:
    if not mail_listo():
        return False
    message = EmailMessage()
    message["Subject"] = "Tu código de TravelEquality"
    message["From"] = os.environ["MAIL_USERNAME"].strip()
    message["To"] = destinatario
    message.set_content(f"Tu código de un solo uso es {codigo}. Vence en {minutos} minutos.")
    try:
        with smtplib.SMTP(os.environ.get("MAIL_SERVER", "smtp.gmail.com"), 587, timeout=10) as server:
            server.starttls()
            server.login(os.environ["MAIL_USERNAME"].strip(), os.environ["MAIL_PASSWORD"].strip())
            server.send_message(message)
        return True
    except (OSError, smtplib.SMTPException):
        return False


@app.post("/api/solicitar-codigo")
def solicitar_codigo(body: CorreoIn, request: Request):
    if limited(request, "codigo"):
        return fail(429, "Demasiados intentos. Espera unos minutos.")
    email = body.direccion()
    if not looks_like_email(email):
        return fail(400, "Escribe un correo válido.")
    code = None
    user_id = None
    with _LOCK, connect() as connection:
        row = connection.execute("SELECT id, verified FROM users WHERE email = ?", (email,)).fetchone()
        if row is not None and row["verified"]:
            user_id = row["id"]
            code = f"{secrets.randbelow(1_000_000):06d}"
            connection.execute("DELETE FROM tokens WHERE user_id = ? AND kind = ?", (user_id, "login"))
            connection.execute(
                "INSERT INTO tokens (token, user_id, kind, expires_at) VALUES (?, ?, ?, ?)",
                (code, user_id, "login", stamp(now() + timedelta(minutes=15))),
            )
    if code is not None and not enviar_codigo(email, code):
        with _LOCK, connect() as connection:
            connection.execute("DELETE FROM tokens WHERE user_id = ? AND kind = ?", (user_id, "login"))
    return {"ok": True, "mensaje": _MISMO_AVISO}


@app.post("/api/verificar-ingreso")
def verificar_ingreso(body: VerificarIngresoIn):
    email = body.correo.strip().lower()
    code = body.codigo.strip()
    with _LOCK, connect() as connection:
        row = connection.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
        if row is None:
            return fail(400, "Código inválido.")
        saved = connection.execute(
            "SELECT expires_at FROM tokens WHERE user_id = ? AND kind = ? AND token = ?",
            (row["id"], "login", code),
        ).fetchone()
        if saved is None or datetime.fromisoformat(saved["expires_at"]) < now():
            return fail(400, "Código inválido.")
        connection.execute("DELETE FROM tokens WHERE user_id = ? AND kind = ?", (row["id"], "login"))
        token = issue_token(connection, row["id"], "session", 24 * 30)
        user = public_user(row)
    return {"success": True, "token": token, **user}


# ==========================================
# 9. RUTAS DE SINCRONIZACIÓN DE DATOS (LISTAS Y VIAJES)
# ==========================================
@app.get("/datos")
def leer_datos(authorization: str | None = Header(default=None)):
    row = user_from_header(authorization)
    if row is None:
        return fail(401, "La sesión expiró.")
    with _LOCK, connect() as connection:
        saved = connection.execute(
            "SELECT lists_json, trips_json FROM user_data WHERE user_id = ?",
            (row["id"],),
        ).fetchone()
    if saved is None:
        return {"sincronizado": False, "listas": [], "viajes": []}
    return {
        "sincronizado": True,
        "listas": json.loads(saved["lists_json"]),
        "viajes": json.loads(saved["trips_json"]),
    }


@app.put("/datos")
def guardar_datos(body: DatosIn, authorization: str | None = Header(default=None)):
    row = user_from_header(authorization)
    if row is None:
        return fail(401, "La sesión expiró.")
    lists_json = json.dumps(body.listas)
    trips_json = json.dumps(body.viajes)
    with _LOCK, connect() as connection:
        connection.execute(
            """
            INSERT INTO user_data (user_id, lists_json, trips_json)
            VALUES (?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
              lists_json = excluded.lists_json,
              trips_json = excluded.trips_json
            """,
            (row["id"], lists_json, trips_json),
        )
    return {"ok": True}


# ==========================================
# 10. EJECUCIÓN DEL SERVIDOR
# ==========================================
if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", "8088"))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=False)