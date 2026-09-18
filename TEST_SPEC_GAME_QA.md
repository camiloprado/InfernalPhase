# ESPECIFICAÇÃO DE TESTES TÉCNICOS E DESIGN QA: TOP-DOWN BULLET HELL

Este documento estabelece o protocolo integral de validação para Infernal Phase (Godot 4.7.2, GL Compatibility, um floor). Abrange integridade visual, tilesets, portas, combate, controles, walkers, diálogo do Concierge, SFX e auditoria de spritesheets.

Harness: `./run.sh -- --qa-play`  
Cada `QA_ITEM` grava um still em `gate/spec/<id>.png`. Look plates extras: `./run.sh -- --qa-look --qa-proof`.

---

## 1. DESIGN VISUAL, TILESETS E PIXEL ART AUDIT

### 1.1 Floor e Paredes (Autotiling & Seams)
* [ ] **Costuras e Seams (Gaps de 1px):** Caminhar por todas as junções de tiles do chão. Nenhuma linha de fundo, cor vazia ou "fissura" de 1 pixel pode aparecer entre os blocos durante o movimento da câmera.
* [ ] **Contraste de Fundo vs. Gameplay:** O piso não pode conter ruído visual de alto contraste que compita com a visibilidade de tiros e inimigos pequenos. Projéteis devem ser 100% legíveis sobre qualquer parte do chão.
* [ ] **Alinhamento de Paredes e Sombras:** As paredes superiores e laterais devem manter perspectiva consistente. Sombras projetadas no chão não podem ter colisores físicos invisíveis que travem o movimento do jogador.
* [ ] **Repetição Textural (Tiling Fatigue):** Verificar se o chão parece um padrão quadriculado repetitivo e artificial. Variações sutis de tiles devem estar espalhadas sem quebrar a harmonia.
* [ ] **Env bind (não checker vazio):** Tiles de `env.png` nas linhas 1–3 (64px). Linhas 0 e 4 são vazias e **não** podem ser o tema da sala. Combate = pedra/lava + parede Ash, não ColorRect Void/Ash no lugar da ficha.

### 1.2 Integridade do Pixel Art e Spritesheets
* [ ] **Modo de Filtragem (Point / Nearest Neighbor):** Todos os assets (cenário, entidades, HUD, partículas) devem estar estritamente configurados com amostragem *Nearest*. Zero interpolação bilinear (proibido texturas embaçadas ou suaves).
* [ ] **Pixel Mixels (Densidade Inconsistente):** Nenhum sprite em cena pode possuir densidade de pixels por unidade (PPU) diferente dos demais. Um "pixel" do jogador deve ter rigorosamente as mesmas dimensões no mundo que um "pixel" do cenário ou do Boss.
* [ ] **Subpixel Rendering e Jitter:** Sprites em repouso ou em movimento lento não podem renderizar em frações de pixel. O renderizador deve forçar arredondamento de coordenadas (*Pixel Snapping*) para evitar que as bordas dos sprites tremam ou deformem.
* [ ] **Sangramento de Spritesheet (Texture Bleed):** Checar todas as animações (Walk, Attack, Hurt, Death) contra fundos escuros e claros. Não deve haver bordas estranhas ou fragmentos de frames vizinhos do spritesheet aparecendo na borda do quadro.
* [ ] **Escala e Proporção:** Escala X e Y devem ser estritamente simétricas (escala $1:1$). Sprites não podem achatar ou esticar durante transições de rotação ou animações de andar.
* [ ] **Pivot no corpo:** Sprite e collider compartilham origem (top-down). Offset de chão estilo side-scroller é FAIL.
* [ ] **Print por ficha:** Um still por walker / inimigo / porta / drop / HUD, com a ficha visível e o pivot no centro do ator.

---

## 2. MECÂNICA DE SALAS, PORTAS E TRANSIÇÕES

### 2.1 Fechamento e Bloqueio
* [ ] **Trancamento Imediato:** Ao cruzar a entrada de uma sala hostil, as portas devem fechar e trancar no mesmo frame em que o primeiro monstro surge.
* [ ] **Anti-Trava no Batente:** Se o jogador tentar recuar no frame exato em que a porta tranca, o colisor deve empurrá-lo para dentro da sala de combate, nunca prensá-lo dentro do colisor da parede ou expulsá-lo para fora com a sala trancada.
* [ ] **Paredes Herméticas:** Projéteis do jogador e dos monstros não podem atravessar paredes ou portas fechadas para acertar entidades em outras salas.
* [ ] **Arco visível:** A sala atual desenha `doors.png` (4×2 de 384×512), escala uniforme, posição inteira, coroa para dentro. Vizinha não empilha um segundo arco no mesmo vão.

