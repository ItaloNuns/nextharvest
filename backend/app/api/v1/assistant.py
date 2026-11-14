from fastapi import APIRouter, Query

from app.schemas.rotation_models import GlossaryResponse

router = APIRouter()

_TERMS: dict[str, tuple[str, str]] = {
    "ndvi": (
        "NDVI compara o vermelho e o infravermelho próximo da planta. "
        "Quanto mais verde e ativo o dossel, maior o índice. Abaixo de cerca de 0,22 o talhão parece solo exposto ou palhada seca.",
        "O satélite vê o dossel por cima, numa célula de dezenas de metros. Uma visita ao talhão ou uma foto de campo confirma se o valor baixo é solo nu, palhada ou falha de plantio.",
    ),
    "evapotranspiracao": (
        "Evapotranspiração é a água que sai do talhão por evaporação do solo e pela transpiração das plantas, em milímetros, como uma chuva ao contrário.",
        "OpenET e ECOSTRESS estimam essa saída a partir de temperatura e reflectância. Um lisímetro ou a conta de irrigação da fazenda medem a água que de fato saiu daquele talhão.",
    ),
    "et": (
        "Evapotranspiração é a água que sai do talhão por evaporação do solo e pela transpiração das plantas, em milímetros, como uma chuva ao contrário.",
        "OpenET e ECOSTRESS estimam essa saída a partir de temperatura e reflectância. Um lisímetro ou a conta de irrigação da fazenda medem a água que de fato saiu daquele talhão.",
    ),
    "smap": (
        "A anomalia SMAP diz se a umidade do solo neste mês está acima ou abaixo do que é normal para o mesmo mês em anos anteriores, em desvios-padrão.",
        "O SMAP enxerga uma célula de quilômetros. Uma sonda no talhão, na profundidade da raiz, é o dado local que o satélite não substitui.",
    ),
    "smap anomaly": (
        "A anomalia SMAP diz se a umidade do solo neste mês está acima ou abaixo do que é normal para o mesmo mês em anos anteriores, em desvios-padrão.",
        "O SMAP enxerga uma célula de quilômetros. Uma sonda no talhão, na profundidade da raiz, é o dado local que o satélite não substitui.",
    ),
    "grupo hidrologico": (
        "O grupo hidrológico (A, B, C ou D) resume quão rápido a chuva infiltra. A drena bem; D escorre quase toda pela superfície.",
        "O SSURGO traz o grupo do mapa de solos. Um teste de infiltração no talhão confirma se o mapa ainda vale depois de compactação ou nivelamento.",
    ),
    "hydrologic group": (
        "O grupo hidrológico (A, B, C ou D) resume quão rápido a chuva infiltra. A drena bem; D escorre quase toda pela superfície.",
        "O SSURGO traz o grupo do mapa de solos. Um teste de infiltração no talhão confirma se o mapa ainda vale depois de compactação ou nivelamento.",
    ),
}

_UNKNOWN = (
    "Este termo ainda não está no glossário estático. O assistente com RAG entra na próxima fase.",
    "Satélite descreve a paisagem de longe. Análise de solo, sonda e o julgamento do agrônomo local continuam necessários antes do plantio.",
)


@router.get("/explain", response_model=GlossaryResponse)
async def explain_term(term: str = Query(min_length=1)) -> GlossaryResponse:
    explanation, satellite_vs_in_situ = _TERMS.get(term.strip().lower(), _UNKNOWN)
    return GlossaryResponse(
        term=term,
        explanation=explanation,
        satellite_vs_in_situ=satellite_vs_in_situ,
        placeholder=True,
    )
