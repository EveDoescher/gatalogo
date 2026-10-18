/// Uses only the confirmed effect; older servers keep a neutral message.
String quintalPlayResultDescription(Map<String, dynamic> result) {
  final effect = result['care_effect'];
  if (effect is! Map) {
    return 'O cuidado foi registrado. Confira o vínculo na ficha do seu gato.';
  }
  final gained = effect['bond_gained'];
  final total = effect['bond_total'];
  if (gained is! num || total is! num) {
    return 'O cuidado foi registrado. Confira o vínculo na ficha do seu gato.';
  }
  final bond = gained > 0
      ? '+${gained.toInt()} de vínculo! Total: ${total.toInt()}.'
      : 'Vínculo: ${total.toInt()}. O bônus de brincar de hoje já foi recebido.';
  final bonus = effect['play_bonus_after'];
  return bonus is num && bonus > 0
      ? '$bond\nBônus de brincadeira renovado: ajuda na satisfação e diminui ao longo de 24 horas.'
      : bond;
}
