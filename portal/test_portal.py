"""Run source checks: python portal/test_portal.py

Set RUN_PORTAL_DOCKER_TESTS=1 to additionally verify real nginx HTTP behavior.
Docker tests use an isolated container, ephemeral port, and disposable credentials.
"""
import base64
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import unittest
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

PORTAL = Path(__file__).resolve().parent
ROOT = PORTAL.parent


class SourceSafetyTest(unittest.TestCase):
    def test_browser_receives_no_password_verifier_or_fake_login(self):
        html = (PORTAL / "index.html").read_text(encoding="utf-8")
        for marker in ("ADMIN_HASH", "sessionStorage", "grantAccess", "login-overlay"):
            self.assertNotIn(marker, html)
        self.assertNotRegex(html, r"\b[a-f0-9]{64}\b")
        self.assertIn("https://panel.e-any.online", html)

    def test_compose_uses_one_html_source_and_an_external_secret(self):
        root = (ROOT / "docker-compose.yml").read_text()
        compose = (PORTAL / "docker-compose.yml").read_text()
        self.assertIn("./portal/docker-compose.yml", root)
        self.assertFalse((ROOT / "index.html").exists())
        self.assertIn("./index.html:/usr/share/nginx/html/index.html:ro", compose)
        self.assertIn("${PORTAL_HTPASSWD_FILE:?", compose)
        config = (PORTAL / "nginx.conf").read_text()
        self.assertIn("auth_basic_user_file /run/secrets/portal_htpasswd;", config)
        self.assertNotIn("auth_basic off", config)


@unittest.skipUnless(os.environ.get("RUN_PORTAL_DOCKER_TESTS") == "1", "opt-in Docker integration tests")
class NginxAccessTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="eany-portal-test-")
        cls.addClassCleanup(cls.temp.cleanup)
        auth = Path(cls.temp.name) / "test.htpasswd"
        # Disposable public test fixture. Production uses an externally provisioned htpasswd.
        digest = base64.b64encode(hashlib.sha1(b"fixture-only-password").digest()).decode()
        auth.write_text("tester:{SHA}" + digest + "\n", encoding="ascii")
        env = dict(os.environ, PORTAL_HTPASSWD_FILE=str(auth))
        for compose in (ROOT / "docker-compose.yml", PORTAL / "docker-compose.yml"):
            subprocess.run(["docker", "compose", "-f", str(compose), "config", "--quiet"],
                           env=env, check=True, capture_output=True, timeout=30)
        mounts = [
            (PORTAL / "index.html", "/usr/share/nginx/html/index.html"),
            (PORTAL / "nginx.conf", "/etc/nginx/conf.d/default.conf"),
            (PORTAL / "start.sh", "/opt/portal/start.sh"),
            (auth, "/run/secrets/portal_htpasswd"),
        ]
        command = ["docker", "run", "--rm", "-d", "-p", "127.0.0.1::80"]
        for source, target in mounts:
            command += ["-v", f"{source}:{target}:ro"]
        command += ["--entrypoint", "/bin/sh", "nginx:alpine", "/opt/portal/start.sh",
                    "nginx", "-g", "daemon off;"]
        cls.container = subprocess.check_output(command, text=True, timeout=120).strip()
        cls.addClassCleanup(lambda: subprocess.run(["docker", "rm", "-f", cls.container],
                                                  capture_output=True, timeout=30))
        address = subprocess.check_output(["docker", "port", cls.container, "80/tcp"],
                                          text=True, timeout=10).strip()
        if not re.fullmatch(r"127\.0\.0\.1:\d+", address):
            raise AssertionError("Unexpected test container address")
        cls.url = "http://" + address
        for _ in range(50):
            try:
                cls.get_status("/")
                break
            except URLError:
                time.sleep(0.1)
        else:
            raise AssertionError("nginx did not become ready")

    @classmethod
    def get_status(cls, path, credentials=None):
        headers = {}
        if credentials:
            headers["Authorization"] = "Basic " + base64.b64encode(credentials.encode()).decode()
        try:
            with urlopen(Request(cls.url + path, headers=headers), timeout=2) as response:
                return response.status, response.read(), response.headers
        except HTTPError as response:
            return response.code, response.read(), response.headers

    def test_unauthenticated_and_invalid_password_cannot_read_html(self):
        for path in ("/", "/index.html"):
            for credentials in (None, "tester:wrong-password"):
                status, body, _ = self.get_status(path, credentials)
                self.assertEqual(status, 401)
                self.assertNotIn(b"AgentsMesh", body)

    def test_valid_credentials_return_portal_without_mutating_source(self):
        before = (PORTAL / "index.html").read_bytes()
        status, body, headers = self.get_status("/", "tester:fixture-only-password")
        self.assertEqual(status, 200)
        self.assertIn(b"panel.e-any.online", body)
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertEqual(before, (PORTAL / "index.html").read_bytes())


if __name__ == "__main__":
    unittest.main()