### 2.2 Desfecho de Sala e Persistência
* [ ] **Gatilho de Conclusão:** A morte do último inimigo da sala deve disparar:
  * Abertura simultânea de todas as saídas.
  * Toca do SFX de sala liberada (`unlock`).
  * Spawn de recompensas/drops no centro ou ponto predeterminado.
* [ ] **Idempotência (Salas Visitadas):** Sair da sala limpa e retornar não pode reviver inimigos, trancar portas novamente ou regenerar baús e drops já coletados.
* [ ] **I-Frames de Entrada:** Ao entrar em uma nova sala, o jogador deve ter uma janela segura de $0.3$ a $0.5$ segundos de imunidade ou garantia de que nenhum inimigo ou tiro surja colado no ponto de entrada.

### 2.3 Mapa completo (um floor)
* [ ] **Threshold (start):** Pit `pit.png`, Caim 64px, portas norte/leste/oeste/sul.
* [ ] **North / West / East / South / SE:** Cada combate usa ficha de inimigo (imp, wretch, cantor/cultist) — print da sala com atores no chão.
* [ ] **NPC Concierge:** `concierge.png` 80px, dais de env, diálogo de RPG.
* [ ] **Boss (THE PHASE):** Boss ≥ 1.25× o player, anel com miolo seguro.
* [ ] **Deep (fosso):** Teleporte do pit; walker ainda é Caim, não o imp de espada.

---

## 3. COMBATE, HITBOXES E BULLET HELL (PADRÃO UNDERTALE)

### 3.1 Precisão de Hurtbox e Hitbox
* [ ] **Micro-Hurtbox do Jogador:** A área vulnerável do jogador deve ser reduzida (núcleo do personagem, no estilo bullet hell) e centralizada, permitindo raspagens precisas entre tiros densos sem levar dano indevido.
* [ ] **Visualização de Debug:** Ativar renderizador de colisão:
  * Verde = Hurtbox (área que recebe dano).
  * Vermelho = Hitbox ativa (área que causa dano).
  * Azul = Colisor de física/terreno (navegação no chão).
* [ ] **Alinhamento do Ataque:** A ponta do cano/arma do jogador deve ser a coordenada exata de spawn dos projéteis, tanto parado quanto correndo ou atirando na diagonal.

### 3.2 Padrões de Projéteis do Boss e Solvabilidade
* [ ] **Esquivabilidade Matemática:** Nenhum padrão procedural ou pré-programado de projéteis pode criar uma linha contínua de 100% de cobertura de parede a parede sem rota física de desvio.
* [ ] **Ciclo de Vida das Balas:**
  * Projéteis que atingem paredes se desintegram imediatamente.
  * Projéteis que atingem o jogador são destruídos (a menos que possuam a propriedade explícita de perfuração).
  * Descarte de balas em massa (Memory Pool) sem acúmulo de instâncias inativas na memória.
* [ ] **I-Frames do Jogador:** Tomar dano ativa piscar visual no sprite do jogador. Ficar em cima de um tiro persistente não pode causar $10$ hits no mesmo segundo. (Jogo: `IFRAME_MS=550`; spec clássico pedia 1–1.5s.)
* [ ] **Ficha de tiro:** `shots.png` 4×8 de 64, nearest, diamante Ember / anel Bone — nunca `_draw` de corpo.

---

## 4. MAPEAMENTO DE ENTRADAS, CONTROLES E COMANDOS

### 4.1 Comandos Essenciais
* [ ] **Movimento 8-Direções:** Testar direções cardinais (`W`, `A`, `S`, `D` ou Setas) e diagonais (`W+D`, `S+A`, etc.). A velocidade normalizada na diagonal não pode ser $\sqrt{2}$ mais rápida que a velocidade reta; o vetor precisa ser normalizado para $1.0$.
* [ ] **Mira e Disparo 360° ou 4-Direções:**
  * Se disparo for via mouse: o tiro segue o ângulo exato do cursor com precisão angular estrita.
  * Se for via teclas dedicadas (estilo Isaac com setas): o tiro aceita a última tecla pressionada ou composição angular definida pela regra do jogo.
* [ ] **Esquiva / Dash (se aplicável):** Acionamento interrompe aceleração anterior e concede I-Frames temporários durante o deslocamento rápido. *Este twin-stick não tem dash — SKIP.*

