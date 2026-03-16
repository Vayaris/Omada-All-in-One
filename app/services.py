# ============================================================
# Omada All-In-One Hub - Services helpers
# (systemctl, version lecture, GitHub API)
# ============================================================

import subprocess
import urllib.request
import urllib.error
import json
import os

import config


# ----------------------------------------------------------------
# Lecture version locale
# ----------------------------------------------------------------

def read_local_version(version_file: str):
    """Lit le fichier VERSION. Retourne None si le fichier n'existe pas."""
    try:
        with open(version_file) as f:
            v = f.read().strip()
            return v if v else None
    except OSError:
        return None


# ----------------------------------------------------------------
# Statut systemd
# ----------------------------------------------------------------

def get_service_status(service_name: str) -> dict:
    """
    Retourne le statut d'un service systemd.
    {
      "installed": bool,
      "active": bool,
      "state": "active"|"inactive"|"failed"|"not_installed"|"unknown",
      "sub_state": str,
    }
    """
    # Vérifier si le fichier unit existe
    unit_check = subprocess.run(
        ["systemctl", "list-unit-files", f"{service_name}.service", "--no-legend"],
        capture_output=True, text=True, timeout=5
    )
    installed = service_name in unit_check.stdout

    if not installed:
        return {"installed": False, "active": False, "state": "not_installed", "sub_state": ""}

    result = subprocess.run(
        ["systemctl", "show", service_name,
         "--property=ActiveState,SubState,LoadState"],
        capture_output=True, text=True, timeout=5
    )
    props = {}
    for line in result.stdout.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            props[k] = v

    active_state = props.get("ActiveState", "unknown")
    sub_state    = props.get("SubState", "")
    load_state   = props.get("LoadState", "")

    return {
        "installed":  load_state != "not-found",
        "active":     active_state == "active",
        "state":      active_state,
        "sub_state":  sub_state,
    }


def run_systemctl(action: str, service: str) -> dict:
    """Lance start/stop/restart sur un service systemd."""
    if action not in ("start", "stop", "restart"):
        return {"success": False, "error": "Action invalide"}
    try:
        r = subprocess.run(
            ["systemctl", action, f"{service}.service"],
            capture_output=True, text=True, timeout=30
        )
        if r.returncode == 0:
            return {"success": True, "error": ""}
        return {"success": False, "error": (r.stderr or r.stdout).strip()}
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "systemctl timeout"}
    except Exception as e:
        return {"success": False, "error": str(e)}


# ----------------------------------------------------------------
# GitHub version check
# ----------------------------------------------------------------

def fetch_github_latest(repo: str) -> dict:
    """
    Interroge l'API GitHub Releases pour obtenir la dernière version.
    Retourne {"tag": "1.2.3", "url": "...", "body": ""} ou None en cas d'erreur.
    Fallback sur fichier VERSION brut si pas encore de release.
    """
    url = f"{config.GITHUB_API_BASE}/{repo}/releases/latest"
    try:
        req = urllib.request.Request(url, headers=config.GITHUB_HEADERS)
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read())
            tag = data.get("tag_name", "").lstrip("v")
            return {
                "tag":  tag,
                "url":  data.get("html_url", f"https://github.com/{repo}"),
                "body": data.get("body", ""),
            }
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return _fallback_raw_version(repo)
        return None
    except Exception:
        return None


def _fallback_raw_version(repo: str) -> dict:
    """Lit le fichier VERSION brut sur GitHub (si pas encore de release)."""
    url = f"https://raw.githubusercontent.com/{repo}/main/VERSION"
    try:
        req = urllib.request.Request(url, headers=config.GITHUB_HEADERS)
        with urllib.request.urlopen(req, timeout=8) as resp:
            tag = resp.read().decode().strip()
            return {"tag": tag, "url": f"https://github.com/{repo}", "body": ""}
    except Exception:
        return None


def compare_versions(local, remote) -> bool:
    """Retourne True si remote > local. Gère None sans crash."""
    if not local or not remote:
        return False
    try:
        return (
            [int(x) for x in str(remote).split(".")]
            > [int(x) for x in str(local).split(".")]
        )
    except (ValueError, AttributeError):
        return False


# ----------------------------------------------------------------
# IP serveur (pour les URLs d'ouverture)
# ----------------------------------------------------------------

def get_server_ip() -> str:
    """Tente de détecter l'IP principale du serveur."""
    try:
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "localhost"
