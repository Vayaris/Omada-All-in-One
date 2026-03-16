#!/bin/bash
# ===================================================================
# Omada All-In-One - Script d'installation complet
# ===================================================================
# Installe :
#   1. Omada All-In-One Hub (ce projet, port choisi par l'utilisateur)
#   2. Omada Manager (optionnel, si pas déjà présent)
#   3. Omada API Hub (optionnel, si pas déjà présent)
#
# Usage :
#   curl -fsSL https://raw.githubusercontent.com/Vayaris/Omada-All-in-One/main/install.sh | sudo bash
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

MANAGER_REPO_RAW="https://raw.githubusercontent.com/Vayaris/Omada-Manager/main/install_omada_manager.sh"
API_HUB_REPO="https://github.com/YakuMawi/omada-api-hub.git"
API_HUB_DIR="/opt/omada-api-hub"

# Ports réservés (interdits pour le Hub) :
# - Omada Controller : 8088, 8043, 8843, 29810-29817
# - MongoDB          : 27001, 27217
# - Omada Manager    : 30560
# - Omada API Hub    : 5000
# - Système courants : 22, 25, 53, 80, 443
RESERVED_PORTS=(22 25 53 80 443 5000 8043 8088 8843
                27001 27217
                29810 29811 29812 29813 29814 29815 29816 29817
                30560)

# --- Helper : lire une entrée même en mode pipe (curl | bash) ---
read_input() {
    if [ -t 0 ]; then
        read -rp "$1" REPLY
    else
        read -rp "$1" REPLY < /dev/tty || REPLY=""
    fi
    echo "$REPLY"
}

is_reserved_port() {
    local p=$1
    for r in "${RESERVED_PORTS[@]}"; do
        [[ "$p" -eq "$r" ]] && return 0
    done
    return 1
}

# ===================================================================
# Bannière
# ===================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Omada All-In-One - Installation           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ===================================================================
# [0] Sélection de la langue
# ===================================================================
echo -e "  Langue / Language :"
echo -e "    ${CYAN}en${NC} - English (default)"
echo -e "    ${CYAN}fr${NC} - Français"
echo ""
LANG_CHOICE=$(read_input "  Choice / Choix [en]: ")
LANG_CHOICE="${LANG_CHOICE:-en}"

if [[ "$LANG_CHOICE" == "fr" ]]; then
    msg_root="ERREUR : Ce script doit être exécuté en tant que root (sudo)."
    msg_port_ask="  Choisissez le port pour le Hub All-In-One [8080] : "
    msg_port_invalid="  ✗ Port invalide. Entrez un nombre entre 1024 et 65535."
    msg_port_reserved="  ✗ Port réservé par Omada ou le système. Ports interdits :"
    msg_port_ok="  ✓ Port sélectionné :"
    msg_update="Mise à jour du système et installation des dépendances…"
    msg_clone="Clonage du dépôt Omada All-In-One Hub…"
    msg_pull="Mise à jour de l'installation Hub existante…"
    msg_venv="Création de l'environnement virtuel Python…"
    msg_pip="Installation des dépendances Python…"
    msg_config="Écriture de la configuration du port…"
    msg_service="Installation du service systemd…"
    msg_start="Démarrage du service Hub…"
    msg_hub_active="✓ Hub actif"
    msg_hub_warn="⚠ Vérifiez les logs :"
    msg_optional="Composants optionnels"
    msg_mgr_detected="Omada Manager déjà installé — ignoré."
    msg_hub_detected="Omada API Hub déjà installé — ignoré."
    msg_install_mgr="  Installer Omada Manager ? [O/n] : "
    msg_install_apihub="  Installer Omada API Hub ? [O/n] : "
    msg_installing_mgr="Installation d'Omada Manager…"
    msg_installing_apihub="Installation d'Omada API Hub…"
    msg_done="✓ Installation terminée !"
    msg_summary="Récapitulatif"
    msg_hub_label="Hub All-In-One"
    msg_mgr_label="Omada Manager"
    msg_apihub_label="Omada API Hub"
    msg_logs="Logs"
    msg_status_cmd="Statut"
    msg_restart_cmd="Redémarrer"
