# Local Module Repository

Lokales dateibasiertes Vyra Module Repository für Offline-Entwicklung und Testing.

## 📁 Struktur

```
local-module-repository/
├── repository.json          # Repository-Metadaten
├── modules/                 # Module als .tar.gz Dateien
│   ├── v2_dashboard_aef036f639d3486a985b65ee25df8fec.tar.gz
│   ├── v2_modulemanager_733256b82d6b48a48bc52b5ec73ebfff.tar.gz
│   └── ...
├── metadata/                # Modul-Metadaten (JSON)
│   ├── v2_dashboard.json
│   ├── v2_modulemanager.json
│   └── ...
└── README.md               # Diese Datei
```

## 🚀 Verwendung

### 1. Repository in Client konfigurieren

Füge das Repository in deiner `repository_config.json` hinzu:

```json
{
  "repositories": [
    {
      "name": "local-module-repository",
      "url": "file:///home/holgder/VOS2_WORKSPACE/local-module-repository",
      "priority": 0,
      "enabled": true,
      "type": "file-based"
    }
  ]
}
```

### 2. Module hinzufügen

#### Manuell:
```bash
# Modul exportieren
cd /home/holgder/VOS2_WORKSPACE/modules
tar -czf v2_dashboard_aef036f639d3486a985b65ee25df8fec.tar.gz v2_dashboard_aef036f639d3486a985b65ee25df8fec/

# In Repository kopieren
cp v2_dashboard_aef036f639d3486a985b65ee25df8fec.tar.gz \
   /home/holgder/VOS2_WORKSPACE/local-module-repository/modules/

# Metadaten erstellen
cat > /home/holgder/VOS2_WORKSPACE/local-module-repository/metadata/v2_dashboard.json << 'EOF'
{
  "name": "v2_dashboard",
  "version": "1.0.0",
  "hash": "aef036f639d3486a985b65ee25df8fec",
  "description": "Vyra Dashboard Module",
  "author": "Vyra Team",
  "dependencies": [],
  "filename": "v2_dashboard_aef036f639d3486a985b65ee25df8fec.tar.gz",
  "size": 0,
  "checksum": ""
}
EOF
```

#### Mit Script (automatisch):
```bash
# Verwende das sync-script (wird noch erstellt)
./local-module-repository/tools/sync_from_modules.sh
```

### 3. Module installieren

```python
from repository_client import RepositoryClient

client = RepositoryClient(config_file="repository_config.json")
await client.install_module("v2_dashboard", version="1.0.0")
```

## 🔧 Vorteile

- ✅ **Kein Webserver nötig** - direkter Dateisystem-Zugriff
- ✅ **Offline-fähig** - funktioniert ohne Internet
- ✅ **Schnell** - keine Netzwerk-Latenz
- ✅ **Einfach** - keine Authentifizierung nötig
- ✅ **Entwicklung** - ideal für lokales Testing

## 📝 Notizen

- Base URL: `file:///home/holgder/VOS2_WORKSPACE/local-module-repository`
- Priorität: 0 (wird zuerst geprüft, vor Online-Repositories)
- Keine API-Key Authentifizierung erforderlich
- Module können einfach per `cp` hinzugefügt werden
