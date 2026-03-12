# Xojo ↔ AntV X6 Bridge — Architecture Research

---

## 1. The Communication Stack

```
┌─────────────────────────────────────────────────────┐
│  Xojo Desktop Window                                │
│  ┌───────────────────────┐  ┌─────────────────────┐ │
│  │   Native Controls     │  │  HTMLViewer /        │ │
│  │                       │  │  MBS WKWebView       │ │
│  │  • Property editor    │  │                      │ │
│  │  • Column list        │  │  ┌──────────────┐   │ │
│  │  • Type dropdowns     │  │  │  AntV X6     │   │ │
│  │  • Constraint toggles │  │  │  ER Diagram  │   │ │
│  │  • Toolbar buttons    │  │  │              │   │ │
│  │                       │  │  │  [users]──┐  │   │ │
│  │  ◄── JSON ──►         │  │  │  [notes]──┘  │   │ │
│  │                       │  │  │              │   │ │
│  └───────────────────────┘  │  └──────────────┘   │ │
│          ▲                  │         ▲            │ │
│          │                  └─────────┼────────────┘ │
│          │     Xojo ↔ JS Bridge      │              │
│          └───────────────────────────-┘              │
└─────────────────────────────────────────────────────┘
```

---

## 2. Three Bridge Options (Ranked)

### Option A: Xojo Built-in HTMLViewer (Recommended Start)

Xojo's `DesktopHTMLViewer` has a **native two-way JS bridge** since recent versions:

**Xojo → JavaScript:**
```xojo
// Async (fire-and-forget)
HTMLViewer1.ExecuteJavaScript("graph.selectNode('node-1')")

// Sync (returns string or number only)
Var json As String = HTMLViewer1.ExecuteJavaScriptSync("JSON.stringify(graph.toJSON())")
```

**JavaScript → Xojo:**
```javascript
// Async (fire-and-forget)
executeInXojo("nodeSelected", JSON.stringify({id: "node-1", table: "users"}));

// Sync (blocks JS until Xojo returns a string)
var result = executeInXojoSync("getColumnTypes");
var types = JSON.parse(result);
```

**Xojo event handler:**
```xojo
Event JavaScriptRequest(method As String, parameters() As Variant) As String
  Select Case method
  Case "nodeSelected"
    Var json As String = parameters(0).StringValue
    HandleNodeSelected(json)

  Case "getColumnTypes"
    // Return data to JavaScript synchronously
    Return "[""INTEGER"",""TEXT"",""REAL"",""BLOB"",""DATETIME""]"

  Case "edgeConnected"
    Var json As String = parameters(0).StringValue
    HandleEdgeConnected(json)

  Case "graphChanged"
    Var json As String = parameters(0).StringValue
    HandleGraphChanged(json)

  End Select
End Event
```

**Limitations:**
- Parameters support **only strings and numbers** (no bools, arrays, objects)
- Workaround: always `JSON.stringify()` on JS side, parse in Xojo
- Must wait for `DocumentComplete` before calling `ExecuteJavaScript`
- `ExecuteJavaScriptSync` returns only strings or numbers
- No way to inject JS before page load (must wait for load, then execute)

**Verdict:** Good enough for v1. Works cross-platform (WKWebView on macOS, CEF/Chromium on Windows, WebKitGTK on Linux).

---

### Option B: MBS WKWebViewControlMBS (macOS — Best Bridge)

MBS exposes the full WKWebView API including **message handlers** and **user scripts**:

**Setup (once):**
```xojo
// Register a message handler — JS can post to it
WKWebView1.addScriptMessageHandler("xojo")

// Inject bridge code BEFORE page loads
Var bridge As New WKUserScriptMBS( _
  "window.xojoBridge = { send: function(event, data) { " + _
  "window.webkit.messageHandlers.xojo.postMessage(JSON.stringify({event: event, data: data})); " + _
  "} };", _
  WKUserScriptMBS.InjectionTimeAtDocumentStart, True)
WKWebView1.addUserScript(bridge)
```

