# NextHarvest API

**Space Apps overview (English):** see the [repository root README](../README.md) for the public project link, challenge mapping, and quick start.

Backend do desafio Field Shift. Cadastre-se em `POST /api/v1/auth/register`, envie o **Bearer token** nas rotas de talhão. `POST /api/v1/fields/analyze` salva o talhão no PostGIS e monta um diagnóstico com **NASA POWER** (clima no centroide), **USDA SSURGO** (solo) e **OpenET** (ET, se houver chave). `POST /api/v1/rotations/recommend` devolve **3 rotações** (explicações via templates; com `OPENAI_API_KEY`, o texto é reescrito com RAG). `POST /api/v1/rotations/simulate` recalcula os scores com sliders de chuva e temperatura. AMS e Gemini ainda não entram.

## Subir

Na pasta `backend`:

```bash
docker compose up -d
cp .env.example .env
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --reload
```

O compose publica o Postgres em **5433** (evita conflito com um Postgres local na 5432). Confirme `DATABASE_URL` no `.env` com essa porta.

O arquivo `.env` fica em `backend/` (não na raiz do repositório). O app carrega esse caminho automaticamente; você pode rodar o uvicorn a partir de `backend/` ou da raiz do repo, desde que o pacote `app` esteja no `PYTHONPATH` (ex.: `pip install -e .` a partir de `backend/`). Para evitar confusão com banco ou chaves, prefira `cd backend` antes de subir o servidor.

Documentação: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs). Saúde: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health). Guia das rotas (entregas e fluxo do app): [API_ROTAS.md](API_ROTAS.md).

### Auth (Swagger)

1. `POST /api/v1/auth/register` com `name`, `farmer@example.com` / `password1` (ou `POST /auth/login` se já existir).
2. Copie `access_token`.
3. Clique em **Authorize**, cole o token (só o valor, ou `Bearer <token>` conforme o campo) e confirme.
4. Analyze → Recommend → Simulate usam só os talhões **desse** usuário. Talhões antigos sem `user_id` ficam invisíveis.

O app Flutter deve guardar o token e mandar `Authorization: Bearer <token>` em analyze, diagnostics, recommend, simulate e na última simulação.

## Relatório desta feat (Fase 1–2)

| Etapa | O que foi implementado | Como testar |
| :--- | :--- | :--- |
| 1. Geo | `app/geo.py`: centroide `(lat, lon)` e WKT a partir de Polygon/Feature | `pytest tests/test_geo.py` (sem internet) |
| 2. NASA POWER | `NasaPowerClient.fetch_point` soma `PRECTOTCORR` do último ano e ignora fill `-999` | `pytest tests/test_nasa_power.py` (mock). Ao vivo: `NEXTHARVEST_LIVE=1 pytest tests/test_nasa_power.py -m live` |
| 3. USDA SDA | `UsdaSdaSoilsClient.fetch_polygon` consulta SSURGO; fora dos EUA devolve perfil vazio, não 500 | `pytest tests/test_usda_sda.py`. Ao vivo: `NEXTHARVEST_LIVE=1 pytest tests/test_usda_sda.py -m live` |
| 4. Harmonizer | `GeoHarmonizerService.summarize` chama POWER e SDA em paralelo; uma falha não derruba a outra; GWETROOT preenche Z e meses de solo nu (proxy) | `pytest tests/test_harmonizer.py` |
| 5. Analyze | `POST /api/v1/fields/analyze` persiste geometria + `last_summary` + `last_analysis_meta`; JSON inclui `analysis_meta`; `placeholder=false` só se clima **e** solo ok | `pytest tests/test_analyze_route.py` ou o POST no `/docs` com o polígono Nevada |
| 6. Diagnostics | `GET /api/v1/diagnostics/{field_id}` lê o resumo gravado, deriva `health` e devolve o mesmo `analysis_meta` | Analyze → copiar `field_id` → GET diagnostics |

## Relatório desta feat (Fase 3 — Recommend)

