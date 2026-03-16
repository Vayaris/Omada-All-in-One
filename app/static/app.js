// ============================================================
// Omada All-In-One Hub - JavaScript
// ============================================================

// ---- i18n --------------------------------------------------
const I18N = {
    fr: {
        // Status
        "status.active":         "Actif",
        "status.inactive":       "Inactif",
        "status.failed":         "Erreur",
        "status.activating":     "Démarrage…",
        "status.not_installed":  "Non installé",
        "status.unknown":        "Inconnu",
        // Buttons
        "btn.open":              "Ouvrir",
        "btn.restart":           "Redémarrer",
        "btn.update":            "Mettre à jour",
        "btn.check":             "Vérifier les MAJ",
        "btn.hub_update":        "Mettre à jour le Hub",
        // Update info
        "update.checking":       "Vérification…",
        "update.current":        "À jour",
        "update.available":      "Mise à jour disponible",
        "update.error":          "Impossible de vérifier",
        "update.none":           "",
        // Not installed
        "not_installed.title":   "Non installé",
        "not_installed.desc":    "Ce composant n'est pas installé.\nRelancez install.sh pour l'ajouter.",
        // Hub footer
        "hub.label":             "Hub",
        "hub.version":           "version",
        // Toast messages
        "toast.restarting":      "Redémarrage du service…",
        "toast.restart_ok":      "Service redémarré avec succès.",
        "toast.restart_fail":    "Échec du redémarrage",
        "toast.update_start":    "Mise à jour en cours…",
        "toast.update_ok":       "Mise à jour appliquée — redémarrage en cours.",
        "toast.update_fail":     "Échec de la mise à jour",
        "toast.hub_update_ok":   "Hub mis à jour — reconnexion dans quelques secondes…",
        "toast.hub_update_fail": "Échec de la mise à jour du Hub",
        // Port / proto
        "port.label":            "Port",
    },
    en: {
        "status.active":         "Active",
        "status.inactive":       "Inactive",
        "status.failed":         "Error",
        "status.activating":     "Starting…",
        "status.not_installed":  "Not installed",
        "status.unknown":        "Unknown",
        "btn.open":              "Open",
        "btn.restart":           "Restart",
        "btn.update":            "Update",
        "btn.check":             "Check for updates",
        "btn.hub_update":        "Update Hub",
        "update.checking":       "Checking…",
        "update.current":        "Up to date",
        "update.available":      "Update available",
        "update.error":          "Unable to check",
        "update.none":           "",
        "not_installed.title":   "Not installed",
        "not_installed.desc":    "This component is not installed.\nRe-run install.sh to add it.",
        "hub.label":             "Hub",
        "hub.version":           "version",
        "toast.restarting":      "Restarting service…",
        "toast.restart_ok":      "Service restarted successfully.",
        "toast.restart_fail":    "Restart failed",
        "toast.update_start":    "Updating…",
        "toast.update_ok":       "Update applied — service is restarting.",
        "toast.update_fail":     "Update failed",
        "toast.hub_update_ok":   "Hub updated — reconnecting in a few seconds…",
        "toast.hub_update_fail": "Hub update failed",
        "port.label":            "Port",
    },
};

let currentLang = localStorage.getItem("hub_lang") || "fr";
const t = (key) => (I18N[currentLang] || I18N.fr)[key] || key;

function setLang(lang) {
    currentLang = lang;
    localStorage.setItem("hub_lang", lang);
    document.getElementById("langBtn").textContent = lang === "fr" ? "EN" : "FR";
    refreshUI();
}

// ---- Theme -------------------------------------------------
function setTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme);
    localStorage.setItem("hub_theme", theme);
    document.getElementById("themeBtn").textContent = theme === "dark" ? "☀" : "☾";
}

function toggleTheme() {
    const current = document.documentElement.getAttribute("data-theme") || "dark";
    setTheme(current === "dark" ? "light" : "dark");
}

function toggleLang() {
    setLang(currentLang === "fr" ? "en" : "fr");
}

// ---- State -------------------------------------------------
let statusData    = null;   // dernière réponse /api/status
let versionData   = null;   // dernière réponse /api/version-check
let versionChecked = false;

// ---- Toast -------------------------------------------------
function showToast(message, type = "info", duration = 4000) {
    const container = document.getElementById("toastContainer");
    const toast = document.createElement("div");
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    container.appendChild(toast);
    requestAnimationFrame(() => {
        requestAnimationFrame(() => toast.classList.add("show"));
    });
    setTimeout(() => {
        toast.classList.remove("show");
        setTimeout(() => toast.remove(), 350);
    }, duration);
}