**JavaScript → Xojo (via message handler):**
```javascript
// Clean, native WebKit API — no hacks
window.webkit.messageHandlers.xojo.postMessage({
  event: "nodeSelected",
  nodeId: "node-1",
  data: { tableName: "users", columns: [...] }
});

// Or using the injected bridge helper:
xojoBridge.send("nodeSelected", { nodeId: "node-1", tableName: "users" });
```

**Xojo event:**
```xojo
Event didReceiveScriptMessage(Body as Variant, name as String)
  // name = "xojo" (the handler name)
  // Body = the full message object (auto-parsed from JSON!)
  Var json As String = Body.StringValue
  Var msg As New JSONItem(json)

  Select Case msg.Value("event").StringValue
  Case "nodeSelected"
    ShowPropertyEditor(msg.Child("data"))
  Case "edgeConnected"
    HandleNewRelationship(msg.Child("data"))
  End Select
End Event
```

**Xojo → JavaScript:**
```xojo
// Async with completion callback
WKWebView1.EvaluateJavaScript("graph.addNode({shape:'er-table', x:100, y:100, data:" + tableJSON + "})")

// Sync with error handling
Var err As NSErrorMBS
Var result As Variant = WKWebView1.EvaluateJavaScript("JSON.stringify(graph.toJSON())", err)
If err <> Nil Then
  // Handle error
End If
```

**Advantages over built-in HTMLViewer:**
| Feature | HTMLViewer | MBS WKWebView |
|---------|-----------|---------------|
| JS → Native | `executeInXojo()` (strings/numbers only) | `postMessage()` (any JSON) |
| Inject JS before load | Not possible | `addUserScript()` at DocumentStart |
| Async JS with callback | No | `JavaScriptEvaluated` event |
| Error handling | Silent failures | `NSErrorMBS` with details |
| Web Inspector | No control | `developerExtrasEnabled = True` |
| Local file access | Limited | `allowFileAccessFromFileURLs` |

**Limitation:** macOS only. Need WebView2 (Option C) for Windows.

---

### Option C: MBS WebView2ControlMBS (Windows)

The Windows equivalent, using Microsoft Edge WebView2 (Chromium-based):

**JavaScript → Xojo:**
```javascript
// Windows WebView2 bridge
window.chrome.webview.postMessage({
  event: "nodeSelected",
  nodeId: "node-1",
  data: { tableName: "users" }
});
```

**Xojo event:**
```xojo
Event WebMessageReceived(Source As String, webMessageAsJson As String, webMessageAsString As String)
  Var msg As New JSONItem(webMessageAsJson)
  // Handle the same way as macOS
End Event
```

**Xojo → JavaScript:**
```xojo
// Execute JS
WebView2Control1.ExecuteScript("nativeCommand(" + commandJSON + ")")

// Or send structured message
WebView2Control1.PostWebMessageAsJson(commandJSON)
```

**JavaScript receives native messages:**
```javascript
window.chrome.webview.addEventListener("message", (event) => {
  const cmd = event.data;
  handleNativeCommand(cmd);
});
```

**Bonus:** `SetVirtualHostNameToFolderMapping` maps local folders to virtual URLs — load your HTML/JS via `https://er-editor.local/index.html` instead of `file://` (avoids CORS issues).

---

## 3. Cross-Platform Bridge Abstraction

To support both macOS and Windows with MBS, create a unified bridge in JavaScript:

```javascript
// bridge.js — auto-detects platform and provides uniform API
const XojoBridge = {
  send(event, data) {
    const msg = JSON.stringify({ event, data, timestamp: Date.now() });

    // macOS: WKWebView message handler
    if (window.webkit?.messageHandlers?.xojo) {
      window.webkit.messageHandlers.xojo.postMessage(msg);
      return;
    }

    // Windows: WebView2 message handler
    if (window.chrome?.webview) {
      window.chrome.webview.postMessage(msg);
      return;
    }

    // Fallback: Xojo built-in HTMLViewer bridge
    if (typeof executeInXojo === 'function') {
      executeInXojo("bridgeMessage", msg);
      return;
    }

    console.warn("No native bridge available");
  },

  // Listen for commands from Xojo
  onCommand(handler) {
    // All platforms: Xojo calls nativeCommand() via evaluateJavaScript
    window.nativeCommand = handler;

    // Windows WebView2: also receives via message event
    if (window.chrome?.webview) {
      window.chrome.webview.addEventListener("message", (e) => handler(e.data));
    }
  }
};
```

