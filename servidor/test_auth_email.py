import os
import sqlite3
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

from starlette.background import BackgroundTasks
from starlette.requests import Request

sys.path.insert(0, str(Path(__file__).resolve().parent))

import app as server
import db


def request_from(ip: str) -> Request:
    return Request(
        {
            "type": "http",
            "http_version": "1.1",
            "method": "POST",
            "scheme": "http",
            "path": "/",
            "raw_path": b"/",
            "query_string": b"",
            "headers": [],
            "client": (ip, 12345),
            "server": ("test", 80),
        }
    )


@unittest.skipUnless(
    os.environ.get("VIAJELISTO_TEST_DB") == "1" and db.supabase_url(),
    "Requieren una base de Supabase de prueba",
)
class RegistrationOtpTests(unittest.TestCase):
    def setUp(self):
        server._ATTEMPTS.clear()
        server.init_db()

    def test_registration_sends_six_digit_code_and_confirms_account(self):
        sent = []
        background_tasks = BackgroundTasks()

        def capture_code(email, code, minutos=15):
            sent.append((email, code, minutos))
            return True

        with (
            patch.object(server, "correo_disponible", return_value=True),
            patch.object(server, "enviar_codigo", side_effect=capture_code),
        ):
            result = server.registro(
                server.RegistroIn(name="Test", email="test@example.com", password="secret1"),
                request_from("127.0.0.1"),
                background_tasks,
            )
            self.assertEqual(sent, [])
            self.assertEqual(len(background_tasks.tasks), 1)
            task = background_tasks.tasks[0]
            task.func(*task.args, **task.kwargs)

        self.assertIn("Revisa tu correo", result["mensaje"])
        self.assertEqual(sent[0][0], "test@example.com")
        self.assertRegex(sent[0][1], r"^\d{6}$")
        self.assertEqual(sent[0][2], 15)

        confirmed = server.confirmar(
            server.TokenIn(token=sent[0][1]),
            request_from("127.0.0.2"),
        )
        self.assertEqual(confirmed, {"ok": True})

        with db.connect() as connection:
            user = connection.execute(
                "SELECT name, email, verified FROM users WHERE email = ?",
                ("test@example.com",),
            ).fetchone()
        self.assertEqual(user["name"], "Test")
        self.assertEqual(user["verified"], 1)

        login = server.entrar(
            server.EntrarIn(email="test@example.com", password="secret1"),
            request_from("127.0.0.4"),
        )
        self.assertTrue(login["token"])

    def test_failed_background_send_can_be_retried(self):
        background_tasks = BackgroundTasks()
        with (
            patch.object(server, "correo_disponible", return_value=True),
            patch.object(server, "enviar_codigo", return_value=False),
        ):
            result = server.registro(
                server.RegistroIn(name="Test", email="test@example.com", password="secret1"),
                request_from("127.0.0.1"),
                background_tasks,
            )
            task = background_tasks.tasks[0]
            task.func(*task.args, **task.kwargs)

        with db.connect() as connection:
            row = connection.execute(
                "SELECT id, verified FROM users WHERE email = ?", ("test@example.com",)
            ).fetchone()
            tokens = connection.execute(
                "SELECT token FROM tokens WHERE user_id = ? AND kind = ?",
                (row["id"], "verify"),
            ).fetchall()
        self.assertEqual(row["verified"], 0)
        self.assertEqual(tokens, [])

        sent = []
        with (
            patch.object(server, "correo_disponible", return_value=True),
            patch.object(
                server,
                "enviar_codigo",
                side_effect=lambda email, code, minutos=15: sent.append(code) or True,
            ),
        ):
            result = server.reenviar_confirmacion(
                server.CorreoIn(email="test@example.com"),
                request_from("127.0.0.2"),
            )

        self.assertTrue(result["ok"])
        self.assertRegex(sent[0], r"^\d{6}$")
        confirmed = server.confirmar(
            server.TokenIn(token=sent[0]),
            request_from("127.0.0.3"),
        )
        self.assertEqual(confirmed, {"ok": True})


class LoginOtpTests(unittest.TestCase):
    def setUp(self):
        server._ATTEMPTS.clear()
        self.connection = sqlite3.connect(":memory:")
        self.connection.row_factory = sqlite3.Row
        self.connection.executescript(
            """
            CREATE TABLE users (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                phone TEXT,
                photo TEXT,
                verified INTEGER NOT NULL,
                provider TEXT NOT NULL
            );
            CREATE TABLE tokens (
                token TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                kind TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                UNIQUE (user_id, kind)
            );
            INSERT INTO users (id, name, email, password_hash, verified, provider)
            VALUES (1, 'Test', 'test@example.com', 'unused', 1, 'password');
            """
        )
        self.connection.commit()
        self.connect_patch = patch.object(server, "connect", return_value=self.connection)
        self.connect_patch.start()
        self.addCleanup(self.connect_patch.stop)
        self.addCleanup(self.connection.close)

    def test_email_code_creates_one_time_session(self):
        sent = []

        with (
            patch.object(server, "correo_disponible", return_value=True),
            patch.object(
                server,
                "enviar_codigo",
                side_effect=lambda email, code: sent.append((email, code)) or True,
            ),
        ):
            result = server.solicitar_codigo(
                server.CorreoIn(correo="TEST@example.com"),
                request_from("127.0.0.1"),
            )

        self.assertTrue(result["ok"])
        self.assertEqual(sent[0][0], "test@example.com")
        self.assertRegex(sent[0][1], r"^\d{6}$")

        login = server.verificar_ingreso(
            server.VerificarIngresoIn(correo="test@example.com", codigo=sent[0][1]),
            request_from("127.0.0.2"),
        )

        self.assertTrue(login["success"])
        self.assertTrue(login["token"])
        self.assertIsNone(
            self.connection.execute(
                "SELECT token FROM tokens WHERE user_id = 1 AND kind = 'login'"
            ).fetchone()
        )
        self.assertIsNotNone(
            self.connection.execute(
                "SELECT token FROM tokens WHERE user_id = 1 AND kind = 'session'"
            ).fetchone()
        )

    def test_login_code_verification_rejects_malformed_and_limits_attempts(self):
        request = request_from("127.0.0.3")
        body = server.VerificarIngresoIn(correo="test@example.com", codigo="123")

        for _ in range(server._MAX_ATTEMPTS):
            result = server.verificar_ingreso(body, request)
            self.assertEqual(result.status_code, 400)

        limited_result = server.verificar_ingreso(body, request)
        self.assertEqual(limited_result.status_code, 429)


if __name__ == "__main__":
    unittest.main()