// ---- API helpers -------------------------------------------
async function apiPost(url) {
    const resp = await fetch(url, { method: "POST" });
    const data = await resp.json().catch(() => ({}));
    return { ok: resp.ok, data };
}

async function apiGet(url) {
    const resp = await fetch(url);
    const data = await resp.json().catch(() => ({}));
    return { ok: resp.ok, data };
}

// ---- Status polling ----------------------------------------
async function fetchStatus() {
    const { ok, data } = await apiGet("/api/status");
    if (ok) {
        statusData = data;
        renderStatus();
    }
}

function renderStatus() {
    if (!statusData) return;
    renderAppCard("manager", statusData.manager);
    renderAppCard("api_hub", statusData.api_hub);
    renderHubFooter(statusData.hub);
}

function renderAppCard(key, info) {
    const card = document.getElementById(`card-${key}`);
    if (!card) return;

    const installed  = info.installed;
    const svc        = info.service || {};
    const state      = svc.state || "unknown";
    const ver        = info.version || "—";
    const proto      = info.proto  || "http";
    const port       = info.port;
    const serverIp   = window.SERVER_IP || location.hostname;
    const appUrl     = `${proto}://${serverIp}:${port}`;

    // État "non installé"
    if (!installed) {
        card.innerHTML = buildNotInstalledCard(key);
        return;
    }

    // Status dot + texte
    const dotClass   = `status-dot status-${state}`;
    const statusText = t(`status.${state}`) || state;

    // Version badge
    let badgeClass = "version-badge";
    let badgeText  = ver;
    if (versionData && versionData[key]) {
        const vd = versionData[key];
        if (vd.update_available) badgeClass += " update-available";
    }

    // Update info line
    let updateHtml = "";
    if (versionData && versionData[key]) {
        const vd = versionData[key];
        if (vd.error) {
            updateHtml = `<span class="update-info update-error">⚠ ${t("update.error")}</span>`;
        } else if (vd.update_available) {
            const linkText = vd.remote ? `v${vd.remote}` : t("update.available");
            const href     = vd.remote_url ? `href="${vd.remote_url}" target="_blank"` : "";
            updateHtml = `<span class="update-info update-available">↑ <a ${href} style="color:inherit">${linkText} ${t("update.available")}</a></span>`;
        } else {
            updateHtml = `<span class="update-info update-current">✓ ${t("update.current")}</span>`;
        }
    }

    // Couleur accent selon l'app
    const accentColor = key === "manager" ? "var(--accent)" : "var(--teal)";
    const updateBtnClass = (versionData && versionData[key] && versionData[key].update_available)
        ? (key === "manager" ? "btn btn-sm btn-success" : "btn btn-sm btn-teal")
        : "btn btn-sm btn-outline";

    card.innerHTML = `
      <div class="card-header">
        <div class="card-title">
          <div class="card-title-icon">${key === "manager" ? "⚙" : "🌐"}</div>
          <h2>${key === "manager" ? "Omada Manager" : "Omada API Hub"}</h2>
        </div>
        <span class="${badgeClass}">v${ver}</span>
      </div>
      <div class="card-body">
        <div class="status-row">
          <span class="${dotClass}"></span>
          <span class="status-text">${statusText}</span>
          <span class="status-sub">${svc.sub_state || ""}</span>
        </div>
        ${updateHtml ? `<div>${updateHtml}</div>` : ""}
        <div class="actions-row">
          <a href="${appUrl}" target="_blank" class="btn btn-outline btn-sm">
            ${t("btn.open")} ↗
          </a>
          <button class="btn btn-outline btn-sm" onclick="restartService('${key}', this)">
            ↺ ${t("btn.restart")}
          </button>
          <button class="${updateBtnClass}" id="upd-${key}" onclick="updateComponent('${key}', this)">
            ↑ ${t("btn.update")}
          </button>
        </div>
        <div class="port-info">
          <span>${t("port.label")} ${port} · ${proto.toUpperCase()}</span>
        </div>
      </div>`;
}

