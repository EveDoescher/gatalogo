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

## Habitat

O cenário usa Flame com projeção isométrica fixa, sprites PNG e sombras
pré-calculadas. Os modelos GLB são fontes de arte e não entram no app.
As animações de gatos compartilham atlas entre os personagens; alimentação,
reações e dança são carregadas quando necessárias. Caminhadas e visitas aos
móveis são locais e não alteram continuamente o ponto salvo do gato.

A API determina preços, saldo, propriedade, afinidade e crescimento. Edições
do quintal têm rascunho offline; compras e cuidados exigem conexão. O catálogo
offline é gerado a partir do repositório irmão `gatalogo-ai-api`:

```powershell
python tool/export_habitat_catalog.py
python tool/export_habitat_catalog.py --check
```

Para regenerar arte, instale NumPy e Pillow no ambiente Python e execute:

```powershell
python tool/recover_habitat_decor.py
python tool/render_habitat_decor.py
python tool/render_habitat_cat.py
python tool/build_habitat_manifest.py
python tool/build_habitat_lighting.py
```

A recuperação usa `feature/etapa9-3d-metagame` sem trocar a branch atual.
`tool/habitat_assets.py` limita a seleção; licenças permanecem em cada pack.
Para validar alterações e gerar capturas com a navegação do app:

```powershell
flutter analyze
flutter test
python -m unittest discover -s tool -p "test_habitat_*.py"
flutter test tool/habitat_preview_test.dart --plain-name "capture Habitat with bottom navigation"
```
