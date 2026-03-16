# ============================================================
# Omada All-In-One Hub - Configuration centrale
# ============================================================

# ---- Hub (self) ------------------------------------------------
HUB_INSTALL_DIR  = "/opt/omada-hub"
HUB_VERSION_FILE = "/opt/omada-hub/VERSION"
HUB_SERVICE_NAME = "omada-hub"
HUB_GITHUB_REPO  = "Vayaris/Omada-All-in-One"
HUB_PORT         = 8080

# ---- Omada Manager ---------------------------------------------
MANAGER_INSTALL_DIR  = "/opt/omada-web-manager"
MANAGER_VERSION_FILE = "/opt/omada-web-manager/VERSION"
MANAGER_SERVICE_NAME = "omada-web"
MANAGER_GITHUB_REPO  = "Vayaris/Omada-Manager"
MANAGER_GITHUB_RAW   = "https://raw.githubusercontent.com/Vayaris/Omada-Manager/main"
MANAGER_UPDATE_FILES = [
    ("app.py",                 "app.py"),
    ("requirements.txt",       "requirements.txt"),
    ("templates/index.html",   "templates/index.html"),
    ("templates/login.html",   "templates/login.html"),
    ("static/style.css",       "static/style.css"),
    ("VERSION",                "VERSION"),
]
MANAGER_PORT = 30560

# ---- Omada API Hub ---------------------------------------------
API_HUB_INSTALL_DIR  = "/opt/omada-api-hub"
API_HUB_VERSION_FILE = "/opt/omada-api-hub/VERSION"
API_HUB_SERVICE_NAME = "omada-api-hub"
API_HUB_GITHUB_REPO  = "YakuMawi/omada-api-hub"
API_HUB_PORT         = 443

# ---- GitHub API ------------------------------------------------
GITHUB_API_BASE = "https://api.github.com/repos"
GITHUB_HEADERS  = {
    "User-Agent": "OmadaAllInOneHub/1.0",
    "Accept":     "application/vnd.github+json",
}
