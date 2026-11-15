# NextHarvest API

**Space Apps overview:** see the [repository root README](../README.md) for the public project link, challenge mapping, and quick start.

Field Shift challenge backend. Register at `POST /api/v1/auth/register`, send **Bearer token** on field routes. `POST /api/v1/fields/analyze` saves the field in PostGIS and builds a diagnosis with **NASA POWER** (climate at centroid), **USDA SSURGO** (soil), and **OpenET** (ET when keyed). `POST /api/v1/rotations/recommend` returns **3 rotations** (template explanations; with `OPENAI_API_KEY`, text is rewritten with RAG). `POST /api/v1/rotations/simulate` recalculates scores with rainfall and temperature sliders. AMS and Gemini are not wired yet.

## Run locally

From `backend/`:

```bash
docker compose up -d
cp .env.example .env
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --reload
```

Docker Compose publishes Postgres on **5433** (avoids conflict with a local Postgres on 5432). Confirm `DATABASE_URL` in `.env` uses that port.

`.env` lives in `backend/` (not the repo root). The app loads that path automatically; you can run uvicorn from `backend/` or the repo root if `app` is on `PYTHONPATH` (e.g. `pip install -e .` from `backend/`). Prefer `cd backend` before starting the server to avoid DB/key confusion.

Docs: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs). Health: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health). Route guide: [API_ROTAS.md](API_ROTAS.md) (English).

### Auth (Swagger)

1. `POST /api/v1/auth/register` with `name`, `farmer@example.com` / `password1` (or `POST /auth/login` if the user exists).
2. Copy `access_token`.
3. Click **Authorize**, paste the token (value only, or `Bearer <token>` per the field) and confirm.
4. Analyze → Recommend → Simulate only see fields for **that** user. Legacy fields without `user_id` are hidden.

The Flutter app should store the token and send `Authorization: Bearer <token>` on analyze, diagnostics, recommend, simulate, and latest simulation.

## Phase 1–2 report

| Step | Implemented | How to test |
| :--- | :--- | :--- |
| 1. Geo | `app/geo.py`: centroid `(lat, lon)` and WKT from Polygon/Feature | `pytest tests/test_geo.py` |
| 2. NASA POWER | `NasaPowerClient.fetch_point` sums last-year `PRECTOTCORR`, ignores `-999` | `pytest tests/test_nasa_power.py`. Live: `NEXTHARVEST_LIVE=1 pytest tests/test_nasa_power.py -m live` |
| 3. USDA SDA | `UsdaSdaSoilsClient.fetch_polygon` queries SSURGO; outside US returns empty profile, not 500 | `pytest tests/test_usda_sda.py`. Live: `NEXTHARVEST_LIVE=1 pytest tests/test_usda_sda.py -m live` |
| 4. Harmonizer | `GeoHarmonizerService.summarize` calls POWER and SDA in parallel; GWETROOT proxy for Z and bare months | `pytest tests/test_harmonizer.py` |
| 5. Analyze | `POST /api/v1/fields/analyze` persists geometry + `last_summary` + `last_analysis_meta`; `placeholder=false` only if climate **and** soil OK | `pytest tests/test_analyze_route.py` or POST in `/docs` with Nevada polygon |
| 6. Diagnostics | `GET /api/v1/diagnostics/{field_id}` reads stored summary, derives `health` and `analysis_meta` | Analyze → copy `field_id` → GET diagnostics |

## Phase 3 — Recommend

| Step | Implemented | How to test |
| :--- | :--- | :--- |
| 1. Catalog | `crop_catalog.py`: crops, sequences, aliases (`Alfafa` → `alfalfa`) | `pytest tests/test_crop_catalog.py` |
| 2. Scoring | `score_sequence` uses rain + SSURGO + catalog (no invented ET/SMAP) | `pytest tests/test_rotation_scoring.py` |
| 3. Ranking | 3 strategies: current, water resilience, soil/priorities (TOPSIS) | `pytest tests/test_rotation_engine.py` |
| 4. Text | 5 explanation fields with real field numbers | `pytest tests/test_explanation_templates.py` |
| 5. Route | `POST /rotations/recommend` reads field; `404` / `409` / `503` like diagnostics | `pytest tests/test_recommend_route.py` |

## Phase 4–5 — OpenET, NASS, Simulate

