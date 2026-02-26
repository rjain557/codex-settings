<purpose>
Generate a cross-browser extension that runs on Chrome, Edge, and Safari. Supports Manifest V3 (Chrome/Edge) and Safari Web Extension format. Optionally integrates with your application's API for data sync and authentication.

The extension follows a shared-core architecture: common logic lives in shared/, with browser-specific adapters for APIs that differ across browsers (storage, identity, sidebar panels).
</purpose>

<core_principle>
One codebase, three browsers. The core extension logic lives in shared/, browser-specific polyfills and manifest differences are handled by the build system. Chrome and Edge share Manifest V3 directly. Safari uses a Web Extension wrapper with Xcode project scaffolding.
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
3. Check for existing auth configuration (Azure AD, JWT)
4. Detect if React/TypeScript is already in use (reuse toolchain)

Parse arguments:
- `$ARGUMENTS` may contain target browser: `chrome`, `edge`, `safari`, or empty for all three
- Parse any flags: `--name <extension-name>`, `--api-url <base-url>`
</step>

<step name="ask_extension_type">
Present the extension type choice:

```
AskUserQuestion(
  header="Ext type",
  question="What type of browser extension should be generated?",
  options=[
    {
      label: "Popup (Recommended)",
      description: "Toolbar icon with a popup panel when clicked. Best for quick actions, status display, and settings. Like 1Password or Grammarly."
    },
    {
      label: "Side panel",
      description: "Full-height sidebar that persists alongside web pages. Best for reference tools, chat assistants, and reading aids. Like Claude sidebar."
    },
    {
      label: "Content script only",
      description: "Injects into web pages with no visible UI of its own. Best for page enhancement, auto-fill, ad blocking. Like Dark Reader."
    },
    {
      label: "Full extension",
      description: "All components: popup, side panel, content scripts, options page, and background service worker. Maximum flexibility."
    }
  ]
)
```

Store choice as `EXT_TYPE`: `popup`, `sidepanel`, `content-script`, or `full`.
</step>

<step name="ask_framework">
Present framework choice for UI components:

```
AskUserQuestion(
  header="UI Framework",
  question="What framework should the extension UI use?",
  options=[
    {
      label: "React + Fluent UI (Recommended)",
      description: "Matches your web app stack. Fluent UI v9 components for consistent Microsoft-style look. TypeScript + Vite build."
    },
    {
      label: "React + Tailwind",
      description: "React with Tailwind CSS for lightweight, custom styling. Good for unique extension designs."
    },
    {
      label: "Vanilla TypeScript",
      description: "No framework. Plain TypeScript with minimal dependencies. Smallest bundle size. Best for simple extensions."
    }
  ]
)
```

Store as `UI_FRAMEWORK`.
Note: If `content-script` type was chosen with no UI, skip this question.
</step>

<step name="generate_project_structure">
Generate the directory structure:

