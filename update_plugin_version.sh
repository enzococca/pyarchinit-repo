#!/bin/bash
# Script per aggiornare automaticamente la versione del plugin in plugins.xml
# Uso: ./update_plugin_version.sh [stable|dev] [messaggio commit opzionale]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_XML="$SCRIPT_DIR/plugins.xml"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funzione per estrarre versione corrente
get_current_version() {
    local plugin_type=$1
    if [ "$plugin_type" = "stable" ]; then
        grep -A5 'name="pyarchinit"' "$PLUGINS_XML" | grep "<version>" | head -1 | sed 's/.*<version>\(.*\)<\/version>.*/\1/'
    else
        grep -A5 'name="pyarchinit-dev"' "$PLUGINS_XML" | grep "<version>" | head -1 | sed 's/.*<version>\(.*\)<\/version>.*/\1/'
    fi
}

# Funzione per incrementare versione
increment_version() {
    local version=$1
    local type=$2

    if [ "$type" = "dev" ]; then
        # Per dev: 4.1.0-dev -> 4.1.1-dev, oppure 4.1.10-dev -> 4.1.11-dev
        local base=$(echo "$version" | sed 's/-dev$//')
        local major=$(echo "$base" | cut -d. -f1)
        local minor=$(echo "$base" | cut -d. -f2)
        local patch=$(echo "$base" | cut -d. -f3)
        patch=$((patch + 1))
        echo "${major}.${minor}.${patch}-dev"
    else
        # Per stable: 4.0.0 -> 4.0.1
        local major=$(echo "$version" | cut -d. -f1)
        local minor=$(echo "$version" | cut -d. -f2)
        local patch=$(echo "$version" | cut -d. -f3)
        patch=$((patch + 1))
        echo "${major}.${minor}.${patch}"
    fi
}

# Funzione per aggiornare plugins.xml
update_plugins_xml() {
    local plugin_type=$1
    local new_version=$2
    local today=$(date +%Y-%m-%d)

    if [ "$plugin_type" = "stable" ]; then
        # Aggiorna versione stable (primo blocco pyqgis_plugin)
        sed -i.bak "/<pyqgis_plugin name=\"pyarchinit\" version=/,/<\/pyqgis_plugin>/{
            s/<version>[^<]*<\/version>/<version>$new_version<\/version>/
            s/<update_date>[^<]*<\/update_date>/<update_date>$today<\/update_date>/
        }" "$PLUGINS_XML"
    else
        # Aggiorna versione dev (secondo blocco pyqgis_plugin)
        sed -i.bak "/<pyqgis_plugin name=\"pyarchinit-dev\" version=/,/<\/pyqgis_plugin>/{
            s/<version>[^<]*<\/version>/<version>$new_version<\/version>/
            s/<update_date>[^<]*<\/update_date>/<update_date>$today<\/update_date>/
        }" "$PLUGINS_XML"
    fi

    # Rimuovi backup
    rm -f "$PLUGINS_XML.bak"
}

# Main
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  PyArchInit Plugin Version Updater${NC}"
echo -e "${GREEN}========================================${NC}"

# Determina tipo plugin (default: dev)
PLUGIN_TYPE=${1:-dev}
COMMIT_MSG=${2:-""}

if [ "$PLUGIN_TYPE" != "stable" ] && [ "$PLUGIN_TYPE" != "dev" ]; then
    echo -e "${RED}Errore: Tipo plugin deve essere 'stable' o 'dev'${NC}"
    echo "Uso: $0 [stable|dev] [messaggio commit]"
    exit 1
fi

# Ottieni versione corrente
CURRENT_VERSION=$(get_current_version "$PLUGIN_TYPE")
echo -e "\nPlugin: ${YELLOW}pyarchinit${NC} ($PLUGIN_TYPE)"
echo -e "Versione corrente: ${YELLOW}$CURRENT_VERSION${NC}"

# Calcola nuova versione
NEW_VERSION=$(increment_version "$CURRENT_VERSION" "$PLUGIN_TYPE")
echo -e "Nuova versione: ${GREEN}$NEW_VERSION${NC}"

# Conferma
echo ""
read -p "Procedere con l'aggiornamento? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Annullato.${NC}"
    exit 0
fi

# Aggiorna plugins.xml
echo -e "\n${GREEN}Aggiornamento plugins.xml...${NC}"
update_plugins_xml "$PLUGIN_TYPE" "$NEW_VERSION"

# Verifica modifica
echo -e "${GREEN}Verifica:${NC}"
grep -A2 "name=\"pyarchinit" "$PLUGINS_XML" | grep -E "(version|update_date)"

# Git commit e push
echo -e "\n${GREEN}Commit e push...${NC}"
cd "$SCRIPT_DIR"

git add plugins.xml

if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="chore: bump pyarchinit-$PLUGIN_TYPE to $NEW_VERSION"
fi

git commit -m "$COMMIT_MSG"
git push

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Aggiornamento completato!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nGli utenti QGIS vedranno ora la versione ${GREEN}$NEW_VERSION${NC}"
echo -e "disponibile nel Plugin Manager."