function buildNotInstalledCard(key) {
    const title = key === "manager" ? "Omada Manager" : "Omada API Hub";
    const icon  = key === "manager" ? "⚙" : "🌐";
    return `
      <div class="card-header">
        <div class="card-title">
          <div class="card-title-icon">${icon}</div>
          <h2>${title}</h2>
        </div>
        <span class="version-badge version-unknown">—</span>
      </div>
      <div class="card-body">
        <div class="not-installed-body">
          <div style="font-size:32px;margin-bottom:8px">📦</div>
          <strong>${t("not_installed.title")}</strong>
          <p>${t("not_installed.desc").replace(/\n/g, "<br>")}</p>
        </div>
      </div>`;
}

function renderHubFooter(hub) {
    const ver = hub.version || "—";
    document.getElementById("hub-version").textContent = `v${ver}`;

    let updateHtml = "";
    if (versionData && versionData.hub) {
        const vd = versionData.hub;
        if (vd.error) {
            updateHtml = `<span class="hub-update-info update-error">⚠ ${t("update.error")}</span>`;
        } else if (vd.update_available) {
            updateHtml = `<span class="hub-update-info update-available">↑ ${t("update.available")} v${vd.remote}</span>`;
        } else if (vd.remote !== null) {
            updateHtml = `<span class="hub-update-info update-current">✓ ${t("update.current")}</span>`;
        }
    }
    document.getElementById("hub-update-info").innerHTML = updateHtml;
}

// ---- Version check -----------------------------------------
async function checkVersions() {
    // Met tous les indicateurs en "checking"
    document.getElementById("hub-update-info").innerHTML =
        `<span class="hub-update-info update-checking">${t("update.checking")}</span>`;

    const { ok, data } = await apiGet("/api/version-check");
    if (ok) {
        versionData   = data;
        versionChecked = true;
        renderStatus();
        renderHubFooter(statusData ? statusData.hub : {});
    }
}

// ---- Service actions ----------------------------------------
async function restartService(key, btn) {
    btn.disabled = true;
    showToast(t("toast.restarting"), "info");
    const { ok, data } = await apiPost(`/api/service/${key}/restart`);
    if (ok) {
        showToast(t("toast.restart_ok"), "success");
    } else {
        showToast(`${t("toast.restart_fail")}: ${data.error || ""}`, "error", 6000);
    }
    btn.disabled = false;
    setTimeout(fetchStatus, 2000);
}

async function updateComponent(key, btn) {
    btn.disabled = true;
    const origText = btn.innerHTML;
    btn.innerHTML = `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" class="spinning"><path d="M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0"/></svg>`;
    showToast(t("toast.update_start"), "info");

    const { ok, data } = await apiPost(`/api/update/${key}`);
    if (ok) {
        showToast(`${t("toast.update_ok")} (v${data.new_version || "?"})`, "success", 6000);
    } else {
        showToast(`${t("toast.update_fail")}: ${data.error || ""}`, "error", 8000);
    }
    btn.innerHTML = origText;
    btn.disabled = false;
    setTimeout(fetchStatus, 3000);
}

async function updateHub(btn) {
    btn.disabled = true;
    const origText = btn.innerHTML;
    btn.innerHTML = `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" class="spinning"><path d="M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0"/></svg>`;
    showToast(t("toast.update_start"), "info");

    const { ok, data } = await apiPost("/api/update/hub");
    if (ok) {
        showToast(t("toast.hub_update_ok"), "success", 8000);
        // Le hub va redémarrer — on reconnecte après 5s
        setTimeout(() => location.reload(), 5000);
    } else {
        showToast(`${t("toast.hub_update_fail")}: ${data.error || ""}`, "error", 8000);
        btn.innerHTML = origText;
        btn.disabled = false;
    }
}

// ---- refreshUI (rebuild text after lang change) ------------
function refreshUI() {
    renderStatus();
    if (statusData) renderHubFooter(statusData.hub || {});

    // Boutons statiques
    document.getElementById("checkBtn").textContent    = t("btn.check");
    document.getElementById("hubUpdateBtn").textContent = `↑ ${t("btn.hub_update")}`;
}

// ---- Init --------------------------------------------------
document.addEventListener("DOMContentLoaded", () => {
    // Thème
    const savedTheme = localStorage.getItem("hub_theme") || "dark";
    setTheme(savedTheme);

    // Langue
    document.getElementById("langBtn").textContent = currentLang === "fr" ? "EN" : "FR";

    // Premier chargement
    fetchStatus().then(() => {
        // Vérification version automatique au chargement
        checkVersions();
    });

    // Polling statut toutes les 15s
    setInterval(fetchStatus, 15000);
});
