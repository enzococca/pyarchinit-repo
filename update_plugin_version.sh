#!/bin/bash
# Script per aggiornare automaticamente la versione del plugin
# Aggiorna sia plugins.xml (repo) che metadata.txt (plugin)
# Uso: ./update_plugin_version.sh [stable|dev] [messaggio commit opzionale]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_XML="$SCRIPT_DIR/plugins.xml"

# Path al plugin pyarchinit (branch cloudinary-integration)
PYARCHINIT_DIR="/Users/enzo/Library/Application Support/QGIS/QGIS3/profiles/default/python/plugins/pyarchinit"
METADATA_TXT="$PYARCHINIT_DIR/metadata.txt"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  PyArchInit Version Sync Tool${NC}"
echo -e "${GREEN}========================================${NC}"

# Determina tipo plugin (default: dev)
PLUGIN_TYPE=${1:-dev}
COMMIT_MSG=${2:-""}

if [ "$PLUGIN_TYPE" != "stable" ] && [ "$PLUGIN_TYPE" != "dev" ]; then
    echo -e "${RED}Errore: Tipo plugin deve essere 'stable' o 'dev'${NC}"
    echo "Uso: $0 [stable|dev] [messaggio commit]"
    exit 1
fi

# Verifica che il file metadata.txt esista
if [ ! -f "$METADATA_TXT" ]; then
    echo -e "${RED}Errore: metadata.txt non trovato in $PYARCHINIT_DIR${NC}"
    exit 1
fi

# Usa Python per parsing e aggiornamento
python3 << EOF
import re
import sys
from datetime import date

plugin_type = "$PLUGIN_TYPE"
plugins_xml = "$PLUGINS_XML"
metadata_txt = "$METADATA_TXT"

# Leggi metadata.txt per ottenere versione corrente
with open(metadata_txt, 'r', encoding='utf-8') as f:
    metadata_content = f.read()

# Estrai versione corrente da metadata.txt
match = re.search(r'^version=(.+)$', metadata_content, re.MULTILINE)
if not match:
    print("Errore: versione non trovata in metadata.txt")
    sys.exit(1)

current_version = match.group(1).strip()
print(f"\n${BLUE}Versione corrente (metadata.txt): ${YELLOW}{current_version}${NC}")

# Incrementa versione
parts = current_version.split('.')
# Incrementa l'ultimo numero
last_part = parts[-1]
# Gestisci suffissi come -dev
suffix = ''
if '-' in last_part:
    num_part, suffix = last_part.split('-', 1)
    suffix = '-' + suffix
else:
    num_part = last_part

parts[-1] = str(int(num_part) + 1) + suffix
new_version = '.'.join(parts)

print(f"${GREEN}Nuova versione: {new_version}${NC}")

# Aggiorna metadata.txt
new_metadata = re.sub(
    r'^version=.+$',
    f'version={new_version}',
    metadata_content,
    flags=re.MULTILINE
)

# Aggiungi entry al changelog
today = date.today().strftime('%Y-%m-%d')
changelog_entry = f"{new_version} Update {today}"

# Trova la riga changelog e aggiungi la nuova versione
new_metadata = re.sub(
    r'^(changelog=)(.+)$',
    rf'\g<1>{changelog_entry}\n  \g<2>',
    new_metadata,
    count=1,
    flags=re.MULTILINE
)

with open(metadata_txt, 'w', encoding='utf-8') as f:
    f.write(new_metadata)
print(f"\n${GREEN}✓ metadata.txt aggiornato${NC}")

# Aggiorna plugins.xml
with open(plugins_xml, 'r', encoding='utf-8') as f:
    xml_content = f.read()

if plugin_type == "dev":
    # Aggiorna blocco pyarchinit-dev
    xml_content = re.sub(
        r'(name="pyarchinit-dev"[^>]*>.*?<version>)[^<]+(</version>)',
        rf'\g<1>{new_version}\g<2>',
        xml_content,
        count=1,
        flags=re.DOTALL
    )
    xml_content = re.sub(
        r'(name="pyarchinit-dev"[^>]*>.*?<update_date>)[^<]+(</update_date>)',
        rf'\g<1>{today}\g<2>',
        xml_content,
        count=1,
        flags=re.DOTALL
    )
else:
    # Aggiorna blocco pyarchinit stable
    xml_content = re.sub(
        r'(name="pyarchinit" version=")[^"]+(")',
        rf'\g<1>{new_version}\g<2>',
        xml_content,
        count=1
    )
    xml_content = re.sub(
        r'(name="pyarchinit"[^-].*?<version>)[^<]+(</version>)',
        rf'\g<1>{new_version}\g<2>',
        xml_content,
        count=1,
        flags=re.DOTALL
    )
    xml_content = re.sub(
        r'(name="pyarchinit"[^-].*?<update_date>)[^<]+(</update_date>)',
        rf'\g<1>{today}\g<2>',
        xml_content,
        count=1,
        flags=re.DOTALL
    )

with open(plugins_xml, 'w', encoding='utf-8') as f:
    f.write(xml_content)
print(f"${GREEN}✓ plugins.xml aggiornato${NC}")

# Salva nuova versione per bash
with open('/tmp/new_version.txt', 'w') as f:
    f.write(new_version)
EOF

# Leggi nuova versione
NEW_VERSION=$(cat /tmp/new_version.txt)

# Mostra riepilogo
echo -e "\n${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}Riepilogo modifiche:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "  plugins.xml  → versione ${GREEN}$NEW_VERSION${NC}"
echo -e "  metadata.txt → versione ${GREEN}$NEW_VERSION${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

# Conferma
echo ""
read -p "Procedere con commit e push su ENTRAMBI i repo? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Annullato. I file sono stati modificati ma non pushati.${NC}"
    echo -e "${YELLOW}Per annullare le modifiche:${NC}"
    echo -e "  cd '$SCRIPT_DIR' && git checkout plugins.xml"
    echo -e "  cd '$PYARCHINIT_DIR' && git checkout metadata.txt"
    exit 0
fi

# Messaggio commit
if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="chore: bump version to $NEW_VERSION"
fi

# 1. Commit e push pyarchinit-repo
echo -e "\n${GREEN}[1/2] Push pyarchinit-repo...${NC}"
cd "$SCRIPT_DIR"
git add plugins.xml
git commit -m "$COMMIT_MSG"
git push

# 2. Commit e push pyarchinit plugin
echo -e "\n${GREEN}[2/2] Push pyarchinit (branch cloudinary-integration)...${NC}"
cd "$PYARCHINIT_DIR"
git add metadata.txt
git commit -m "$COMMIT_MSG"
git push

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Aggiornamento completato!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nVersione ${GREEN}$NEW_VERSION${NC} pubblicata su:"
echo -e "  • pyarchinit-repo (plugins.xml)"
echo -e "  • pyarchinit (metadata.txt)"
echo -e "\nGli utenti QGIS vedranno l'aggiornamento nel Plugin Manager."
