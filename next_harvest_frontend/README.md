# next_harvest_frontend

A new Flutter project.

## Configuração do ambiente

Copie `.env.example` para `.env` na raiz do frontend e ajuste `API_BASE_URL`.
O `.env` local é ignorado pelo Git e carregado por `flutter_dotenv` em `main()`
antes da criação do `ProviderScope`. O `dioProvider` utiliza essa URL.

```dotenv
API_BASE_URL=http://localhost:8000
AREA_CREATE_PATH=/api/v1/fields/analyze
```

No emulador Android, use `http://10.0.2.2:8000` para acessar o backend na máquina
de desenvolvimento. Após alterar o `.env`, reinicie o app. Em novos checkouts e
no CI, crie o `.env` antes de executar testes ou builds, pois ele é um asset.

Use o arquivo para configurações públicas do cliente, como a URL da API.

## Desenhar e enviar uma área

No mapa, escolha **Desenhar área**. Cada toque adiciona um vértice; tocar em um
vértice abre a opção de exclusão. Arrastar um vértice move somente esse ponto.
O preenchimento é amarelo com opacidade de 50%. A linha tracejada antecipa o
fechamento enquanto o desenho ainda está aberto.

Para fechar, toque no primeiro ponto e escolha **Fechar área**, ou use o botão
de fechar. São necessários três vértices distintos, área não nula e contorno
sem cruzamentos ou sobreposição de arestas. Depois informe nome e cultura atual
no formulário e escolha **Enviar área**. Editar um contorno fechado o reabre;
é preciso fechá-lo novamente antes do envio.

O POST usa `API_BASE_URL` e `AREA_CREATE_PATH`, configurado como `/api/v1/fields/analyze`. O Android debug
permite HTTP para o backend de desenvolvimento; a variante release não foi
alterada. Após alterar o manifest, reinicie a execução do app.

O corpo segue exatamente a estrutura solicitada:

```json
{
  "current_crop": "Alfafa",
  "geometry": {
    "type": "Polygon",
    "coordinates": [[
      [-118.78, 39.47], [-118.77, 39.47], [-118.77, 39.48],
      [-118.78, 39.48], [-118.78, 39.47]
    ]]
  },
  "name": "Alfafa Nevada"
}
```

As coordenadas são WGS84, em longitude/latitude, com o primeiro ponto repetido
uma única vez no fim do anel. O anel externo é normalizado em sentido
anti-horário. O editor não mantém um vértice duplicado de fechamento. Uma área
contém um único polígono, sem buracos. Nenhuma requisição de envio acontece ao
adicionar, arrastar, excluir ou apenas fechar os pontos; o envio ocorre após o
formulário de um polígono válido e fechado. Durante o envio, edições e envios
duplicados são bloqueados. Em falha, desenho, nome e cultura são preservados.

O sucesso indica que a API recebeu a requisição com resposta 2xx; o frontend
não presume armazenamento local nem apresenta a análise agronômica retornada
nesta etapa. A resposta HTTP permanece disponível nos logs Dio em debug.

A feature `lib/features/areas/` segue MVVM + Repository + Dio + Riverpod, com
models, state, providers, viewmodel, view e contrato/implementação de repository.
Os testes cobrem o payload, validação geométrica, envio somente depois de
fechado, bloqueio de duplicação, recuperação de falhas, toques e arraste no mapa
e formulário. O teste HTTP usa um adapter controlado e não cria áreas reais.

## Mapa com imagem aérea e Sentinel-2

A tela inicial usa flutter_map. O botão de camadas permite alternar entre imagem aérea detalhada e o mosaico anual **Sentinel-2 Cloudless 2025**,
processado pela EOX com imagens Copernicus Sentinel-2 de 10 m. Nuvens são
reduzidas no processamento do produto, antes de gerar os tiles. Não se trata de
uma simples sobreposição de dias no aplicativo; não há garantia de ausência
total de artefatos, neve ou áreas sem dados.

O painel indica janeiro a dezembro de 2025. O mosaico é uma base histórica para
localizar talhões, sem representar a safra atual nem uma aquisição diária. Não
há seletor diário para este produto anual. A data diária e a sobreposição HLS de
sete dias foram removidas.

A imagem aérea USDA NAIP é a opção inicial, em zoom 17, com limite 19. Ela reúne ortofotos NAIP, com resolução variável, geralmente de 30 cm a 1 m por local. As datas variam espacialmente; a data de atualização do serviço não é a data de captura. O zoom alto não garante detalhe uniforme. O mosaico não representa necessariamente a safra atual.

Ao escolher Sentinel-2, o limite é 14. O nível
máximo fica limitado à resolução útil do produto, mesmo que a grade WMTS comum
anuncie níveis maiores. O recorte é retangular e inclui partes de países vizinhos.

A feature segue MVVM + Repository + Dio + Riverpod em `lib/features/map/`:
models, repositories (contrato e implementação), providers, state, viewmodel e
view. O repository consulta metadados JSON do USDA ou o catálogo WMTS da EOX com o Dio compartilhado. Os
tiles JPEG são carregados diretamente pelo flutter_map. A opção aérea usa exportImage do USDA com BBOX determinístico em EPSG:3857, JPEG RGB (bandIds=0,1,2) e recortes de 256x256 pixels. O WMS USGS NAIP Plus foi substituído após medições de cerca de 11 s por tile; o USDA respondeu em cerca de 1 s nas amostras consultadas. Esses tempos dependem da rede, região e disponibilidade do serviço. Não usa o cache USGSImageryOnly, cujos tiles em zoom alto podem não existir. As URLs são HTTPS. Metadados de cada fonte são reutilizados durante a sessão; trocar a fonte mantém a posição, ajusta o zoom ao limite e preserva a camada atual em caso de falha.
`API_BASE_URL` continua reservada ao backend; este serviço público dispensa chave.
Os logs debug usam `[DIO]`, `[MAP]`, `[SENTINEL MAP]` e `[MAP TILE]` (incluindo a URL completa quando um tile falha).