| Step | Implemented | How to test |
| :--- | :--- | :--- |
| 1. POWER ET | `EVPTRNS` summed as ET fallback | `pytest tests/test_nasa_power.py` |
| 2. OpenET | `OpenEtClient` on polygon (point fallback); 60s timeout + retry on 429/502/503 | `pytest tests/test_openet.py`. Live: `NEXTHARVEST_LIVE=1 pytest tests/test_openet.py -m live` |
| 3. Harmonizer | Prefers OpenET; else POWER; analyze persists deficit | `pytest tests/test_harmonizer.py tests/test_analyze_route.py` |
| 4. County + NASS | FCC Census (no key) + QuickStats if `NASS_API_KEY` | `pytest tests/test_census_location.py tests/test_nass.py` |
| 5. Recommend | `state`/`county`, `nass_used`, honest ET/NASS text | `pytest tests/test_recommend_route.py` |
| 6. Simulate | Radar with `delta_precip_pct` / `delta_temp_c`; optional `priorities`; `GET .../simulations/latest` | `pytest tests/test_simulate_route.py` |

## OpenAI / RAG on Recommend

| Step | Implemented | How to test |
| :--- | :--- | :--- |
| 1. RAG | `agronomic_rag.py`: 5 NRCS/FAO/NASA snippets, tag overlap | `pytest tests/test_agronomic_rag.py` |
| 2. Explainer | `AiExplainer` rewrites 5 fields via OpenAI; template fallback | `pytest tests/test_ai_explainer.py` |
| 3. Route | Recommend calls explainer when `OPENAI_API_KEY` is set | Recommend in `/docs` with Bearer |

Full suite (mocked):

```bash
pytest
```

Live calls (Nevada, Churchill County):

```bash
NEXTHARVEST_LIVE=1 pytest -m live
```

### Demo polygon (Swagger)

```json
{
  "name": "Nevada Alfalfa",
  "current_crop": "Alfafa",
  "geometry": {
    "type": "Polygon",
    "coordinates": [[
      [-118.78, 39.47],
      [-118.77, 39.47],
      [-118.77, 39.48],
      [-118.78, 39.48],
      [-118.78, 39.47]
    ]]
  }
}
```

**Analyze ready when:** `placeholder` is `false`, `annual_precip_mm` ≠ 0, `soil_profile.mapunit_name` non-empty, `health` filled, `analysis_meta.et_source` is `openet` (with key) or `power`, and `GET /diagnostics/{field_id}` matches analyze.

### Recommend (Swagger)

After analyze, copy `field_id` and POST priorities (see OpenAPI example **nevada_demo**).

**Recommend ready when:** `placeholder` is `false`, **3 strategies**, first is baseline, same `annual_precip_mm` as diagnostics. With OpenET key, `annual_et_demand_mm` ≠ 0. With FCC, `location.county` set (e.g. Churchill). With `NASS_API_KEY`, `nass_used` is `true`.

### Simulate (Swagger)

Use the same **priorities** as recommend in the app. In Swagger, pick **nevada_demo** and replace `field_id`.

**Simulate ready when:** baseline radar changes with −25% rain / +2 °C vs recommend. `GET .../simulations/latest` returns the last `delta_*`.

### Before demo

1. Set `OPENET_API_KEY` and `NASS_API_KEY` in `backend/.env` (do not commit).
2. Restart uvicorn after `.env` changes.
3. Re-run **analyze** on demo fields to refresh `analysis_meta`.
4. Nevada polygon: `et_source=openet`; recommend with `nass_used=true`.

## Routes

- `POST /api/v1/auth/register` — name + email + password (min 8); returns JWT
- `POST /api/v1/auth/login` — same contract
- `GET /api/v1/auth/me` — user from token
- `GET /api/v1/fields/` — logged-in user's fields
- `DELETE /api/v1/fields/{field_id}` — owner delete + simulation cascade (**Bearer**); **204**
- `POST /api/v1/fields/analyze` — POWER + SSURGO + OpenET; `health` + `analysis_meta` (**Bearer**)
- `GET /api/v1/diagnostics/{field_id}` — stored summary + `health` + `analysis_meta` (**Bearer**, owner)
- `GET /api/v1/fields/{field_id}/simulations/latest` — last simulate; 404 if none (**Bearer**, owner)
- `POST /api/v1/rotations/recommend` — 3 rotations; FCC county; `nass_used`; OpenAI if keyed (**Bearer**)
- `POST /api/v1/rotations/simulate` — climate sliders; optional `priorities` (**Bearer**)
- `GET /api/v1/glossary/explain?term=NDVI` — static glossary (public)

`.env` keys: `OPENET_API_KEY`, `NASS_API_KEY`, optional `OPENAI_API_KEY` (`OPENAI_MODEL` default `gpt-4o-mini`). Recommend `message` includes **Explanations enriched with OpenAI** when the LLM ran.