<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux-blue?logo=linux&logoColor=white" alt="Linux">
  <img src="https://img.shields.io/badge/Python-3.10+-green?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/License-Open_Source-orange" alt="License">
  <img src="https://img.shields.io/badge/Lang-EN_|_FR-purple" alt="Languages">
  <img src="https://img.shields.io/badge/Version-1.0.0-brightgreen" alt="Version">
</p>

<h1 align="center">Omada All-In-One</h1>

<p align="center">
  <strong>A unified dashboard to manage, monitor and update all your Omada tools in one place.</strong>
</p>

<p align="center">
  <a href="#-version-française">🇫🇷 Version française disponible en bas de page</a>
</p>

---

## What is this?

**Omada All-In-One** is a lightweight web hub that brings together two separate Omada management tools under a single interface. Instead of juggling multiple browser tabs and URLs, you get one dashboard that shows you the state of everything, lets you open each tool instantly, and handles updates for all three components independently.

| Component | Description | Port |
|-----------|-------------|------|
| **Omada Manager** | Web panel to install, manage and update the Omada SDN Controller service | 30560 (HTTPS) |
| **Omada API Hub** | Multi-user portal to manage Omada controllers via OpenAPI | 5000 (HTTPS) |
| **All-In-One Hub** | This dashboard | your choice (HTTP, default 8080) |

Each component is a fully independent project — they can be updated separately, and the All-In-One Hub is just an orchestration layer on top.

---

## Features

| Feature | Description |
|---------|-------------|
| **Split dashboard** | Two cards side by side — one per app — with live service status |
| **Service monitoring** | Real-time status (active / inactive / failed) with 15-second auto-refresh |
| **One-click open** | Opens each app in a new browser tab at its correct URL |
| **Service control** | Restart any sub-app service directly from the hub |
| **Install from UI** | Missing components can be installed directly from the dashboard with a live console log |
| **Uninstall from UI** | Fully uninstall any sub-app (stops service, removes files) with one click |
| **Independent updates** | Each component updates separately via its own GitHub mechanism |
| **Version checking** | Compares local version against GitHub releases for all 3 components |
| **Self-update** | The Hub can update itself and restart automatically |
| **Dark / Light theme** | Toggle between themes, saved in the browser |
| **EN / FR** | Full bilingual interface |
| **Responsive** | Works on mobile and tablet screens |

---

## Requirements

- **Ubuntu 22.04 / 24.04** (or Debian-based)
- **Root** or **sudo** access
- Internet connection
- **git** (installed automatically by `install.sh`)