---

## 4. AntV X6 Events → Xojo Property Editor

### Complete Event Wiring

```javascript
// ---- er-editor.js ----

// Node selected → show property editor in Xojo
graph.on('node:selected', ({ node }) => {
  const data = node.getData();
  XojoBridge.send('node:selected', {
    nodeId: node.id,
    tableName: data.tableName,
    columns: data.columns,       // [{name, type, pk, fk, nullable, default}, ...]
    position: node.getPosition(),
    size: node.getSize(),
  });
});

// Node unselected → hide/clear property editor
graph.on('node:unselected', ({ node }) => {
  XojoBridge.send('node:unselected', { nodeId: node.id });
});

// Node moved → update position in schema
graph.on('node:moved', ({ node }) => {
  XojoBridge.send('node:moved', {
    nodeId: node.id,
    position: node.getPosition(),
  });
});

// Edge connected → new FK relationship created
graph.on('edge:connected', ({ edge, isNew }) => {
  XojoBridge.send('edge:connected', {
    edgeId: edge.id,
    isNew: isNew,
    sourceNodeId: edge.getSourceCellId(),
    sourcePort: edge.getSourcePortId(),   // e.g. "users-id-R"
    targetNodeId: edge.getTargetCellId(),
    targetPort: edge.getTargetPortId(),   // e.g. "notes-user_id-L"
  });
});

// Edge removed → FK relationship deleted
graph.on('edge:removed', ({ edge }) => {
  XojoBridge.send('edge:removed', {
    edgeId: edge.id,
    sourceNodeId: edge.getSourceCellId(),
    targetNodeId: edge.getTargetCellId(),
  });
});

// Blank area clicked → deselect, hide property editor
graph.on('blank:click', () => {
  XojoBridge.send('blank:click', {});
});

// Graph changed → mark as dirty (unsaved changes)
graph.on('cell:added', () => XojoBridge.send('graph:dirty', {}));
graph.on('cell:removed', () => XojoBridge.send('graph:dirty', {}));
graph.on('cell:changed', () => XojoBridge.send('graph:dirty', {}));
```

### Xojo Responds to Events

```xojo
// In the WebView's message handler event:
Select Case eventName

Case "node:selected"
  // Populate native property editor
  Var columns As JSONItem = data.Child("columns")
  PropertyPanel.Visible = True
  TableNameField.Text = data.Value("tableName")
  ColumnsListBox.RemoveAllRows
  For i As Integer = 0 To columns.Count - 1
    Var col As JSONItem = columns.ChildAt(i)
    ColumnsListBox.AddRow(col.Value("name"), col.Value("type"))
    If col.Value("pk") Then ColumnsListBox.CellTagAt(ColumnsListBox.LastAddedRowIndex, 0) = "PK"
  Next

Case "node:unselected", "blank:click"
  PropertyPanel.Visible = False
  ColumnsListBox.RemoveAllRows

Case "edge:connected"
  // Show FK relationship dialog or auto-create FK constraint
  If data.Value("isNew") Then
    ShowForeignKeyDialog(data)
  End If

Case "graph:dirty"
  Self.Title = "Model Toolkit *"  // Mark unsaved
  SaveButton.Enabled = True

End Select
```

### Xojo Property Editor → X6 Updates

