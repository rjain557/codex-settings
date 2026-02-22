<purpose>
Generate a cross-platform remote agent that runs as a background service on Mac, Linux, and Windows. Optionally includes a system tray icon with context menu or popup window for user interaction.

The agent follows API-First architecture (communicates via API, never holds DB credentials), supports MCP client integration, health reporting, and auto-update. Platform-specific service wrappers handle install/uninstall lifecycle.
</purpose>

<core_principle>
One codebase, three platforms. The core agent logic lives in shared/, and platform-specific code is limited to service wrappers, tray integration, and packaging. The agent MUST communicate through the API layer only (API-First rule).
</core_principle>

<required_reading>
Read STATE.md and ROADMAP.md before any operation to load project context.
Read any existing OpenAPI spec at docs/spec/openapi.yaml for API integration.
</required_reading>

<process>

<step name="initialize" priority="first">
Determine project context:

1. Check if `.planning/` exists (GSD project) or standalone generation
2. Check for existing OpenAPI spec at `docs/spec/openapi.yaml`
3. Check for existing API client code
4. Detect project language (C#/.NET preferred for Technijian stack, Node.js/TypeScript alternative)

Parse arguments:
- `$ARGUMENTS` may contain target platform: `mac`, `linux`, `windows`, or empty for all three
- Parse any flags: `--name <agent-name>`, `--api-url <base-url>`
</step>

<step name="ask_ui_mode">
Present the UI mode choice to the user:

```
AskUserQuestion(
  header="Agent UI",
  question="What UI should the agent have when running as a service?",
  options=[
    {
      label: "Headless (Recommended)",
      description: "No UI. Runs silently as a service. Managed via CLI commands and config files. Best for servers and CI/CD."
    },
    {
      label: "System tray with menu",
      description: "Tray icon with right-click context menu (status, pause/resume, settings, quit). Like Docker Desktop or Dropbox."
    },
    {
      label: "System tray with popup",
      description: "Tray icon with a popup window for richer interaction (logs, config editor, activity feed). Like Claude Desktop or 1Password."
    }
  ]
)
```

Store choice as `UI_MODE`: `headless`, `tray-menu`, or `tray-popup`.
</step>

<step name="ask_runtime">
If not already determined from project context:

```
AskUserQuestion(
  header="Runtime",
  question="What runtime should the agent use?",
  options=[
    {
      label: ".NET 8 (Recommended)",
      description: "Matches your backend stack. Native Windows Service support via Worker Service. Cross-platform via dotnet publish."
    },
    {
      label: "Node.js / TypeScript",
      description: "Lighter weight. Good for MCP-focused agents. Uses pm2 or node-windows/node-mac for service management."
    },
    {
      label: "Electron",
      description: "Required for tray-popup mode with rich UI. Heavier but gives full desktop app experience. Chromium-based."
    }
  ]
)
```

Note: If user chose `tray-popup` and picks .NET or Node.js, recommend Electron for the UI layer with the chosen runtime for the agent core.
</step>

<step name="generate_project_structure">
Generate the directory structure based on choices:

```
src/agents/{agent-name}/
  shared/                          # Cross-platform core
    agent-core.ts (or .cs)         # Main agent loop (start, stop, health check)
    config.ts                      # Configuration loader (env vars, config file, defaults)
    api-client.ts                  # Typed API client (from OpenAPI if available)
    mcp-client.ts                  # MCP client integration (optional)
    health-reporter.ts             # Health check endpoint / heartbeat
    auto-updater.ts                # Self-update mechanism (check version, download, restart)
    logger.ts                      # Structured logging (file + console)
    types.ts                       # Shared type definitions

  platforms/
    mac/
      launchd.plist                # macOS LaunchAgent/LaunchDaemon config
      install.sh                   # Install script (copies plist, loads agent)
      uninstall.sh                 # Uninstall script (unloads, removes)
      Info.plist                   # App bundle info (if tray mode)
      build-pkg.sh                 # Package as .pkg installer

    linux/
      systemd.service              # systemd unit file
      install.sh                   # Install script (copies unit, enables service)
      uninstall.sh                 # Uninstall script (stops, disables, removes)
      build-deb.sh                 # Package as .deb
      build-rpm.sh                 # Package as .rpm

    windows/
      service-wrapper.ts (or .cs)  # Windows Service wrapper (or NSSM config)
      install.ps1                  # PowerShell install script
      uninstall.ps1                # PowerShell uninstall script
      build-msi.wxs                # WiX MSI installer definition

  tray/                            # Only if UI_MODE != headless
    tray-icon.ts                   # System tray icon setup
    tray-menu.ts                   # Context menu definition (if tray-menu mode)
    tray-popup/                    # Only if tray-popup mode
      index.html                   # Popup window HTML
      popup.ts                     # Popup logic
      popup.css                    # Popup styles
    assets/
      icon.png                     # Tray icon (16x16, 32x32, 64x64)
      icon.ico                     # Windows icon
      icon.icns                    # macOS icon

  cli/
    index.ts                       # CLI entry point (status, start, stop, config)
    commands/
      status.ts                    # Show agent status
      config.ts                    # View/edit configuration
      logs.ts                      # Tail log output
      update.ts                    # Trigger manual update

  config/
    default.json                   # Default configuration
    schema.json                    # JSON Schema for config validation

  tests/
    agent-core.test.ts             # Core logic tests
    api-client.test.ts             # API client tests
    health-reporter.test.ts        # Health check tests

  package.json (or .csproj)        # Project manifest
  tsconfig.json                    # TypeScript config (if TS)
  README.md                        # Agent documentation
```
</step>

<step name="generate_core_agent">
Generate the core agent logic in `shared/`:

**agent-core** must implement:
1. **Lifecycle**: `start()`, `stop()`, `restart()`, `getStatus()`
2. **Health**: Periodic heartbeat to API (configurable interval)
3. **Config**: Hot-reload configuration without restart
4. **Graceful shutdown**: Handle SIGTERM/SIGINT, complete in-flight work
5. **Error recovery**: Automatic restart on crash (with backoff)
6. **Logging**: Structured JSON logs with rotation

**api-client** must follow API-First:
- Generated from OpenAPI spec if available
- Uses typed HTTP client (axios/fetch for TS, HttpClient for .NET)
- Handles auth (JWT token refresh, retry on 401)
- Never connects to database directly

**mcp-client** (optional):
- Connects to MCP servers as a client
- Discovers available tools and resources
- Executes tools on behalf of the agent's workflow

**health-reporter**:
- Exposes local health endpoint (HTTP GET /health on configurable port)
- Reports: agent version, uptime, last successful API call, pending work count
- Heartbeat to central API: POST /agents/{id}/heartbeat

**auto-updater**:
- Checks for updates on configurable schedule
- Downloads new version to staging directory
- Signals service manager to restart with new version
- Rollback if new version fails health check within 60s
</step>

<step name="generate_platform_wrappers">
Generate platform-specific service wrappers:

**macOS (launchd)**:
```xml
<!-- LaunchAgent for user-level, LaunchDaemon for system-level -->
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.technijian.{agent-name}</string>
    <key>ProgramArguments</key>
    <array>
      <string>/usr/local/bin/{agent-name}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/{agent-name}/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/{agent-name}/stderr.log</string>
  </dict>
</plist>
```

**Linux (systemd)**:
```ini
[Unit]
Description=Technijian {Agent Name}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/{agent-name}
Restart=on-failure
RestartSec=10
User={agent-name}
Group={agent-name}
WorkingDirectory=/opt/{agent-name}
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal
SyslogIdentifier={agent-name}

[Install]
WantedBy=multi-user.target
```

**Windows (Worker Service or NSSM)**:
- For .NET: Use `Microsoft.Extensions.Hosting.WindowsServices` (native Worker Service)
- For Node.js: Use `node-windows` package or NSSM wrapper
- Generate PowerShell install/uninstall scripts
- Register with Windows Event Log for logging
</step>

<step name="generate_tray_integration">
Only if `UI_MODE` is `tray-menu` or `tray-popup`.

**System tray icon** (cross-platform):
- macOS: Use `tray` module (Electron) or `rumps` (Python) or native NSStatusItem
- Linux: Use `libappindicator` or Electron tray
- Windows: Use `NotifyIcon` (.NET) or Electron tray

**Context menu** (tray-menu mode):
```
[ Agent Name v1.2.3 ]
--------------------
Status: Running
Last sync: 2 min ago
--------------------
> Pause Agent
> View Logs...
> Settings...
--------------------
> Check for Updates
> About
--------------------
> Quit
```

**Popup window** (tray-popup mode):
- Generates a small popup (400x500px) anchored to tray icon
- Tabs: Activity, Logs, Settings
- Activity: Recent operations with timestamps
- Logs: Scrollable log viewer with filter
- Settings: Config editor with save/apply
- Uses Electron BrowserWindow or .NET WPF/Avalonia
</step>

<step name="generate_cli">
Generate CLI commands for managing the agent:

```bash
{agent-name} status          # Show agent status (running/stopped, uptime, version)
{agent-name} start           # Start the agent service
{agent-name} stop            # Stop the agent service
{agent-name} restart         # Restart the agent service
{agent-name} logs            # Tail agent logs
{agent-name} logs --level error  # Filter by log level
{agent-name} config          # Show current config
{agent-name} config set key=value  # Update config (hot-reload)
{agent-name} update          # Check and apply updates
{agent-name} install         # Install as system service
{agent-name} uninstall       # Remove system service
```
</step>

<step name="generate_packaging">
Generate build and packaging scripts:

**macOS**: `build-pkg.sh` -- Creates signed .pkg installer
**Linux**: `build-deb.sh` / `build-rpm.sh` -- Creates .deb/.rpm packages
**Windows**: `build-msi.wxs` -- WiX-based MSI installer

All packages should:
- Install the binary to standard location (/usr/local/bin, Program Files)
- Register the service
- Create config directory
- Set up log rotation
- Create uninstall entry
</step>

<step name="generate_tests">
Generate test suite:

1. **Core tests**: Agent lifecycle (start/stop/restart), config loading, health reporting
2. **API client tests**: Request/response mapping, auth token refresh, error handling
3. **Platform tests**: Service install/uninstall (mocked), tray menu actions (if applicable)
4. **Integration tests**: End-to-end agent start, health check, API call, graceful shutdown
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add src/agents/{agent-name}/
git commit -m "feat: scaffold {agent-name} remote agent ({platforms}, {ui_mode})"
```

Report:
```
## Agent Generated: {agent-name}

**UI Mode**: {headless | tray-menu | tray-popup}
**Runtime**: {.NET 8 | Node.js | Electron}
**Platforms**: {Mac + Linux + Windows | specific}

### Generated Structure
{tree output}

### Next Steps
1. Configure API endpoint in config/default.json
2. Run tests: npm test (or dotnet test)
3. Build: npm run build (or dotnet publish)
4. Install locally: {platform-specific install command}
5. Package for distribution: {build-pkg/build-deb/build-msi}
```
</step>

</process>

<success_criteria>
- [ ] Core agent logic generated (lifecycle, config, health, logging)
- [ ] API client generated (typed, API-First compliant, no DB access)
- [ ] Platform wrappers generated for target platforms (launchd/systemd/Windows Service)
- [ ] Tray integration generated if requested (menu or popup)
- [ ] CLI commands generated (status, start, stop, config, logs)
- [ ] Install/uninstall scripts generated per platform
- [ ] Packaging scripts generated (pkg/deb/rpm/msi)
- [ ] Test suite generated
- [ ] README with setup instructions
</success_criteria>

<failure_handling>
- **No OpenAPI spec found**: Generate a minimal API client with placeholder endpoints; warn user to update
- **Unsupported runtime + UI combo**: If tray-popup requested with non-Electron runtime, recommend Electron wrapper
- **Platform-specific build tools missing**: Generate scripts but warn about required tools (Xcode, dpkg, WiX)
</failure_handling>

