"""Servidor de TravelEquality: cuentas, listas, viaje y verificación por correo."""

from datetime import datetime, timezone, timedelta
from pathlib import Path
import hashlib
import json
import random
import secrets
import smtplib
import string
import sqlite3
import threading
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from fastapi import FastAPI, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

# ==========================================
# 1. CONFIGURACIÓN INICIAL Y BASE DE DATOS
# ==========================================

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "datos" / "nube.db"
_LOCK = threading.Lock()

app = FastAPI(title="TravelEquality")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuración de correo SMTP (Gmail)
MAIL_SERVER = "smtp.gmail.com"
MAIL_PORT = 587
MAIL_USERNAME = "tu_correo@gmail.com"
MAIL_PASSWORD = "tu_contraseña_de_aplicacion"

# Almacenamiento en memoria para códigos de verificación con control de tiempo
verification_codes = {}


def now() -> datetime:
    return datetime.now(timezone.utc)


def stamp(moment: datetime) -> str:
    return moment.isoformat()


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
# 2. FUNCIONES AUXILIARES Y SEGURIDAD
# ==========================================

def fail(status_code: int, message: str) -> JSONResponse:
    return JSONResponse({"error": message}, status_code=status_code)


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


def user_from_header(authorization: str | None) -> dict | None:
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


def generar_codigo_aleatorio() -> str:
    return "".join(random.choices(string.digits, k=6))


def enviar_correo(destinatario: str, codigo: str) -> bool:
    mensaje = MIMEMultipart()
    mensaje["From"] = MAIL_USERNAME
    mensaje["To"] = destinatario
    mensaje["Subject"] = "Código de verificación - ViajeListo"

    cuerpo = (
        f"Tu código de verificación de un solo uso es: {codigo}\n"
        "Este código expirará o dejará de ser válido una vez utilizado."
    )
    mensaje.attach(MIMEText(cuerpo, "plain"))

    try:
        servidor = smtplib.SMTP(MAIL_SERVER, MAIL_PORT)
        servidor.starttls()
        servidor.login(MAIL_USERNAME, MAIL_PASSWORD)
        servidor.sendmail(MAIL_USERNAME, destinatario, mensaje.as_string())
        servidor.quit()
        return True
    except Exception as e:
        print(f"Error al enviar correo: {e}")
        return False


# ==========================================
# 3. ESQUEMAS PYDANTIC (MODELOS DE ENTRADA)
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


class DatosIn(BaseModel):
    listas: list
    viajes: list


class CorreoIn(BaseModel):
    email: str


class VerificarIngresoIn(BaseModel):
    correo: str
    codigo: str


# ==========================================
# 4. ENDPOINTS DE LA APLICACIÓN (FASTAPI)
# ==========================================

@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/salud")
def salud() -> dict:
    return {"ok": True}


@app.post("/auth/registro")
def registro(body: RegistroIn):
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
    return {"token": token}


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
def entrar(body: EntrarIn):
    email = body.email.strip().lower()
    if not looks_like_email(email):
        return fail(400, "Escribe un correo válido.")
    with _LOCK, connect() as connection:
        row = connection.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
        if row is None or not check_password(body.password, row["password_hash"]):
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
def recuperar(body: CorreoIn):
    email = body.email.strip().lower()
    if not looks_like_email(email):
        return fail(400, "Escribe un correo válido.")
    with _LOCK, connect() as connection:
        row = connection.execute("SELECT id, verified FROM users WHERE email = ?", (email,)).fetchone()
        if row is None:
            return fail(400, "No hay una cuenta con ese correo.")
        if not row["verified"]:
            return fail(400, "Confirma tu correo antes de cambiar la contraseña.")
        token = issue_token(connection, row["id"], "reset", 1)
    return {"token": token}


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
# 5. ENDPOINTS DE VERIFICACIÓN SMTP (FASTAPI)
# ==========================================

@app.post("/api/solicitar-codigo")
def solicitar_codigo(body: CorreoIn):
    correo = body.email.strip().lower()
    if not looks_like_email(correo):
        return fail(400, "Escribe un correo válido.")

    ahora = datetime.now()

    if correo in verification_codes:
        ultimo_envio = verification_codes[correo].get("created_at")
        if ultimo_envio:
            tiempo_transcurrido = (ahora - ultimo_envio).total_seconds()
            if tiempo_transcurrido < 30:
                tiempo_restante = int(30 - tiempo_transcurrido)
                return JSONResponse(
                    {
                        "error": f"Debes esperar {tiempo_restante} segundos para solicitar otro código.",
                        "tiempo_restante": tiempo_restante,
                    },
                    status_code=429,
                )

    nuevo_codigo = generar_codigo_aleatorio()
    verification_codes[correo] = {
        "code": nuevo_codigo,
        "used": False,
        "created_at": ahora,
    }

    enviado = enviar_correo(correo, nuevo_codigo)
    if not enviado:
        return fail(500, "No se pudo enviar el correo electrónico.")

    return {
        "mensaje": "Código de verificación enviado correctamente. Si solicitas otro, podrás hacerlo en 30 segundos."
    }


@app.post("/api/verificar-ingreso")
def verificar_ingreso(body: VerificarIngresoIn):
    correo = body.correo.strip().lower()
    codigo_ingresado = body.codigo.strip()

    if not correo or not codigo_ingresado:
        return fail(400, "Correo y código de verificación requeridos.")

    registro = verification_codes.get(correo)

    if not registro or registro["used"]:
        return fail(400, "El código no es válido, ya fue utilizado o expiró por una nueva solicitud.")

    if registro["code"] == codigo_ingresado:
        registro["used"] = True
        return {
            "success": True,
            "mensaje": "Verificación exitosa. Acceso concedido.",
        }
    else:
        return fail(400, "Código incorrecto.")


# ==========================================
# 6. ARRANQUE DEL SERVIDOR
# ==========================================

if __name__ == "__main__":
    uvicorn.run("app:app", host="127.0.0.1", port=8088, reload=False)