import 'dart:convert';
import 'dart:io';

const visualGalleryDirectory = 'build/galeria-visual';

final _labels = {
  for (final width in [320, 390])
    for (final zoom in [.8, 1.6, 2.4])
      'quintal_matrix_${width}_z$zoom':
          'Câmera — capacidade máxima, $width px, zoom $zoom e texto 1,5 (fixture)',
  for (final state in [
    'abandoned',
    'clearing',
    'empty',
    'bud',
    'growing',
    'full',
    'ready',
    'pending',
    'apple_0',
    'apple_6',
    'apple_15',
    'pear_0',
    'pear_6',
    'pear_15',
    'reduced',
    'actions_320',
    'actions_390',
  ])
    'quintal_orchard_$state': 'Pomar — $state (fixture, coleta individual)',
  for (final state in [
    'abandoned',
    'building',
    'waiting',
    'ready',
    'pending',
    'reduced',
    'recovery_0',
    'recovery_6',
    'recovery_15',
    'pickup_0',
    'pickup_6',
    'pickup_15',
    'actions_320',
    'actions_390',
  ])
    'quintal_market_$state': 'Mercadinho — $state (fixture, sem crédito local)',
  for (final width in [320, 390])
    for (final kind in ['daily', 'weekly'])
      'quintal_routine_${kind}_$width':
          'Rotina opcional ${kind == 'daily' ? 'diária' : 'semanal'}, $width px e texto 1,5 (fixture)',
  'quintal_world_kitchen_fruit_choices':
      'Cozinha — receitas de maçã e pera (fixture)',
  'quintal_world_market_fruit_choices':
      'Mercadinho — alternativa de troca por frutas (fixture)',
  'quintal_world_cat_food_fruit_choices':
      'Pote — servir rações de frutas (fixture)',
  'quintal_world_orchard_purpose':
      'Pomar — utilidade das frutas antes da construção (fixture)',
  for (final width in [320, 390])
    for (final tab in [1, 2, 3])
      'quintal_inventory_detail_${tab}_$width':
          'Inventário — ${tab == 1
              ? 'porções'
              : tab == 2
              ? 'ingredientes'
              : 'frutas'}, $width px e texto 1,5 (fixture)',
  for (final count in [8, 12])
    'quintal_garden_expanding_$count':
        'Horta — relógio na ampliação para $count canteiros (fixture)',
  for (final count in [8, 12])
    for (final frame in [0, 12, 31])
      'quintal_garden_${count}_$frame':
          'Horta — transição para $count canteiros, quadro $frame (fixture)',
  'quintal_camera_kitchen_320':
      'Câmera — cozinha 320 px, texto 1,5 e zoom afastado',
  'quintal_camera_kitchen_390':
      'Câmera — cozinha 390 px, texto 1,5 e zoom afastado',
  'quintal_kitchen_level2_0': 'Cozinha nível 2 — preparo, fila e prato pronto',
  'quintal_kitchen_level2_16': 'Cozinha nível 2 — tampa e vapor em movimento',
  'quintal_kitchen_level2_63': 'Cozinha nível 2 — estados preservados',
  'quintal_kitchen_next_started':
      'Cozinha — próxima receita, sem coleta automática',
  'quintal_kitchen_reduced': 'Cozinha — movimento reduzido',
  'quintal_kitchen_expanding_ready':
      'Cozinha — ampliação preserva o prato pronto',
  'quintal_garden_foliage':
      'Horta — seis culturas com folhagem em movimento (fixture)',
  'quintal_garden_foliage_reduced':
      'Horta — folhagem com movimento reduzido (fixture)',

  'quintal_meals_meal': 'Gatos — consumo gradual e gostos distintos (fixture)',
  'quintal_meals_refused': 'Gato — recusa no próprio pote (fixture)',
  'quintal_meals_drink': 'Gato — beber no próprio pote (fixture)',
  'quintal_meals_reduced': 'Gatos — refeição com movimento reduzido (fixture)',
  'quintal_meals_taste_320':
      'Gato — mudança de gosto e apetite, 320 px (fixture)',
  for (final width in [390, 320]) ...{
    'quintal_reward_progress_$width':
        'Quintal — missão, medalha e prêmios confirmados (fixture)',
    'quintal_reward_bond_$width': 'Quintal — prêmio de vínculo (fixture)',
    'quintal_reward_inventory_$width':
        'Quintal — destino do prêmio na bandeja (fixture)',
    for (final affinity in [20, 50, 100, 200])
      'quintal_bond_${affinity}_$width':
          'Ficha — vínculo $affinity e próximo prêmio (fixture)',
  },

  'quintal_world_garden_water_effect':
      'Horta — regador durante a rega confirmada (fixture)',
  'quintal_world_cat_water_effect':
      'Gato — abastecimento do pote de água (fixture)',
  'quintal_world_cat_food_effect': 'Gato — servir com pá de ração (fixture)',
  'quintal_world_coop_food_effect':
      'Galinhas — abastecer com pá de ração (fixture)',
  'quintal_world_pasture_food_effect':
      'Vacas — abastecer o cocho com feno (fixture)',
  'quintal_world_coop_water_reduced':
      'Água — ferramenta sem inclinação em movimento reduzido (fixture)',

  'quintal_world_garden_project':
      'Horta — projeto de 4 para 8 canteiros (fixture)',
  'quintal_world_garden_project_max':
      'Horta — projeto de 8 para 12 canteiros (fixture)',
  'quintal_world_coop_project':
      'Galinheiro — perímetro e capacidade de 2 para 4 (fixture)',
  'quintal_world_pasture_project':
      'Celeiro — perímetro e capacidade de 1 para 2 (fixture)',
  'quintal_world_kitchen_project':
      'Cozinha — perímetro e ampliação da fila (fixture)',

  'quintal_world_garden_mature':
      'Horta — seis culturas maiores e prontas no canteiro (fixture)',
  'quintal_world_garden_harvest_carrot':
      'Horta — retirada da planta · cenoura (fixture)',
  'quintal_world_garden_harvest_turnip':
      'Horta — retirada da planta · nabo (fixture)',
  'quintal_world_garden_harvest_corn':
      'Horta — retirada da planta · milho (fixture)',
  'quintal_world_garden_harvest_wheat':
      'Horta — retirada da planta · trigo (fixture)',
  'quintal_world_garden_harvest_pumpkin':
      'Horta — retirada da planta · abóbora (fixture)',
  'quintal_world_garden_harvest_melon':
      'Horta — retirada da planta · melão (fixture)',
  'quintal_world_garden_harvest_reduced':
      'Horta — retirada da planta · movimento reduzido (fixture)',
  'quintal_world_cat_play':
      'Brincadeira — gato e varinha sobre o próprio Quintal (fixture)',
  'quintal_world_kitchen_simultaneous':
      'Cozinha — porção pronta e outro preparo ativo (fixture)',
  'social_publish': 'Social — botão Publicar acima do menu (fixture)',
  'quintal_return_summary':
      'Quintal — resumo de retorno com destinos (fixture)',
  'quintal_notification_settings':
      'Configurações — avisos do Quintal (fixture)',
  'quintal_world_page': 'Quintal — interação na tela completa com menu',
  'quintal_world_cat_coats':
      'Quintal — quatro pelagens clássicas (demonstração)',
  'quintal_world_garden_choices': 'Quintal — escolher cultivo no balão',
  'quintal_world_kitchen_choices': 'Quintal — receitas e ingredientes',
  'quintal_world_kitchen_queue':
      'Quintal — fila de preparações: pronto, preparando e aguardando',
  'quintal_world_kitchen_waiting': 'Quintal — relógio de produção na cozinha',
  'quintal_world_pier_fishing': 'Quintal — minijogo de pesca',
  'quintal_world_pier_fishing_waiting': 'Quintal — aguardando a mordida',
  'quintal_world_market_choices':
      'Quintal — Mercadinho, pagar com moedas ou produtos',
  'quintal_world_cat_food_choices': 'Quintal — escolher ração para o gato',
  'quintal_world_garden_abandoned': 'Quintal — horta abandonada',
  'quintal_world_coop_abandoned': 'Quintal — galinheiro abandonado',
  'quintal_world_pasture_abandoned': 'Quintal — pasto abandonado',
  'quintal_world_kitchen_abandoned': 'Quintal — cozinha abandonada',
  'quintal_world_market_abandoned': 'Quintal — mercado abandonado',
  'quintal_world_orchard_abandoned': 'Quintal — pomar abandonado',
  'quintal_world_pier_abandoned': 'Quintal — píer quebrado',
  'quintal_world_coop_repairing': 'Quintal — galinheiro em reforma',
  'quintal_world_pasture_repairing': 'Quintal — celeiro em reforma (fixture)',
  'quintal_world_garden_upgrading_max':
      'Quintal — horta ampliando de 8 para 12 canteiros (fixture)',
  'quintal_world_coop_upgrading':
      'Quintal — galinheiro ampliando com ovos prontos (fixture)',
  'quintal_world_pasture_upgrading':
      'Quintal — celeiro ampliando com leite pronto (fixture)',
  'quintal_world_kitchen_upgrading':
      'Quintal — cozinha ampliando com produção (fixture)',
  'quintal_world_garden_upgrading':
      'Quintal — horta ampliando de 4 para 8 canteiros (fixture)',
  'quintal_inventory_rations': 'Quintal — rações guardadas',
  'quintal_inventory_ingredients': 'Quintal — ingredientes guardados',
  'quintal_inventory': 'Quintal — inventário com três abas',
  'quintal_shop_production': 'Quintal — loja e espaços de produção',
  'quintal_world_garden': 'Quintal — colher diretamente no canteiro',
  'quintal_world_garden_empty': 'Quintal — escolher cultivo no canteiro',
  'quintal_world_coop': 'Quintal — comedouro das galinhas',
  'quintal_world_coop_water': 'Quintal — bebedouro das galinhas',
  'quintal_fishing_result_success': 'Pesca — captura confirmada (fixture)',
  'quintal_fishing_result_failure': 'Pesca — peixe escapou (fixture)',
  'quintal_cat_play': 'Quintal — brincar com a varinha (fixture)',
  'quintal_play_result_2':
      'Brincadeira — vínculo recebido (fixture de resultado)',
  'quintal_play_result_0':
      'Brincadeira — bônus diário já recebido (fixture de resultado)',
  'quintal_cat_play_320': 'Quintal — brincar com a varinha em 320 px (fixture)',
  'quintal_fishing_result_practice': 'Pesca — treino sem prêmio (fixture)',
  'quintal_world_coop_paused_nest':
      'Quintal — ovos pausados por falta de água (fixture)',
  'quintal_world_coop_producing_nest': 'Quintal — progresso dos ovos (fixture)',
  'quintal_world_coop_scratch': 'Quintal — galinha ciscando (fixture)',
  'quintal_world_coop_shelter':
      'Quintal — subida da rampa do galinheiro (fixture)',
  'quintal_world_pasture_shelter':
      'Quintal — entrada da vaca no celeiro (fixture)',
  'quintal_world_coop_shelter_inside': 'Quintal — galinha no abrigo (fixture)',
  'quintal_world_pasture_shelter_inside': 'Quintal — vaca no celeiro (fixture)',
  'quintal_world_coop_shelter_level1':
      'Quintal — galinheiro nível 1 com residente no abrigo (fixture)',
  'quintal_world_pasture_shelter_level1':
      'Quintal — celeiro nível 1 com residente no abrigo (fixture)',
  'quintal_world_coop_shelter_upgrading':
      'Quintal — abrigo em ampliação (fixture)',
  'quintal_world_coop_gate':
      'Quintal — passagem pelo portão do galinheiro (fixture)',
  'quintal_world_pasture_gate':
      'Quintal — passagem pelo portão do pasto (fixture)',
  'quintal_world_coop_routine_food':
      'Quintal — galinha no comedouro (rotina, fixture)',
  'quintal_world_coop_routine_water':
      'Quintal — galinha bebendo (rotina, fixture)',
  'quintal_world_pasture_routine_food':
      'Quintal — vaca no cocho (rotina, fixture)',
  'quintal_world_pasture_routine_water':
      'Quintal — vaca bebendo (rotina, fixture)',
  'quintal_world_coop_water_effect':
      'Quintal — água após confirmação (efeito em fixture)',
  'quintal_world_coop_nest': 'Quintal — coletar ovos no ninho',
  'quintal_world_pasture': 'Quintal — comedouro das vaquinhas',
  'quintal_world_pasture_milk': 'Quintal — coletar leite no cenário',
  'quintal_world_pasture_milking_empty':
      'Quintal — ordenha confirmada, balde vazio (fixture)',
  'quintal_world_pasture_milking_half':
      'Quintal — ordenha, balde enchendo (fixture)',
  'quintal_world_pasture_milking_full':
      'Quintal — ordenha, leite recolhido (fixture)',
  'quintal_world_pier': 'Quintal — pescar tocando no píer',
  'quintal_world_kitchen': 'Quintal — receitas e fila na panela',
  'quintal_world_market': 'Quintal — pedidos no Mercadinho',
  'quintal_world_market_waiting': 'Quintal — Mercadinho preparando o pedido',
  'quintal_world_market_ready': 'Quintal — caixote pronto para retirar',
  'quintal_world_orchard': 'Quintal — colher nas fruteiras',
  'quintal_world_cat_food': 'Quintal — servir no pote do gato',
  'quintal_world_cat_water': 'Quintal — abastecer o pote de água do gato',
  'missions_paused': 'Missões — concessões pausadas nesta conta',
  'public_profile_medals': 'Perfil público — medalha em destaque',
  'missions_initial_progress': 'Missões iniciais — etapas para conhecer o app',
  'missions_weekly_progress': 'Missões semanais — segunda a domingo',
  'seasonal_challenges': 'Desafios — temporada ainda não iniciada',
  'medal_celebration_progress': 'Medalha — apresentação da conquista',
  'poster_details': 'Cartaz — contatos e compartilhamento',
  'poster_settings': 'Cartaz — escolher informações públicas',
  'poster_contacts': 'Cartaz — telefones e WhatsApp',
  'habitat_outskirts_north': 'Quintal — limite norte da câmera',
  'habitat_outskirts_south': 'Quintal — limite sul da câmera',
  'habitat_outskirts_east': 'Quintal — limite leste da câmera',
  'habitat_outskirts_west': 'Quintal — limite oeste da câmera',
  'social_text': 'Social — texto e fotografia na mesma timeline',
  'habitat_gift': 'Quintal — presente externo destacado',
  'habitat_expanded': 'Quintal — expansão e presente reposicionado',
  'habitat_edit_ground': 'Quintal — ferramentas de chão',
  'habitat_reward': 'Quintal — recompensa confirmada',
  'composer_text': 'Nova publicação — texto e espaço do teclado',
  'composer_photo': 'Nova publicação — fotografia anexada',
  'home': 'Início',
  'social': 'Social — comunidade',
  'navigation': 'Navegação principal',
  'capture': 'Gatalogar',
  'collection': 'Coleção',
  'challenges': 'Missões',
  'habitat': 'Quintal — com menu',
  'profile': 'Meu perfil',
  'achievements': 'Conquistas',
  'friends': 'Amigos',
  'friends_discover': 'Descobrir pessoas',
  'friends_invites': 'Convites',
  'friends_ranking': 'Ranking',
  'public_profile': 'Perfil público',
  'notifications': 'Notificações',
  'settings': 'Configurações',
  'experience': 'Nível e experiência',
  'login': 'Login — restaurado',
  'my_cats': 'Meus gatos',
  'pet': 'Perfil do meu gato',
  'add_pet': 'Adicionar gato',
  'add_pet_details': 'Adicionar gato — foto e salvar',
  'cat_detail': 'Detalhes da descoberta',
  'cat_gallery': 'Galeria de fotografias',
  'cat_gallery_angles': 'Galeria de fotografias — ângulos',
  'history': 'Histórico',
  'result': 'Resultado da descoberta',
  'contribution': 'Contribuição',
  'map': 'Mapa de avistamentos',
  'inbox': 'Conversas',
  'chat': 'Chat',
  'composer': 'Nova publicação',
  'quick_alert': 'Alerta rápido',
  'registered_alert': 'Alerta de gato cadastrado',
  'active_alert': 'Alerta ativo',
  'poster': 'Cartaz',
  'community_posters': 'Cartazes da comunidade',
  'community_case': 'Detalhes da busca',
  'missing_cats': 'Gatos desaparecidos',
  'clues': 'Pistas',
  'clue_detail': 'Detalhes da pista',
  'missing_map': 'Mapa das buscas',
  'shop': 'Loja',
  'habitat_help': 'Ajuda do Quintal',
  'inbox_filled': 'Conversas — com mensagens',
  'notifications_filled': 'Notificações — com avisos',
  'missing_cats_filled': 'Buscas — ativas e concluídas',
  'community_posters_filled': 'Cartazes — lista preenchida',
  'community_case_filled': 'Busca — fotografia e contatos',
  'clues_filled': 'Pistas — pendentes, reconhecidas e descartadas',
  'contribution_confirmed': 'Contribuição — reconhecida',
  'friends_filled': 'Amigos — lista preenchida',
  'friends_discover_filled': 'Descobrir — sugestões',
  'friends_invites_filled': 'Convites — recebidos',
  'friends_ranking_filled': 'Ranking — participantes',
  'home_progress': 'Início — com conquistas',
  'challenges_progress': 'Desafios — com progresso',
  'achievements_progress': 'Missões — diária e semanais',
  'achievements_medals': 'Conquistas — mural de medalhas',
};