| Etapa | O que foi implementado | Como testar |
| :--- | :--- | :--- |
| 1. Catálogo | `app/services/crop_catalog.py`: culturas, sequências e apelidos (`Alfafa` → `alfalfa`) | `pytest tests/test_crop_catalog.py` |
| 2. Notas | `score_sequence` usa chuva + solo SSURGO + catálogo (sem ET/SMAP inventados) | `pytest tests/test_rotation_scoring.py` |
| 3. Ranking | 3 estratégias: atual, resiliência hídrica, solo/prioridades (TOPSIS) | `pytest tests/test_rotation_engine.py` |
| 4. Textos | 5 campos de explicação com números reais do talhão, sem Gemini | `pytest tests/test_explanation_templates.py` |
| 5. Rota | `POST /rotations/recommend` lê o talhão; `404` / `409` / `503` como no diagnostics | `pytest tests/test_recommend_route.py` ou o POST no `/docs` |

## Relatório desta feat (Fase 4–5 — OpenET, NASS, Simulate)

| Etapa | O que foi implementado | Como testar |
| :--- | :--- | :--- |
| 1. POWER ET | `EVPTRNS` somado como reserva de ET anual | `pytest tests/test_nasa_power.py` |
| 2. OpenET | `OpenEtClient` no polígono (fallback ponto); timeout 60s e um retry em 429/502/503; chave em `OPENET_API_KEY` | `pytest tests/test_openet.py`. Ao vivo: `NEXTHARVEST_LIVE=1 pytest tests/test_openet.py -m live` |
| 3. Harmonizer | Prefere OpenET; se falhar, usa POWER; Analyze persiste o déficit | `pytest tests/test_harmonizer.py tests/test_analyze_route.py` |
| 4. Condado + NASS | FCC Census (sem chave) + QuickStats se `NASS_API_KEY` | `pytest tests/test_census_location.py tests/test_nass.py` |
| 5. Recommend | `state`/`county`, `nass_used` no JSON, textos com ET/NASS honestos | `pytest tests/test_recommend_route.py` |
| 6. Simulate | Recalcula radar com `delta_precip_pct` e `delta_temp_c`; `priorities` opcional na API (perfil demo se omitir); `GET /fields/{id}/simulations/latest` | `pytest tests/test_simulate_route.py` |

## Relatório desta feat (IA / RAG — OpenAI no Recommend)

| Etapa | O que foi implementado | Como testar |
| :--- | :--- | :--- |
| 1. RAG | `agronomic_rag.py`: 5 snippets NRCS/FAO/NASA, overlap de tags | `pytest tests/test_agronomic_rag.py` |
| 2. Explainer | `AiExplainer` reescreve os 5 campos com OpenAI; fallback nos templates | `pytest tests/test_ai_explainer.py` |
| 3. Rota | `POST /rotations/recommend` chama o explainer se `OPENAI_API_KEY` existir | Recommend no `/docs` com Bearer; sem chave o texto continua o de template |

Suite completa (mocks, sem NASA/USDA reais):

```bash
pytest
```

Chamadas reais (Nevada, Churchill County):

```bash
NEXTHARVEST_LIVE=1 pytest -m live
```

### Polígono demo (Swagger)

