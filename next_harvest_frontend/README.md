# next_harvest_frontend

A new Flutter project.

## Configuração do ambiente

Copie `.env.example` para `.env` na raiz do frontend e ajuste `API_BASE_URL`.
O `.env` local é ignorado pelo Git e carregado por `flutter_dotenv` em `main()`
antes da criação do `ProviderScope`. O `dioProvider` utiliza essa URL.

```dotenv
API_BASE_URL=http://localhost:8000
```

No emulador Android, use `http://10.0.2.2:8000` para acessar o backend na máquina
de desenvolvimento. Após alterar o `.env`, reinicie o app. Em novos checkouts e
no CI, crie o `.env` antes de executar testes ou builds, pois ele é um asset.

Use o arquivo para configurações públicas do cliente, como a URL da API.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