```xojo
// User edits table name in native TextField
Sub TableNameField_TextChanged()
  Var nodeId As String = currentSelectedNodeId
  Var newName As String = TableNameField.Text

  // Update the X6 node's data
  Var cmd As New JSONItem
  cmd.Value("action") = "updateTableName"
  cmd.Value("nodeId") = nodeId
  cmd.Value("tableName") = newName

  WebView.ExecuteJavaScript("nativeCommand(" + cmd.ToString + ")")
End Sub

// User adds a column via native dialog
Sub AddColumnButton_Pressed()
  Var dlg As New AddColumnDialog
  If dlg.ShowModal = Window.ButtonOK Then
    Var cmd As New JSONItem
    cmd.Value("action") = "addColumn"
    cmd.Value("nodeId") = currentSelectedNodeId

    Var col As New JSONItem
    col.Value("name") = dlg.ColumnName
    col.Value("type") = dlg.ColumnType
    col.Value("pk") = dlg.IsPrimaryKey
    col.Value("nullable") = dlg.IsNullable
    cmd.Child("column") = col

    WebView.ExecuteJavaScript("nativeCommand(" + cmd.ToString + ")")
  End If
End Sub
```

```javascript
// er-editor.js — handle commands from Xojo
XojoBridge.onCommand(function(cmd) {
  switch (cmd.action) {
    case 'updateTableName': {
      const node = graph.getCellById(cmd.nodeId);
      if (node) {
        const data = node.getData();
        data.tableName = cmd.tableName;
        node.setData(data);  // triggers re-render via effect: ['data']
      }
      break;
    }
    case 'addColumn': {
      const node = graph.getCellById(cmd.nodeId);
      if (node) {
        const data = node.getData();
        data.columns.push(cmd.column);
        node.setData(data);
        // Also add port for the new column
        node.addPort({
          id: `${data.tableName}-${cmd.column.name}-L`,
          group: 'left'
        });
        node.addPort({
          id: `${data.tableName}-${cmd.column.name}-R`,
          group: 'right'
        });
      }
      break;
    }
    case 'removeColumn': {
      const node = graph.getCellById(cmd.nodeId);
      if (node) {
        const data = node.getData();
        data.columns = data.columns.filter(c => c.name !== cmd.columnName);
        node.setData(data);
        node.removePort(`${data.tableName}-${cmd.columnName}-L`);
        node.removePort(`${data.tableName}-${cmd.columnName}-R`);
      }
      break;
    }
    case 'addTable': {
      graph.addNode({
        shape: 'er-table',
        x: cmd.x || 200, y: cmd.y || 200,
        data: cmd.tableData,
        ports: buildPortsFromColumns(cmd.tableData),
      });
      break;
    }
    case 'removeTable': {
      graph.removeNode(cmd.nodeId);
      break;
    }
    case 'getGraph': {
      XojoBridge.send('graph:export', graph.toJSON());
      break;
    }
    case 'loadGraph': {
      graph.fromJSON(cmd.graphData);
      break;
    }
    case 'selectNode': {
      const node = graph.getCellById(cmd.nodeId);
      if (node) graph.select(node);
      break;
    }
    case 'fitContent': {
      graph.zoomToFit({ padding: 40 });
      break;
    }
    case 'undo': {
      graph.undo();
      break;
    }
    case 'redo': {
      graph.redo();
      break;
    }
    case 'exportPNG': {
      graph.exportPNG('er-diagram.png');
      break;
    }
  }
});
```

---

## 5. File Loading Strategy

### How to Load the X6 Editor HTML

**Option A: Bundled HTML file (Recommended)**

Ship a folder alongside the app:

```
ModelToolkit.app
├── er-editor/
│   ├── index.html        ← the X6 editor page
│   ├── er-editor.js      ← X6 setup + bridge code
│   ├── bridge.js          ← cross-platform bridge
│   ├── er-table.js        ← custom ER node shape
│   ├── style.css          ← editor styling
│   └── lib/
│       ├── x6.min.js              ← @antv/x6 bundle
│       ├── x6-plugin-selection.js
│       ├── x6-plugin-history.js
│       ├── x6-plugin-snapline.js
│       ├── x6-plugin-minimap.js
│       ├── x6-plugin-keyboard.js
│       └── x6-plugin-export.js
```

