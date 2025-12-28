#!/bin/bash
# Script unificato per rilasciare una nuova versione di PyArchInit
# Uso: ./release.sh [messaggio opzionale]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYARCHINIT_DIR="/Users/enzo/Library/Application Support/QGIS/QGIS3/profiles/default/python/plugins/pyarchinit"
PLUGINS_XML="$SCRIPT_DIR/plugins.xml"
METADATA_TXT="$PYARCHINIT_DIR/metadata.txt"
OUTPUT_DIR="$SCRIPT_DIR/releases"
TEMP_DIR="/tmp/pyarchinit_release"

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  PyArchInit Release Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Verifica file
if [ ! -f "$METADATA_TXT" ]; then
    echo -e "${RED}Errore: metadata.txt non trovato${NC}"
    exit 1
fi

# Messaggio commit opzionale
COMMIT_MSG=${1:-""}

# ============================================
# FASE 1: Incrementa versione
# ============================================
echo -e "\n${BLUE}[1/5] Incremento versione...${NC}"

python3 << PYTHON_SCRIPT
import re
import sys
from datetime import date

metadata_txt = "/Users/enzo/Library/Application Support/QGIS/QGIS3/profiles/default/python/plugins/pyarchinit/metadata.txt"
plugins_xml = "$SCRIPT_DIR/plugins.xml"

# Leggi metadata.txt
with open(metadata_txt, 'r', encoding='utf-8') as f:
    metadata_content = f.read()

# Estrai versione corrente
match = re.search(r'^version=(.+)$', metadata_content, re.MULTILINE)
if not match:
    print("Errore: versione non trovata")
    sys.exit(1)

current_version = match.group(1).strip()
print(f"Versione corrente: {current_version}")

# Incrementa versione
parts = current_version.split('.')
last_num = int(parts[-1])
parts[-1] = str(last_num + 1)
new_version = '.'.join(parts)
print(f"Nuova versione: {new_version}")

# Aggiorna metadata.txt
new_metadata = re.sub(
    r'^version=.+$',
    f'version={new_version}',
    metadata_content,
    flags=re.MULTILINE
)

# Aggiungi changelog
today = date.today().strftime('%Y-%m-%d')
changelog_entry = f"{new_version} Update {today}"
new_metadata = re.sub(
    r'^(changelog=)(.+)$',
    rf'\g<1>{changelog_entry}\n  \g<2>',
    new_metadata,
    count=1,
    flags=re.MULTILINE
)

with open(metadata_txt, 'w', encoding='utf-8') as f:
    f.write(new_metadata)

# Aggiorna plugins.xml
with open(plugins_xml, 'r', encoding='utf-8') as f:
    xml_content = f.read()

# Aggiorna versione nel tag
xml_content = re.sub(
    r'(name="pyarchinit" version=")[^"]+(")',
    rf'\g<1>{new_version}\g<2>',
    xml_content
)

# Aggiorna tag version
xml_content = re.sub(
    r'(<version>)[^<]+(</version>)',
    rf'\g<1>{new_version}\g<2>',
    xml_content
)

# Aggiorna update_date
xml_content = re.sub(
    r'(<update_date>)[^<]+(</update_date>)',
    rf'\g<1>{today}\g<2>',
    xml_content
)

# Aggiorna download_url con nuova versione
xml_content = re.sub(
    r'(releases/pyarchinit-dev-)[^.]+(\.\d+\.zip)',
    rf'\g<1>{new_version}.zip',
    xml_content
)
# Gestisci anche il caso con formato diverso
xml_content = re.sub(
    r'(releases/pyarchinit-dev-)\d+\.\d+\.\d+(\.zip)',
    rf'\g<1>{new_version}\g<2>',
    xml_content
)

with open(plugins_xml, 'w', encoding='utf-8') as f:
    f.write(xml_content)

# Salva versione per bash
with open('/tmp/new_version.txt', 'w') as f:
    f.write(new_version)

print(f"Versione aggiornata a {new_version}")
PYTHON_SCRIPT

NEW_VERSION=$(cat /tmp/new_version.txt)
echo -e "${GREEN}✓ Versione: $NEW_VERSION${NC}"

# ============================================
# FASE 2: Crea lo zip
# ============================================
echo -e "\n${BLUE}[2/5] Creazione zip...${NC}"

mkdir -p "$OUTPUT_DIR"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copia plugin
cp -r "$PYARCHINIT_DIR" "$TEMP_DIR/pyarchinit"

# Pulisci
cd "$TEMP_DIR/pyarchinit"
rm -rf .git .gitignore .idea __pycache__ *.pyc .DS_Store
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true

# Rimuovi vecchi zip
rm -f "$OUTPUT_DIR"/pyarchinit-dev-*.zip

# Crea zip
ZIP_NAME="pyarchinit-dev-$NEW_VERSION.zip"
cd "$TEMP_DIR"
zip -rq "$OUTPUT_DIR/$ZIP_NAME" pyarchinit

rm -rf "$TEMP_DIR"
echo -e "${GREEN}✓ Creato: $ZIP_NAME ($(du -h "$OUTPUT_DIR/$ZIP_NAME" | cut -f1))${NC}"

# ============================================
# FASE 3: Commit plugin pyarchinit
# ============================================
echo -e "\n${BLUE}[3/5] Commit pyarchinit...${NC}"

cd "$PYARCHINIT_DIR"
git add metadata.txt
if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="chore: bump version to $NEW_VERSION"
fi
git commit -m "$COMMIT_MSG" || echo "Nessuna modifica da committare"
git push || echo "Push fallito o niente da pushare"
echo -e "${GREEN}✓ Plugin pushato${NC}"

# ============================================
# FASE 4: Commit pyarchinit-repo
# ============================================
echo -e "\n${BLUE}[4/5] Commit pyarchinit-repo...${NC}"

cd "$SCRIPT_DIR"
git add plugins.xml "releases/$ZIP_NAME"
git commit -m "release: v$NEW_VERSION" || echo "Nessuna modifica"
git push || echo "Push fallito"
echo -e "${GREEN}✓ Repository pushato${NC}"

# ============================================
# FASE 5: Riepilogo
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Release $NEW_VERSION completata!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nFile: $OUTPUT_DIR/$ZIP_NAME"
echo -e "URL:  https://github.com/enzococca/pyarchinit-repo/raw/main/releases/$ZIP_NAME"
echo -e "\nGli utenti vedranno l'aggiornamento nel Plugin Manager di QGIS."