---

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/Vayaris/Omada-All-in-One/main/install.sh | sudo bash
```

That's it. The script will:

1. Ask for a language (`fr` / `en`)
2. Ask which port to use for the Hub (default: **8080**) — reserved ports are blocked
3. Install Python 3, venv, git if missing
4. Clone the Hub into `/opt/omada-hub/`
5. Create a Python venv and install dependencies
6. Set up and start the `omada-hub` systemd service on the chosen port
7. Optionally install **Omada Manager** (uses its own installer)
8. Optionally install **Omada API Hub** (git clone + systemd service)
9. Display the access URL

### Manual install

```bash
git clone https://github.com/Vayaris/Omada-All-in-One.git
cd Omada-All-in-One
sudo bash install.sh
```

The script is **idempotent** — you can run it again to update the Hub itself or add missing components.

---

## Access

Open your browser and go to:

```
http://<SERVER_IP>:<PORT>
```

The installer displays the exact URL at the end of the installation. No login is required for the Hub — it is designed for use on a local/private network.

---

## Dashboard

The dashboard shows two cards side by side:

**Left card — Omada Manager**
- Status indicator (green dot = active, red = stopped)
- Current version + update availability badge
- Buttons: **Open ↗** / **Restart** / **Update**
- Port and protocol info

**Right card — Omada API Hub**
- Same status, version and action buttons

**Bottom bar — Hub (self)**
- Current Hub version
- Update availability
- **Check for updates** button (queries GitHub releases for all 3 components)
- **Update Hub** button (pulls latest code, restarts automatically)

---

## Updates

Each component has its own update mechanism, triggered from the Hub:

| Component | Update mechanism |
|-----------|-----------------|
| **Omada Manager** | Downloads updated files directly from GitHub (`raw.githubusercontent.com`) |
| **Omada API Hub** | `git pull origin main` in `/opt/omada-api-hub/` |
| **Hub (self)** | `git pull origin main` in `/opt/omada-hub/` then restarts via systemd |

The Hub checks GitHub Releases for new versions. If a newer version is available, the version badge pulses green and the Update button is highlighted. The update is applied with one click — no SSH required.

---

## Architecture

```
/opt/omada-hub/
├── VERSION                    # Hub version
├── install.sh                 # All-in-one installer
├── app/
│   ├── app.py                 # Flask application (port 8080)
│   ├── config.py              # Centralized configuration
│   ├── services.py            # systemctl helpers, version reading, GitHub API
│   ├── updater.py             # Per-component update logic
│   ├── requirements.txt       # Python dependencies (flask, requests)
│   ├── templates/
│   │   └── index.html         # Hub dashboard
│   └── static/
│       ├── style.css          # Styles (dark/light themes)
│       └── app.js             # Polling, toasts, i18n
└── systemd/
    └── omada-hub.service      # systemd unit file
