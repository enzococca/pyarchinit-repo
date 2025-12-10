# PyArchInit Plugin Repository

Repository personalizzato per l'installazione e aggiornamento di PyArchInit tramite QGIS Plugin Manager.

## Come Aggiungere questo Repository in QGIS

1. Apri QGIS
2. Vai su **Plugin → Gestisci e Installa Plugin**
3. Clicca sulla tab **Impostazioni**
4. Nella sezione "Repository di plugin", clicca **Aggiungi...**
5. Inserisci:
   - **Nome**: `PyArchInit Dev Repository`
   - **URL**: `https://raw.githubusercontent.com/enzococca/pyarchinit-repo/main/plugins.xml`
6. Clicca **OK**
7. Spunta **Mostra anche plugin sperimentali** per vedere pyarchinit-dev

## Plugin Disponibili

| Plugin | Versione | Tipo | Note |
|--------|----------|------|------|
| **pyarchinit** | 4.0.0 | Stable | Versione ufficiale da pyarchinit/pyarchinit master |
| **pyarchinit-dev** | 4.1.0-dev | Development | Branch cloudinary-integration |

## ⚠️ ATTENZIONE

**La versione DEV utilizza un database MODIFICATO!**

- NON installare pyarchinit-dev su un database di produzione
- Le due versioni NON sono compatibili tra loro
- Usare pyarchinit-dev solo per test su database separato

## Aggiornamenti

Per aggiornare il plugin:
1. Vai su **Plugin → Gestisci e Installa Plugin**
2. Clicca su **Aggiorna tutto** o seleziona il singolo plugin

## Contatti

- Repository principale: https://github.com/pyarchinit/pyarchinit
- Issues: https://github.com/pyarchinit/pyarchinit/issues
