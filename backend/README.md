# NextHarvest API

Backend do desafio Field Shift. `POST /api/v1/fields/analyze` salva o talhão no PostGIS e monta um diagnóstico com **NASA POWER** (clima no centroide) e **USDA SSURGO** (solo no polígono). Rotação, Gemini e OpenET ainda não entram.

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

Documentação: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs). Saúde: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health).

## Relatório desta feat (Fase 1–2)

| Etapa | O que foi implementado | Como testar |
| :--- | :--- | :--- |
| 1. Geo | `app/geo.py`: centroide `(lat, lon)` e WKT a partir de Polygon/Feature | `pytest tests/test_geo.py` (sem internet) |
| 2. NASA POWER | `NasaPowerClient.fetch_point` soma `PRECTOTCORR` do último ano e ignora fill `-999` | `pytest tests/test_nasa_power.py` (mock). Ao vivo: `NEXTHARVEST_LIVE=1 pytest tests/test_nasa_power.py -m live` |
| 3. USDA SDA | `UsdaSdaSoilsClient.fetch_polygon` consulta SSURGO; fora dos EUA devolve perfil vazio, não 500 | `pytest tests/test_usda_sda.py`. Ao vivo: `NEXTHARVEST_LIVE=1 pytest tests/test_usda_sda.py -m live` |
| 4. Harmonizer | `GeoHarmonizerService.summarize` chama POWER e SDA em paralelo; uma falha não derruba a outra | `pytest tests/test_harmonizer.py` |
| 5. Analyze | `POST /api/v1/fields/analyze` persiste geometria + `last_summary`; `placeholder=false` só se clima **e** solo ok | `pytest tests/test_analyze_route.py` ou o POST no `/docs` com o polígono Nevada |
| 6. Diagnostics | `GET /api/v1/diagnostics/{field_id}` lê o resumo gravado (404 se o id não existir) | Analyze → copiar `field_id` → GET diagnostics |

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

Pronto quando: `placeholder` é `false`, `annual_precip_mm` ≠ 0, `soil_profile.mapunit_name` não vazio, e `GET /diagnostics/{field_id}` devolve o mesmo resumo. Conferência no banco:

```bash
docker compose exec postgres psql -U nextharvest -d nextharvest -c "SELECT id, name FROM fields;"
```

## Rotas

- `POST /api/v1/fields/analyze` — diagnóstico real (POWER + SSURGO) e persistência
- `GET /api/v1/diagnostics/{field_id}` — resumo persistido
- `POST /api/v1/rotations/recommend` — ainda exemplo estático (`placeholder: true`)
- `POST /api/v1/rotations/simulate` — ainda exemplo estático
- `GET /api/v1/glossary/explain?term=NDVI` — glossário estático

Chaves em `.env` (`NASS_API_KEY`, `AMS_API_KEY`, `OPENET_API_KEY`, `GEMINI_API_KEY`, Earthdata) ficam vazias até o conector correspondente ser implementado.
