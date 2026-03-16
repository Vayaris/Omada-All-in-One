#!/bin/bash
# ===================================================================
# Omada All-In-One - Script d'installation complet
# ===================================================================
# Installe :
#   1. Omada All-In-One Hub (ce projet, port 8080)
#   2. Omada Manager (optionnel, port 30560 HTTPS)
#   3. Omada API Hub (optionnel, port 5000 HTTP)
#
# Usage :
#   curl -fsSL https://raw.githubusercontent.com/YakuMawi/omada-all-in-one/main/install.sh | sudo bash
#   ou : sudo bash install.sh
# ===================================================================

set -e

# --- Couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Configuration ---
HUB_DIR="/opt/omada-hub"
HUB_REPO="https://github.com/Vayaris/Omada-All-in-One.git"
HUB_SERVICE="omada-hub"
HUB_PORT=8080

MANAGER_REPO_RAW="https://raw.githubusercontent.com/Vayaris/Omada-Manager/main/install_omada_manager.sh"
API_HUB_REPO="https://github.com/YakuMawi/omada-api-hub.git"
API_HUB_DIR="/opt/omada-api-hub"

# --- Helper : lire une entrée même en mode pipe ---
read_input() {
    if [ -t 0 ]; then
        read -rp "$1" REPLY
    else
        read -rp "$1" REPLY < /dev/tty || REPLY=""
    fi
    echo "$REPLY"
}

# ===================================================================
# [0] Sélection de la langue
# ===================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Omada All-In-One - Installation         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Langue / Language :"
echo -e "    ${CYAN}fr${NC} - Français (défaut)"
echo -e "    ${CYAN}en${NC} - English"
echo ""
LANG_CHOICE=$(read_input "  Choix / Choice [fr]: ")
LANG_CHOICE="${LANG_CHOICE:-fr}"

if [[ "$LANG_CHOICE" == "en" ]]; then
    msg_root="ERROR: This script must be run as root (sudo)."
    msg_update="System update and dependency installation…"
    msg_git_needed="git is required. Installing…"
    msg_clone="Cloning Omada All-In-One Hub repository…"
    msg_pull="Updating existing Hub installation…"
    msg_venv="Creating Python virtual environment…"
    msg_pip="Installing Python dependencies…"
    msg_service="Installing systemd service…"
    msg_start="Starting Hub service…"
    msg_install_mgr="Install Omada Manager? [Y/n]: "
    msg_install_hub="Install Omada API Hub? [Y/n]: "
    msg_already_mgr="Omada Manager already installed — skipping."
    msg_already_hub="Omada API Hub already installed — skipping."
    msg_installing="Installing"
    msg_done="Installation complete!"
    msg_summary="Summary"
    msg_hub_url="Hub dashboard"
    msg_manager_url="Omada Manager"
    msg_apihub_url="Omada API Hub"
    msg_logs="View logs"
    msg_status="Service status"
else
    msg_root="ERREUR : Ce script doit être exécuté en tant que root (sudo)."
    msg_update="Mise à jour du système et installation des dépendances…"
    msg_git_needed="git est requis. Installation en cours…"
    msg_clone="Clonage du dépôt Omada All-In-One Hub…"
    msg_pull="Mise à jour de l'installation Hub existante…"
    msg_venv="Création de l'environnement virtuel Python…"
    msg_pip="Installation des dépendances Python…"
    msg_service="Installation du service systemd…"
    msg_start="Démarrage du service Hub…"
    msg_install_mgr="Installer Omada Manager ? [O/n] : "
    msg_install_hub="Installer Omada API Hub ? [O/n] : "
    msg_already_mgr="Omada Manager déjà installé — ignoré."
    msg_already_hub="Omada API Hub déjà installé — ignoré."
    msg_installing="Installation de"
    msg_done="Installation terminée !"
    msg_summary="Récapitulatif"
    msg_hub_url="Tableau de bord Hub"
    msg_manager_url="Omada Manager"
    msg_apihub_url="Omada API Hub"
    msg_logs="Voir les logs"
    msg_status="Statut du service"
fi

# ===================================================================
# [1] Vérification root
# ===================================================================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}$msg_root${NC}"
    exit 1
fi

# Détection IP serveur
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

# ===================================================================
# [2] Dépendances système
# ===================================================================
echo ""
echo -e "${CYAN}[1/6]${NC} $msg_update"
apt-get update -qq
apt-get install -y -qq python3-venv python3-pip curl git 2>/dev/null || true

# ===================================================================
# [3] Clone ou pull du repo Hub
# ===================================================================
echo ""
echo -e "${CYAN}[2/6]${NC}"

if [ -d "${HUB_DIR}/.git" ]; then
    echo -e "      $msg_pull"
    git -C "$HUB_DIR" pull origin main --quiet