```
src/extensions/{extension-name}/
  shared/                              # Cross-browser core
    background/
      service-worker.ts                # Background service worker (MV3)
      api-client.ts                    # Typed API client (from OpenAPI if available)
      auth.ts                          # Auth handler (Azure AD / JWT token management)
      storage.ts                       # Cross-browser storage abstraction
      messaging.ts                     # Message passing (popup â†” background â†” content)
    content/
      content-script.ts               # Content script entry point
      page-analyzer.ts                # Page content analysis utilities
      injected-ui.ts                  # DOM injection utilities (if content-script type)
    popup/                            # Only if popup or full type
      App.tsx                         # Popup React app root
      components/                    # Popup UI components
      hooks/                         # Custom React hooks
      index.html                     # Popup HTML entry
      index.tsx                      # Popup entry point
      popup.css                      # Popup styles
    sidepanel/                        # Only if sidepanel or full type
      App.tsx                         # Side panel React app root
      components/                    # Side panel UI components
      index.html                     # Side panel HTML entry
      index.tsx                      # Side panel entry point
    options/                          # Only if full type
      App.tsx                         # Options page React app root
      index.html                     # Options HTML entry
      index.tsx                      # Options entry point
    types.ts                          # Shared type definitions
    constants.ts                      # Extension constants

  browsers/
    chrome/
      manifest.json                   # Chrome Manifest V3
    edge/
      manifest.json                   # Edge Manifest V3 (slight differences)
    safari/
      manifest.json                   # Safari Web Extension manifest
      xcode/                          # Xcode project scaffold
        {ExtName}.xcodeproj/
        {ExtName} Extension/
          SafariWebExtensionHandler.swift  # Native Safari handler
          Info.plist
        {ExtName}/                    # Container app
          AppDelegate.swift
          Info.plist

  assets/
    icons/
      icon-16.png
      icon-32.png
      icon-48.png
      icon-128.png
    icon.svg                          # Source SVG for icon generation

  config/
    default.json                      # Default extension settings
    schema.json                       # Settings JSON Schema

  scripts/
    build.ts                          # Cross-browser build script
    package-chrome.sh                 # Package for Chrome Web Store
    package-edge.sh                   # Package for Edge Add-ons
    package-safari.sh                 # Package for Safari (via Xcode)

  tests/
    background.test.ts                # Service worker tests
    content.test.ts                   # Content script tests
    popup.test.ts                     # Popup UI tests
    messaging.test.ts                 # Message passing tests

  package.json                        # Project manifest
  tsconfig.json                       # TypeScript config
  vite.config.ts                      # Vite build config (multi-entry)
  README.md                           # Extension documentation
```
</step>

<step name="generate_manifest">
Generate browser-specific manifests:

**Chrome/Edge (Manifest V3):**
```json
{
  "manifest_version": 3,
  "name": "{Extension Name}",
  "version": "1.0.0",
  "description": "{description}",
  "permissions": ["storage", "activeTab", "identity"],
  "host_permissions": ["https://api.example.com/*"],
  "background": {
    "service_worker": "background/service-worker.js",
    "type": "module"
  },
  "action": {
    "default_popup": "popup/index.html",
    "default_icon": {
      "16": "assets/icons/icon-16.png",
      "32": "assets/icons/icon-32.png",
      "48": "assets/icons/icon-48.png",
      "128": "assets/icons/icon-128.png"
    }
  },
  "side_panel": {
    "default_path": "sidepanel/index.html"
  },
  "content_scripts": [{
    "matches": ["<all_urls>"],
    "js": ["content/content-script.js"]
  }],
  "options_page": "options/index.html",
  "icons": {
    "16": "assets/icons/icon-16.png",
    "48": "assets/icons/icon-48.png",
    "128": "assets/icons/icon-128.png"
  }
}
```

Adjust manifest based on EXT_TYPE:
- `popup`: Include action.default_popup, background, no side_panel or content_scripts
- `sidepanel`: Include side_panel, background, no action.default_popup
- `content-script`: Include content_scripts, background, no action or side_panel
- `full`: Include everything

**Edge differences:**
- Add `"browser_specific_settings": { "edge": { ... } }` if needed
- Edge supports same MV3 as Chrome with minor API differences

**Safari:**
- Convert MV3 manifest to Safari-compatible format
- Generate Xcode project with Web Extension target
- Generate `SafariWebExtensionHandler.swift` for native messaging
- Generate container app shell
</step>

<step name="generate_background">
Generate background service worker:

1. **Lifecycle**: Install, activate, idle/wake handlers
2. **API client**: Typed HTTP client for your backend API
3. **Auth**: Token management (store in chrome.storage.session, refresh on 401)
4. **Storage**: Cross-browser storage wrapper (chrome.storage.local/sync/session)
5. **Messaging**: chrome.runtime.onMessage handler for popup/content communication
6. **Alarms**: Periodic tasks (sync, token refresh) via chrome.alarms API
7. **Context menus**: Right-click menu items (if applicable)
</step>