else
    msg_root="ERROR: This script must be run as root (sudo)."
    msg_port_ask="  Choose the Hub port [8080]: "
    msg_port_invalid="  ✗ Invalid port. Enter a number between 1024 and 65535."
    msg_port_reserved="  ✗ Port reserved by Omada or system. Forbidden ports:"
    msg_port_ok="  ✓ Selected port:"
    msg_update="System update and dependency installation…"
    msg_clone="Cloning Omada All-In-One Hub repository…"
    msg_pull="Updating existing Hub installation…"
    msg_venv="Creating Python virtual environment…"
    msg_pip="Installing Python dependencies…"
    msg_config="Writing port configuration…"
    msg_service="Installing systemd service…"
    msg_start="Starting Hub service…"
    msg_hub_active="✓ Hub is active"
    msg_hub_warn="⚠ Check logs:"
    msg_optional="Optional components"
    msg_mgr_detected="Omada Manager already installed — skipping."
    msg_hub_detected="Omada API Hub already installed — skipping."
    msg_install_mgr="  Install Omada Manager? [Y/n]: "
    msg_install_apihub="  Install Omada API Hub? [Y/n]: "
    msg_installing_mgr="Installing Omada Manager…"
    msg_installing_apihub="Installing Omada API Hub…"
    msg_done="✓ Installation complete!"
    msg_summary="Summary"
    msg_hub_label="Hub All-In-One"
    msg_mgr_label="Omada Manager"
    msg_apihub_label="Omada API Hub"
    msg_logs="Logs"
    msg_status_cmd="Status"
    msg_restart_cmd="Restart"
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
# [2] Choix du port Hub
# ===================================================================
echo ""
HUB_PORT=0
while true; do
    PORT_INPUT=$(read_input "$msg_port_ask")
    PORT_INPUT="${PORT_INPUT:-8080}"

    # Vérification : numérique
    if ! [[ "$PORT_INPUT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}$msg_port_invalid${NC}"
        continue
    fi

    # Vérification : plage
    if [[ "$PORT_INPUT" -lt 1024 || "$PORT_INPUT" -gt 65535 ]]; then
        echo -e "${RED}$msg_port_invalid${NC}"
        continue
    fi

    # Vérification : pas réservé Omada/système
    if is_reserved_port "$PORT_INPUT"; then
        echo -e "${RED}$msg_port_reserved${NC}"
        echo -e "    ${YELLOW}${RESERVED_PORTS[*]}${NC}"
        continue
    fi

    HUB_PORT="$PORT_INPUT"
    echo -e "${GREEN}$msg_port_ok ${BOLD}${HUB_PORT}${NC}"
    break
done

# ===================================================================
# [3] Dépendances système
# ===================================================================
echo ""
echo -e "${CYAN}[1/5]${NC} $msg_update"
apt-get update -qq
apt-get install -y -qq python3-venv python3-pip curl git 2>/dev/null || true

# ===================================================================
# [4] Clone ou pull du repo Hub
# ===================================================================
echo ""
echo -e "${CYAN}[2/5]${NC}"

if [ -d "${HUB_DIR}/.git" ]; then
    echo -e "      $msg_pull"
    git -C "$HUB_DIR" pull origin main --quiet
else
    echo -e "      $msg_clone"
    # Si on lance depuis une copie locale (dev), on copie au lieu de cloner
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-install.sh}")" 2>/dev/null && pwd || echo "")"
    if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/app/app.py" ] && [ "$SCRIPT_DIR" != "$HUB_DIR" ]; then
        mkdir -p "$HUB_DIR"
        cp -r "${SCRIPT_DIR}/." "$HUB_DIR/"
        if [ ! -d "${HUB_DIR}/.git" ]; then
            git -C "$HUB_DIR" init -q
            git -C "$HUB_DIR" remote add origin "$HUB_REPO" 2>/dev/null || true
        fi
    else
        git clone "$HUB_REPO" "$HUB_DIR" --quiet
    fi
fi

# ===================================================================
# [5] Environnement Python + configuration port
# ===================================================================
echo ""
echo -e "${CYAN}[3/5]${NC} $msg_venv"
python3 -m venv "${HUB_DIR}/venv"

echo -e "      $msg_pip"
"${HUB_DIR}/venv/bin/pip" install --quiet --upgrade pip
"${HUB_DIR}/venv/bin/pip" install --quiet -r "${HUB_DIR}/app/requirements.txt"

