#!/bin/bash
# Synchronisiert Module aus /modules in das lokale Repository

REPO_DIR="/home/holgder/VOS2_WORKSPACE/local_module_repository"
MODULES_DIR="/home/holgder/VOS2_WORKSPACE/modules"

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
    
    module_name=$(basename "$module_dir")
    
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
        # Temporäre Datei im Repository-Ordner erstellen
        tar -czf "$REPO_DIR/modules/.${module_name}.tar.gz.tmp" -C "$MODULES_DIR" "$module_name" 2>/dev/null || {
            echo "   ⚠️  Warnung: Fehler beim Packen (möglicherweise Permission-Probleme)"
            # Versuche es ohne problematische Dateien
            tar -czf "$REPO_DIR/modules/.${module_name}.tar.gz.tmp" -C "$MODULES_DIR" --exclude='*/storage/certificates/*' "$module_name"
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
    metadata_file="$REPO_DIR/metadata/${module_base}.json"
    
    # Berechne Checksum und Größe
    size=$(stat -f%z "$target_file" 2>/dev/null || stat -c%s "$target_file")
    checksum=$(sha256sum "$target_file" | awk '{print $1}')
    
    # Metadata speichert OHNE UUID im filename
    cat > "$metadata_file" << EOF
{
  "name": "$module_base",
  "version": "1.0.0",
  "hash": "$version_hash",
  "description": "Vyra Module: $module_base",
  "author": "Vyra Team",
  "dependencies": [],
  "filename": "${repo_filename}",
  "size": $size,
  "checksum": "$checksum",
  "synced_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
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
for metadata in "$REPO_DIR/metadata"/*.json; do
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
  "base_url": "file:///home/holgder/VOS2_WORKSPACE/local_module_repository",
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