<step name="generate_ui_components">
Generate UI based on EXT_TYPE and UI_FRAMEWORK:

**Popup** (400x600px max):
- Header with extension name and status
- Main content area (scrollable)
- Action buttons
- Settings link â†’ options page
- Theme-aware (detect system dark/light mode)

**Side panel** (full height, ~400px wide):
- Tab navigation (if multiple views)
- Scrollable content area
- Persistent state across page navigations
- Resize handle (if supported)

**Content script UI** (injected into pages):
- Shadow DOM isolation (prevent CSS conflicts)
- Floating action button or inline widget
- Non-intrusive positioning

**Options page**:
- Settings form with save/reset
- API endpoint configuration
- Auth login/logout
- Extension permissions display

All UI follows Fluent UI v9 patterns if that framework was selected.
</step>

<step name="generate_build_system">
Generate cross-browser build configuration:

**Vite config** with multiple entry points:
- Background service worker (no DOM)
- Popup (if applicable)
- Side panel (if applicable)
- Content script (isolated world)
- Options page (if applicable)

**Build targets:**
- `npm run build:chrome` â†’ outputs to `dist/chrome/`
- `npm run build:edge` â†’ outputs to `dist/edge/`
- `npm run build:safari` â†’ outputs to `dist/safari/`
- `npm run build:all` â†’ builds all targets
- `npm run dev` â†’ Chrome dev mode with hot reload
- `npm run package` â†’ creates .zip files for store submission

**Key considerations:**
- Service worker must be a single file (no dynamic imports)
- Content scripts run in isolated world (separate from page JS)
- Assets must be listed in web_accessible_resources if used by content scripts
</step>

<step name="generate_tests">
Generate test suite:

1. **Background tests**: Service worker lifecycle, message handling, API calls
2. **Content script tests**: DOM injection, page analysis, message passing
3. **UI tests**: Component rendering, user interactions (React Testing Library)
4. **Integration tests**: Full message flow (popup â†’ background â†’ API â†’ response)
5. **Cross-browser tests**: Verify manifest compatibility, API polyfill coverage
</step>

<step name="commit_and_report">
Commit all generated files:

```bash
git add src/extensions/{extension-name}/
git commit -m "feat: scaffold {extension-name} browser extension ({browsers}, {ext_type})"
```

Report:
```
## Extension Generated: {extension-name}

**Type**: {popup | sidepanel | content-script | full}
**UI Framework**: {React + Fluent UI | React + Tailwind | Vanilla TS}
**Browsers**: {Chrome + Edge + Safari | specific}

### Generated Structure
{tree output}

### Next Steps
1. Install dependencies: cd src/extensions/{extension-name} && npm install
2. Configure API endpoint in config/default.json
3. Dev mode: npm run dev (loads in Chrome)
4. Load unpacked in Chrome: chrome://extensions â†’ dist/chrome/
5. Load in Edge: edge://extensions â†’ dist/edge/
6. Safari: Open xcode/{ExtName}.xcodeproj â†’ Run
7. Run tests: npm test
8. Package for stores: npm run package
```
</step>

</process>

<success_criteria>
- [ ] Manifest V3 generated for Chrome and Edge
- [ ] Safari Web Extension manifest and Xcode project generated
- [ ] Background service worker with API integration
- [ ] UI components generated for selected extension type
- [ ] Content scripts generated (if applicable)
- [ ] Cross-browser storage and messaging abstractions
- [ ] Vite build config with multi-target output
- [ ] Packaging scripts for all browser stores
- [ ] Test suite generated
- [ ] README with setup and store submission instructions
</success_criteria>

<failure_handling>
- **No OpenAPI spec found**: Generate API client with placeholder endpoints; warn user to update
- **Safari Xcode not available**: Generate all Safari files but warn that Xcode is required to build
- **MV3 API not available in Safari**: Add polyfill layer for APIs that Safari doesn't support yet
- **Content Security Policy conflicts**: Generate appropriate CSP in manifest; document any limitations
</failure_handling>

