---
name: Gatálogo
description: Diário botânico e acolhedor de exploração felina
colors:
  primary: "#DC8BA1"
  primary-dark: "#C7607E"
  primary-light: "#FCEBE8"
  primary-soft-bg: "#FCEDED"
  green: "#7E9B70"
  green-button: "#72856A"
  green-light: "#F1F5ED"
  green-link: "#5D7A58"
  green-progress: "#6B8A5A"
  background: "#FBF6F2"
  surface: "#FFFFFF"
  card-background: "#FAF3F0"
  card-alt-background: "#FDF8F5"
  text-dark: "#382923"
  text-title: "#4A352F"
  text-medium: "#786B67"
  text-light: "#948C87"
  border: "#EDDEDB"
  border-light: "#F3ECE6"
  input-bg: "#FDF6F5"
  guest-card-bg: "#F0EEE3"
  guest-card-text: "#4A5844"
  guest-card-subtext: "#7A8772"
typography:
  display:
    fontFamily: "Nunito, sans-serif"
    fontSize: "32px"
    fontWeight: 800
    lineHeight: 1.1
  headline:
    fontFamily: "Nunito, sans-serif"
    fontSize: "26px"
    fontWeight: 800
    lineHeight: 1.15
  title:
    fontFamily: "Nunito, sans-serif"
    fontSize: "20px"
    fontWeight: 800
    lineHeight: 1.1
  body:
    fontFamily: "Nunito, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.3
  label:
    fontFamily: "Nunito, sans-serif"
    fontSize: "12px"
    fontWeight: 700
    lineHeight: 1.2
rounded:
  sm: "8px"
  md: "14px"
  lg: "16px"
  xl: "18px"
  pill: "24px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#FFFFFF"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
    height: "48px"
  button-google:
    backgroundColor: "{colors.input-bg}"
    textColor: "{colors.text-title}"
    rounded: "21px"
    padding: "10px 20px"
    height: "42px"
  input-text:
    backgroundColor: "{colors.input-bg}"
    textColor: "{colors.text-dark}"
    rounded: "{rounded.lg}"
    padding: "13px 16px"
---

# Design System: Gatálogo

## Overview

**Creative North Star: "O Herbário Felino Acolhedor"**

Gatálogo constrói uma experiência sensorial suave e afetuosa, inspirada em cadernos de campo botânicos e ilustrações infantis artesanais. A identidade visual afasta-se deliberadamente da frieza tecnológica de aplicativos utilitários modernos, optando por uma atmosfera de conto ilustrado onde cada gato encontrado é uma descoberta botânica preciosa.

A paleta fundamenta-se em tons orgânicos de papel envelhecido (`#FBF6F2`), folhagens verdes calmas (`#7E9B70`), rosa pétala suave (`#DC8BA1`) e tipografia marrom-cacau acolhedora (`#382923` e `#4A352F`). Não há cantos pontiagudos ou pretos puros; todas as arestas são suavizadas com curvas generosas e sombras sutis ou ausentes, priorizando a textura e o calor visual.

**Key Characteristics:**
- Ilustrações botânicas delicadas (`Folha_1` a `Folha_6`) integradas holisticamente às margens.
- Cantos arredondados contínuos em todos os elementos estruturais (14px a 24px).
- Tipografia Nunito orgânica e legível com pesos expressivos (600 a 800) em cores terrosas.
- Zero pretos puros; contraste obtido com cafés e marrons quentes.

## Colors

A paleta de cores transmite serenidade, ternura e proximidade com a natureza, dividida em papéis funcionais estritos.

### Primary
- **Blush Petal / Rosa Gatálogo** (`#DC8BA1`): Cor de destaque e chamada principal para ação (CTAs primários, badges de destaque e acentos da marca).
- **Deep Petal** (`#C7607E`): Estados ativos e ênfases de maior contraste sobre superfícies claras.
- **Soft Blush** (`#FCEBE8` / `#FCEDED`): Fundos de badges secundárias e cartões de destaque afetivo.

### Secondary
- **Sage Foliage / Verde Botânico** (`#7E9B70`): Representa a vegetação, avistamentos e natureza.
- **Forest Link / Verde Musgo** (`#5D7A58`): Usado em hiperlinks textuais, setas de navegação e indicadores de ação secundária.
- **Pale Sage** (`#F0EEE3`): Fundo do cartão de acesso sem conta e superfícies utilitárias relaxadas.

### Neutral
- **Warm Paper / Fundo Pergaminho** (`#FBF6F2`): A tela de fundo de toda a aplicação; papel natural levemente aquecido.
- **Pure White** (`#FFFFFF`): Reservado para elementos flutuantes de alto relevo e ícones de contraste sobre o botão primário.
- **Deep Roast / Café Escuro** (`#382923`): Texto corrido e preenchimento de inputs com alto contraste sem dureza óptica.
- **Warm Umber / Marrom Título** (`#4A352F`): Títulos principais e marca Gatálogo.
- **Muted Clay** (`#786B67`): Subtítulos, legendas explicativas e ícones neutros.
- **Blush Border** (`#EDDEDB`): Linha sutil de delimitação em inputs e divisores de conteúdo.
- **Vanilla Cream / Fundo de Input** (`#FDF6F5`): Superfície de acolhimento para digitação de dados.

