import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

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


class RegistrationOtpTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.old_db_path = db.DB_PATH
        db.DB_PATH = Path(self.temp_dir.name) / "test.sqlite"
        server._ATTEMPTS.clear()
        server.init_db()

    def tearDown(self):
        db.DB_PATH = self.old_db_path
        self.temp_dir.cleanup()

    def test_registration_sends_six_digit_code_and_confirms_account(self):
        sent = []

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
            )

        self.assertIn("Revisa tu correo", result["mensaje"])
        self.assertEqual(sent[0][0], "test@example.com")
        self.assertRegex(sent[0][1], r"^\d{6}$")
        self.assertEqual(sent[0][2], 15)

        confirmed = server.confirmar(
            server.TokenIn(token=sent[0][1]),
            request_from("127.0.0.2"),
        )
        self.assertEqual(confirmed, {"ok": True})

    def test_registration_does_not_create_account_when_email_fails(self):
        with (
            patch.object(server, "correo_disponible", return_value=True),
            patch.object(server, "enviar_codigo", return_value=False),
        ):
            result = server.registro(
                server.RegistroIn(name="Test", email="test@example.com", password="secret1"),
                request_from("127.0.0.1"),
            )

        self.assertEqual(result.status_code, 503)
        self.assertIn("No se pudo enviar", json.loads(result.body)["error"])
        with db.connect() as connection:
            row = connection.execute(
                "SELECT id FROM users WHERE email = ?", ("test@example.com",)
            ).fetchone()
        self.assertIsNone(row)


if __name__ == "__main__":
    unittest.main()