```json
{
  "name": "Alfafa Nevada",
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

Pronto quando (Analyze): `placeholder` é `false`, `annual_precip_mm` ≠ 0, `soil_profile.mapunit_name` não vazio, `health.overall` e `health.dimensions` preenchidos, `analysis_meta.et_source` é `openet` (com chave) ou `power`, e `GET /diagnostics/{field_id}` devolve o mesmo resumo, o mesmo `health.overall` e o mesmo `analysis_meta`. Conferência no banco:

```bash
docker compose exec postgres psql -U nextharvest -d nextharvest -c "SELECT id, name FROM fields;"
```

### Recommend (Swagger)

Depois do Analyze, copie o `field_id` e envie:

```json
{
  "field_id": "fld_cole_o_id_aqui",
  "priorities": {
    "water_savings": 5,
    "soil_organic_matter": 3,
    "erosion_control": 4,
    "pest_cycle_break": 3,
    "forage_value": 2,
    "market_income": 3,
    "has_irrigation": false,
    "machinery": []
  }
}
```

Pronto quando (Recommend): `placeholder` é `false`, há **3 estratégias**, a primeira é a baseline da cultura atual, e `harmonized_summary.annual_precip_mm` é o mesmo do diagnostics daquele `field_id`. Com chave OpenET, `annual_et_demand_mm` ≠ 0. Com FCC, `location.county` preenchido (ex.: Churchill). Com `NASS_API_KEY`, `nass_used` é `true`.

### Simulate (Swagger)

No **app**, reenvie as **mesmas prioridades** do recommend. No **Swagger** (`/docs`), escolha o exemplo **nevada_demo** no POST simulate (ou recommend) — o body já vem com `priorities` preenchido; basta trocar o `field_id`.

Corpo completo (equivalente ao exemplo):

```json
{
  "field_id": "fld_cole_o_id_aqui",
  "delta_precip_pct": -25,
  "delta_temp_c": 2,
  "priorities": {
    "water_savings": 5,
    "soil_organic_matter": 3,
    "erosion_control": 4,
    "pest_cycle_break": 3,
    "forage_value": 2,
    "market_income": 3,
    "has_irrigation": false,
    "machinery": []
  }
}
```

Pronto quando (Simulate): `placeholder` é `false` e o radar da baseline muda com chuva −25% / +2 °C em relação ao recommend. `GET /api/v1/fields/{field_id}/simulations/latest` devolve os mesmos `delta_*` do último POST.

### Antes do demo

1. Confirme `OPENET_API_KEY` e `NASS_API_KEY` em `backend/.env` (não commite o arquivo).
2. Reinicie o uvicorn depois de mudar o `.env`.
3. Rode **analyze de novo** nos talhões da demo para gravar `analysis_meta` (talhões antigos não inventam `et_source=openet`).
4. No Swagger, no polígono Nevada: analyze com `analysis_meta.et_source` = `openet`; recommend com `nass_used` = `true`.

## Rotas

- `POST /api/v1/auth/register` — nome + email + senha (mín. 8); devolve JWT
- `POST /api/v1/auth/login` — mesmo contrato
- `GET /api/v1/auth/me` — usuário do token
- `GET /api/v1/fields/` — talhões do usuário logado
- `POST /api/v1/fields/analyze` — POWER + SSURGO + OpenET (se houver chave) e persistência; `health` + `analysis_meta` (`et_source`, `failures`) (**Bearer**)
- `GET /api/v1/diagnostics/{field_id}` — resumo persistido + o mesmo `health` e `analysis_meta` (**Bearer**, só o dono)
- `GET /api/v1/fields/{field_id}/simulations/latest` — último simulate gravado (`id`, `created_at`, `simulation`); 404 se ainda não houver (**Bearer**, só o dono)
- `POST /api/v1/rotations/recommend` — 3 rotações; condado via FCC; `nass_used` se QuickStats respondeu; OpenAI nas explicações se `OPENAI_API_KEY` (**Bearer**)
- `POST /api/v1/rotations/simulate` — sliders de chuva/temperatura; envie `priorities` no app; na API, omitir usa o demo Nevada (**Bearer**)
- `GET /api/v1/glossary/explain?term=NDVI` — glossário estático (público)

Chaves em `.env`: `OPENET_API_KEY` e `NASS_API_KEY` ligam ET e mercado. `OPENAI_API_KEY` (opcional, modelo `OPENAI_MODEL` default `gpt-4o-mini`) reescreve as explicações do Recommend; sem chave ou se a API falhar, usam-se os templates. `AMS_API_KEY` e `GEMINI_API_KEY` ainda não são usadas. Sem chave, Analyze/Recommend degradam (ET via POWER ou mercado do catálogo).

Para confirmar que o OpenAI rodou no Recommend, veja o campo `message` da resposta: deve incluir **Explicações enriquecidas com OpenAI**. Se não aparecer, confira `OPENAI_API_KEY` em `backend/.env`, reinicie o uvicorn e olhe os logs do logger `nextharvest.explainer` (skip sem chave, warning se o parse vier vazio).