```xojo
// Load the bundled editor
Var editorFolder As FolderItem = App.ExecutableFile.Parent.Child("er-editor")
Var indexFile As FolderItem = editorFolder.Child("index.html")

// Built-in HTMLViewer:
HTMLViewer1.LoadPage(indexFile)

// MBS WKWebView (better — allows local file access):
WKWebView1.LoadFileURL(indexFile, editorFolder)

// MBS WebView2 (Windows — virtual host avoids file:// issues):
WebView2Control1.SetVirtualHostNameToFolderMapping( _
  "er-editor.local", editorFolder.NativePath, 2)  // 2 = AllowAll
WebView2Control1.LoadURL("https://er-editor.local/index.html")
```

**Option B: Inline HTML (simpler, single file)**

```xojo
Var html As String = "" // Build or read from resource
HTMLViewer1.LoadPage(html, App.ExecutableFile.Parent)
```

Not recommended for X6 — too much JS to inline.

**Option C: CDN (requires internet)**

```html
<script src="https://unpkg.com/@antv/x6@3.1.6/dist/x6.js"></script>
```

Only for development/prototyping. Production should bundle locally.

---

## 6. X6 Plugins Needed for ER Editor

| Plugin | Package | Why |
|--------|---------|-----|
| **Selection** | `@antv/x6-plugin-selection` | Click to select tables, multi-select with rubber band |
| **History** | `@antv/x6-plugin-history` | Undo/redo for all operations |
| **Snapline** | `@antv/x6-plugin-snapline` | Alignment guides when dragging tables |
| **Keyboard** | `@antv/x6-plugin-keyboard` | Delete key, Ctrl+Z/Y, Ctrl+A |
| **MiniMap** | `@antv/x6-plugin-minimap` | Overview panel for large schemas |
| **Export** | `@antv/x6-plugin-export` | PNG/SVG export of diagram |
| **Transform** | `@antv/x6-plugin-transform` | Resize table nodes |

```javascript
import { Graph } from '@antv/x6'
import { Selection } from '@antv/x6-plugin-selection'
import { History } from '@antv/x6-plugin-history'
import { Snapline } from '@antv/x6-plugin-snapline'
import { Keyboard } from '@antv/x6-plugin-keyboard'
import { MiniMap } from '@antv/x6-plugin-minimap'
import { Export } from '@antv/x6-plugin-export'
import { Transform } from '@antv/x6-plugin-transform'

const graph = new Graph({
  container: document.getElementById('er-canvas'),
  grid: { visible: true, size: 10 },
  panning: { enabled: true, modifiers: [] },
  mousewheel: { enabled: true, factor: 1.1 },
  connecting: {
    snap: { radius: 30 },
    allowBlank: false,
    allowLoop: false,
    allowPort: true,
    router: { name: 'er' },          // Built-in ER orthogonal router!
    connector: { name: 'rounded' },
    createEdge() {
      return new Shape.Edge({
        attrs: { line: { stroke: '#5F95FF', strokeWidth: 1.5 } },
      })
    },
  },
})

graph.use(new Selection({ enabled: true, rubberband: true, showNodeSelectionBox: true }))
graph.use(new History({ enabled: true }))
graph.use(new Snapline({ enabled: true }))
graph.use(new Keyboard({ enabled: true }))
graph.use(new MiniMap({ container: document.getElementById('minimap'), width: 180, height: 120 }))
graph.use(new Export())
graph.use(new Transform({ resizing: { enabled: true } }))
```

---

## 7. Gaps and Challenges

### Gap 1: Parameter Type Limitation (Built-in HTMLViewer)

**Problem:** `executeInXojo()` only accepts strings and numbers — no booleans, arrays, objects.

**Solution:** Always serialize to JSON string:
```javascript
// Instead of: executeInXojo("nodeSelected", {id: "n1", name: "users"})
// Do:         executeInXojo("nodeSelected", JSON.stringify({id: "n1", name: "users"}))
```

Not needed with MBS — `postMessage()` handles any JSON-serializable value.

### Gap 2: No Pre-Load Script Injection (Built-in HTMLViewer)

**Problem:** Can't inject the bridge JS before the page loads. Must wait for `DocumentComplete`.

**Solution:** Either:
- Include bridge code directly in the HTML file (preferred)
- Or use MBS `addUserScript()` with `InjectionTimeAtDocumentStart`

### Gap 3: Cross-Platform WebView Differences

