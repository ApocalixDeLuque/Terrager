import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

private let appName = "Terrager"
private let runtimeDir: String = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
    return base.appendingPathComponent(appName, isDirectory: true).path
}()
private let saveOnCloseKey = "saveOnAppClose"
private let profilesPath = runtimeDir + "/config/server-profiles.json"
private let scriptsDir = runtimeDir + "/scripts"
private let installRollbackScript = scriptsDir + "/install-rollback-scheduler.sh"
private let joinInfoScript = scriptsDir + "/join-info.sh"

private enum AppTheme {
    static let background = Color(red: 0.965, green: 0.968, blue: 0.985)
    static let panel = Color.white
    static let panelSubtle = Color(red: 0.982, green: 0.984, blue: 0.994)
    static let sidebar = Color(red: 0.078, green: 0.063, blue: 0.176)
    static let sidebarMuted = Color(red: 0.78, green: 0.76, blue: 0.92)
    static let primary = Color(red: 0.459, green: 0.298, blue: 0.463)
    static let primaryDeep = Color(red: 0.078, green: 0.063, blue: 0.176)
    static let primarySoft = Color(red: 0.49, green: 0.34, blue: 0.51)
    static let lavender = Color(red: 0.671, green: 0.753, blue: 0.988)
    static let border = Color(red: 0.87, green: 0.88, blue: 0.94)
    static let success = Color(red: 0.22, green: 0.68, blue: 0.38)
    static let danger = Color(red: 0.82, green: 0.19, blue: 0.24)
    static let warning = Color(red: 0.78, green: 0.50, blue: 0.13)
}

struct CommandResult {
    let status: Int32
    let output: String
}

enum Shell {
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func run(_ command: String) -> CommandResult {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-lc", command]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandResult(status: 127, output: error.localizedDescription)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return CommandResult(status: process.terminationStatus, output: output.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum WorldSize: String, CaseIterable, Codable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        }
    }

    var configCode: Int {
        switch self {
        case .small:
            return 1
        case .medium:
            return 2
        case .large:
            return 3
        }
    }
}

enum WorldDifficulty: String, CaseIterable, Codable, Identifiable {
    case classic
    case expert
    case master
    case journey

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic:
            return "Classic"
        case .expert:
            return "Expert"
        case .master:
            return "Master"
        case .journey:
            return "Journey"
        }
    }

    var configCode: Int {
        switch self {
        case .classic:
            return 0
        case .expert:
            return 1
        case .master:
            return 2
        case .journey:
            return 3
        }
    }

    var seedCode: Int {
        configCode + 1
    }
}

enum WorldEvil: String, CaseIterable, Codable, Identifiable {
    case corruption
    case crimson

    var id: String { rawValue }

    var label: String {
        switch self {
        case .corruption:
            return "Corruption"
        case .crimson:
            return "Crimson"
        }
    }

    var seedCode: Int {
        switch self {
        case .corruption:
            return 1
        case .crimson:
            return 2
        }
    }
}

struct ServerProfile: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var worldName: String
    var seedIdentifier: String
    var size: WorldSize
    var difficulty: WorldDifficulty
    var evil: WorldEvil
    var port: Int
    var maxPlayers: Int
    var motd: String
    var sessionName: String
    var worldPath: String
    var configPath: String
    var logPath: String
    var serverPath: String

    var backupDir: String {
        runtimeDir + "/worlds/backups/" + id
    }

    var encodedSeed: String {
        "\(size.configCode).\(difficulty.seedCode).\(evil.seedCode).0.\(seedIdentifier)"
    }

    var worldExists: Bool {
        FileManager.default.fileExists(atPath: worldPath)
    }

    var configText: String {
        var lines = [
            "# Terraria dedicated server config generated by Terrager.",
            "world=\(worldPath)",
            "worldpath=\(URL(fileURLWithPath: worldPath).deletingLastPathComponent().path)",
            "seed=\(encodedSeed)",
            "worldname=\(worldName)",
            "difficulty=\(difficulty.configCode)",
            "maxplayers=\(maxPlayers)",
            "port=\(port)",
            "motd=\(motd)",
            "worldrollbackstokeep=2",
            "banlist=\(runtimeDir)/banlist.txt",
            "secure=1",
            "language=en-US",
            "upnp=1",
            "priority=0"
        ]

        if worldExists {
            lines.insert("# autocreate omitted because the world file already exists.", at: 3)
        } else {
            lines.insert("autocreate=\(size.configCode)", at: 3)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func make(name: String, worldName: String, seedIdentifier: String, size: WorldSize, difficulty: WorldDifficulty, evil: WorldEvil, port: Int, maxPlayers: Int, motd: String, serverPath: String, existingID: String? = nil, existingWorldPath: String? = nil) -> ServerProfile {
        let baseID = existingID ?? slug(name.isEmpty ? worldName : name)
        let id = baseID.isEmpty ? "server" : baseID
        let worldFile = existingWorldPath ?? runtimeDir + "/worlds/" + id + ".wld"

        return ServerProfile(
            id: id,
            name: name.isEmpty ? worldName : name,
            worldName: worldName.isEmpty ? name : worldName,
            seedIdentifier: seedIdentifier.isEmpty ? worldName : seedIdentifier,
            size: size,
            difficulty: difficulty,
            evil: evil,
            port: port,
            maxPlayers: maxPlayers,
            motd: motd.isEmpty ? name : motd,
            sessionName: "terraria-" + id,
            worldPath: worldFile,
            configPath: runtimeDir + "/serverconfigs/" + id + ".serverconfig.txt",
            logPath: runtimeDir + "/logs/" + id + "-server.log",
            serverPath: serverPath
        )
    }

    static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
    }
}

struct ProfileDraft {
    var name = ""
    var worldName = ""
    var seedIdentifier = ""
    var size: WorldSize = .medium
    var difficulty: WorldDifficulty = .classic
    var evil: WorldEvil = .corruption
    var port = "7777"
    var maxPlayers = "8"
    var motd = ""
    var serverPath = defaultServerPath()

    init() {}

    init(profile: ServerProfile) {
        name = profile.name
        worldName = profile.worldName
        seedIdentifier = profile.seedIdentifier
        size = profile.size
        difficulty = profile.difficulty
        evil = profile.evil
        port = String(profile.port)
        maxPlayers = String(profile.maxPlayers)
        motd = profile.motd
        serverPath = profile.serverPath
    }
}

struct RuntimeStatus {
    var isRunning = false
    var isListening = false
    var pid = ""
    var nice = ""
    var cpu = ""
    var memory = ""
    var joinAddress = "127.0.0.1"
    var internetJoinAddress = "not configured"
    var worldSummary = "World file not found."
    var connections = "No active player TCP sessions detected."
    var activePlayers: [String] = []

    var playerCount: Int {
        activePlayers.count
    }

    var worldTimeTitle: String {
        if !isRunning {
            return "Stopped"
        }
        return activePlayers.isEmpty ? "Idle" : "Active"
    }

    var worldTimeDetail: String {
        if !isRunning {
            return "The world is offline."
        }
        if activePlayers.isEmpty {
            return "No players detected."
        }
        return "\(playerCount) connected: \(activePlayers.joined(separator: ", "))"
    }
}

struct BackupRecord: Identifiable, Hashable {
    let id: String
    let path: String
    let filename: String
    let ownerName: String
    let ownerID: String?
    let label: String
    let sizeBytes: Int64
    let createdAt: Date

    var sizeText: String {
        byteString(String(sizeBytes))
    }