### 4.2 Robustez de Entradas
* [ ] **Input Ghosting:** Pressionar movimento simultâneo oposto (`A` + `D` ou `W` + `S`) deve neutralizar o movimento em vez de travar o personagem ou acelerar infinitamente.
* [ ] **Input Buffer:** Apertar o comando de disparo ou ação frações de segundo antes do fim do cooldown do tiro anterior deve registrar o comando e executá-lo imediatamente no próximo frame livre.
* [ ] **Perda de Foco do Sistema:** Pressionar `Alt+Tab` ou clicar fora da janela durante movimentação contínua não pode prender a tecla na memória (personagem não pode continuar andando sozinho para sempre após a perda de foco).

---

## 5. CICLO DE VIDA DO JOGO (PERMADEATH & RESTART)

* [ ] **Morte do Jogador:** Ao chegar a $0$ de HP:
  * Desativação imediata da hitbox e da física do jogador.
  * Sem tiro zumbi.
  * Overlay YOU DIED + `R` / Enter.
* [ ] **Reinicialização Limpa (Soft Reset):** Acionar o restart deve:
  * Resetar HP do jogador ao valor inicial máximo.
  * Redefinir a sala atual e todas as outras salas do mapa com seus inimigos originais.
  * Destruir imediatamente todas as balas de monstros ainda em voo da tentativa anterior.
  * Restaurar o Boss com vida cheia e reiniciar seus padrões de ataque do estágio 1.
* [ ] **Vitória sobre o Boss:** Quando a vida do Boss chega a zero:
  * Todas as balas inimigas na tela se dissipam imediatamente (evita morte injusta pós-vitória).
  * Inicia sequência de vitória/saída sem congelamento de tela.

---

## 6. PERFORMANCE E ESTABILIDADE

* [ ] **Saturação de Projéteis:** Instanciar a carga máxima de projéteis simultâneos do Boss. A taxa de quadros (FPS) deve permanecer cravada na taxa alvo (60 FPS padrão), sem flutuações de delta time que afetem a precisão física da colisão.
* [ ] **Vazamento de Memória (Memory Leak):** Jogar $15$ tentativas consecutivas de morte e reinício. O consumo de memória RAM do processo deve se estabilizar em um teto e não escalar continuamente a cada restart.

---

## 7. START CARD E WALKERS

* [ ] **Retrato Caim:** Preview `player.png` idle, nearest, sem polígono Penitente. Print `PLAY-MENU-01`.
* [ ] **Retrato Lilith:** Preview `player_f.png` (cabelo mais longo). Print `PLAY-MENU-02`.
* [ ] **Retrato Bebê Chorão:** Preview `baby.png`, esconde Caim/Lilith. Print `PLAY-MENU-03`.
* [ ] **Caim in-world:** 4×3 idle/walk/shoot, altura ~64px, `caim_own=1`, pivot centrado, pos inteira. Print `PLAY-SHEET-CAIM`.
* [ ] **Lilith in-world:** mesma grade, ficha distinta (md5 ≠ Caim). Print `PLAY-SHEET-LILITH`.
* [ ] **Bebê in-world:** `baby.png` visível, `_sheet` nulo, deflect de tiro inimigo, SFX choro. Print `PLAY-SHEET-BABY`.
* [ ] **Hierarquia:** Wretch > player; imp e cantor ≤ player; boss ≥ 1.25×; Concierge ~80px.

---

## 8. HUD, DROPS E FICHAS DE UI

* [ ] **Hearts:** `hearts.png` 4×1 de 64, nearest, à esquerda. Cheio / vazio / hit. Print `PLAY-SHEET-HEARTS`.
* [ ] **Skills no HUD:** `skills.png` só aparece com pierce/rapid/heavy/burn.
* [ ] **Drops no chão:** `pickups.png` 3×1 e skills, ~48px, nearest, bob. Print `PLAY-SHEET-PICKUP`.
* [ ] **Minimap:** nós de sala; current com anel Bone. Print `PLAY-HUD-LAYOUT`.
* [ ] **Flavor / overlay:** não cobrem o walker; YOU DIED usa Void + Bone type.

---

## 9. CONCIERGE — DIÁLOGO RPG

* [ ] **Trigger:** Entrar no raio do Concierge abre caixa (não só flavor solto).
* [ ] **Caixa:** painel tile `env.png`, retrato de quem fala, nome Ember, texto Bone, hint E/Space/Click.
* [ ] **Script:** Concierge pede badge; Caim / Lilith / Bebê respondem diferente; grant na primeira visita.
* [ ] **Lock:** durante o diálogo o walker não anda nem atira.
* [ ] **Avanço:** E / Space / clique; fecha no último line e libera input.
* [ ] **Print:** `PLAY-DIALOGUE` com a caixa aberta e o NPC no frame.