else
    echo -e "      $msg_clone"
    # Si on est dans le répertoire du projet (dev local), copier au lieu de cloner
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "${SCRIPT_DIR}/app/app.py" ]; then
        # Installation depuis une copie locale
        mkdir -p "$HUB_DIR"
        cp -r "${SCRIPT_DIR}/." "$HUB_DIR/"
        # Initialiser git si nécessaire pour les futures MAJ
        if [ ! -d "${HUB_DIR}/.git" ]; then
            git -C "$HUB_DIR" init -q
            git -C "$HUB_DIR" remote add origin "$HUB_REPO" 2>/dev/null || true
        fi
    else
        git clone "$HUB_REPO" "$HUB_DIR" --quiet
    fi
fi

# ===================================================================
# [4] Environnement Python
# ===================================================================
echo ""
echo -e "${CYAN}[3/6]${NC} $msg_venv"
python3 -m venv "${HUB_DIR}/venv"

echo -e "      $msg_pip"
"${HUB_DIR}/venv/bin/pip" install --quiet --upgrade pip
"${HUB_DIR}/venv/bin/pip" install --quiet -r "${HUB_DIR}/app/requirements.txt"

# ===================================================================
# [5] Service systemd
# ===================================================================
echo ""
echo -e "${CYAN}[4/6]${NC} $msg_service"
cp "${HUB_DIR}/systemd/omada-hub.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable "$HUB_SERVICE" --quiet

# ===================================================================
# [6] Démarrage Hub
# ===================================================================
echo ""
echo -e "${CYAN}[5/6]${NC} $msg_start"
systemctl restart "$HUB_SERVICE"
sleep 2

# Vérification
if systemctl is-active --quiet "$HUB_SERVICE"; then
    echo -e "      ${GREEN}✓ Hub actif${NC}"
else
    echo -e "      ${YELLOW}⚠ Vérifiez : journalctl -u $HUB_SERVICE -n 30${NC}"
fi

# ===================================================================
# [7] Installation optionnelle Omada Manager
# ===================================================================
echo ""
echo -e "${CYAN}[6/6]${NC} Composants optionnels"
echo ""

INSTALL_MANAGER="o"
INSTALL_API_HUB="o"

if [ -f "/opt/omada-web-manager/VERSION" ]; then
    echo -e "      ${GREEN}✓${NC} $msg_already_mgr"
else
    MGR_CHOICE=$(read_input "      $msg_install_mgr")
    MGR_CHOICE="${MGR_CHOICE:-o}"
    if [[ "$MGR_CHOICE" =~ ^[OoYy]$ ]]; then
        echo -e "      $msg_installing Omada Manager…"
        curl -fsSL "$MANAGER_REPO_RAW" | sudo bash
    else
        INSTALL_MANAGER="n"
    fi
fi

echo ""

if [ -f "${API_HUB_DIR}/VERSION" ]; then
    echo -e "      ${GREEN}✓${NC} $msg_already_hub"
else
    HUB_CHOICE=$(read_input "      $msg_install_hub")
    HUB_CHOICE="${HUB_CHOICE:-o}"
    if [[ "$HUB_CHOICE" =~ ^[OoYy]$ ]]; then
        echo -e "      $msg_installing Omada API Hub…"
        if [ -d "$API_HUB_DIR" ]; then
            git -C "$API_HUB_DIR" pull origin main --quiet
        else
            git clone "$API_HUB_REPO" "$API_HUB_DIR" --quiet
        fi
        cd "$API_HUB_DIR"
        bash install-service.sh
        cd - > /dev/null
    else
        INSTALL_API_HUB="n"
    fi
fi

# ===================================================================
# Récapitulatif
# ===================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ $msg_done${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}$msg_summary :${NC}"
echo ""
echo -e "  🔗 $msg_hub_url     → ${CYAN}http://${SERVER_IP}:${HUB_PORT}${NC}"

if [ -f "/opt/omada-web-manager/VERSION" ]; then
    MGR_PORT=$(grep "^PORT=" /opt/omada-web-manager/config.txt 2>/dev/null | cut -d= -f2 || echo "30560")
    echo -e "  ⚙  $msg_manager_url  → ${CYAN}https://${SERVER_IP}:${MGR_PORT}${NC}"
fi

if [ -f "${API_HUB_DIR}/VERSION" ]; then
    echo -e "  🌐 $msg_apihub_url    → ${CYAN}http://${SERVER_IP}:5000${NC}"
fi

echo ""
echo -e "  $msg_logs    : sudo journalctl -u $HUB_SERVICE -f"
echo -e "  $msg_status  : sudo systemctl status $HUB_SERVICE"
echo ""