/// Regenerated alongside the screenshots, never a hand-maintained stale index.
Future<void> updateVisualGallery(Iterable<String> screenNames) async {
  final root = Directory(visualGalleryDirectory).absolute;
  final retained = <String>{...screenNames};
  final previousIndex = File('${root.path}/galeria.html');
  if (await previousIndex.exists()) {
    for (final match in RegExp(
      r'href="([a-zA-Z0-9_-]+)\.png"',
    ).allMatches(await previousIndex.readAsString())) {
      final name = match.group(1)!;
      if (await File('${root.path}/$name.png').exists()) retained.add(name);
    }
  }
  // Known captures also recover entries omitted by older index generators.
  if (await root.exists()) {
    await for (final file in root.list()) {
      if (file is! File || !file.path.endsWith('.png')) continue;
      final name = file.uri.pathSegments.last.replaceAll('.png', '');
      if (_labels.containsKey(name) ||
          _labels.containsKey(name.replaceFirst(RegExp(r'_320$'), ''))) {
        retained.add(name);
      }
    }
  }
  final names = retained.toList()..sort();
  final timestamp = DateTime.now().toIso8601String();
  const notice =
      'Capturas de widgets Flutter em 390 × 844 pontos (PNG a 2×). '
      'Fotografias, nomes e valores são dados exclusivos dos testes. '
      'A galeria reúne estados vazios e preenchidos das telas reformadas. '
      'Os mapas de ruas não carregam neste ambiente. '
      'Estas imagens não substituem a validação em aparelho.';
  const htmlEscape = HtmlEscape();
  final html = StringBuffer('''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Gatálogo — galeria visual</title>
<style>
body{margin:0;background:#fbf6e8;color:#4b281b;font:16px/1.6 system-ui,sans-serif}
main{max-width:1400px;margin:auto;padding:28px}h1{font-size:30px}
header{max-width:960px}.notice{padding:18px;background:#fff9ec;border:1px solid #bfa581;border-radius:16px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:22px}
figure{margin:0;padding:14px;background:#fff9ec;border:1px solid #d8c6a5;border-radius:20px}
a{color:inherit}img{width:100%;height:auto;display:block;border-radius:12px}
figcaption{font-weight:650;margin-bottom:12px}.note{font-size:14px;color:#806349}
input{font:inherit;padding:10px;border:1px solid #bfa581;border-radius:12px;margin:18px 0;width:min(90%,420px)}
a:focus-visible,input:focus-visible{outline:3px solid #d97e9c;outline-offset:4px}
[hidden]{display:none}
</style><main><header><h1>Gatálogo — galeria visual</h1>
<p>Atualizada: $timestamp · ${names.length} capturas</p>
<p class="notice">$notice</p><p>Clique na imagem para abrir o PNG completo.</p>
<p><a href="movimentos.html">Ver animais e brincadeira em movimento</a> · <a href="modelos/index.html">Biblioteca de modelos por categoria</a> · <a href="quintal-auditoria/index.html">Quintal: câmera, rio e sobreposições</a> · <a href="cartaz-impressao.pdf">Cartaz completo para impressão (dados de teste)</a></p>
<p><a href="mercadinho/recuperacao.mp4">Mercadinho — recuperação (fixture)</a> · <a href="mercadinho/retirada.mp4">Retirada confirmada (fixture)</a></p>
<p><a href="pomar/apple.mp4">Pomar — colher maçãs preserva peras (fixture)</a> · <a href="pomar/pear.mp4">Colher peras (fixture)</a></p>
<p><a href="cozinha/index.html">Cozinha — preparo, fila e prato pronto (fixtures)</a></p>
<p><a href="horta/index.html">Horta — ampliação e folhagem (fixtures)</a></p>
<p><a href="refeicoes/index.html">Gatos — refeições, recusa e bebida no próprio pote (fixtures)</a></p>
<p><a href="ferramentas/index.html">Rega e abastecimento — ferramentas sobre a cena (fixtures)</a></p>
<p><a href="colheita/index.html">Colheita — retirada das seis plantas e movimento reduzido (fixtures)</a></p>
<p><a href="abrigos/index.html">Abrigos — entrada, descanso e saída dos residentes (fixtures)</a></p>
<p><a href="portoes/index.html">Portões — saída e retorno dos residentes (fixtures)</a></p>
<p><a href="brincadeira/index.html">Brincadeira na cena — controle e reação do gato (fixture)</a></p>
<p><a href="ancoragem/index.html">Ações no mundo — pan, zoom e residente em movimento (fixtures)</a></p>
<p><a href="pelagens/index.html">Pelagens dos gatos — cores, padrões e animações</a></p>
<p><a href="modelos-novos/index.html">Novos modelos do Quintal — estados e arquivos 3D (em desenvolvimento)</a></p>
<p><a href="modelos-novos/cultivos.html">Plantações — brotos, crescimento e colheita</a></p>
<label for="search">Buscar tela</label><br><input id="search" type="search" placeholder="Perfil, Quintal, coleção…">
</header><div class="grid">
''');
  final markdown = StringBuffer(
    '# Gatálogo — galeria visual\n\n'
    'Atualizada: $timestamp · ${names.length} capturas\n\n$notice\n\n'
    '[Abrir galeria](galeria.html)\n\n',
  );
  for (final name in names) {
    final file = File('${root.path}/$name.png');
    if (!await file.exists()) throw StateError('Captura ausente: $name');
    final label = _labels[name] ?? name;
    final escaped = htmlEscape.convert(label);
    final capturedAt = (await file.lastModified()).toIso8601String();
    final note = name == 'map' || name == 'missing_map'
        ? 'Mapa de ruas indisponível no ambiente de captura.'
        : '';
    html.write(
      '<figure><figcaption>$escaped</figcaption>'
      '<a href="$name.png"><img loading="lazy" src="$name.png" alt="Captura: $escaped"></a>'
      '<p class="note">Captura: $capturedAt. $note</p></figure>',
    );
    markdown.writeln('- [$label](${file.path.replaceAll('\\', '/')})');
  }
  html.write('''</div></main><script>
const norm=s=>s.normalize('NFD').replace(/[\\u0300-\\u036f]/g,'').toLowerCase();
document.querySelector('#search').addEventListener('input',e=>{
const q=norm(e.target.value);
document.querySelectorAll('figure').forEach(f=>f.hidden=!norm(f.querySelector('figcaption').textContent).includes(q));
});</script></html>''');
  await File('${root.path}/galeria.html').writeAsString(html.toString());
  await File('${root.path}/LEIA-ME.md').writeAsString(markdown.toString());
}
