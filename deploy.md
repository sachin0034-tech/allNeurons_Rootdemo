# Deployment Guide — Roots Analytics (Streamlit)

## Prerequisites

- Python 3.10+
- A GitHub account (Streamlit Cloud deploys directly from a repo)
- Snowflake account with `RETAIL_ANALYTICS.CORE` schema loaded (run `fresh_dataset.SQL` + `june_2026_extension.SQL`)
- *(Optional)* Anthropic API key for AI-generated deck narratives — the app falls back to static templates without it

---

## 1. Local Development

```bash
# Clone and install
git clone <your-repo-url>
cd allNeurons_Rootdemo
pip install -r requirements.txt

# Configure credentials (already gitignored — never commit this file)
cp .streamlit/secrets.toml.example .streamlit/secrets.toml   # if example exists
# then edit .streamlit/secrets.toml — see "Secrets" section below

# Run
streamlit run Home.py
```

App will be available at `http://localhost:8501`.

---

## 2. Deploy to Streamlit Community Cloud

### Step 1 — Push to GitHub

Make sure `.streamlit/secrets.toml` is listed in `.gitignore` (it already is).  
Push everything else:

```bash
git add .
git commit -m "initial deploy"
git push origin main
```

### Step 2 — Connect your repo

1. Go to **[share.streamlit.io](https://share.streamlit.io)** and sign in with GitHub.
2. Click **"New app"**.
3. Select your repository and branch (`main`).
4. Set **Main file path** to `Home.py`.
5. Click **"Advanced settings"** before deploying — you must add secrets here.

### Step 3 — Add secrets

In the **Secrets** text box (Advanced settings → Secrets), paste and fill in:

```toml
SNOWFLAKE_ACCOUNT  = "your-account-identifier"   # e.g. LUMNPAC-EF71075
SNOWFLAKE_USER     = "your-username"
SNOWFLAKE_PASSWORD = "your-password"

# Optional — enables Claude AI narratives in the deck builder
# Without this key the app still works using template-based text
ANTHROPIC_API_KEY  = "sk-ant-..."
```

> The app also hardcodes `warehouse = "COMPUTE_WH"`, `database = "RETAIL_ANALYTICS"`, and `schema = "CORE"` in `utils/snowflake_conn.py`. Update those values there if your Snowflake setup differs.

### Step 4 — Deploy

Click **"Deploy"**. Streamlit installs `requirements.txt` automatically and starts the app. First boot takes ~60–90 seconds.

Your app URL will be:
```
https://<your-github-handle>-<repo-name>-<hash>.streamlit.app
```

---

## 3. Updating the App

Push any commit to `main` — Streamlit Cloud redeploys automatically.

To update secrets without redeploying code: go to your app's **⋮ menu → Settings → Secrets**, edit, and click **Save**. The app restarts automatically.

---

## 4. Local Secrets Reference

`.streamlit/secrets.toml` (gitignored — local only):

```toml
SNOWFLAKE_ACCOUNT  = "..."
SNOWFLAKE_USER     = "..."
SNOWFLAKE_PASSWORD = "..."
ANTHROPIC_API_KEY  = "..."   # optional
```

---

## 5. Project Structure

```
Home.py                        # entry point / homepage
pages/
  1_Claude_Skill.py            # AI deck generator
utils/
  snowflake_conn.py            # Snowflake connection + query runner
  queries.py                   # all SQL view queries
  narrative.py                 # Claude API narrative generator (with fallback)
  deck_builder_light.py        # PowerPoint assembly
  formatters.py / styles.py    # UI helpers
.streamlit/
  config.toml                  # theme + server config (committed)
  secrets.toml                 # credentials (gitignored — never commit)
requirements.txt
fresh_dataset.SQL              # Snowflake schema + Jan–May data seed
june_2026_extension.SQL        # June 2026 data patch
```

---

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| `250001: Could not connect to Snowflake backend` | Check `SNOWFLAKE_ACCOUNT` format — should be `ORG-ACCOUNT` (no `.snowflakecomputing.com`) |
| `Warehouse not found` | Ensure `COMPUTE_WH` exists and the user has `USAGE` privilege on it |
| App loads but charts are empty | Run `fresh_dataset.SQL` (and `june_2026_extension.SQL`) in Snowflake first |
| Deck generates but no AI text | `ANTHROPIC_API_KEY` is missing or invalid — app uses template fallback, which is expected |
| `ModuleNotFoundError` on deploy | Check `requirements.txt` is in the repo root and committed |
