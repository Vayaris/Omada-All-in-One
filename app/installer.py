# ============================================================
# Omada All-In-One Hub - Install / Uninstall helpers
# Installs run in background threads; output is streamed
# line-by-line and polled by the frontend.
# ============================================================

import os
import shutil
import subprocess
import threading
import urllib.request

import config

# ---- Job state store ----------------------------------------
# { component: { "running": bool, "logs": [str], "success": bool|None } }
_jobs: dict = {}
_lock = threading.Lock()


def get_job(component: str) -> dict:
    with _lock:
        j = _jobs.get(component)
        if not j:
            return {"running": False, "logs": [], "success": None}
        return {"running": j["running"], "logs": list(j["logs"]), "success": j["success"]}


def start_install(component: str) -> bool:
    """Start a background install. Returns False if already running."""
    with _lock:
        if _jobs.get(component, {}).get("running"):
            return False
        _jobs[component] = {"running": True, "logs": [], "success": None}
    threading.Thread(target=_run_install, args=(component,), daemon=True).start()
    return True


def _add_log(component: str, line: str):
    with _lock:
        if component in _jobs:
            _jobs[component]["logs"].append(line)


def _run_install(component: str):
    try:
        if component == "manager":
            _install_manager()
        elif component == "api_hub":
            _install_api_hub()
        with _lock:
            _jobs[component]["success"] = True
            _jobs[component]["running"] = False
    except Exception as exc:
        _add_log(component, f"✗ Erreur : {exc}")
        with _lock:
            _jobs[component]["success"] = False
            _jobs[component]["running"] = False


def _stream_cmd(component: str, cmd, cwd=None):
    """Run a command and stream its combined stdout/stderr line-by-line."""
    proc = subprocess.Popen(
        cmd, cwd=cwd,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1,
    )
    for line in proc.stdout:
        _add_log(component, line.rstrip())
    proc.wait()
    if proc.returncode != 0:
        raise RuntimeError(f"Commande échouée (code {proc.returncode})")


def _install_manager():
    script_path = "/tmp/install_omada_manager.sh"
    url = f"{config.MANAGER_GITHUB_RAW}/install_omada_manager.sh"
    _add_log("manager", "→ Téléchargement du script d'installation Omada Manager…")
    try:
        urllib.request.urlretrieve(url, script_path)
    except Exception as exc:
        raise RuntimeError(f"Téléchargement échoué : {exc}")
    os.chmod(script_path, 0o755)
    _add_log("manager", "→ Lancement de l'installation (cela peut prendre quelques minutes)…")
    _stream_cmd("manager", ["bash", script_path])
    _add_log("manager", "✓ Omada Manager installé avec succès.")


def _install_api_hub():
    hub_dir = config.API_HUB_INSTALL_DIR
    repo_url = "https://github.com/YakuMawi/omada-api-hub.git"

    if os.path.isdir(os.path.join(hub_dir, ".git")):
        _add_log("api_hub", "→ Mise à jour du dépôt omada-api-hub…")
        _stream_cmd("api_hub", ["git", "-C", hub_dir, "pull", "origin", "main"])
    else:
        _add_log("api_hub", "→ Clonage du dépôt omada-api-hub…")
        _stream_cmd("api_hub", ["git", "clone", repo_url, hub_dir])

    _add_log("api_hub", "→ Lancement de install-service.sh…")
    _stream_cmd("api_hub", ["bash", f"{hub_dir}/install-service.sh"], cwd=hub_dir)
    _add_log("api_hub", "✓ Omada API Hub installé avec succès.")


# ---- Uninstall (synchronous, blocking) ----------------------

def uninstall(component: str) -> tuple[bool, list]:
    """
    Désinstalle un composant. Bloquant.
    Retourne (success: bool, logs: list[str]).
    """
    logs: list = []
    try:
        if component == "manager":
            _do_uninstall("omada-web", "/opt/omada-web-manager", logs)
        elif component == "api_hub":
            _do_uninstall("omada-api-hub", "/opt/omada-api-hub", logs)
        return True, logs
    except Exception as exc:
        logs.append(f"✗ Erreur : {exc}")
        return False, logs


def _do_uninstall(service: str, directory: str, logs: list):
    def run(cmd):
        r = subprocess.run(cmd, capture_output=True, text=True)
        for line in (r.stdout + r.stderr).splitlines():
            if line.strip():
                logs.append(line)

    logs.append(f"→ Arrêt du service {service}…")
    run(["systemctl", "stop", f"{service}.service"])
    run(["systemctl", "disable", f"{service}.service"])
    logs.append("→ Suppression du fichier service systemd…")
    run(["rm", "-f", f"/etc/systemd/system/{service}.service"])
    run(["systemctl", "daemon-reload"])
    logs.append(f"→ Suppression du répertoire {directory}…")
    if os.path.isdir(directory):
        shutil.rmtree(directory)
    logs.append(f"✓ {service} désinstallé avec succès.")
