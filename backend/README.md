# NextHarvest API

Backend do desafio Field Shift. Nesta fase o servidor sobe, valida os contratos e devolve exemplos estáticos. Os conectores NASA/USDA e o motor de rotação ainda não calculam nada.

## Subir

Na pasta `backend`:

```bash
docker compose up -d
cp .env.example .env
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn app.main:app --reload
```

A documentação interativa fica em [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs). O estado do Postgres e do Redis fica em [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health).

Se o banco ou o Redis não estiverem no ar, a API continua de pé e `/health` responde `degraded`. As rotas de análise não dependem deles ainda.

## Rotas

- `POST /api/v1/fields/analyze` — aceita o polígono e devolve um diagnóstico vazio
- `GET /api/v1/diagnostics/{field_id}` — série harmonizada ainda vazia
- `POST /api/v1/rotations/recommend` — três estratégias de exemplo (Churchill County, NV), com `placeholder: true`
- `POST /api/v1/rotations/simulate` — aceita chuva (−30% a +30%) e temperatura (0 a +4 °C) e devolve os mesmos scores
- `GET /api/v1/glossary/explain?term=NDVI` — glossário estático

As chaves em `.env` (`NASS_API_KEY`, `AMS_API_KEY`, `OPENET_API_KEY`, `GEMINI_API_KEY`, Earthdata) ficam vazias até o conector correspondente ser implementado.