---

## 10. ÁUDIO SFX (SEM OGG DE CAMA)

* [ ] **Stingers:** shoot, hit, pickup, door (tranca), unlock (sala limpa), talk, death.
* [ ] **Bebê:** `cry.wav` no lugar de `cry.ogg` loop.
* [ ] **Ambience:** rumble baixo, não `floor.ogg`.
* [ ] Autoload `Sfx` bound; miss de WAV não aborta o floor.

---

## 11. AUDITORIA DE ESTILO E POSIÇÃO DE CADA SHEET

Para **cada** ficha abaixo: nearest (ou inherit do default nearest), `scale.x == scale.y`, pivot centrado no ator, coordenada global em pixel inteiro (±0.51), altura de mundo na faixa da hierarquia. Still em `gate/spec/<id>.png`.

| ID | Sheet | Grid / nota | Altura mundo |
| --- | --- | --- | --- |
| PLAY-SHEET-CAIM | `player.png` | 4×3 | ~64 |
| PLAY-SHEET-LILITH | `player_f.png` | 4×3 | ~64 |
| PLAY-SHEET-BABY | `baby.png` | 1×1 | ~72 |
| PLAY-SHEET-IMP | `imp/walk_vanilla.png` | anim | ≤ player |
| PLAY-SHEET-WRETCH | `wretch.png` | > player | ~80 |
| PLAY-SHEET-CANTOR | `cantor.png` | ≤ player | ~58 |
| PLAY-SHEET-BOSS | `boss/idle.png` | ≥ 1.25× player | ~115 |
| PLAY-SHEET-NPC | `concierge.png` | 4×2 | ~80 |
| PLAY-SHEET-DOORS | `doors.png` | 4×2 384×512 | escala uniforme, pos `.round()` |
| PLAY-SHEET-ENV | `env.png` | 3×5 de 64, rows 1–3 | tiles no grid 64 |
| PLAY-SHEET-SHOT | `shots.png` | 4×8 de 64 | ~24 |
| PLAY-SHEET-PICKUP | `pickups.png` / `skills.png` | 3×1 / 4×1 | ~48 |
| PLAY-SHEET-HEARTS | `hearts.png` | 4×1 de 64 | HUD 40px |
| PLAY-SHEET-PIT | `env/pit.png` | 1×1 | escala 0.25, Void underlay |
| PLAY-SHEET-CAIM-IDLE | `player.png` row 0 | 4×3 cell 0 | ~64, pivot centro |
| PLAY-SHEET-CAIM-WALK | `player.png` row 1 | 4×3 walk | ~64, sem squash |
| PLAY-SHEET-CAIM-SHOOT | `player.png` row 2 | 4×3 shoot | pistola visível |
| PLAY-SHEET-SKILLS | `skills.png` | 4×1 | HUD ~22px, só com loadout |

FAIL se: filtro linear, squash (`scale.x ≠ scale.y`), pivot deslocado, pos fracionária, ficha errada (Caim = Lilith / bebê / capuz), tile na row 0/4 vazia.

---

## 12. PROTOCOLO DE PRINTS

1. Rodar `./run.sh -- --qa-play`.
2. Confirmar `QA_PLAY ok=1` e **uma PNG por `QA_ITEM`** em `gate/spec/<id>.png` (menu, arts, move, portas, sheets, salas, diálogo, SFX, combate, ciclo).
3. Abrir os `PLAY-SHEET-*` e conferir à olho: nearest, sem bleed da célula vizinha, ator no centro do still, porta no vão, HUD no topo, escala 1:1.
4. `PLAY-DIALOGUE` / `PLAY-DIALOGUE-LILITH` / `PLAY-DIALOGUE-BABY`: caixa na base, retrato à esquerda (ficha certa), texto Bone sobre o tile Ash.
5. `PLAY-ROOM-*`: uma still por sala do grafo (start, north, west, east, south, se, npc, boss, deep). Env nas rows 1–3, sem ColorRect Void no lugar do piso.
6. `PLAY-SHEET-CAIM-IDLE/WALK/SHOOT`: as três linhas da grade 4×3, sem misturar walk no idle.
7. `PLAY-SHEET-SKILLS`: quatro pips de `skills.png` no HUD depois de pierce/rapid/heavy/burn.

---

## 13. ANIMAÇÃO DAS FICHAS (CÉLULAS DA GRADE)

