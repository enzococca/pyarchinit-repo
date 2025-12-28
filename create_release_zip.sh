#!/bin/bash
# Script per creare uno zip del plugin con il nome cartella corretto
# Lo zip scaricato da GitHub ha il nome branch, questo script lo corregge

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYARCHINIT_DIR="/Users/enzo/Library/Application Support/QGIS/QGIS3/profiles/default/python/plugins/pyarchinit"
OUTPUT_DIR="$SCRIPT_DIR/releases"
TEMP_DIR="/tmp/pyarchinit_release"

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  PyArchInit Release Zip Creator${NC}"
echo -e "${GREEN}========================================${NC}"

# Ottieni versione da metadata.txt
VERSION=$(grep "^version=" "$PYARCHINIT_DIR/metadata.txt" | cut -d= -f2)
echo -e "\nVersione: ${YELLOW}$VERSION${NC}"

# Crea directory output se non esiste
mkdir -p "$OUTPUT_DIR"

# Pulisci temp
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copia plugin con nome corretto
echo -e "\nCopiando plugin..."
cp -r "$PYARCHINIT_DIR" "$TEMP_DIR/pyarchinit"

# Rimuovi file non necessari
echo "Rimuovendo file non necessari..."
cd "$TEMP_DIR/pyarchinit"
rm -rf .git .gitignore .idea __pycache__ *.pyc .DS_Store
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true

# Crea zip
ZIP_NAME="pyarchinit-dev-$VERSION.zip"
echo -e "\nCreando $ZIP_NAME..."
cd "$TEMP_DIR"
zip -r "$OUTPUT_DIR/$ZIP_NAME" pyarchinit -x "*.git*"

# Pulisci
rm -rf "$TEMP_DIR"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Zip creato con successo!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nFile: $OUTPUT_DIR/$ZIP_NAME"
echo -e "Dimensione: $(du -h "$OUTPUT_DIR/$ZIP_NAME" | cut -f1)"
echo -e "\nOra devi:"
echo -e "1. Caricare lo zip su GitHub Releases"
echo -e "2. Aggiornare download_url in plugins.xml"