### Named Rules
**The No-Pure-Black Rule.** O código `#000000` é expressamente proibido no sistema. Toda hierarquia de texto utiliza `#382923`, `#4A352F` ou `#786B67` para preservar o tom quente do herbário.
**The Organic Accent Rule.** O rosa primário (`#DC8BA1`) é reservado para ações de avanço imediato. Ações de navegação passiva ou exploração usam tons neutros ou verde botânico.

## Typography

**Display & Body Font:** Nunito (Google Fonts)  
**Fallback:** sans-serif arredondado nativo

**Character:** Tipografia de formas curvas e terminações arredondadas, combinando extrema legibilidade em telas móveis com uma voz amigável e humana.

### Hierarchy
- **Display** (800 / ExtraBold, 32px, line-height 1.1): Cabeçalhos heróicos e grandes apresentações.
- **Headline** (800 / ExtraBold, 26px, line-height 1.15): Títulos de seções principais da coleção.
- **Title** (800 / ExtraBold, 20px, line-height 1.1): Título de telas de fluxo, como "Entre na sua coleção".
- **Body** (600 / SemiBold e 500 / Medium, 14px, line-height 1.3): Textos informativos, inputs e descrições.
- **Label / Caption** (700 / Bold, 12px a 13px, line-height 1.2): Links auxiliares ("Esqueci minha senha"), botões compactos e tags.

### Named Rules
**The Tight Heading Rule.** Título e subtítulo mantêm espaçamento mínimo (máximo 2-4px vertical) e altura de linha compacta (1.1 a 1.15) para manter o bloco de leitura coeso.

## Layout

O layout adota uma grade fluida centralizada com largura máxima de conteúdo de `340px` a `360px` em dispositivos móveis, adaptando-se confortavelmente entre telas compactas e tablets.

- **Margens de tela:** 24px a 36px horizontais para garantir respiração visual.
- **Elementos decorativos perimetrais:** Folhagens (`Folha_2`, `Folha_4`, `Folha_6`) são fixadas via `Stack` com `IgnorePointer` nas bordas exteriores, sem interferir na rolagem central.
- **Rolagem centralizada:** Todo formulário ou área interativa reside em `SingleChildScrollView` dentro de `SafeArea` para evitar sobreposição de teclado ou entalhes de câmera.

## Elevation & Depth

O Gatálogo adota uma abordagem primordialmente plana e tonal (*tonal layering*), descartando sombras projetadas pesadas. A separação entre planos decorre exclusivamente de contraste de superfícies (`#FBF6F2` vs `#FDF6F5` vs `#F0EEE3`) e bordas delicadas (`1.0px` a `1.2px` em `#EDDEDB`).

### Named Rules
**The Tonal Flatness Rule.** Elementos de formulário e cartões não utilizam sombras suspensas (`box-shadow: none`). A elevação percebida é puramente cromática.

## Shapes

- **Inputs:** Cantos arredondados contínuos com raio de `16px`.
- **Botões de Ação Principal:** Formato pílula (*capsule*) com raio de `24px` (altura 48px).
- **Botões Secundários (Google):** Formato pílula suave com raio de `21px` (altura 42px).
- **Cartões de Recurso ("Explorar sem conta"):** Raio generoso de `18px`.
- **Bordas:** Espessura padrão de `1.2px` com anti-aliasing ativo.

## Components

### Buttons
- **Botão Primário ("Entrar" / "Criar Conta"):** Fundo `#DC8BA1`, altura 48px, raio 24px, ícone sólido branco `Icons.pets` à esquerda, texto Nunito 16px Bold em `#FFFFFF`.
- **Botão Google ("Continuar com Google"):** Fundo `#FDF6F5`, borda 1.0px em `#EDDEDB`, altura 42px, raio 21px, asset oficial `google_logo.png` em 20x20px, texto Nunito 14px Bold em `#4A352F`.

### Inputs / Text Fields
- **Campo de Texto (E-mail / Senha):** Fundo `#FDF6F5`, borda `OutlineInputBorder` com raio 16px e cor `#EDDEDB` (1.2px). Ícones de prefixo em 18px cor `#786B67`. Foco suave em `#DC8BA1`.

### Cards
- **Card Convidado ("Explorar sem conta"):** Fundo `#F0EEE3`, raio 18px, padding horizontal 16px, ícone `LucideIcons.userX` em `#4A5844`, título 14px ExtraBold e subtítulo 11px SemiBold em `#7A8772`.

## Do's and Don'ts

### Do:
- **Do** usar o asset oficial `google_logo.png` para todas as chamadas de login com Google.
- **Do** manter `Icons.pets` sólido e branco nos botões de avanço primário.
- **Do** utilizar `OutlineInputBorder(borderRadius: BorderRadius.circular(16))` para garantir bordas visíveis e renderizadas de forma limpa em qualquer densidade de pixels.
- **Do** posicionar `Folha_2` com inclinação horizontal atravessando a margem superior esquerda.
- **Do** alinhar `Folha_4` paralelamente à lateral esquerda do botão de ação primária.

### Don't:
- **Don't** utilizar ícones vazados/outline na pata do botão primário.
- **Don't** usar texto preto puro `#000000` em nenhuma circunstância.
- **Don't** aproximar excessivamente o gato ilustrado do texto da logo Gatálogo.
- **Don't** adicionar sombras projetadas escuras ou artificiais que quebrem a atmosfera plana artesanal.