```

### Systemd service

```bash
systemctl status omada-hub       # View status
sudo systemctl restart omada-hub # Restart
sudo systemctl stop omada-hub    # Stop
journalctl -u omada-hub -f       # View live logs
journalctl -u omada-hub -n 50    # View last 50 lines
```

### Port reference

| Port | Used by |
|------|---------|
| 8080 (default, configurable) | All-In-One Hub (HTTP) |
| 30560 | Omada Manager (HTTPS) |
| 5000 | Omada API Hub (HTTPS) |

---

## Related projects

- [Omada Manager](https://github.com/Vayaris/Omada-Manager) — web panel to install and manage the Omada Controller service
- [Omada API Hub](https://github.com/YakuMawi/omada-api-hub) — multi-user portal to manage Omada controllers via OpenAPI

---

## Uninstall

```bash
sudo systemctl stop omada-hub
sudo systemctl disable omada-hub
sudo rm /etc/systemd/system/omada-hub.service
sudo systemctl daemon-reload
sudo rm -rf /opt/omada-hub
```

> This does **not** remove Omada Manager or Omada API Hub.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Hub not accessible | `journalctl -u omada-hub -n 30` to check logs |
| Sub-app shows "Not installed" | Click the **Install** button on the card, or re-run `install.sh` |
| Install console shows an error | Check the logs in the console output, then retry |
| "Update" button does not appear | No update available — click **Check for updates** to refresh |
| Version check fails | GitHub API may be rate-limited (60 req/hour unauthenticated) — wait a few minutes |
| Hub stuck after self-update | `sudo systemctl restart omada-hub` manually |

---

---

<h1 align="center" id="-version-française">🇫🇷 Version Française</h1>

<p align="center">
  <strong>Un tableau de bord unifié pour gérer, surveiller et mettre à jour tous vos outils Omada en un seul endroit.</strong>
</p>

---

## C'est quoi ?

**Omada All-In-One** est un hub web léger qui regroupe deux outils de gestion Omada distincts sous une seule interface. Au lieu de jongler entre plusieurs onglets et URLs, vous disposez d'un tableau de bord unique qui affiche l'état de tout, permet d'ouvrir chaque outil instantanément, et gère les mises à jour des trois composants de façon indépendante.

| Composant | Description | Port |
|-----------|-------------|------|
| **Omada Manager** | Panneau web pour installer, gérer et mettre à jour le service Omada SDN Controller | 30560 (HTTPS) |
| **Omada API Hub** | Portail multi-utilisateurs pour gérer les contrôleurs Omada via OpenAPI | 5000 (HTTPS) |
| **Hub All-In-One** | Ce tableau de bord | au choix (HTTP, défaut 8080) |

Chaque composant est un projet entièrement indépendant — ils peuvent être mis à jour séparément, et le Hub All-In-One est simplement une couche d'orchestration au-dessus.

---

## Fonctionnalités

| Fonctionnalité | Description |
|----------------|-------------|
| **Tableau de bord split** | Deux cartes côte à côte — une par application — avec statut du service en temps réel |
| **Surveillance des services** | Statut en temps réel (actif / inactif / erreur) avec rafraîchissement automatique toutes les 15 secondes |
| **Ouverture en un clic** | Ouvre chaque application dans un nouvel onglet à son URL correcte |
| **Contrôle des services** | Redémarrer n'importe quel service depuis le hub |
| **Installation depuis l'UI** | Les composants manquants peuvent être installés directement depuis le tableau de bord avec une console de logs en direct |
| **Désinstallation depuis l'UI** | Désinstalle complètement un composant (arrêt service, suppression fichiers) en un clic |
| **Mises à jour indépendantes** | Chaque composant se met à jour séparément via son propre mécanisme GitHub |
| **Vérification de version** | Compare la version locale avec les releases GitHub pour les 3 composants |
| **Auto-mise à jour** | Le Hub peut se mettre à jour et redémarrer automatiquement |
| **Thème sombre / clair** | Basculer entre les thèmes, sauvegardé dans le navigateur |
| **FR / EN** | Interface entièrement bilingue |
| **Responsive** | Fonctionne sur mobile et tablette |

---

## Prérequis

- **Ubuntu 22.04 / 24.04** (ou compatible Debian)
- Accès **root** ou **sudo**
- Connexion internet
- **git** (installé automatiquement par `install.sh`)

---

## Installation rapide

```bash
curl -fsSL https://raw.githubusercontent.com/Vayaris/Omada-All-in-One/main/install.sh | sudo bash
```

C'est tout. Le script va :

1. Demander la langue (`fr` / `en`)
2. Demander le port du Hub (défaut : **8080**) — les ports réservés sont bloqués
3. Installer Python 3, venv, git si absents
4. Cloner le Hub dans `/opt/omada-hub/`
5. Créer un environnement Python virtuel et installer les dépendances
6. Configurer et démarrer le service systemd `omada-hub` sur le port choisi
7. Proposer d'installer **Omada Manager** (utilise son propre installateur)
8. Proposer d'installer **Omada API Hub** (git clone + service systemd)
9. Afficher l'URL d'accès

### Installation manuelle

```bash
git clone https://github.com/Vayaris/Omada-All-in-One.git
cd Omada-All-in-One
sudo bash install.sh
```

Le script est **idempotent** — vous pouvez le relancer pour mettre à jour le Hub ou ajouter des composants manquants.

---

## Accès

Ouvrez votre navigateur et allez sur :

```
http://<IP_DU_SERVEUR>:<PORT>
```

L'installateur affiche l'URL exacte à la fin de l'installation. Aucune connexion n'est requise pour le Hub — il est conçu pour être utilisé sur un réseau local/privé.

---

## Tableau de bord

Le tableau de bord affiche deux cartes côte à côte :

**Carte gauche — Omada Manager**
- Indicateur de statut (point vert = actif, rouge = arrêté)
- Version actuelle + badge de disponibilité de mise à jour
- Boutons : **Ouvrir ↗** / **Redémarrer** / **Mettre à jour**
- Port et protocole

**Carte droite — Omada API Hub**
- Mêmes statut, version et boutons d'action

**Barre inférieure — Hub (lui-même)**
- Version actuelle du Hub
- Disponibilité d'une mise à jour
- Bouton **Vérifier les MAJ** (interroge les releases GitHub pour les 3 composants)
- Bouton **Mettre à jour le Hub** (tire le dernier code, redémarre automatiquement)

---

## Mises à jour

Chaque composant dispose de son propre mécanisme de mise à jour, déclenché depuis le Hub :

| Composant | Mécanisme de mise à jour |
|-----------|--------------------------|
| **Omada Manager** | Télécharge les fichiers mis à jour directement depuis GitHub (`raw.githubusercontent.com`) |
| **Omada API Hub** | `git pull origin main` dans `/opt/omada-api-hub/` |
| **Hub (lui-même)** | `git pull origin main` dans `/opt/omada-hub/` puis redémarrage via systemd |

Le Hub vérifie les releases GitHub pour détecter les nouvelles versions. Si une version plus récente est disponible, le badge de version clignote en vert et le bouton de mise à jour est mis en évidence. La mise à jour s'applique en un clic — pas de SSH nécessaire.

---

## Architecture

```
/opt/omada-hub/
├── VERSION                    # Version du Hub
├── install.sh                 # Installateur tout-en-un
├── app/
│   ├── app.py                 # Application Flask (port 8080)
│   ├── config.py              # Configuration centralisée
│   ├── services.py            # Helpers systemctl, lecture version, GitHub API
│   ├── updater.py             # Logique de mise à jour par composant
│   ├── requirements.txt       # Dépendances Python (flask, requests)
│   ├── templates/
│   │   └── index.html         # Tableau de bord Hub
│   └── static/
│       ├── style.css          # Styles (thèmes sombre/clair)
│       └── app.js             # Polling, toasts, i18n
└── systemd/
    └── omada-hub.service      # Fichier unit systemd
