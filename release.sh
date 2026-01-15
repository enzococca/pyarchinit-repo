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
CHANGELOG_TEMP="/tmp/changelog_entries.txt"

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
# FASE 0: Estrai changelog dai commit recenti
# ============================================
echo -e "\n${BLUE}[0/6] Estrazione changelog dai commit...${NC}"

cd "$PYARCHINIT_DIR"

# Trova l'ultimo commit con "bump version" per capire da dove partire
LAST_VERSION_COMMIT=$(git log --oneline --grep="bump version" -1 --format="%H" 2>/dev/null || echo "")

if [ -n "$LAST_VERSION_COMMIT" ]; then
    # Estrai commit dall'ultimo bump version (escluso)
    COMMITS=$(git log --oneline "$LAST_VERSION_COMMIT"..HEAD --no-merges 2>/dev/null | grep -v "bump version" | head -10)
else
    # Prendi gli ultimi 10 commit
    COMMITS=$(git log --oneline -10 --no-merges 2>/dev/null | grep -v "bump version")
fi

# Formatta i commit per il changelog
echo "" > "$CHANGELOG_TEMP"
if [ -n "$COMMITS" ]; then
    echo "$COMMITS" | while read -r line; do
        # Estrai solo il messaggio (senza hash)
        MSG=$(echo "$line" | sed 's/^[a-f0-9]* //')
        # Rimuovi prefissi convenzionali per renderlo più leggibile
        MSG=$(echo "$MSG" | sed 's/^feat[(:]/Feature: /; s/^fix[(:]/Fix: /; s/^docs[(:]/Docs: /; s/^chore[(:]/Chore: /; s/^refactor[(:]/Refactor: /')
        # Rimuovi eventuale ) rimasto
        MSG=$(echo "$MSG" | sed 's/): /: /')
        echo "    - $MSG" >> "$CHANGELOG_TEMP"
    done
    echo -e "${GREEN}✓ Trovati $(echo "$COMMITS" | wc -l | tr -d ' ') commit da includere${NC}"
else
    echo "    - Miglioramenti e correzioni varie" >> "$CHANGELOG_TEMP"
    echo -e "${YELLOW}⚠ Nessun commit trovato, uso messaggio generico${NC}"
fi

cat "$CHANGELOG_TEMP"

# ============================================
# FASE 1: Incrementa versione
# ============================================
echo -e "\n${BLUE}[1/6] Incremento versione...${NC}"

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

# Leggi changelog entries dal file temporaneo
changelog_details = ""
try:
    with open('/tmp/changelog_entries.txt', 'r') as f:
        # Rimuovi solo righe vuote iniziali/finali, NON gli spazi di indentazione
        lines = f.read().splitlines()
        # Filtra righe vuote all'inizio e alla fine
        while lines and not lines[0].strip():
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
        changelog_details = '\n'.join(lines)
except:
    changelog_details = "    - Miglioramenti e correzioni varie"

# Aggiungi changelog con dettagli
# Formato: versione ha 0 spazi (dopo changelog=), commit hanno 4 spazi, versioni successive hanno 2 spazi
today = date.today().strftime('%Y-%m-%d')
changelog_entry = f"{new_version} ({today}):\n{changelog_details}"

# Trova la posizione del changelog e inserisci la nuova entry
match = re.search(r'^changelog=(.*)$', new_metadata, re.MULTILINE)
if match:
    old_first_line = match.group(1)
    # Inserisci nuova versione, poi 2 spazi prima della vecchia
    new_changelog = f"changelog={changelog_entry}\n  {old_first_line}"
    new_metadata = new_metadata[:match.start()] + new_changelog + new_metadata[match.end():]

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

# Aggiorna o aggiungi changelog nel plugins.xml
changelog_xml = changelog_details.replace('    - ', '• ').replace('\n', ' ')
if '<changelog>' in xml_content:
    # Aggiorna changelog esistente
    xml_content = re.sub(
        r'(<changelog>)<!\[CDATA\[.*?\]\]>(</changelog>)',
        rf'\g<1><![CDATA[{new_version} ({today}): {changelog_xml}]]>\g<2>',
        xml_content,
        flags=re.DOTALL
    )
else:
    # Aggiungi nuovo tag changelog prima di </pyqgis_plugin>
    changelog_tag = f'        <changelog><![CDATA[{new_version} ({today}): {changelog_xml}]]></changelog>\n    '
    xml_content = xml_content.replace('</pyqgis_plugin>', f'{changelog_tag}</pyqgis_plugin>')

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
echo -e "\n${BLUE}[2/6] Creazione zip...${NC}"

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
echo -e "\n${BLUE}[3/6] Commit pyarchinit...${NC}"

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
echo -e "\n${BLUE}[4/6] Commit pyarchinit-repo...${NC}"

cd "$SCRIPT_DIR"
git add plugins.xml "releases/$ZIP_NAME"
git commit -m "release: v$NEW_VERSION" || echo "Nessuna modifica"
git push || echo "Push fallito"
echo -e "${GREEN}✓ Repository pushato${NC}"

# ============================================
# FASE 5: Riepilogo
# ============================================
echo -e "\n${BLUE}[5/6] Riepilogo...${NC}"
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Release $NEW_VERSION completata!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nFile: $OUTPUT_DIR/$ZIP_NAME"
echo -e "URL:  https://github.com/enzococca/pyarchinit-repo/raw/main/releases/$ZIP_NAME"
echo -e "\n${YELLOW}Changelog incluso:${NC}"
cat "$CHANGELOG_TEMP"
echo -e "\nGli utenti vedranno l'aggiornamento nel Plugin Manager di QGIS."
