# Gatálogo

O catálogo pode ser usado localmente antes de uma conta existir. Ao entrar, a
coleção atual é vinculada e enviada em segundo plano; em outro aparelho, o
catálogo e as fotos privadas são baixados para o armazenamento local.

## Configuração de login

Execute `flutter pub get` após atualizar as dependências. Para Google, crie os
clientes Android e iOS no Google Cloud com o pacote/bundle do app e informe o
client ID web no servidor (`GOOGLE_WEB_CLIENT_ID`). Ao iniciar o Flutter, use o
mesmo client ID de servidor:

```powershell
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=seu_client_id.apps.googleusercontent.com
```

O login por e-mail requer a API com PostgreSQL e SMTP configurados. Access e
refresh tokens são guardados somente no armazenamento seguro do sistema; a fila
e o catálogo permanecem no SQLite para funcionar sem rede.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
