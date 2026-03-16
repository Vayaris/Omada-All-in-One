#!/usr/bin/env python3
"""Omada All-In-One Hub - Tableau de bord central."""

import os
import secrets
from flask import Flask, render_template, jsonify, abort

import config
import services
import updater

app = Flask(__name__)
app.config["SECRET_KEY"] = secrets.token_hex(32)


# ============================================================
# Page principale
# ============================================================

@app.route("/")
def index():
    server_ip = services.get_server_ip()
    return render_template("index.html", server_ip=server_ip)


# ============================================================
# API : statut des services
# ============================================================

@app.route("/api/status")
def api_status():
    """
    Snapshot complet de l'état de tous les composants.
    Appelé au chargement et toutes les 15 secondes.
    Léger : pas d'appels GitHub.
    """
    # Manager
    mgr_ver    = services.read_local_version(config.MANAGER_VERSION_FILE)
    mgr_svc    = services.get_service_status(config.MANAGER_SERVICE_NAME)
    mgr_inst   = os.path.isfile(config.MANAGER_VERSION_FILE)

    # API Hub
    hub_ver    = services.read_local_version(config.API_HUB_VERSION_FILE)
    hub_svc    = services.get_service_status(config.API_HUB_SERVICE_NAME)
    hub_inst   = os.path.isfile(config.API_HUB_VERSION_FILE)

    # Hub (self)
    self_ver   = services.read_local_version(config.HUB_VERSION_FILE)
    self_svc   = services.get_service_status(config.HUB_SERVICE_NAME)

    return jsonify({
        "manager": {
            "installed": mgr_inst,
            "version":   mgr_ver,
            "service":   mgr_svc,
            "port":      config.MANAGER_PORT,
            "proto":     "https",
        },
        "api_hub": {
            "installed": hub_inst,
            "version":   hub_ver,
            "service":   hub_svc,
            "port":      config.API_HUB_PORT,
            "proto":     "http",
        },
        "hub": {
            "version": self_ver,
            "service": self_svc,
        },
    })


# ============================================================
# API : vérification versions GitHub
# ============================================================

@app.route("/api/version-check")
def api_version_check():
    """
    Interroge l'API GitHub Releases pour les 3 composants.
    Appelé sur demande (pas en polling automatique).
    """
    results = {}
    checks = [
        ("manager", config.MANAGER_GITHUB_REPO, config.MANAGER_VERSION_FILE),
        ("api_hub", config.API_HUB_GITHUB_REPO, config.API_HUB_VERSION_FILE),
        ("hub",     config.HUB_GITHUB_REPO,     config.HUB_VERSION_FILE),
    ]
    for key, repo, vfile in checks:
        local  = services.read_local_version(vfile)
        remote = services.fetch_github_latest(repo)
        results[key] = {
            "local":            local,
            "remote":           remote["tag"]  if remote else None,
            "remote_url":       remote["url"]  if remote else None,
            "update_available": services.compare_versions(
                local, remote["tag"] if remote else None
            ),
            "error":            remote is None,
        }
    return jsonify(results)


# ============================================================
# API : contrôle des services
# ============================================================

@app.route("/api/service/<app_key>/<action>", methods=["POST"])
def api_service_action(app_key, action):
    """
    app_key : "manager" | "api_hub"
    action  : "start" | "stop" | "restart"
    """
    if action not in ("start", "stop", "restart"):
        abort(400)

    service_map = {
        "manager": config.MANAGER_SERVICE_NAME,
        "api_hub": config.API_HUB_SERVICE_NAME,
    }
    if app_key not in service_map:
        abort(404)

    result = services.run_systemctl(action, service_map[app_key])
    return jsonify(result), (200 if result["success"] else 500)


# ============================================================
# API : mises à jour
# ============================================================

@app.route("/api/update/manager", methods=["POST"])
def api_update_manager():
    result = updater.update_manager()
    return jsonify(result), (200 if result["success"] else 500)


@app.route("/api/update/api_hub", methods=["POST"])
def api_update_api_hub():
    result = updater.update_api_hub()
    return jsonify(result), (200 if result["success"] else 500)


@app.route("/api/update/hub", methods=["POST"])
def api_update_hub():
    result = updater.update_hub()
    return jsonify(result), (200 if result["success"] else 500)


# ============================================================
# Démarrage
# ============================================================

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=config.HUB_PORT, debug=False)