**Problem:** macOS uses `window.webkit.messageHandlers`, Windows uses `window.chrome.webview`, built-in uses `executeInXojo`.

**Solution:** The `bridge.js` abstraction layer (Section 3 above) auto-detects and unifies.

### Gap 4: X6 Bundle Size

**Problem:** @antv/x6 is ~8.5 MB unpacked (npm). Need to create a browser-ready bundle.

**Solution:** Use a bundler (esbuild/rollup) to tree-shake and produce a single `x6-er-bundle.js`:
```bash
# One-time build step
npx esbuild er-editor.js --bundle --minify --outfile=lib/x6-er-bundle.min.js --format=iife
```

Expected output: ~300-500 KB minified (X6 core + plugins used).

### Gap 5: X6 Documentation is Chinese-First

**Problem:** Best docs and examples are in Chinese.

**Solution:**
- English API reference exists at https://x6.antv.antgroup.com/en/api/graph/graph
- Browser translate works well for Chinese docs
- The API itself is English (method/property names)
- The ER diagram example is directly usable regardless of language

### Gap 6: Node Height Auto-Sizing

**Problem:** When columns are added/removed, the node height must change. X6 HTML nodes don't auto-size.

**Solution:** Calculate height from column count:
```javascript
function updateNodeSize(node) {
  const data = node.getData();
  const headerHeight = 32;
  const rowHeight = 24;
  const height = headerHeight + (data.columns.length * rowHeight) + 8;
  node.resize(240, height);
}
```

### Gap 7: Undo/Redo Sync Between X6 and Xojo

**Problem:** X6 has its own undo/redo stack (History plugin). Xojo property editor changes should participate.

**Solution:** All Xojo property changes go through X6 (via `nativeCommand`), which records them in X6's history. Xojo never modifies data directly — it always tells X6 to do it:
```
User edits in Xojo → ExecuteJavaScript → X6 updates → X6 history records → X6 fires change event → Xojo notified
```

---

## 8. Recommendation: Which WebView to Use

### For Phase 1 (Prototype)

**Use Xojo's built-in `DesktopHTMLViewer`.**

- Works immediately, no plugin purchase needed
- `JavaScriptRequest` + `executeInXojo()` is sufficient for the ER editor
- JSON-stringify everything — the string-only limitation is easy to work around
- Cross-platform out of the box

### For Phase 2+ (Production)

**Use MBS `WKWebViewControlMBS` (macOS) + `WebView2ControlMBS` (Windows).**

Benefits:
- `postMessage` is cleaner than `executeInXojo` — native JSON, no string-only hack
- `addUserScript` injects bridge code before page loads — no race conditions
- `developerExtrasEnabled` enables Web Inspector for debugging
- `allowFileAccessFromFileURLs` eliminates CORS headaches with local files
- Better error handling (`NSErrorMBS`)
- `SetVirtualHostNameToFolderMapping` (Windows) elegantly serves local files

Create a Xojo wrapper class that abstracts the platform difference:

```xojo
Class ERWebView
  // Wraps either MBS WKWebView or MBS WebView2
  // Provides: LoadEditor(), SendCommand(json), OnMessage(json) event
  // Internally dispatches to the right MBS control per platform
End Class
```

---

## 9. Summary: What to Build

| Layer | Technology | Status |
|-------|-----------|--------|
| ER Canvas | AntV X6 v3 + HTML custom nodes | MIT, proven for ER |
| JS Bridge | `bridge.js` auto-detecting platform | ~50 lines of JS |
| macOS WebView | Built-in HTMLViewer (v1) → MBS WKWebView (v2) | Available now |
| Windows WebView | Built-in HTMLViewer (v1) → MBS WebView2 (v2) | Available now |
| Property Editor | Native Xojo controls (TextField, ListBox, PopupMenu) | Standard Xojo |
| Data Format | JSON (graph.toJSON / graph.fromJSON) | X6 built-in |
| Undo/Redo | X6 History plugin (all changes flow through X6) | Plugin, MIT |
| Export | X6 Export plugin (PNG/SVG) | Plugin, MIT |