    var createdText: String {
        BackupRecord.dateFormatter.string(from: createdAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

struct BackupStats {
    var count = 0
    var sizeBytes: Int64 = 0

    var sizeText: String {
        byteString(String(sizeBytes))
    }
}

struct RollbackSettings {
    var enabled = true
    var intervalMinutes = 60

    var summary: String {
        if enabled {
            return "On, every \(intervalMinutes)m, only while the selected server is running."
        }
        return "Off. No automatic backup snapshots will be created."
    }
}

enum DetailSection: String, CaseIterable, Identifiable {
    case overview
    case backups
    case logs

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview:
            return "Overview"
        case .backups:
            return "Backups"
        case .logs:
            return "Logs"
        }
    }
}

private func defaultServerPath() -> String {
    for path in knownServerPaths() where FileManager.default.isExecutableFile(atPath: path) {
        return path
    }
    return knownServerPaths().first ?? ""
}

private func knownServerPaths() -> [String] {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return [
        home + "/Library/Application Support/Steam/steamapps/common/Terraria/Terraria.app/Contents/MacOS/TerrariaServer",
        "/Applications/Terraria.app/Contents/MacOS/TerrariaServer"
    ]
}

private func ensureRuntimeFolders() {
    let paths = [
        runtimeDir + "/config",
        runtimeDir + "/logs",
        runtimeDir + "/serverconfigs",
        runtimeDir + "/worlds",
        runtimeDir + "/worlds/backups"
    ]

    for path in paths {
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
    installRuntimeScripts()
}

private func installRuntimeScripts() {
    let scripts: [String: String] = [
        "join-info.sh": joinInfoScriptText,
        "set-rollback-settings.sh": setRollbackSettingsScriptText,
        "rollback-scheduler.sh": rollbackSchedulerScriptText,
        "install-rollback-scheduler.sh": installRollbackSchedulerScriptText
    ]

    for (name, content) in scripts {
        let path = scriptsDir + "/" + name
        let url = URL(fileURLWithPath: path)
        if (try? String(contentsOf: url, encoding: .utf8)) != content {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }
}

private let joinInfoScriptText = #"""
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-7777}"
PUBLIC_CONFIG="$ROOT_DIR/config/public-endpoint.env"

iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
LAN_IP=""
if [[ -n "${iface:-}" ]]; then
  LAN_IP="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
fi
if [[ -z "$LAN_IP" ]]; then
  LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"
fi

echo "LAN IP: $LAN_IP"
echo "Terraria port: $PORT"
echo "Same Wi-Fi join target: $LAN_IP:$PORT"

PUBLIC_HOST=""
PUBLIC_PORT=""
PUBLIC_LOCAL_PORT=""
if [[ -f "$PUBLIC_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$PUBLIC_CONFIG"
fi

if [[ -n "${PUBLIC_HOST:-}" && -n "${PUBLIC_PORT:-}" && ( -z "${PUBLIC_LOCAL_PORT:-}" || "${PUBLIC_LOCAL_PORT:-}" == "$PORT" ) ]]; then
  echo "Internet join target: $PUBLIC_HOST:$PUBLIC_PORT"
  echo "Internet host field: $PUBLIC_HOST"
  echo "Internet port field: $PUBLIC_PORT"
else
  echo "Internet join target: not configured"
  echo "Internet host field: not configured"
  echo "Internet port field: not configured"
fi
"""#

private let setRollbackSettingsScriptText = #"""
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
SETTINGS="$CONFIG_DIR/rollback-settings.env"

ENABLED="${1:-1}"
INTERVAL_MINUTES="${2:-60}"

if [[ "$ENABLED" != "0" && "$ENABLED" != "1" ]]; then
  echo "ENABLED must be 0 or 1" >&2
  exit 1
fi

if ! [[ "$INTERVAL_MINUTES" =~ ^[0-9]+$ ]] || [[ "$INTERVAL_MINUTES" -lt 1 ]]; then
  echo "INTERVAL_MINUTES must be a positive number" >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
{
  echo "ENABLED=$ENABLED"
  echo "INTERVAL_MINUTES=$INTERVAL_MINUTES"
} > "$SETTINGS"

echo "Saved rollback settings to $SETTINGS"
"""#

private let rollbackSchedulerScriptText = #"""
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$ROOT_DIR/config/rollback-settings.env"
STAMP="$ROOT_DIR/config/rollback-last-run"
LOG="$ROOT_DIR/logs/rollback-scheduler.log"
PROFILES="$ROOT_DIR/config/server-profiles.json"

mkdir -p "$ROOT_DIR/config" "$ROOT_DIR/logs" "$ROOT_DIR/worlds/backups"

ENABLED=1
INTERVAL_MINUTES=60
if [[ -f "$SETTINGS" ]]; then
  # shellcheck disable=SC1090
  source "$SETTINGS"
fi

if [[ "${ENABLED:-1}" != "1" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') scheduler disabled" >> "$LOG"
  exit 0
fi

NOW="$(date +%s)"
LAST="0"
if [[ -f "$STAMP" ]]; then
  LAST="$(cat "$STAMP")"
fi

INTERVAL_SECONDS="$(( ${INTERVAL_MINUTES:-60} * 60 ))"
if (( NOW - LAST < INTERVAL_SECONDS )); then
  exit 0
fi

if [[ ! -f "$PROFILES" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') no profiles file; skipped" >> "$LOG"
  exit 0
fi

created=0
while IFS=$'\t' read -r profile_id session_name world_path; do
  [[ -n "$profile_id" && -n "$session_name" && -n "$world_path" ]] || continue
  if ! screen -list 2>/dev/null | grep -q "[.]$session_name[[:space:]]"; then
    continue
  fi
  if [[ ! -s "$world_path" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $profile_id world missing; skipped" >> "$LOG"
    continue
  fi

  screen -S "$session_name" -p 0 -X stuff $'save\n' || true
  sleep 8

  backup_dir="$ROOT_DIR/worlds/backups/$profile_id"
  mkdir -p "$backup_dir"
  stamp="$(date +%Y%m%d-%H%M%S)"
  destination="$backup_dir/$profile_id.auto.$stamp.wld"
  cp -p "$world_path" "$destination"
  echo "$(date '+%Y-%m-%d %H:%M:%S') created $destination" >> "$LOG"
  created=1
done < <(/usr/bin/python3 - "$PROFILES" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    profiles = json.load(handle)

for profile in profiles:
    print(f"{profile.get('id', '')}\t{profile.get('sessionName', '')}\t{profile.get('worldPath', '')}")
PY
)

if (( created == 1 )); then
  printf '%s\n' "$NOW" > "$STAMP"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') no running servers; skipped" >> "$LOG"
fi
"""#

private let installRollbackSchedulerScriptText = #"""
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.terrager.rollback-scheduler"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$HOME/Library/LaunchAgents" "$ROOT_DIR/logs"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$ROOT_DIR/scripts/rollback-scheduler.sh</string>
  </array>
  <key>StartInterval</key>
  <integer>60</integer>
  <key>StandardOutPath</key>
  <string>$ROOT_DIR/logs/rollback-launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>$ROOT_DIR/logs/rollback-launchd.err.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/$LABEL"

echo "Installed rollback scheduler: $LABEL"
"""#

private func defaultProfiles() -> [ServerProfile] {
    discoverWorldProfiles()
}

private func discoverWorldProfiles() -> [ServerProfile] {
    ensureRuntimeFolders()
    let worldRoot = runtimeDir + "/worlds"
    guard let contents = try? FileManager.default.contentsOfDirectory(atPath: worldRoot) else {
        return []
    }

    let worldFiles = contents
        .filter { $0.hasSuffix(".wld") }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    return worldFiles.enumerated().map { index, filename in
        let worldName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let id = ServerProfile.slug(worldName).isEmpty ? "server-\(index + 1)" : ServerProfile.slug(worldName)
        return ServerProfile.make(
            name: worldName,
            worldName: worldName,
            seedIdentifier: worldName,
            size: .medium,
            difficulty: .classic,
            evil: .corruption,
            port: 7777 + index,
            maxPlayers: 8,
            motd: "Terraria server",
            serverPath: defaultServerPath(),
            existingID: id,
            existingWorldPath: worldRoot + "/" + filename
        )
    }
}

private func loadProfilesFromDisk() -> [ServerProfile] {
    ensureRuntimeFolders()
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: profilesPath)),
          let decoded = try? JSONDecoder().decode([ServerProfile].self, from: data),
          !decoded.isEmpty
    else {
        let profiles = defaultProfiles()
        saveProfilesToDisk(profiles)
        return profiles
    }

    return decoded
}

private func saveProfilesToDisk(_ profiles: [ServerProfile]) {
    ensureRuntimeFolders()
    guard let data = try? JSONEncoder.pretty.encode(profiles) else {
        return
    }
    try? data.write(to: URL(fileURLWithPath: profilesPath), options: .atomic)
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private func localIPAddress() -> String {
    let result = Shell.run("""
    iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
    if [[ -n "$iface" ]]; then
      ipconfig getifaddr "$iface" 2>/dev/null && exit 0
    fi
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || ipconfig getifaddr en7 2>/dev/null || echo 127.0.0.1
    """)
    return result.output.isEmpty ? "127.0.0.1" : result.output
}

private func joinInfoLine(_ title: String, output: String) -> String? {
    output.components(separatedBy: .newlines)
        .first { $0.hasPrefix(title + ":") }
        .map { line in
            line.dropFirst(title.count + 1).trimmingCharacters(in: .whitespacesAndNewlines)
        }
}

private func splitJoinAddress(_ value: String) -> (host: String, port: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return ("unknown", "unknown")
    }

    if trimmed.hasPrefix("["),
       let closeBracket = trimmed.firstIndex(of: "]") {
        let host = String(trimmed[...closeBracket])
        let afterHost = trimmed[trimmed.index(after: closeBracket)...]
        let port = afterHost.hasPrefix(":") ? String(afterHost.dropFirst()) : ""
        return (host, port.isEmpty ? "unknown" : port)
    }

    guard let separator = trimmed.range(of: ":", options: .backwards) else {
        return (trimmed, "unknown")
    }

    let host = String(trimmed[..<separator.lowerBound])
    let port = String(trimmed[separator.upperBound...])
    return (host, port.isEmpty ? "unknown" : port)
}

private func byteString(_ raw: String) -> String {
    guard let value = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return raw
    }

    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(value))
}

private func byteString(kilobytes: String) -> String {
    guard let value = Int64(kilobytes.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return kilobytes
    }

    let formatter = ByteCountFormatter()
    formatter.countStyle = .memory
    return formatter.string(fromByteCount: value * 1024)
}

private func backupOwner(for path: String, profiles: [ServerProfile]) -> (name: String, id: String?) {
    let filename = URL(fileURLWithPath: path).lastPathComponent.lowercased()
    let components = path.components(separatedBy: "/")

    for profile in profiles {
        let id = profile.id.lowercased()
        let world = profile.worldName.lowercased()
        let seed = profile.seedIdentifier.lowercased()
        let backupComponentMatch = components.contains(profile.id)
        let filenameMatch = filename.hasPrefix(id + ".")
            || filename.hasPrefix(world + ".")
            || filename.hasPrefix(seed + ".")
            || filename.hasPrefix(id.replacingOccurrences(of: "-", with: "_") + ".")

        if backupComponentMatch || filenameMatch {
            return (profile.name, profile.id)
        }
    }

    return ("Unmatched", nil)
}

private func backupLabel(from filename: String) -> String {
    let name = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    let pieces = name.components(separatedBy: ".")
    guard pieces.count >= 3 else {
        return "manual"
    }
    return pieces.dropFirst().dropLast().joined(separator: ".")
}

private func loadBackupInventory(profiles: [ServerProfile]) -> ([BackupRecord], BackupStats) {
    let root = runtimeDir + "/worlds/backups"
    let fileManager = FileManager.default
    guard let enumerator = fileManager.enumerator(atPath: root) else {
        return ([], BackupStats())
    }

    var records: [BackupRecord] = []
    var stats = BackupStats()

    for case let relativePath as String in enumerator {
        guard relativePath.hasSuffix(".wld") else {
            continue
        }

        let path = root + "/" + relativePath
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber
        else {
            continue
        }

        let modified = attributes[.modificationDate] as? Date ?? Date.distantPast
        let owner = backupOwner(for: path, profiles: profiles)
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let record = BackupRecord(
            id: path,
            path: path,
            filename: filename,
            ownerName: owner.name,
            ownerID: owner.id,
            label: backupLabel(from: filename),
            sizeBytes: size.int64Value,
            createdAt: modified
        )
        records.append(record)
        stats.count += 1
        stats.sizeBytes += size.int64Value
    }

    records.sort { $0.createdAt > $1.createdAt }
    return (records, stats)
}

private func loadRollbackSettings() -> RollbackSettings {
    let settingsPath = runtimeDir + "/config/rollback-settings.env"
    guard let content = try? String(contentsOfFile: settingsPath, encoding: .utf8) else {
        return RollbackSettings()
    }

    var settings = RollbackSettings()
    for line in content.components(separatedBy: .newlines) {
        let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            continue
        }

        switch parts[0] {
        case "ENABLED":
            settings.enabled = parts[1] == "1"
        case "INTERVAL_MINUTES":
            settings.intervalMinutes = Int(parts[1]) ?? settings.intervalMinutes
        default:
            continue
        }
    }

    return settings
}

private func screenSessionRunning(_ listing: String, sessionName: String) -> Bool {
    listing.contains(".\(sessionName)\t") || listing.contains(".\(sessionName) ")
}

private func worldSummary(for path: String) -> String {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
          let size = attributes[.size] as? NSNumber
    else {
        return "World file not found."
    }

    let modified = attributes[.modificationDate] as? Date
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let modifiedText = modified.map(formatter.string(from:)) ?? "unknown"
    return "\(URL(fileURLWithPath: path).lastPathComponent)  \(byteString(String(size.int64Value)))  modified \(modifiedText)"
}

private func processStatus(for profile: ServerProfile, processOutput: String) -> RuntimeStatus {
    var status = RuntimeStatus()

    for line in processOutput.components(separatedBy: .newlines) {
        guard line.contains(profile.configPath) else {
            continue
        }

        let parts = line.split(separator: " ", maxSplits: 5).map(String.init)
        guard parts.count >= 5 else {
            continue
        }

        status.pid = parts[0]
        status.nice = parts[1]
        status.cpu = parts[2] + "%"
        status.memory = byteString(kilobytes: parts[4])
        break
    }

    return status
}

private func activePlayers(from logOutput: String, isRunning: Bool) -> [String] {
    guard isRunning else {
        return []
    }

    var players = Set<String>()
    for rawLine in logOutput.components(separatedBy: .newlines) {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix(": ") {
            line.removeFirst(2)
        }

        if line.contains("Server started") || line.contains("Listening on port") {
            players.removeAll()
            continue
        }

        if line.hasSuffix(" has joined.") {
            let name = String(line.dropLast(" has joined.".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                players.insert(name)
            }
            continue
        }

        if line.hasSuffix(" has left.") {
            let name = String(line.dropLast(" has left.".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                players.remove(name)
            }
        }
    }

    return players.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

final class ServerViewModel: ObservableObject {
    @Published var profiles: [ServerProfile] = []
    @Published var selectedProfileID: String?
    @Published var statuses: [String: RuntimeStatus] = [:]
    @Published var selectedLog = ""
    @Published var lastAction = ""
    @Published var isBusy = false
    @Published var isRefreshing = false
    @Published var backups: [BackupRecord] = []
    @Published var backupStats = BackupStats()
    @Published var selectedBackupID: String?
    @Published var rollbackSettings = RollbackSettings()
    @Published var rollbackEnabled = true
    @Published var rollbackIntervalMinutes = "60"
    @Published var saveOnAppClose = UserDefaults.standard.object(forKey: saveOnCloseKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(saveOnAppClose, forKey: saveOnCloseKey)
        }
    }

    init() {
        UserDefaults.standard.register(defaults: [saveOnCloseKey: true])
        profiles = loadProfilesFromDisk()
        selectedProfileID = profiles.first?.id
        let initialSettings = loadRollbackSettings()
        rollbackSettings = initialSettings
        rollbackEnabled = initialSettings.enabled
        rollbackIntervalMinutes = String(initialSettings.intervalMinutes)
    }

    var selectedProfile: ServerProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    var selectedStatus: RuntimeStatus {
        guard let selectedProfile else {
            return RuntimeStatus()
        }
        return statuses[selectedProfile.id] ?? RuntimeStatus(worldSummary: worldSummary(for: selectedProfile.worldPath))
    }

    var canStartSelectedServer: Bool {
        guard selectedProfile != nil else {
            return false
        }
        return !isBusy && !selectedStatus.isRunning && !selectedStatus.isListening
    }

    var canStartPublicSelectedServer: Bool {
        guard selectedProfile != nil else {
            return false
        }
        if isBusy {
            return false
        }
        return selectedStatus.isRunning || !selectedStatus.isListening
    }

    var canSaveSelectedWorld: Bool {
        selectedProfile != nil && selectedStatus.isRunning && !isBusy
    }

    var canStopSelectedServer: Bool {
        selectedProfile != nil && selectedStatus.isRunning && !isBusy
    }

    var canBackupSelectedWorld: Bool {
        guard let profile = selectedProfile else {
            return false
        }
        return !isBusy && FileManager.default.fileExists(atPath: profile.worldPath)
    }

    var canEditSelectedProfile: Bool {
        selectedProfile != nil && !selectedStatus.isRunning && !isBusy
    }

    var canDeleteSelectedWorld: Bool {
        selectedProfile != nil && !selectedStatus.isRunning && !isBusy
    }

    var canRestoreSelectedBackup: Bool {
        guard let backup = selectedBackup,
              let ownerID = backup.ownerID,
              let profile = profiles.first(where: { $0.id == ownerID })
        else {
            return false
        }

        return !(statuses[profile.id] ?? RuntimeStatus()).isRunning
    }

    var selectedBackupRestoreHelp: String {
        guard let backup = selectedBackup else {
            return "Select a backup first."
        }

        guard let ownerID = backup.ownerID,
              let profile = profiles.first(where: { $0.id == ownerID })
        else {
            return "This backup is not matched to a server profile."
        }

        if (statuses[profile.id] ?? RuntimeStatus()).isRunning {
            return "Safe Stop \(profile.name) before restoring. Restore never overwrites a live world."
        }

        return "Restore \(backup.filename) to \(profile.name)."
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        let profileSnapshot = profiles
        let selectedID = selectedProfileID

        DispatchQueue.global(qos: .utility).async {
            let screenList = Shell.run("screen -list 2>/dev/null || true").output
            let listeners = Shell.run("lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null || true").output
            let processes = Shell.run("ps -axo pid=,ni=,%cpu=,%mem=,rss=,args= | grep -F 'TerrariaServer.bin.osx' | grep -v grep || true").output
            let lanAddress = localIPAddress()
            let backupInventory = loadBackupInventory(profiles: profileSnapshot)
            let rollback = loadRollbackSettings()

            var nextStatuses: [String: RuntimeStatus] = [:]
            for profile in profileSnapshot {
                var status = processStatus(for: profile, processOutput: processes)
                status.isRunning = screenSessionRunning(screenList, sessionName: profile.sessionName) || !status.pid.isEmpty
                status.isListening = listeners.contains(":\(profile.port) (LISTEN)")
                let joinInfo = Shell.run("\(Shell.quote(joinInfoScript)) \(Shell.quote(String(profile.port))) 2>/dev/null || true").output
                status.joinAddress = joinInfoLine("Same Wi-Fi join target", output: joinInfo) ?? "\(lanAddress):\(profile.port)"
                status.internetJoinAddress = joinInfoLine("Internet join target", output: joinInfo) ?? "not configured"
                status.worldSummary = worldSummary(for: profile.worldPath)
                nextStatuses[profile.id] = status
            }

            if let selected = profileSnapshot.first(where: { $0.id == selectedID }) {
                var status = nextStatuses[selected.id] ?? RuntimeStatus()
                let connectionOutput = Shell.run("lsof -nP -iTCP:\(selected.port) 2>/dev/null | awk 'NR==1 || /ESTABLISHED/' || true").output
                let connections = connectionOutput.components(separatedBy: .newlines).filter { $0.contains("ESTABLISHED") }
                if !connections.isEmpty {
                    status.connections = connections.joined(separator: "\n")
                }
                let playerLog = Shell.run("awk '/Listening on port|Server started| has joined\\.| has left\\./ { print }' \(Shell.quote(selected.logPath)) 2>/dev/null | tail -n 1000 || true").output
                status.activePlayers = activePlayers(from: playerLog, isRunning: status.isRunning)
                nextStatuses[selected.id] = status
            }

            let log = profileSnapshot
                .first(where: { $0.id == selectedID })
                .map { Shell.run("tail -n 220 \(Shell.quote($0.logPath)) 2>/dev/null || true").output } ?? ""

            DispatchQueue.main.async {
                self.statuses = nextStatuses
                self.selectedLog = log
                self.backups = backupInventory.0
                self.backupStats = backupInventory.1
                self.rollbackSettings = rollback
                self.rollbackEnabled = rollback.enabled
                self.rollbackIntervalMinutes = String(rollback.intervalMinutes)
                if let selectedBackupID = self.selectedBackupID,
                   !backupInventory.0.contains(where: { $0.id == selectedBackupID }) {
                    self.selectedBackupID = backupInventory.0.first?.id
                } else if self.selectedBackupID == nil {
                    self.selectedBackupID = backupInventory.0.first?.id
                }
                self.isRefreshing = false
            }
        }
    }

    func startSelectedServer() {
        guard let profile = selectedProfile else {
            lastAction = "Select a server first."
            return
        }
        guard canStartSelectedServer else {
            lastAction = selectedStatus.isRunning ? "\(profile.name) is already running." : "Port \(profile.port) is already in use."
            return
        }

        runAction("Start \(profile.name)") {
            self.start(profile)
        }
    }

    func startPublicSelectedServer() {
        guard let profile = selectedProfile else {
            lastAction = "Select a server first."
            return
        }
        guard canStartPublicSelectedServer else {
            lastAction = selectedStatus.isListening ? "Port \(profile.port) is already in use." : "Select a server first."
            return
        }

        runAction("Start public \(profile.name)") {
            self.startForInternet(profile)
        }
    }

    func stopSelectedServer() {
        guard let profile = selectedProfile else {
            lastAction = "Select a server first."
            return
        }
        guard canStopSelectedServer else {
            lastAction = "\(profile.name) is already stopped."
            return
        }

        runAction("Safe stop \(profile.name)") {
            self.safeStop(profile)
        }
    }

    func saveSelectedWorld() {
        guard let profile = selectedProfile else {
            lastAction = "Select a server first."
            return
        }
        guard canSaveSelectedWorld else {
            lastAction = "\(profile.name) is not running."
            return
        }

        runAction("Save \(profile.name)") {
            self.send(profile, command: "save")
        }
    }

    func backupSelectedWorld() {
        guard let profile = selectedProfile else {
            lastAction = "Select a server first."
            return
        }
        guard canBackupSelectedWorld else {
            lastAction = "World file is not available for backup yet."
            return
        }

        runAction("Backup \(profile.name)") {
            self.backup(profile, label: "manual")
        }
    }

    func saveRollbackSettings() {
        let enabled = rollbackEnabled ? "1" : "0"
        let interval = rollbackIntervalMinutes.trimmingCharacters(in: .whitespacesAndNewlines)

        runAction("Rollback settings") {
            let result = Shell.run("\(Shell.quote(scriptsDir + "/set-rollback-settings.sh")) \(Shell.quote(enabled)) \(Shell.quote(interval))")
            if result.status != 0 {
                return result
            }

            let install = Shell.run(Shell.quote(installRollbackScript))
            if install.status != 0 {
                return install
            }

            return CommandResult(status: 0, output: [result.output, install.output].filter { !$0.isEmpty }.joined(separator: "\n"))
        }
    }

    func deleteSelectedBackup() {
        guard let backup = selectedBackup else {
            lastAction = "Select a backup first."
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete backup?"
        alert.informativeText = backup.path
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        runAction("Delete backup") {
            self.delete(backup)
        }
    }

    func restoreSelectedBackup() {
        guard let backup = selectedBackup else {
            lastAction = "Select a backup first."
            return
        }

        guard let ownerID = backup.ownerID,
              let profile = profiles.first(where: { $0.id == ownerID })
        else {
            lastAction = "This backup is not matched to a server profile."
            return
        }

        if (statuses[profile.id] ?? RuntimeStatus()).isRunning {
            lastAction = "Safe Stop \(profile.name) before restoring. Restore will not overwrite a live world."
            return
        }

        let alert = NSAlert()
        alert.messageText = "Restore \(backup.filename)?"
        alert.informativeText = "The current world will be backed up first, then replaced with this backup. The server must stay stopped."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        runAction("Restore backup") {
            self.restore(backup, to: profile)
        }
    }

    func revealSelectedBackup() {
        guard let backup = selectedBackup else {
            openBackupFolder()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: backup.path)])
    }

    func openBackupFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: runtimeDir + "/worlds/backups"))
    }

    func openRuntimeFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: runtimeDir))
    }

    func openWorldFolder() {
        guard let selectedProfile else {
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: selectedProfile.worldPath).deletingLastPathComponent())
    }

    var selectedBackup: BackupRecord? {
        guard let selectedBackupID else {
            return nil
        }
        return backups.first { $0.id == selectedBackupID }
    }

    func beginAdd() -> ProfileDraft {
        var draft = ProfileDraft()
        draft.port = nextAvailablePort()
        return draft
    }

    func importWorldFromPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import Terraria World"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let worldType = UTType(filenameExtension: "wld") {
            panel.allowedContentTypes = [worldType]
        }

        guard panel.runModal() == .OK,
              let url = panel.url
        else {
            return
        }

        let result = importWorld(at: url)
        lastAction = result.output
        refresh()
    }

    func addProfile(from draft: ProfileDraft) {
        guard let profile = makeProfile(from: draft) else {
            lastAction = "Invalid server profile."
            return
        }

        var candidate = profile
        var counter = 2
        while profiles.contains(where: { $0.id == candidate.id }) {
            candidate.id = profile.id + "-\(counter)"
            candidate.sessionName = "terraria-" + candidate.id
            candidate.worldPath = runtimeDir + "/worlds/" + candidate.id + ".wld"
            candidate.configPath = runtimeDir + "/serverconfigs/" + candidate.id + ".serverconfig.txt"
            candidate.logPath = runtimeDir + "/logs/" + candidate.id + "-server.log"
            counter += 1
        }

        profiles.append(candidate)
        selectedProfileID = candidate.id
        saveProfiles()
        lastAction = "Added \(candidate.name). Start it to create or open its world."
        refresh()
    }

    func updateSelectedProfile(from draft: ProfileDraft) {
        guard let selectedProfile,
              let index = profiles.firstIndex(where: { $0.id == selectedProfile.id }),
              var updated = makeProfile(from: draft, existing: selectedProfile)
        else {
            lastAction = "Invalid server profile."
            return
        }
        guard !(statuses[selectedProfile.id] ?? RuntimeStatus()).isRunning else {
            lastAction = "Stop \(selectedProfile.name) before editing its launch settings."
            return
        }

        updated.id = selectedProfile.id
        updated.sessionName = selectedProfile.sessionName
        updated.worldPath = selectedProfile.worldPath
        updated.configPath = selectedProfile.configPath
        updated.logPath = selectedProfile.logPath
        profiles[index] = updated
        saveProfiles()
        lastAction = "Updated \(updated.name)."
        refresh()
    }

    func deleteSelectedWorld() {
        guard let profile = selectedProfile else {
            lastAction = "Select a server first."
            return
        }

        if selectedStatus.isRunning {
            lastAction = "Stop \(profile.name) before deleting its world."
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete \(profile.name)?"
        alert.informativeText = "The world, generated config, and log will be moved to Trash. Running servers are never deleted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        runAction("Delete \(profile.name)") {
            self.delete(profile)
        }
    }

    private func runAction(_ label: String, work: @escaping () -> CommandResult) {
        guard !isBusy else {
            return
        }

        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = work()
            let prefix = result.status == 0 ? label : "\(label) failed"
            let output = [prefix, result.output].filter { !$0.isEmpty }.joined(separator: "\n")

            DispatchQueue.main.async {
                self.lastAction = output
                self.isBusy = false
                self.refresh()
            }
        }
    }

    private func start(_ profile: ServerProfile) -> CommandResult {
        ensureRuntimeFolders()

        if screenSessionRunning(Shell.run("screen -list 2>/dev/null || true").output, sessionName: profile.sessionName) {
            return CommandResult(status: 0, output: "Already running in screen session \(profile.sessionName).")
        }

        let portCheck = Shell.run("lsof -nP -iTCP:\(profile.port) -sTCP:LISTEN 2>/dev/null || true")
        if !portCheck.output.isEmpty {
            return CommandResult(status: 1, output: "Port \(profile.port) is already in use.\n\(portCheck.output)")
        }

        do {
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: profile.worldPath).deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: profile.configPath).deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: profile.logPath).deletingLastPathComponent(), withIntermediateDirectories: true)
            try profile.configText.write(toFile: profile.configPath, atomically: true, encoding: .utf8)
        } catch {
            return CommandResult(status: 1, output: error.localizedDescription)
        }

        let backupResult = profile.worldExists ? backup(profile, label: "before-start") : CommandResult(status: 0, output: "World file does not exist yet; Terraria will generate it from the profile settings.")
        if backupResult.status != 0 {
            return backupResult
        }

        let serverDirectory = URL(fileURLWithPath: profile.serverPath).deletingLastPathComponent().path
        let launch = "cd \(Shell.quote(serverDirectory)) && exec /usr/bin/caffeinate -dimsu /usr/bin/nice -n 10 \(Shell.quote(profile.serverPath)) -config \(Shell.quote(profile.configPath)) >> \(Shell.quote(profile.logPath)) 2>&1"
        let command = "screen -dmS \(Shell.quote(profile.sessionName)) bash -lc \(Shell.quote(launch))"
        let startResult = Shell.run(command)
        if startResult.status != 0 {
            return startResult
        }

        Thread.sleep(forTimeInterval: 5)

        if !screenSessionRunning(Shell.run("screen -list 2>/dev/null || true").output, sessionName: profile.sessionName) {
            let tail = Shell.run("tail -n 100 \(Shell.quote(profile.logPath)) 2>/dev/null || true").output
            return CommandResult(status: 1, output: "Server did not stay running.\n\(tail)")
        }

        return CommandResult(status: 0, output: [backupResult.output, "Screen session: \(profile.sessionName)", "Log: \(profile.logPath)"].joined(separator: "\n"))
    }

    private func startForInternet(_ profile: ServerProfile) -> CommandResult {
        var messages: [String] = []
        if screenSessionRunning(Shell.run("screen -list 2>/dev/null || true").output, sessionName: profile.sessionName) {
            messages.append("Server already running.")
        } else {
            let startResult = start(profile)
            if startResult.status != 0 {
                return startResult
            }
            messages.append(startResult.output)
        }

        let rollbackResult = Shell.run(Shell.quote(installRollbackScript))
        if rollbackResult.status == 0, !rollbackResult.output.isEmpty {
            messages.append(rollbackResult.output)
        }

        let joinInfo = Shell.run("\(Shell.quote(joinInfoScript)) \(Shell.quote(String(profile.port))) 2>/dev/null || true").output
        messages.append(joinInfo)
        return CommandResult(status: 0, output: messages.filter { !$0.isEmpty }.joined(separator: "\n"))
    }

    private func safeStop(_ profile: ServerProfile) -> CommandResult {
        let wasRunning = screenSessionRunning(Shell.run("screen -list 2>/dev/null || true").output, sessionName: profile.sessionName)
        var messages: [String] = []

        guard wasRunning else {
            let backupResult = FileManager.default.fileExists(atPath: profile.worldPath) ? backup(profile, label: "shutdown-stopped") : CommandResult(status: 0, output: "No world backup made because the world file is missing.")
            if backupResult.status != 0 {
                return backupResult
            }
            messages.append("Server was already stopped.")
            messages.append(backupResult.output)
            return CommandResult(status: 0, output: messages.filter { !$0.isEmpty }.joined(separator: "\n"))
        }

        _ = send(profile, command: "say Server is saving and shutting down now.")
        let saveResult = send(profile, command: "save")
        if saveResult.status != 0 {
            return saveResult
        }
        messages.append(saveResult.output)

        Thread.sleep(forTimeInterval: 10)

        let preBackup = backup(profile, label: "shutdown-prestop")
        if preBackup.status != 0 {
            return preBackup
        }
        messages.append(preBackup.output)

        let exitResult = send(profile, command: "exit")
        if exitResult.status != 0 {
            return exitResult
        }
        messages.append(exitResult.output)

        let stopped = waitUntilStopped(profile, timeout: 60)
        if !stopped {
            return CommandResult(status: 1, output: messages.joined(separator: "\n") + "\nServer did not stop within 60 seconds.")
        }

        let postBackup = backup(profile, label: "shutdown-poststop")
        if postBackup.status != 0 {
            return postBackup
        }
        messages.append(postBackup.output)
        messages.append("Server stopped cleanly.")
        return CommandResult(status: 0, output: messages.filter { !$0.isEmpty }.joined(separator: "\n"))
    }

    private func waitUntilStopped(_ profile: ServerProfile, timeout: Int) -> Bool {
        for _ in 0..<timeout {
            let screenList = Shell.run("screen -list 2>/dev/null || true").output
            let listener = Shell.run("lsof -nP -iTCP:\(profile.port) -sTCP:LISTEN 2>/dev/null || true").output
            if !screenSessionRunning(screenList, sessionName: profile.sessionName) && listener.isEmpty {
                return true
            }
            Thread.sleep(forTimeInterval: 1)
        }
        return false
    }

    private func send(_ profile: ServerProfile, command: String) -> CommandResult {
        guard screenSessionRunning(Shell.run("screen -list 2>/dev/null || true").output, sessionName: profile.sessionName) else {
            return CommandResult(status: 1, output: "\(profile.name) is not running.")
        }

        let screenCommand = "screen -S \(Shell.quote(profile.sessionName)) -p 0 -X stuff \(Shell.quote(command + "\n"))"
        let result = Shell.run(screenCommand)
        if result.status == 0 {
            return CommandResult(status: 0, output: "Sent command: \(command)")
        }
        return result
    }

    private func backup(_ profile: ServerProfile, label: String) -> CommandResult {
        guard FileManager.default.fileExists(atPath: profile.worldPath) else {
            return CommandResult(status: 1, output: "World file not found: \(profile.worldPath)")
        }

        let isRunning = screenSessionRunning(Shell.run("screen -list 2>/dev/null || true").output, sessionName: profile.sessionName)
        if isRunning {
            _ = send(profile, command: "save")
            Thread.sleep(forTimeInterval: 8)
        }

        do {
            try FileManager.default.createDirectory(atPath: profile.backupDir, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let stamp = formatter.string(from: Date())
            let destination = profile.backupDir + "/" + profile.id + "." + label + "." + stamp + ".wld"
            try FileManager.default.copyItem(atPath: profile.worldPath, toPath: destination)
            return CommandResult(status: 0, output: "Backup: \(destination)")
        } catch {
            return CommandResult(status: 1, output: error.localizedDescription)
        }
    }

    private func delete(_ backup: BackupRecord) -> CommandResult {
        do {
            var trashed: NSURL?
            try FileManager.default.trashItem(at: URL(fileURLWithPath: backup.path), resultingItemURL: &trashed)
            return CommandResult(status: 0, output: "Moved to Trash: \(backup.path)")
        } catch {
            return CommandResult(status: 1, output: error.localizedDescription)
        }
    }

    private func restore(_ backup: BackupRecord, to profile: ServerProfile) -> CommandResult {
        let screenList = Shell.run("screen -list 2>/dev/null || true").output
        if screenSessionRunning(screenList, sessionName: profile.sessionName) {
            return CommandResult(status: 1, output: "Refusing to restore while \(profile.name) is running.")
        }

        guard FileManager.default.fileExists(atPath: backup.path) else {
            return CommandResult(status: 1, output: "Backup file not found: \(backup.path)")
        }

        let preRestore = FileManager.default.fileExists(atPath: profile.worldPath)
            ? self.backup(profile, label: "pre-restore")
            : CommandResult(status: 0, output: "No current world file existed before restore.")
        if preRestore.status != 0 {
            return preRestore
        }

        do {
            try FileManager.default.copyItem(atPath: backup.path, toPath: profile.worldPath + ".restore-tmp")
            if FileManager.default.fileExists(atPath: profile.worldPath) {
                try FileManager.default.removeItem(atPath: profile.worldPath)
            }
            try FileManager.default.moveItem(atPath: profile.worldPath + ".restore-tmp", toPath: profile.worldPath)
            return CommandResult(status: 0, output: [preRestore.output, "Restored \(backup.filename) to \(profile.worldPath)"].filter { !$0.isEmpty }.joined(separator: "\n"))
        } catch {
            _ = try? FileManager.default.removeItem(atPath: profile.worldPath + ".restore-tmp")
            return CommandResult(status: 1, output: error.localizedDescription)
        }
    }

    private func importWorld(at sourceURL: URL) -> CommandResult {
        ensureRuntimeFolders()

        let fileManager = FileManager.default
        let sourcePath = sourceURL.path
        guard sourceURL.pathExtension.lowercased() == "wld",
              fileManager.fileExists(atPath: sourcePath)
        else {
            return CommandResult(status: 1, output: "Select a Terraria .wld file.")
        }

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let baseID = ServerProfile.slug(baseName).isEmpty ? "imported-world" : ServerProfile.slug(baseName)
        var id = baseID
        var counter = 2
        while profiles.contains(where: { $0.id == id }) || fileManager.fileExists(atPath: runtimeDir + "/worlds/" + id + ".wld") {
            id = baseID + "-\(counter)"
            counter += 1
        }

        let destination = runtimeDir + "/worlds/" + id + ".wld"
        do {
            if URL(fileURLWithPath: sourcePath).standardizedFileURL.path != URL(fileURLWithPath: destination).standardizedFileURL.path {
                try fileManager.copyItem(atPath: sourcePath, toPath: destination)
            }
        } catch {
            return CommandResult(status: 1, output: error.localizedDescription)
        }

        let profile = ServerProfile.make(
            name: baseName,
            worldName: baseName,
            seedIdentifier: baseName,
            size: .medium,
            difficulty: .classic,
            evil: .corruption,
            port: Int(nextAvailablePort()) ?? 7777,
            maxPlayers: 8,
            motd: "Terraria server",
            serverPath: defaultServerPath(),
            existingID: id,
            existingWorldPath: destination
        )

        profiles.append(profile)
        selectedProfileID = profile.id
        saveProfiles()
        return CommandResult(status: 0, output: "Imported \(sourceURL.lastPathComponent) as \(profile.name).")
    }

    private func delete(_ profile: ServerProfile) -> CommandResult {
        let screenList = Shell.run("screen -list 2>/dev/null || true").output
        if screenSessionRunning(screenList, sessionName: profile.sessionName) {
            return CommandResult(status: 1, output: "Stop \(profile.name) before deleting its world.")
        }

        let fileManager = FileManager.default
        var messages: [String] = []

        for path in [profile.worldPath, profile.configPath, profile.logPath] where fileManager.fileExists(atPath: path) {
            do {
                var trashed: NSURL?
                try fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &trashed)
                messages.append("Moved to Trash: \(path)")
            } catch {
                return CommandResult(status: 1, output: error.localizedDescription)
            }
        }

        DispatchQueue.main.async {
            self.profiles.removeAll { $0.id == profile.id }
            self.selectedProfileID = self.profiles.first?.id
            self.saveProfiles()
        }

        return CommandResult(status: 0, output: messages.isEmpty ? "Removed profile. No files existed." : messages.joined(separator: "\n"))
    }

    private func makeProfile(from draft: ProfileDraft, existing: ServerProfile? = nil) -> ServerProfile? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let worldName = draft.worldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = draft.seedIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let motd = draft.motd.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverPath = draft.serverPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty || !worldName.isEmpty,
              let port = Int(draft.port),
              (1024...65535).contains(port),
              let maxPlayers = Int(draft.maxPlayers),
              (1...255).contains(maxPlayers),
              FileManager.default.isExecutableFile(atPath: serverPath)
        else {
            return nil
        }

        return ServerProfile.make(
            name: name,
            worldName: worldName.isEmpty ? name : worldName,
            seedIdentifier: seed.isEmpty ? (worldName.isEmpty ? name : worldName) : seed,
            size: draft.size,
            difficulty: draft.difficulty,
            evil: draft.evil,
            port: port,
            maxPlayers: maxPlayers,
            motd: motd.isEmpty ? name : motd,
            serverPath: serverPath,
            existingID: existing?.id,
            existingWorldPath: existing?.worldPath
        )
    }

    private func nextAvailablePort() -> String {
        let used = Set(profiles.map(\.port))
        for port in 7777...7799 where !used.contains(port) {
            return String(port)
        }
        return "7800"
    }

    private func saveProfiles() {
        saveProfilesToDisk(profiles)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if UserDefaults.standard.object(forKey: saveOnCloseKey) as? Bool ?? true {
            let screenList = Shell.run("screen -list 2>/dev/null || true").output
            for profile in loadProfilesFromDisk() where screenSessionRunning(screenList, sessionName: profile.sessionName) {
                _ = Shell.run("screen -S \(Shell.quote(profile.sessionName)) -p 0 -X stuff \(Shell.quote("save\n"))")
            }
        }
        return .terminateNow
    }
}

struct StatusPill: View {
    let title: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isOn ? AppTheme.success : AppTheme.danger)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.panelSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PanelContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.border))
    }
}

struct AppLogoView: View {
    var size: CGFloat

    var body: some View {
        if let path = Bundle.main.path(forResource: "terrager", ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            Image(systemName: "server.rack")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: size, height: size)
                .background(AppTheme.lavender.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.body, design: .monospaced))
    }
}

struct JoinTargetCard: View {
    let title: String
    let host: String
    let port: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                Text("Host")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(host)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text("Port")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                Text(port)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.panelSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.panelSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ServerRowView: View {
    let profile: ServerProfile
    let status: RuntimeStatus
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Circle()
                    .fill(status.isRunning ? AppTheme.success : AppTheme.sidebarMuted.opacity(0.72))
                    .frame(width: 8, height: 8)
                Text(profile.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Spacer()
            }

            Text("\(profile.worldName) :\(String(profile.port))")
                .font(.caption)
                .foregroundStyle(AppTheme.sidebarMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AppTheme.primarySoft.opacity(0.42) : Color.white.opacity(0.0001))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.lavender.opacity(0.36), lineWidth: 1)
            }
        }
    }
}

struct BackupRowView: View {
    let backup: BackupRecord
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox")
                .foregroundStyle(isSelected ? AppTheme.primary : Color.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(backup.filename)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 12) {
                    Text(backup.ownerName)
                    Text(backup.label)
                    Text(backup.sizeText)
                    Text(backup.createdText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(isSelected ? AppTheme.lavender.opacity(0.18) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ControlButton: View {
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let action: () -> Void

    init(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
    }
}

struct EditorSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryDeep)
            content
        }
        .padding(14)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.border))
    }
}

struct PlainTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var monospaced = false

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.cell?.focusRingType = .none
        textField.delegate = context.coordinator
        textField.font = monospaced
            ? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.text = $text
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.focusRingType = .none
        nsView.cell?.focusRingType = .none
        nsView.font = monospaced
            ? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            : NSFont.systemFont(ofSize: NSFont.systemFontSize)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }
            text.wrappedValue = textField.stringValue
        }
    }
}

struct LabeledInput: View {
    let title: String
    let help: String
    let placeholder: String
    @Binding var text: String
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                if !help.isEmpty {
                    Text(help)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            PlainTextField(placeholder: placeholder, text: $text, monospaced: monospaced)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(AppTheme.panelSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.border))
        }
    }
}

struct ProfileEditorView: View {
    let title: String
    @Binding var draft: ProfileDraft
    let onCancel: () -> Void
    let onSave: () -> Void

    private var validationMessages: [String] {
        var messages: [String] = []
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Server name required")
        }
        if draft.worldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("World name required")
        }
        if Int(draft.port).map({ !(1024...65535).contains($0) }) ?? true {
            messages.append("Port must be 1024-65535")
        }
        if Int(draft.maxPlayers).map({ !(1...255).contains($0) }) ?? true {
            messages.append("Players must be 1-255")
        }
        if !FileManager.default.isExecutableFile(atPath: draft.serverPath) {
            messages.append("TerrariaServer binary not executable")
        }
        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                AppLogoView(size: 58)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.largeTitle.weight(.semibold))
                    Text("Create a reusable Terraria profile. The world is not generated until you press Start.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(22)
            .background(AppTheme.panel)

            Divider()

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Launch Summary")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 10) {
                        summaryRow("Server", draft.name.isEmpty ? "Unnamed" : draft.name)
                        summaryRow("World", draft.worldName.isEmpty ? "New world" : draft.worldName)
                        summaryRow("Port", draft.port)
                        summaryRow("Players", draft.maxPlayers)
                        summaryRow("Mode", "\(draft.size.label), \(draft.difficulty.label)")
                    }
                    .font(.subheadline)

                    Divider()

                    Text("Terrager creates reusable profiles without generating worlds until you start them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !validationMessages.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Needs attention")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.warning)
                            ForEach(validationMessages, id: \.self) { message in
                                Label(message, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.warning)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(width: 230, alignment: .topLeading)
                .background(AppTheme.primaryDeep)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        EditorSection(title: "Identity", systemImage: "tag") {
                            LabeledInput(title: "Server Name", help: "Shown in the manager", placeholder: "Weekend co-op", text: $draft.name)
                            LabeledInput(title: "World Name", help: "Shown in Terraria", placeholder: "SharedWorld", text: $draft.worldName)
                            LabeledInput(title: "MOTD", help: "Optional server message", placeholder: "Terraria server from this Mac", text: $draft.motd)
                        }

                        EditorSection(title: "World Generation", systemImage: "globe.americas") {
                            LabeledInput(title: "Seed", help: "Optional", placeholder: "leave blank to use the world name", text: $draft.seedIdentifier)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Size")
                                    .font(.subheadline.weight(.medium))
                                Picker("Size", selection: $draft.size) {
                                    ForEach(WorldSize.allCases) { size in
                                        Text(size.label).tag(size)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Difficulty")
                                    .font(.subheadline.weight(.medium))
                                Picker("Difficulty", selection: $draft.difficulty) {
                                    ForEach(WorldDifficulty.allCases) { difficulty in
                                        Text(difficulty.label).tag(difficulty)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("World Evil")
                                    .font(.subheadline.weight(.medium))
                                Picker("World Evil", selection: $draft.evil) {
                                    ForEach(WorldEvil.allCases) { evil in
                                        Text(evil.label).tag(evil)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        EditorSection(title: "Network", systemImage: "network") {
                            HStack(spacing: 12) {
                                LabeledInput(title: "Port", help: "LAN join port", placeholder: "7777", text: $draft.port, monospaced: true)
                                LabeledInput(title: "Max Players", help: "1-255", placeholder: "8", text: $draft.maxPlayers, monospaced: true)
                            }
                        }

                        EditorSection(title: "Server Binary", systemImage: "terminal") {
                            HStack(alignment: .bottom, spacing: 10) {
                                LabeledInput(title: "Executable", help: "Usually Steam's TerrariaServer", placeholder: defaultServerPath(), text: $draft.serverPath, monospaced: true)
                                Button {
                                    chooseBinary()
                                } label: {
                                    Label("Browse", systemImage: "folder")
                                }
                            }
                        }
                    }
                    .padding(18)
                }
                .frame(maxHeight: 560)
            }
            .background(AppTheme.background)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save Profile", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(18)
            .background(AppTheme.panel)
        }
        .tint(AppTheme.primary)
        .frame(width: 920, height: 720)
        .onAppear {
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(AppTheme.sidebarMuted)
                .frame(width: 76, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private func chooseBinary() {
        let panel = NSOpenPanel()
        panel.title = "Choose TerrariaServer"
        panel.prompt = "Use Binary"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            draft.serverPath = url.path
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()
    @State private var refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    @State private var showingAddProfile = false
    @State private var showingEditProfile = false
    @State private var draft = ProfileDraft()
    @State private var selectedSection: DetailSection = .overview

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(minWidth: 1060, minHeight: 720)
        .background(AppTheme.background)
        .tint(AppTheme.primary)
        .onAppear {
            viewModel.refresh()
        }
        .onReceive(refreshTimer) { _ in
            viewModel.refresh()
        }
        .sheet(isPresented: $showingAddProfile) {
            ProfileEditorView(title: "New Server", draft: $draft) {
                showingAddProfile = false
            } onSave: {
                viewModel.addProfile(from: draft)
                showingAddProfile = false
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            ProfileEditorView(title: "Edit Server", draft: $draft) {
                showingEditProfile = false
            } onSave: {
                viewModel.updateSelectedProfile(from: draft)
                showingEditProfile = false
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Servers", systemImage: "server.rack")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                Spacer()
                Button {
                    draft = viewModel.beginAdd()
                    showingAddProfile = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add server")
                Button {
                    viewModel.importWorldFromPanel()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Import .wld world")
            }
            .padding(14)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.profiles) { profile in
                        let status = viewModel.statuses[profile.id] ?? RuntimeStatus(worldSummary: worldSummary(for: profile.worldPath))
                        Button {
                            viewModel.selectedProfileID = profile.id
                        } label: {
                            ServerRowView(
                                profile: profile,
                                status: status,
                                isSelected: viewModel.selectedProfileID == profile.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 260)
        .background(AppTheme.sidebar)
    }

    private var detail: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                selectedContent
                .padding(18)
            }
        }
        .background(AppTheme.background)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .overview:
            VStack(alignment: .leading, spacing: 16) {
                statusPanel
                controlsPanel
            }
        case .backups:
            backupsPanel
        case .logs:
            logsPanel
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AppLogoView(size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.selectedProfile?.name ?? appName)
                    .font(.title2.weight(.semibold))
                Text(runtimeDir)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            Picker("Section", selection: $selectedSection) {
                ForEach(DetailSection.allCases) { section in
                    Text(section.label).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            Toggle("Save on close", isOn: $viewModel.saveOnAppClose)

            if viewModel.isBusy || viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                viewModel.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(16)
        .background(AppTheme.panel)
    }

    private var statusPanel: some View {
        guard let profile = viewModel.selectedProfile else {
            return AnyView(
                Text("No servers configured.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            )
        }

        let status = viewModel.selectedStatus
        let lanTarget = splitJoinAddress(status.joinAddress)
        let internetTarget = splitJoinAddress(status.internetJoinAddress)
        return AnyView(
            PanelContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    StatusPill(title: "Server", isOn: status.isRunning)
                    StatusPill(title: "Port \(String(profile.port))", isOn: status.isListening)
                    StatusPill(title: profile.difficulty.label, isOn: true)
                    StatusPill(title: profile.evil.label, isOn: true)
                    Spacer()
                }

                HStack(alignment: .top, spacing: 12) {
                    JoinTargetCard(title: "Same Wi-Fi", host: lanTarget.host, port: lanTarget.port, systemImage: "wifi")
                    JoinTargetCard(title: "Outside Network", host: internetTarget.host, port: internetTarget.port, systemImage: "network")
                }

                HStack(alignment: .top, spacing: 12) {
                    MetricTile(title: "World", value: profile.worldName, detail: status.worldSummary, systemImage: "globe.americas")
                    MetricTile(title: "Seed", value: profile.encodedSeed, detail: "\(profile.size.label), \(profile.difficulty.label), \(profile.evil.label)", systemImage: "leaf")
                    MetricTile(title: "Process", value: status.pid.isEmpty ? "Stopped" : "PID \(status.pid)", detail: status.pid.isEmpty ? "No server process" : "CPU \(status.cpu), RAM \(status.memory)", systemImage: "cpu")
                    MetricTile(title: "World Time", value: status.worldTimeTitle, detail: status.worldTimeDetail, systemImage: "moon.stars")
                }

                HStack(alignment: .top, spacing: 12) {
                    MetricTile(title: "Players", value: "\(status.playerCount)", detail: status.activePlayers.isEmpty ? "No connected players detected." : status.activePlayers.joined(separator: ", "), systemImage: "person.2")
                    MetricTile(title: "Backups", value: "\(viewModel.backupStats.count)", detail: "\(viewModel.backupStats.sizeText) total", systemImage: "archivebox")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Active Connections")
                        .font(.headline)
                    Text(status.connections)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            }
        )
    }

    private var controlsPanel: some View {
        let status = viewModel.selectedStatus
        let publicTitle = status.isRunning ? "Public Info" : "Start Public"

        return PanelContainer {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Controls")
                    .font(.headline)
                Spacer()
                Button {
                    if let profile = viewModel.selectedProfile {
                        draft = ProfileDraft(profile: profile)
                        showingEditProfile = true
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(!viewModel.canEditSelectedProfile)
                .help(viewModel.canEditSelectedProfile ? "Edit this server profile." : "Stop the server before editing launch settings.")
                Button(role: .destructive) {
                    viewModel.deleteSelectedWorld()
                } label: {
                    Label("Delete World", systemImage: "trash")
                }
                .disabled(!viewModel.canDeleteSelectedWorld)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], alignment: .leading, spacing: 10) {
                ControlButton("Start", systemImage: "play.fill") {
                    viewModel.startSelectedServer()
                }
                .disabled(!viewModel.canStartSelectedServer)
                .help(viewModel.canStartSelectedServer ? "Start the selected server." : "Start is unavailable while this server is running or its port is occupied.")
                ControlButton(publicTitle, systemImage: "network") {
                    viewModel.startPublicSelectedServer()
                }
                .disabled(!viewModel.canStartPublicSelectedServer)
                .help(viewModel.canStartPublicSelectedServer ? "Start the server and show public endpoint information if configured." : "Public endpoint info is unavailable while the selected port is occupied.")
                ControlButton("Save", systemImage: "square.and.arrow.down") {
                    viewModel.saveSelectedWorld()
                }
                .disabled(!viewModel.canSaveSelectedWorld)
                ControlButton("Backup", systemImage: "clock.arrow.circlepath") {
                    viewModel.backupSelectedWorld()
                }
                .disabled(!viewModel.canBackupSelectedWorld)
                ControlButton("Safe Stop", systemImage: "stop.fill", role: .destructive) {
                    viewModel.stopSelectedServer()
                }
                .disabled(!viewModel.canStopSelectedServer)
                Button {
                    viewModel.openRuntimeFolder()
                } label: {
                    Label("Runtime", systemImage: "folder")
                }
                .controlSize(.large)
                Button {
                    viewModel.openWorldFolder()
                } label: {
                    Label("Worlds", systemImage: "globe.americas")
                }
                .controlSize(.large)
            }

            if !viewModel.lastAction.isEmpty {
                Text(viewModel.lastAction)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        }
    }

    private var backupsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                MetricTile(title: "Backup Files", value: "\(viewModel.backupStats.count)", detail: "All .wld backups under worlds/backups", systemImage: "archivebox")
                MetricTile(title: "Disk Usage", value: viewModel.backupStats.sizeText, detail: "Total storage used by backups", systemImage: "internaldrive")
                MetricTile(title: "Scheduled Backups", value: viewModel.rollbackSettings.enabled ? "On" : "Off", detail: viewModel.rollbackSettings.summary, systemImage: "clock.arrow.circlepath")
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Scheduled Backup Snapshots")
                        .font(.headline)
                    Spacer()
                    Toggle("Enabled", isOn: $viewModel.rollbackEnabled)
                    TextField("60", text: $viewModel.rollbackIntervalMinutes)
                        .frame(width: 64)
                        .textFieldStyle(.roundedBorder)
                    Text("minutes")
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.saveRollbackSettings()
                    } label: {
                        Label("Apply", systemImage: "checkmark")
                    }
                }

                Text("Runs after the configured interval only while the Terraria screen session is running. When the server is off, it logs a skip and does not copy the world.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Backups")
                        .font(.headline)
                    Spacer()
                    Button {
                        viewModel.backupSelectedWorld()
                    } label: {
                        Label("Backup Now", systemImage: "plus.circle")
                    }
                    Button {
                        viewModel.revealSelectedBackup()
                    } label: {
                        Label("Reveal", systemImage: "magnifyingglass")
                    }
                    Button {
                        viewModel.restoreSelectedBackup()
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!viewModel.canRestoreSelectedBackup)
                    .help(viewModel.selectedBackupRestoreHelp)
                    Button(role: .destructive) {
                        viewModel.deleteSelectedBackup()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        viewModel.openBackupFolder()
                    } label: {
                        Label("Folder", systemImage: "folder")
                    }
                }

                if viewModel.backups.isEmpty {
                    Text("No backups found.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.backups) { backup in
                                Button {
                                    viewModel.selectedBackupID = backup.id
                                } label: {
                                    BackupRowView(backup: backup, isSelected: viewModel.selectedBackupID == backup.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                    }
                    .frame(minHeight: 360)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if let backup = viewModel.selectedBackup {
                    InfoRow(title: "Selected", value: backup.path)
                }
            }
            .padding(14)
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))

            if !viewModel.lastAction.isEmpty {
                Text(viewModel.lastAction)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var logsPanel: some View {
        PanelContainer {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Log")
                    .font(.headline)
                Spacer()
                Text(viewModel.selectedProfile?.logPath ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            ScrollView {
                Text(viewModel.selectedLog.isEmpty ? "No log output yet." : viewModel.selectedLog)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .frame(minHeight: 260)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        }
    }
}

@main
struct TerragerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