```

### Service systemd

```bash
systemctl status omada-hub         # Voir le statut
sudo systemctl restart omada-hub   # Redémarrer
sudo systemctl stop omada-hub      # Arrêter
journalctl -u omada-hub -f         # Voir les logs en direct
journalctl -u omada-hub -n 50      # Voir les 50 dernières lignes
```

### Référence des ports

| Port | Utilisé par |
|------|-------------|
| 8080 (défaut, configurable) | Hub All-In-One (HTTP) |
| 30560 | Omada Manager (HTTPS) |
| 5000 | Omada API Hub (HTTPS) |

---

## Projets liés

- [Omada Manager](https://github.com/Vayaris/Omada-Manager) — panneau web pour installer et gérer le service Omada Controller
- [Omada API Hub](https://github.com/YakuMawi/omada-api-hub) — portail multi-utilisateurs pour gérer les contrôleurs Omada via OpenAPI

---

## Désinstallation

```bash
sudo systemctl stop omada-hub
sudo systemctl disable omada-hub
sudo rm /etc/systemd/system/omada-hub.service
sudo systemctl daemon-reload
sudo rm -rf /opt/omada-hub
```

> Cela ne touche **pas** à Omada Manager ni à Omada API Hub.

---

## Dépannage

| Problème | Solution |
|----------|----------|
| Hub inaccessible | `journalctl -u omada-hub -n 30` pour voir les logs |
| L'application affiche "Non installé" | Cliquer sur le bouton **Installer** sur la carte, ou relancer `install.sh` |
| La console d'installation affiche une erreur | Lire les logs dans la console, puis réessayer |
| Le bouton "Mettre à jour" n'apparaît pas | Aucune mise à jour disponible — cliquer sur **Vérifier les MAJ** pour rafraîchir |
| La vérification de version échoue | L'API GitHub est peut-être limitée en débit (60 req/heure sans auth) — patienter quelques minutes |
| Le Hub reste bloqué après auto-mise à jour | `sudo systemctl restart omada-hub` manuellement |

---

<p align="center">
  <strong>Made with purpose. Open source.</strong>
</p>
