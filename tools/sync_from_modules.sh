#!/bin/bash
# Synchronisiert Module aus /modules in das lokale Repository

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if [ -z "$1" ]; then
    echo "Path to modules not given. Using default: ../modules"
    echo "Example: $0 $REPO_DIR"
    MODULES_DIR="$(dirname "$REPO_DIR")/modules"
else
    MODULES_DIR="$1"
fi

if [ ! -d "$REPO_DIR/modules" ]; then
    echo "Erstelle Verzeichnis für Module im Repository..."
    mkdir -p "$REPO_DIR/modules"
fi

if [ ! -d "$REPO_DIR/modules/metadata" ]; then
    echo "Erstelle Verzeichnis für Module Metadaten im Repository..."
    mkdir -p "$REPO_DIR/modules/metadata"
fi


echo "🔄 Synchronisiere Module ins lokale Repository..."
echo "   Quelle: $MODULES_DIR"
echo "   Ziel: $REPO_DIR"
echo ""

# Zähler
synced=0
skipped=0

# Durchlaufe alle Module
for module_dir in "$MODULES_DIR"/v2_*; do
    if [ ! -d "$module_dir" ]; then
        continue
    fi

    if [[ "$(basename "$module_dir")" == v2_modulemanager_* ]]; then
        echo "Modulemanager aussortieren. Soll nicht in repository."
        continue
    fi
    
    module_name=$(basename "$module_dir")
    
    name=$(yq e '.name' $module_dir/.module/module_data.yaml)
    description=$(yq e '.description' $module_dir/.module/module_data.yaml)
    version=$(yq e '.version' $module_dir/.module/module_data.yaml)
    dependencies=$(yq -o=json '.dependencies' $module_dir/.module/module_data.yaml)
    template=$(yq e '.template' $module_dir/.module/module_data.yaml)
    icon=$(yq e '.icon' $module_dir/.module/module_data.yaml)
    
    if [ "$dependencies" == "null" ]; then
        dependencies="[]"
    fi

    if [ "$icon" == "null" ]; then
        icon=""
    fi

    # Extrahiere Basisname ohne UUID
    # z.B. v2_dashboard_aef036f639d3486a985b65ee25df8fec → v2_dashboard
    module_base=$(echo "$module_name" | sed 's/_[a-f0-9]\{32\}$//')
    version_hash=$(echo "$module_name" | grep -oP '[a-f0-9]{32}$' || echo "")
    


    # Im Repository speichern wir OHNE UUID
    repo_filename="${module_base}.tar.gz"
    
    # Prüfe ob bereits als .tar.gz existiert
    if [ -f "$MODULES_DIR/${module_name}.tar.gz" ]; then
        echo "📦 Gefunden: ${module_name}.tar.gz (bereits gepackt)"
        tar_file="$MODULES_DIR/${module_name}.tar.gz"
    else
        echo "📦 Packe: $module_name"
        echo "   📁 Quelle: $module_dir"
        # Temporäre Datei im Repository-Ordner erstellen
        tar -czf "$REPO_DIR/modules/.${module_name}.tar.gz.tmp" -C "$MODULES_DIR/$module_name" . 2>/dev/null || {
            echo "   ⚠️  Warnung: Fehler beim Packen (möglicherweise Permission-Probleme)"
            # Versuche es ohne problematische Dateien
            tar -czf "$REPO_DIR/modules/.${module_name}.tar.gz.tmp" -C "$MODULES_DIR/$module_name" . --exclude='*/storage/certificates/*'
        }
        tar_file="$REPO_DIR/modules/.${module_name}.tar.gz.tmp"
    fi
    
    # Kopiere ins Repository (OHNE UUID im Dateinamen!)
    target_file="$REPO_DIR/modules/${repo_filename}"
    
    if [ -f "$target_file" ]; then
        # Prüfe ob unterschiedlich
        if cmp -s "$tar_file" "$target_file"; then
            echo "   ⏭️  Überspringe (bereits vorhanden und identisch)"
            skipped=$((skipped + 1))
            continue
        else
            echo "   ♻️  Update (Datei hat sich geändert)"
        fi
    fi
    
    cp "$tar_file" "$target_file"
    
    # Cleanup temp file
    if [[ "$tar_file" == *".tmp" ]]; then
        rm -f "$tar_file"
    fi
    
    # Erstelle/Update Metadaten (bereits extrahiert weiter oben)
    metadata_file="$REPO_DIR/modules/metadata/${module_base}.json"
    
    # Berechne Checksum und Größe
    size=$(stat -f%z "$target_file" 2>/dev/null || stat -c%s "$target_file")
    checksum=$(sha256sum "$target_file" | awk '{print $1}')
    
    # Metadata speichert OHNE UUID im filename
    cat > "$metadata_file" << EOF
{
  "name": "$module_base",
  "version": "$version",
  "hash": "$version_hash",
  "description": "$description",
  "author": "Vyra Team",
  "category": "$template",
  "icon": "$icon",
  "dependencies": $dependencies,
  "filename": "${repo_filename}",
  "synced_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "size": $size,
  "checksum": "$checksum"
}
EOF
    
    echo "   ✅ Synchronisiert: $module_base"
    synced=$((synced + 1))
done

# Update repository.json mit Modulliste
echo ""
echo "📝 Update repository.json..."

# Erstelle Modulliste
module_list="["
first=true
for metadata in "$REPO_DIR/modules/metadata"/*.json; do
    if [ ! -f "$metadata" ]; then
        continue
    fi
    
    if [ "$first" = true ]; then
        first=false
    else
        module_list="${module_list},"
    fi
    
    module_list="${module_list}
    $(cat "$metadata")"
done
module_list="${module_list}
]"

# Update repository.json
cat > "$REPO_DIR/repository.json" << EOF
{
  "name": "local-module-repository",
  "description": "Lokales Vyra Module Repository für Offline-Entwicklung",
  "version": "1.0.0",
  "type": "file-based",
  "base_url": "file:///local_module_repository",
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "modules": $module_list
}
EOF

echo ""
echo "✅ Synchronisation abgeschlossen!"
echo "   📊 Statistik:"
echo "      - Synchronisiert: $synced Module"
echo "      - Übersprungen: $skipped Module"
echo "      - Gesamt: $((synced + skipped)) Module"
echo ""
echo "📍 Repository Pfad: $REPO_DIR"
echo "🔗 Base URL: file://$REPO_DIR"
