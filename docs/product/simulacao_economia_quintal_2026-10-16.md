# F07 — Simulação da economia e dos cuidados

Executada em 16/10/2026. Resultado local reproduzível, sem conta real, PostgreSQL ou alteração de configuração. [Dados completos, premissas e hashes das fontes](simulacao_economia_quintal_2026-10-16.json).

## Resultado

Os quatro cenários exigidos (3/6 gatos × 1/2 visitas) mantêm duas refeições aceitas por gato por dia, quatro galinhas e duas vacas, tanto na dieta Horta quanto na alternativa Ovo. Isso pressupõe horta de 12 canteiros, cozinha ampliada, sete dias de aquecimento e reposição regular; não representa o desbloqueio inicial nem garante aceitação de uma receita por todos os gatos.

O principal custo encontrado é a interação: 80–161 toques estimados/dia. Uma visita/dia perde produção por armazenamento cheio; duas visitas eliminam essa espera, mas aumentam os comandos de servir e recolher. O estoque de milho não se esgota; trigo oscila por lotes de três unidades. O JSON registra estoque no início/fim e mínimo observado para distinguir reposição de consumo de uma reserva.

## Cenários de 28 dias

Todos incluem quatro galinhas e duas vacas. “Mín.” é a menor quantidade disponível após as ações da visita. Toques são uma estimativa explícita dos fluxos atuais, não telemetria de aparelho.

| Dieta | Gatos | Visitas/dia | Toques/dia | Toques/visita | Mín. trigo | Mín. milho | Ovos coletados/dia | Leite coletado/dia |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Horta | 3 | 1 | 83.29 | 83.29 | 8 | 6 | 8 | 4 |
| Horta | 3 | 2 | 101.32 | 50.66 | 10 | 6 | 16 | 6 |
| Horta | 6 | 1 | 131.00 | 131.00 | 13 | 6 | 8 | 4 |
| Horta | 6 | 2 | 161.00 | 80.50 | 16 | 6 | 16 | 6 |
| Ovo | 3 | 1 | 80.00 | 80.00 | 7 | 9 | 8 | 4 |
| Ovo | 3 | 2 | 98.00 | 49.00 | 7 | 9 | 16 | 6 |
| Ovo | 6 | 1 | 124.29 | 124.29 | 8 | 10 | 8 | 4 |
| Ovo | 6 | 2 | 154.32 | 77.16 | 10 | 12 | 16 | 6 |

## Consumo efetivo e períodos de espera

Além dos ingredientes das receitas abaixo, alimentar os residentes consome **6 milhos + 4 trigos/dia** em todos os cenários. Água é renovada diariamente. Não se usou a porção básica gratuita; ela continua disponível no produto e reduziria a necessidade de receitas, com sua regra de uma por gato/dia.

| Dieta | Gatos | Ingredientes de receitas/dia | Cozinha produzindo h/dia | Cozinha sem preparo h/dia |
|---|---:|---|---:|---:|
| Horta | 3 | 2 cenoura, 4 trigo | 0.333 | 23.667 |
| Horta | 6 | 4 cenoura, 8 trigo | 0.667 | 23.333 |
| Ovo | 3 | 2 milho, 2 ovo, 2 trigo | 0.833 | 23.167 |
| Ovo | 6 | 4 milho, 4 ovo, 4 trigo | 1.667 | 22.333 |

Com uma visita diária, **cada galinha fica 12 h/dia parada por ninho cheio** e **cada vaca, 8 h/dia por leite acumulado**. Com duas visitas, ambos ficam 0 h/dia parados por capacidade. Falta de comida/água: 0 h/dia no cenário abastecido. Os testes também confrontam períodos sem suprimentos com o servidor.

Ociosidade da cozinha significa que a quantidade solicitada já foi preparada; não é erro nem falta de capacidade. A fila é sequencial e tem quatro vagas. A horta aguarda colheita manual: o JSON registra a soma em **horas-canteiro/dia**, não horas de relógio de toda a horta. Exemplo com seis gatos/Horta: 209,5 horas-canteiro/dia com uma visita e 101,5 com duas. Nenhuma colheita/preparo é creditada antes da visita e da ação de recolher.

## Orçamento diário de todas as receitas

Quantidade para cobrir duas refeições por gato, arredondada por lote inteiro. Esta tabela é orçamento de ingredientes, não simulação de pesca, compras ou desbloqueio dessas dietas. Sobras de lote permanecem no estoque.

