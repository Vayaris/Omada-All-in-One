# ============================================================
# Omada All-In-One Hub - Logique de mise à jour par composant
# ============================================================

import os
import shutil
import subprocess
import tempfile
import threading
import time
import urllib.request

import config
from services import run_systemctl, read_local_version


# ----------------------------------------------------------------
# MAJ Omada Manager
# Mécanisme : téléchargement fichiers par fichiers depuis raw.githubusercontent.com
# Identique à perform_self_update() dans le Manager original
# ----------------------------------------------------------------

def update_manager() -> dict:
    """
    Phase 1 : télécharge tous les fichiers dans un répertoire temporaire.
    Phase 2 (atomique) : copie vers le répertoire d'installation.
    Phase 3 : pip install dans le venv.
    Phase 4 : systemctl restart omada-web.
    """
    tmp_dir = tempfile.mkdtemp(prefix="hub_mgr_update_")
    try:
        # Phase 1 — download
        for remote_rel, local_rel in config.MANAGER_UPDATE_FILES:
            url = f"{config.MANAGER_GITHUB_RAW}/{remote_rel}"
            dst = os.path.join(tmp_dir, local_rel)
            os.makedirs(os.path.dirname(dst) or tmp_dir, exist_ok=True)
            req = urllib.request.Request(url, headers=config.GITHUB_HEADERS)
            with urllib.request.urlopen(req, timeout=30) as resp:
                with open(dst, "wb") as f:
                    f.write(resp.read())

        # Phase 2 — copie atomique
        for _, local_rel in config.MANAGER_UPDATE_FILES:
            src = os.path.join(tmp_dir, local_rel)
            dst = os.path.join(config.MANAGER_INSTALL_DIR, local_rel)
            os.makedirs(os.path.dirname(dst) or config.MANAGER_INSTALL_DIR, exist_ok=True)
            shutil.copy2(src, dst)

        # Phase 3 — pip dans le venv
        venv_pip = os.path.join(config.MANAGER_INSTALL_DIR, "venv", "bin", "pip")
        req_file = os.path.join(config.MANAGER_INSTALL_DIR, "requirements.txt")
        if os.path.isfile(venv_pip) and os.path.isfile(req_file):
            subprocess.run(
                [venv_pip, "install", "--quiet", "-r", req_file],
                capture_output=True, timeout=120
            )

        # Phase 4 — redémarrage service
        restart = run_systemctl("restart", config.MANAGER_SERVICE_NAME)
        new_ver = read_local_version(config.MANAGER_VERSION_FILE) or "?"
        return {
            "success":     restart["success"],
            "new_version": new_ver,
            "error":       restart.get("error", ""),
        }
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


# ----------------------------------------------------------------
# MAJ Omada API Hub
# Mécanisme : git pull origin main + pip install + restart
# ----------------------------------------------------------------

def update_api_hub() -> dict:
    """
    Vérifie que le répertoire est un repo git avant de procéder.
    git pull → pip install → systemctl restart omada-api-hub.
    """
    install_dir = config.API_HUB_INSTALL_DIR

    # Prérequis : git disponible
    if not shutil.which("git"):
        return {"success": False, "error": "git n'est pas installé sur ce système."}

    # Prérequis : repo git valide
    git_check = subprocess.run(
        ["git", "-C", install_dir, "rev-parse", "--is-inside-work-tree"],
        capture_output=True, text=True, timeout=5
    )
    if git_check.returncode != 0:
        return {
            "success": False,
            "error": "Le répertoire d'installation n'est pas un dépôt git. "
                     "Relancez install.sh pour réinstaller."
        }

    # git pull
    pull = subprocess.run(
        ["git", "-C", install_dir, "pull", "origin", "main"],
        capture_output=True, text=True, timeout=60
    )
    output = (pull.stdout + pull.stderr).strip()
    if pull.returncode != 0:
        return {"success": False, "error": output}

    # pip install
    venv_pip = os.path.join(install_dir, "venv", "bin", "pip")
    req_file  = os.path.join(install_dir, "requirements.txt")
    if os.path.isfile(venv_pip) and os.path.isfile(req_file):
        pip_cmd = [venv_pip, "install", "--quiet", "-r", req_file]
    else:
        pip_cmd = ["pip3", "install", "--break-system-packages", "-q", "-r", req_file]
    subprocess.run(pip_cmd, capture_output=True, timeout=120)

    # restart
    restart = run_systemctl("restart", config.API_HUB_SERVICE_NAME)
    new_ver = read_local_version(config.API_HUB_VERSION_FILE) or "?"
    return {
        "success":     restart["success"],
        "output":      output,
        "new_version": new_ver,
        "error":       restart.get("error", ""),
    }


# ----------------------------------------------------------------
# MAJ Hub (self-update)
# Mécanisme : git pull + pip dans venv + systemctl restart (delayed)
# ----------------------------------------------------------------

def update_hub() -> dict:
    """
    git pull → pip install → systemctl restart omada-hub (thread 2s delay).
    La réponse Flask est envoyée avant le redémarrage.
    """
    install_dir = config.HUB_INSTALL_DIR

    if not shutil.which("git"):
        return {"success": False, "error": "git n'est pas installé sur ce système."}

    git_check = subprocess.run(
        ["git", "-C", install_dir, "rev-parse", "--is-inside-work-tree"],
        capture_output=True, text=True, timeout=5
    )
    if git_check.returncode != 0:
        return {"success": False, "error": "Répertoire hub non initialisé comme repo git."}

    pull = subprocess.run(
        ["git", "-C", install_dir, "pull", "origin", "main"],
        capture_output=True, text=True, timeout=60
    )
    output = (pull.stdout + pull.stderr).strip()
    if pull.returncode != 0:
        return {"success": False, "error": output}

    venv_pip = os.path.join(install_dir, "venv", "bin", "pip")
    req_file  = os.path.join(install_dir, "app", "requirements.txt")
    if os.path.isfile(venv_pip) and os.path.isfile(req_file):
        subprocess.run(
            [venv_pip, "install", "--quiet", "-r", req_file],
            capture_output=True, timeout=120
        )

    new_ver = read_local_version(config.HUB_VERSION_FILE) or "?"

    def _delayed_restart():
        time.sleep(2.0)
        subprocess.run(["systemctl", "restart", config.HUB_SERVICE_NAME])

    threading.Thread(target=_delayed_restart, daemon=True).start()

    return {
        "success":     True,
        "output":      output,
        "new_version": new_ver,
    }
