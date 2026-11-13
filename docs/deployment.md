# Web Export & Deployment Guide (GitHub Pages & itch.io)

**Lunar Outpost: Mission 01** is configured for **Godot 4.x Single-Threaded Web Export** using the **Compatibility (`gl_compatibility`)** renderer.

Because single-threaded export (`variant/thread_support=false`) does **not** use `SharedArrayBuffer`, the game runs in any desktop or mobile browser on **GitHub Pages** and **itch.io** without needing custom `Cross-Origin-Opener-Policy` (COOP) or `Cross-Origin-Embedder-Policy` (COEP) headers.

---

## 1. Exporting to `export/web/`

### Option A: Using the Godot Editor (GUI)
1. Open the project (`project.godot`) in Godot 4.7.
2. If you have not installed the Web export templates yet, open **Editor → Manage Export Templates** and click **Download and Install**.
3. Open **Project → Export…** and select the **Web** preset:
   - **Export Path:** `export/web/index.html`
   - **Thread Support (`variant/thread_support`):** `Off` (`false`)
   - **Extensions Support (`variant/extensions_support`):** `Off` (`false`)
   - **Include Filter:** `*.json` (ensures `data/*.json` files are bundled into the `.pck`)
4. Click **Export Project…**, uncheck *Export With Debug* for a release build, and save to `export/web/index.html`.

### Option B: Using the Command Line (Headless)
From the project root:
```bash
mkdir -p export/web
godot --headless --path . --export-release "Web" export/web/index.html
```

This generates the web bundle inside `export/web/`:
- `index.html`
- `index.js`
- `index.wasm`
- `index.pck`
- `index.icon.png` / `index.apple-touch-icon.png`
- `index.audio.worklet.js` / `index.audio.position.worklet.js`

---

## 2. Testing Locally Before Deployment

Browsers block WebAssembly `.wasm` and `.pck` fetches over `file://` URLs. Serve `export/web/` over local HTTP:

```bash
python3 -m http.server 8000 --directory export/web
```

Then open `http://localhost:8000` in Chrome, Firefox, or Safari.

---

## 3. Deploying to GitHub Pages

1. Build the Web export into `export/web/` as shown above.
2. Add an empty `.nojekyll` file so GitHub Pages serves all generated files cleanly:
   ```bash
   touch export/web/.nojekyll
   ```
3. Push `export/web/` to a `gh-pages` branch:
   ```bash
   git checkout --orphan gh-pages
   git --work-tree=export/web add --all
   git --work-tree=export/web commit -m "Deploy Web build to GitHub Pages"
   git push origin HEAD:gh-pages --force
   git checkout feature/nasa-polish
   ```
4. On GitHub, open **Settings → Pages**:
   - Under **Build and deployment**, set **Source** to **Deploy from a branch**.
   - Select branch **`gh-pages`** and folder **`/ (root)`**, then click **Save**.
5. After 1–2 minutes, your game will be live at:
   `https://<username>.github.io/<repo-name>/`

---

## 4. Deploying to itch.io

1. Zip the contents of `export/web/` so that `index.html` is at the top level of the archive:
   ```bash
   cd export/web
   zip -r ../lunar_outpost_web.zip .
   ```
2. On [itch.io](https://itch.io), click **Create new project**:
   - **Kind of project:** select **HTML**.
   - Upload `lunar_outpost_web.zip` and check **"This file will be played in the browser"**.
   - **Viewport dimensions:** set `1280` × `720`.
   - Under **Frame options**, enable:
     - **Mobile friendly**
     - **Automatically start on page load**
     - **Fullscreen button**
   - Leave **SharedArrayBuffer support** unchecked (not needed for single-threaded builds).
3. Click **Save & view page** to play in the browser.