echo -e "      $msg_config"
echo "PORT=${HUB_PORT}" > "${HUB_DIR}/config.txt"

# ===================================================================
# [6] Service systemd (injection du port dans ExecStart)
# ===================================================================
echo ""
echo -e "${CYAN}[4/5]${NC} $msg_service"

# Copier le template et y injecter le port choisi
# Le service lit le port depuis config.txt via config.py — pas besoin de patcher
cp "${HUB_DIR}/systemd/omada-hub.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable "$HUB_SERVICE" --quiet

# ===================================================================
# [7] Démarrage Hub
# ===================================================================
echo ""
echo -e "${CYAN}[5/5]${NC} $msg_start"
systemctl restart "$HUB_SERVICE"
sleep 2

if systemctl is-active --quiet "$HUB_SERVICE"; then
    echo -e "      ${GREEN}$msg_hub_active${NC}"
else
    echo -e "      ${YELLOW}$msg_hub_warn journalctl -u $HUB_SERVICE -n 30${NC}"
fi

# ===================================================================
# Composants optionnels : Omada Manager + API Hub
# ===================================================================
echo ""
echo -e "${BOLD}── $msg_optional ──${NC}"
echo ""

# --- Omada Manager ---
if [ -f "/opt/omada-web-manager/VERSION" ]; then
    echo -e "  ${GREEN}✓${NC} $msg_mgr_detected"
else
    MGR_CHOICE=$(read_input "$msg_install_mgr")
    MGR_CHOICE="${MGR_CHOICE:-y}"
    if [[ "$MGR_CHOICE" =~ ^[OoYy]$ ]]; then
        echo -e "  $msg_installing_mgr"
        echo ""
        curl -fsSL "$MANAGER_REPO_RAW" | bash
        echo ""
    fi
fi

echo ""

# --- Omada API Hub ---
# Considéré installé uniquement si le fichier VERSION ET le service systemd existent
APIHUB_SVC_EXISTS=false
systemctl list-unit-files omada-api-hub.service --no-legend 2>/dev/null | grep -q "omada-api-hub" && APIHUB_SVC_EXISTS=true

if [ -f "${API_HUB_DIR}/VERSION" ] && [ "$APIHUB_SVC_EXISTS" = true ]; then
    echo -e "  ${GREEN}✓${NC} $msg_hub_detected"
else
    APIHUB_CHOICE=$(read_input "$msg_install_apihub")
    APIHUB_CHOICE="${APIHUB_CHOICE:-y}"
    if [[ "$APIHUB_CHOICE" =~ ^[OoYy]$ ]]; then
        echo -e "  $msg_installing_apihub"
        echo ""
        if [ -d "$API_HUB_DIR/.git" ]; then
            git -C "$API_HUB_DIR" pull origin main --quiet
        else
            git clone "$API_HUB_REPO" "$API_HUB_DIR" --quiet
        fi
        cd "$API_HUB_DIR"
        bash install-service.sh
        cd - > /dev/null
        echo ""
    fi
fi

# ===================================================================
# Récapitulatif final
# ===================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  $msg_done${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}── $msg_summary ──${NC}"
echo ""
echo -e "  🔗  ${BOLD}$msg_hub_label${NC}  →  ${CYAN}http://${SERVER_IP}:${HUB_PORT}${NC}"

if [ -f "/opt/omada-web-manager/VERSION" ]; then
    MGR_PORT=$(grep "^PORT=" /opt/omada-web-manager/config.txt 2>/dev/null | cut -d= -f2 || echo "30560")
    echo -e "  ⚙   ${BOLD}$msg_mgr_label${NC}    →  ${CYAN}https://${SERVER_IP}:${MGR_PORT}${NC}"
fi

if [ -f "${API_HUB_DIR}/VERSION" ]; then
    echo -e "  🌐  ${BOLD}$msg_apihub_label${NC}   →  ${CYAN}https://${SERVER_IP}:5000${NC}"
fi

echo ""
echo -e "  $msg_logs       :  sudo journalctl -u $HUB_SERVICE -f"
echo -e "  $msg_status_cmd :  sudo systemctl status $HUB_SERVICE"
echo -e "  $msg_restart_cmd:  sudo systemctl restart $HUB_SERVICE"
echo ""
