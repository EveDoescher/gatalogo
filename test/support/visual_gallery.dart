import 'dart:convert';
import 'dart:io';

const visualGalleryDirectory = 'build/galeria-visual';

const _labels = {
  'home': 'Início',
  'social': 'Social — comunidade',
  'navigation': 'Navegação principal',
  'capture': 'Gatalogar',
  'collection': 'Coleção',
  'challenges': 'Missões',
  'habitat': 'Habitat — com menu',
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
  'habitat_help': 'Ajuda do Habitat',
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
  final names = screenNames.toList();
  final root = Directory(visualGalleryDirectory).absolute;
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
<label for="search">Buscar tela</label><br><input id="search" type="search" placeholder="Perfil, Habitat, coleção…">
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
    final note = name == 'map' || name == 'missing_map'
        ? 'Mapa de ruas indisponível no ambiente de captura.'
        : '';
    html.write(
      '<figure><figcaption>$escaped</figcaption>'
      '<a href="$name.png"><img loading="lazy" src="$name.png" alt="Captura: $escaped"></a>'
      '<p class="note">$note</p></figure>',
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
