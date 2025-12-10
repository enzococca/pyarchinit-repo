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

# Usa Python per parsing e aggiornamento (più affidabile)
python3 << EOF
import re
import sys
from datetime import date

plugin_type = "$PLUGIN_TYPE"
plugins_xml = "$PLUGINS_XML"

# Leggi file
with open(plugins_xml, 'r', encoding='utf-8') as f:
    content = f.read()

# Trova la versione corrente
if plugin_type == "dev":
    # Cerca nel blocco pyarchinit-dev
    match = re.search(r'name="pyarchinit-dev"[^>]*>.*?<version>([^<]+)</version>', content, re.DOTALL)
else:
    # Cerca nel primo blocco pyarchinit (non dev)
    match = re.search(r'name="pyarchinit"[^>]*version="([^"]+)"', content)
    if not match:
        match = re.search(r'name="pyarchinit"[^-][^>]*>.*?<version>([^<]+)</version>', content, re.DOTALL)

if not match:
    print(f"Errore: versione non trovata per {plugin_type}")
    sys.exit(1)

current_version = match.group(1)
print(f"\nPlugin: pyarchinit ({plugin_type})")
print(f"Versione corrente: {current_version}")

# Incrementa versione
if plugin_type == "dev":
    # 4.1.0-dev -> 4.1.1-dev
    base = current_version.replace('-dev', '')
    parts = base.split('.')
    parts[-1] = str(int(parts[-1]) + 1)
    new_version = '.'.join(parts) + '-dev'
else:
    # 4.0.0 -> 4.0.1
    parts = current_version.split('.')
    parts[-1] = str(int(parts[-1]) + 1)
    new_version = '.'.join(parts)

print(f"Nuova versione: {new_version}")

# Aggiorna il file
today = date.today().strftime('%Y-%m-%d')

if plugin_type == "dev":
    # Aggiorna blocco pyarchinit-dev
    content = re.sub(
        r'(name="pyarchinit-dev"[^>]*>.*?<version>)[^<]+(</version>)',
        rf'\g<1>{new_version}\g<2>',
        content,
        count=1,
        flags=re.DOTALL
    )
    content = re.sub(
        r'(name="pyarchinit-dev"[^>]*>.*?<update_date>)[^<]+(</update_date>)',
        rf'\g<1>{today}\g<2>',
        content,
        count=1,
        flags=re.DOTALL
    )
else:
    # Aggiorna primo blocco pyarchinit
    content = re.sub(
        r'(name="pyarchinit" version=")[^"]+(")',
        rf'\g<1>{new_version}\g<2>',
        content,
        count=1
    )
    content = re.sub(
        r'(name="pyarchinit"[^-].*?<version>)[^<]+(</version>)',
        rf'\g<1>{new_version}\g<2>',
        content,
        count=1,
        flags=re.DOTALL
    )
    content = re.sub(
        r'(name="pyarchinit"[^-].*?<update_date>)[^<]+(</update_date>)',
        rf'\g<1>{today}\g<2>',
        content,
        count=1,
        flags=re.DOTALL
    )

# Scrivi file
with open(plugins_xml, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\nFile aggiornato: {plugins_xml}")
print(f"Data: {today}")

# Salva nuova versione per bash
with open('/tmp/new_version.txt', 'w') as f:
    f.write(new_version)
EOF

# Leggi nuova versione
NEW_VERSION=$(cat /tmp/new_version.txt)

# Conferma
echo ""
read -p "Procedere con commit e push? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Annullato. Il file è stato modificato ma non pushato.${NC}"
    exit 0
fi

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