### Carregamento e cache

A orientação territorial usa a camada transparente **World Boundaries and
Places**, da Esri, sobre ambas as imagens: estados, condados e nomes de
localidades. O desenho e a densidade dos rótulos variam com o zoom. Essa camada
não adiciona vias nem define limites de propriedades rurais. A chave
independente da sobreposição evita refazer os tiles de referência quando se
alterna a imagem aérea e o Sentinel-2.

O botão de camadas inclui **Nomes e limites**, habilitado inicialmente. O estado
e os erros das referências ficam no ViewModel, separados da imagem. Ocultar,
mostrar ou repetir referências não recarrega a imagem. Se a sobreposição falha,
a imagem continua disponível e há uma ação própria para repetir.

Os tiles de referência são PNGs transparentes pré-renderizados, restritos à
mesma área de navegação dos EUA, com cache temporário de sete dias e atualizações
após 200 ms sem movimento. Não há download em massa nem exportação offline.
A atribuição da Esri e dos provedores fica visível no mapa enquanto a camada
está habilitada e também no painel de informações.

- Serviço: https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer
- Item e termos: https://www.arcgis.com/home/item.html?id=a842e359856a4365b1ddf8cc34fde079
- Crédito: Esri, HERE, Garmin, © OpenStreetMap contributors, and the GIS user community

`MapTileProvider` mantém o cliente HTTP durante a vida do TileLayer, permite
cancelar tiles obsoletos e configura cache em disco por sete dias, sem downloads
em massa. A validade explícita substitui o fallback de freshness quando a fonte
não envia cabeçalhos suficientes. O cache já existia no flutter_map: a configuração
não acelera uma resposta ainda não armazenada. No navegador o cache depende do
comportamento HTTP do browser. O cache pode ser limpo pelo sistema operacional.

As atualizações de tiles aguardam 200 ms após o movimento para evitar carregar
níveis e regiões intermediárias. Os tiles antigos continuam visíveis quando
possível; as revisitas à mesma área podem usar o cache. Após atualizar esta
configuração, faça hot restart, pois o cache é um singleton.

### Fonte da imagem aérea

Para o teste regional, os tiles cujo centro está em **Colorado** ou no **estado
de Washington** usam `NAIP/NAIP_plus` do GeoPlatform. As demais áreas continuam
no serviço original do USDA; Sentinel-2 e referências administrativas não mudam.
Não há tentativa de falha global nem troca automática de todo o mapa.

Os contornos são derivados de US Census TIGERweb, consultados uma vez durante a
implementação e incluídos no código, sem consulta de localização pela rede.
A geometria foi generalizada em 0,001 grau. O teste é feito pelo centro do tile;
tiles que atravessam divisas podem conter áreas dos dois estados. Isso é mais
perceptível em zoom distante e não é um recorte pixel a pixel. O contorno de
Washington evita incluir Oregon/Idaho por um retângulo; Washington DC fica fora.

Os recortes mantêm EPSG:3857, JPEG RGB, zoom máximo 19 e URLs determinísticas.
A URL diferente do GeoPlatform evita reaproveitar as imagens pretas guardadas
no cache da fonte original, preservando o cache das outras áreas. O log
`[MAP REGIONAL]` identifica a fonte uma vez por estado e instância do provider.

Os metadados do NAIP Plus consultados indicam imagens de anos diferentes,
incluindo Colorado de 2021; não é uma imagem da safra atual. Datas, resolução e
desempenho variam conforme o local. A atribuição regional fica no mapa e no painel.

- Serviço regional: https://imagery.geoplatform.gov/iipp/rest/services/NAIP/NAIP_plus/ImageServer
- Contornos: https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer/0

USDA Farm Production and Conservation: National Agriculture Imagery Program (NAIP). Atribuição visível no mapa. O painel diferencia este serviço do Sentinel-2 e informa a variação de resolução e data. Documentação: https://apps.geo.fpac.usda.gov/geo-imagery/rest/services/naip/conus_naip/ImageServer

### Fonte e licença da camada Sentinel-2

EOxCloudless https://cloudless.eox.at by EOX IT Services GmbH
(Contains modified Copernicus Sentinel data 2025).

A camada pública está sob **CC BY-NC-SA 4.0**: destina-se a uso não comercial,
com atribuição e demais condições da licença. A atribuição fica visível no mapa
e no painel. Uso comercial requer licença da EOX; não há autorização comercial
embutida nesta integração. A licença da camada não altera a licença do código.

- Catálogo: https://tiles.maps.eox.at/wmts/1.0.0/WMTSCapabilities.xml
- Processamento: https://cloudless.eox.at/documentation/processing
- Termos: https://cloudless.eox.at/documentation/license
- Licença pública: https://creativecommons.org/licenses/by-nc-sa/4.0/

Execute `flutter analyze` e `flutter test` para validar o frontend. Os testes usam
respostas controladas, incluindo o catálogo sem dimensão temporal, seleção da
grade correta, HTTPS, limite de zoom e recuperação de erros.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