| Gatos | Receita | Lotes | Porções produzidas | Ingredientes |
|---:|---|---:|---:|---|
| 3 | Horta | 2 | 6 | 4 trigo, 2 cenoura |
| 3 | Peixe | 2 | 6 | 2 peixe, 4 trigo |
| 3 | Ovo | 2 | 6 | 2 ovo, 2 milho, 2 trigo |
| 3 | Frango | 2 | 8 | 2 frango, 4 trigo, 2 cenoura |
| 3 | Carne | 2 | 8 | 2 carne, 4 trigo, 2 abóbora |
| 3 | Cremosa | 2 | 8 | 2 leite, 2 ovo, 4 trigo |
| 3 | Especial | 1 | 6 | 1 peixe, 1 frango, 1 abóbora |
| 6 | Horta | 4 | 12 | 8 trigo, 4 cenoura |
| 6 | Peixe | 4 | 12 | 4 peixe, 8 trigo |
| 6 | Ovo | 4 | 12 | 4 ovo, 4 milho, 4 trigo |
| 6 | Frango | 3 | 12 | 3 frango, 6 trigo, 3 cenoura |
| 6 | Carne | 3 | 12 | 3 carne, 6 trigo, 3 abóbora |
| 6 | Cremosa | 3 | 12 | 3 leite, 3 ovo, 6 trigo |
| 6 | Especial | 2 | 12 | 2 peixe, 2 frango, 2 abóbora |

## Tempo até Favorita

Amostra de **10,000 pares gato/receita**, semente `20261016`, usando a própria função `evolve` do servidor, duas refeições/dia e horizonte de 365 dias:

- 6817 (68.17%) chegaram a Favorita.
- 3177 (31.77%) chegaram a Odeia antes disso; o estado é terminal para essa receita.
- 6 permaneceram sem estado terminal ao fim do horizonte.
- Entre os que chegaram a Favorita: mediana **72 dias**, percentil 90 **156 dias**.

Esses prazos são condicionais ao sucesso, não uma promessa para todos os gatos. A preferência evolui no máximo uma vez a cada 24 horas: duas visitas/refeições não dobram a velocidade. A simulação de capacidade assume refeições aceitas; esta amostragem de preferência é separada. Repetir uma receita odiada desperdiça porções e exige outra estratégia alimentar, não incluída no orçamento de aceitação.

## Como os toques foram contados

Incluem seleção do objeto e comandos: plantar 3; colher 2; preparar 3; recolher preparo 3; recolher ninhos 2; ordenhar cada vaca 2; abastecer comida/água 2 por recipiente; água e carinho do gato 2 cada; servir duas porções 4 (pote, Servir, quantidade, receita). Selecionar novamente a quantidade em cada visita é conservador. Não incluem pan/zoom, caminho até o espaço, notificações, pesca ou brincadeira opcionais. Contagem por ação e totais estão no JSON; tempos de execução humana precisam de teste em aparelho.

## Decisões e propostas numéricas

**Nenhuma alteração de balanceamento foi aplicada em F07.** Preços base, capacidade, intervalo de refeições e flags foram preservados. Configuração observada nesta execução: `habitat_free_shop=true` e `habitat_instant_build=true`. Não houve mudança de ambiente ou conta.

Para F04, propostas explícitas a implementar/validar na etapa seguinte:

1. Receitas opcionais de frutas: **1 trigo + 2 frutas → 3 porções, 20 minutos, satisfação base 16**. Maçã e pera devem ter destino real no catálogo. Com uma coleta diária, o pomar produz 3 de cada fruta; portanto essas receitas complementam a alimentação, não sustentam sozinhas seis gatos.
2. Troca opcional: **3 maçãs + 3 peras → 2 frangos, prazo de 1 hora**, preservando o preço e a troca agrícola já existentes. Com uma coleta diária ela consome a produção diária do pomar; o jogador escolhe entre receita e troca.
3. Manter por enquanto capacidades e probabilidades atuais. A redução de cliques pode vir de preservar seleções de porções ou recolher preparos em lote, mas essas mudanças de interação não estão incluídas em F07 e não devem virar coleta automática.

## Reprodução e validação

No repositório da API:

```powershell
.\.venv\Scripts\python.exe -m scripts.simulate_quintal_balance --output ..\catlogue\docs\simulacao_economia_quintal_2026-10-16.json
.\.venv\Scripts\python.exe -m pytest tests/test_quintal_production.py -k 'balance_simulation or balance_scenarios' -q
```

**14 testes aprovados:** dez comparações do cálculo de ciclo/capacidade/suprimentos com `quintal_production.reconcile` usando SQLite descartável, mais os quatro cenários exigidos. Log: `build-quintal-balance-tests.log` na API. A distribuição de preferências usa diretamente `evolve`, sem duplicar suas probabilidades. O modelo não substitui F06/V09/V11/U05 conectados/em aparelho, que continuam abertos.
