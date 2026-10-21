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

## Quintal

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
flutter test tool/habitat_preview_test.dart --plain-name "capture Quintal with bottom navigation"
```


### Quintal e Social — rodada 04/10/2026

A implementação está detalhada em `docs/plano_habitat_social_2026-10-04.md`.
O modo de loja gratuita é controlado pela API (`HABITAT_FREE_SHOP=true`),
sem substituir saldo, inventário ou progressão por dados de demonstração.
A galeria contém somente fixtures de teste e não usa contas de produção.

Para reproduzir as animações e a galeria no Windows:

```powershell
$species = 'cat','dog','bee','bunny','chick','deer','fox','beaver','parrot','fish'
foreach ($animal in $species) { python tool/render_habitat_cat.py --animal $animal }
$env:GATALOGO_CAPTURE_ALL = '1'
$env:GATALOGO_CAPTURE_MOTION = '1'
flutter test test/visual_validation_capture_test.dart test/habitat_visit_capture_test.dart
python tool/build_habitat_motion_gallery.py
Remove-Item Env:GATALOGO_CAPTURE_ALL, Env:GATALOGO_CAPTURE_MOTION
```

Resultado em `build/galeria-visual/galeria.html`, com link para movimentos.
Os novos GLBs são do mesmo pacote Kenney existente, com sua licença preservada;
`tool/recover_habitat_decor.py` também recupera as fontes dos visitantes quando faltarem.


## Conclusão da refatoração arquitetural

O mapa de pendências e a validação desta rodada estão em
[docs/architecture_completion.md](docs/architecture_completion.md).

Release exige `--dart-define=API_BASE_URL=<URL explícita>`. Valide sem compilar:

```powershell
.\tool\build_release.ps1 -ApiUrl 'https://sua-api.exemplo' -CheckOnly
```

Para distribuir, remova `-CheckOnly` e informe `-Target apk`, `appbundle` ou `windows`.
O endereço local padrão continua disponível apenas em desenvolvimento.


O mapa dos fluxos, medições de consultas e oportunidades de melhoria interna está
em [docs/performance_flows.md](docs/performance_flows.md).

## Plano de testes de eficiência

Cenários para revisão antes da execução: [latência, carga, dados, segurança, celular e mutação de código](docs/test_plan_efficiency.md). O plano distingue cobertura existente de medições futuras.