* [ ] **Caim idle:** row 0, casaco Bone, marca Ember no peito, cabelo curto/preso. Print `PLAY-SHEET-CAIM-IDLE`.
* [ ] **Caim walk:** row 1, mesmos ombros/botas, sem puxar célula de shoot. Print `PLAY-SHEET-CAIM-WALK`.
* [ ] **Caim shoot:** row 2, pistola no quadro, pivot ainda no tronco. Print `PLAY-SHEET-CAIM-SHOOT`.
* [ ] **Lilith idle:** `player_f.png` cabelo longo, mesma grade. Print `PLAY-SHEET-LILITH`.
* [ ] **Bebê:** `baby.png` 1×1 visível, `_sheet` nulo. Print `PLAY-SHEET-BABY`.
* [ ] **Inimigos:** imp / wretch / cantor / boss cada um na própria ficha, Wretch > Caim, boss ≥ 1.25×. Prints `PLAY-SHEET-IMP` … `PLAY-SHEET-BOSS`.
* [ ] **Bleed:** no still, fundo Void `#0B0C10` sem filete da célula vizinha na borda do quadro.

---

## 14. HUD DE SKILLS E LAYOUT

* [ ] **Skills ocultas** no HUD padrão (sem pierce/rapid/heavy/burn).
* [ ] **Skills visíveis** com os quatro loadouts. Print `PLAY-SHEET-SKILLS`.
* [ ] **Hearts + minimap + walker label** no topo. Print `PLAY-HUD-LAYOUT`.
* [ ] **YOU DIED** não entra neste still (ciclo tem `PLAY-DEATH` / `PLAY-RESTART`).

---

## 15. GRAFO COMPLETO DO FLOOR (STILL POR SALA)

* [ ] Start / Threshold com pit. `PLAY-ROOM-START`
* [ ] North (imps). `PLAY-ROOM-NORTH`
* [ ] West (wretch). `PLAY-ROOM-WEST`
* [ ] East (cantor). `PLAY-ROOM-EAST`
* [ ] South (cultists). `PLAY-ROOM-SOUTH`
* [ ] SE (wretch pack). `PLAY-ROOM-SE`
* [ ] NPC Concierge + dais. `PLAY-ROOM-NPC`
* [ ] Boss THE PHASE. `PLAY-ROOM-BOSS`
* [ ] Deep (depois do pit). `PLAY-ROOM-DEEP`

Em cada still: tiles env, portas no vão, nenhum checker Isaac, nenhum ColorRect no lugar da ficha de chão/parede.

---

## 16. DIÁLOGO POR WALKER

* [ ] Caim: retrato `player.png`, lock de input. `PLAY-DIALOGUE`
* [ ] Lilith: retrato `player_f.png`, fala “I quit…”. `PLAY-DIALOGUE-LILITH`
* [ ] Bebê: retrato `baby.png`, fala “Waa—”. `PLAY-DIALOGUE-BABY`
* [ ] Caixa tile `env.png` row 1–3, nome Ember, hint E/Space/Click.

---

## 17. SFX BIND (WAV, SEM OGG DE CAMA)

* [ ] Autoload `Sfx` com shoot, hit, pickup, door, unlock, talk, death, cry + ambience. Print `PLAY-SFX-BIND` (still do floor no instante do assert).
* [ ] Nenhum `*.ogg` de cama no autoload. Miss de WAV não aborta o floor.

### DIRETRIZ MANDATÓRIA DE ASSETS VISUAIS (RESTRIÇÃO ESTRITA)

1. PROIBIÇÃO DE VETORES E PLACEHOLDERS:
- É terminantemente proibido desenhar shapes procedurais, primitivas geométricas ou vetoriais (ex: `draw_rect`, `draw_circle`, `pygame.draw`, canvas primitives, gráficos vetoriais nativos) para substituir elementos de jogo.
- Não crie funções de fallback que substituam texturas por blocos coloridos ou desenhos por código.

2. OBRIGATORIEDADE DE TEXTURAS .PNG:
- Todos os elementos visuais do cenário e entidades — incluindo portas, buracos/abismos (pits), chão, paredes, monstros, boss e tiros — DEVEM carregar e renderizar exclusivamente seus respectivos arquivos `.png` existentes no diretório de assets.
- Caso um arquivo `.png` falhe ao carregar, NUNCA altere a arte nem injete código vetorial para mascarar o problema. Lance uma exceção explícita com o caminho do arquivo (`FileNotFoundError` ou log de erro fatal) para que o caminho do asset seja corrigido.

3. PRESERVAÇÃO DE ASSETS EXISTENTES:
- É proibido deletar, sobrescrever ou desvincular arquivos `.png` da pasta de assets ou do código de renderização.
- Mantenha a chamada original de carregamento de texturas e o mapeamento de spritesheets/tilesets intactos.