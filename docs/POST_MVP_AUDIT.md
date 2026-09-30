# Auditoria pós-MVP — GDD × As-Built

Tarefa 15. Documento criado pela auditoria obrigatória dos parágrafos 3–7 e 62–65 da spec.

Base da auditoria:

```text
commit auditado        = 5fff237 feat: add level 2 abyssal core evolution
GDD                    = GDD.txt (não alterado por esta tarefa)
seções lidas do GDD    = §7 Núcleo Abissal, §8 Níveis do Núcleo, §9 Integridade,
                         §10 Energia, §11 Recursos principais, §17 Salas, §18 Construção,
                         §19 População, §20-24 Unidades, §75 Save, §83-87 Arquitetura
                         técnica, §88 MVP, §89 Loop exato do MVP, §90 Critério de
                         sucesso, §91 Vertical Slice, §95 O que não entra no MVP,
                         §104 Estado do projeto
método                 = cada linha "As-Built" foi confirmada em arquivo concreto do
                         repositório; nenhuma linha assume comportamento não lido
```

Este documento **não decide** qual lado está certo. Ele registra onde o jogo implementado
diverge do documento mestre, para que a decisão de design seja tomada por quem escreve o GDD.

---

## 1. Tabela GDD × As-Built

Classificações usadas (parágrafo 5 da spec):

```text
IMPLEMENTADO COMO GDD     o comportamento do código é o que o GDD descreve
IMPLEMENTADO DIFERENTE    existe uma versão do recurso, mas com outra regra/valor
NÃO IMPLEMENTADO          o GDD descreve, o código não tem
IMPLEMENTAÇÃO EXTRA       o código tem algo que o GDD não pede
```

| # | Item | GDD | As-Built (evidência) | Status |
| --- | --- | --- | --- | --- |
| 1 | Núcleo único Nv.1 → Nv.2 | §88: "1 Núcleo, Nv.1 → Nv.2" | `data/core/core_level_1.tres`, `data/core/core_level_2.tres`, `CoreState.evolve_to()` | IMPLEMENTADO COMO GDD |
| 2 | Trabalhadores no início do MVP | §89: "3 trabalhadores" | 1 Worker na cena (`game/game_main.gd:22`, `Worker001`) + exatamente 1 invocável (`systems/population/worker_invocation_controller.gd:4` `SUMMONED_UNIT_ID = "worker_002"`, guarda `if _summoned_worker != null`) → máximo 2 | IMPLEMENTADO DIFERENTE |
| 3 | Essência | §11, §10: recurso mágico, atual/máximo | `CoreState.essence`/`max_essence`, geração por `essence_generation_rate` | IMPLEMENTADO COMO GDD |
| 4 | Biomassa | §88, §11: segundo recurso central | inexistente — só existe `data/resources/iron_ore.tres` | NÃO IMPLEMENTADO |
| 5 | Minério | §88, §11: "obtido em minas, ruínas, comércio" | obtido por escavação de rocha com `yield_resource` (`data/environment/iron_ore_rock.tres`); não há mina nem comércio | IMPLEMENTADO DIFERENTE |
| 6 | Cristais Abissais | §88: "Cristais entram como recompensa final"; §89 passo 10 "receber Cristal" | inexistentes como recurso; não há `CristalDefinition` nem estoque de cristal | NÃO IMPLEMENTADO |
| 7 | Gatilho da evolução do Núcleo | §89: sobreviver à invasão → **receber Cristal** → evoluir | sobreviver à invasão (`invasion_victory`) → **25 Essência** (`evolution_essence_cost` em `core_level_2.tres`) → tecla V | IMPLEMENTADO DIFERENTE |
| 8 | Salas do MVP | §88: Núcleo, Ninho, **Mina**, Quartel | Núcleo (`CoreRuntime`), Ninho (`NestRuntime`), Quartel (`BarracksRuntime`); Mina não existe — o depósito é `ResourceDepositRuntime`, um ponto de entrega, não uma sala construída | NÃO IMPLEMENTADO (Mina) |
| 9 | Níveis do Núcleo | §8: tabela Nv.1–Nv.10 | Nv.1 e Nv.2 apenas | IMPLEMENTADO COMO GDD (escopo MVP; §95 exclui o resto) |
| 10 | Population base Nv.1 | §8: 8 | `core_level_1.tres` `population_capacity = 8` | IMPLEMENTADO COMO GDD |
| 11 | Population base Nv.2 | §8: **16** | `core_level_2.tres` `population_capacity = 12` | IMPLEMENTADO DIFERENTE |
| 12 | Salas principais Nv.1 | §8: 4 | 3 salas construídas/construíveis (Núcleo, Ninho, Quartel) + depósito pré-existente | IMPLEMENTADO DIFERENTE |
| 13 | Limite populacional efetivo | §8: população base | base + `population_capacity_bonus` do Ninho (+4) → 12 no Nv.1, 16 no Nv.2 (`CoreState.get_population_capacity()`) | IMPLEMENTAÇÃO EXTRA (conceito de bônus por sala não está no §8) |
| 14 | Integridade / Game Over | §9: "Se chegar a zero: Game Over" | `CoreState.damage()` → `destroyed` → `InvasionController` entra em `DEFEAT`; não há tela de Game Over, reinício nem perda de campanha | IMPLEMENTADO DIFERENTE |
| 15 | 1 inimigo | §88: "1 inimigo — Criatura selvagem" | `data/units/enemies/cave_beast.tres` (Fera Cavernosa), uma Definition, duas instâncias por invasão | IMPLEMENTADO COMO GDD |
| 16 | 1 invasão | §88: "1 invasão" | `InvasionController`, exatamente uma onda de 2 Feras, sem fila de largadas | IMPLEMENTADO COMO GDD |
| 17 | Preparação/defesa antes da invasão | §89 passo 8 "preparar defesa" | `PREPARATION` de 60 s com aviso (`preparation_duration`, `InvasionWarningHud`) — o gatilho por temporizador é decisão de implementação, o GDD não especifica duração nem aviso | IMPLEMENTAÇÃO EXTRA |
| 18 | Construção: custo | §18: "custo" | `build_resource` + `build_cost` consumidos atomicamente do estoque | IMPLEMENTADO COMO GDD |
| 19 | Construção: tempo | §18: "tempo" | modelado como `work_required` (unidades de trabalho), não como segundos de relógio | IMPLEMENTADO DIFERENTE |
| 20 | Construção: espaço, trabalhadores necessários, requisitos, manutenção | §18 | nenhum dos quatro existe: sala não ocupa cells, não exige N trabalhadores, não tem pré-requisito de sala anterior, não tem manutenção | NÃO IMPLEMENTADO |
| 21 | Módulos de sala (Quartel Nv.2, arsenal…) | §18 | inexistente | NÃO IMPLEMENTADO |
| 22 | População em 5 grupos | §19: Trabalhadores, Soldados, Especialistas, Comandantes, Heróis | 2 grupos: Worker, Soldier (+ Enemy não-populacional) | IMPLEMENTADO DIFERENTE (previsto: §95) |
| 23 | Unidades persistentes com estado individual | §20–§24: atributos, XP, traços, ferimentos, moral | `WorkerState`/`SoldierState`/`EnemyState` só carregam saúde (e carga/cargo no Worker) | NÃO IMPLEMENTADO (previsto: §95) |
| 24 | Máquina de estados de unidade | §86: IDLE, MOVE, WORK, ATTACK, DEFEND, FLEE, DOWNED, DEAD | Worker `ActionMode {IDLE, MOVE, EXCAVATE, COLLECT, DELIVER, BUILD}`; Soldier `{IDLE, MOVE, ATTACK}`; Enemy `{IDLE, ADVANCE, COMBAT}` — sem DEFEND, FLEE, DOWNED, DEAD como estado (morte remove a instância) | IMPLEMENTADO DIFERENTE |
| 25 | `Definition → State → Runtime → Visual` | §83 | é exatamente a estrutura do projeto, em todas as famílias (§3 abaixo) | IMPLEMENTADO COMO GDD |
| 26 | Conteúdo data-driven em Resources | §84 | 10 `.tres` de dados em `data/`; nenhum número de gameplay hardcoded nos Runtimes | IMPLEMENTADO COMO GDD |
| 27 | Managers globais | §85: RunManager, WorldManager, DungeonManager, EconomyManager, PopulationManager, ArmyManager, DiplomacyManager, AssimilationManager, EventManager, SaveManager | nenhum deles existe; o projeto usa controllers com dependências injetadas por `GameMain` | IMPLEMENTADO DIFERENTE (deliberado — ver §4) |
| 28 | Save | §75 | `SaveGameController` + `CampaignSnapshot`: a campanha inteira em `user://campaign_save.json` (`save_version = 1`), escrita atômica com backup, Ctrl+S/Ctrl+L pelo InputMap; schema documentado em `docs/SAVE_SCHEMA_V1.md` | IMPLEMENTADO COMO GDD (Tarefa 18) |
| 29 | Sistema de Ameaça | §13 | `InvasionController` tem uma única invasão roteada; não há medidor de ameaça | NÃO IMPLEMENTADO (previsto: §95) |
| 30 | Mapa regional, diplomacia, facções, expedições | §40–§49, §51 | inexistentes | NÃO IMPLEMENTADO (previsto: §95) |
| 31 | Avatar do jogador e dois modos de controle | §31, §32 | inexistentes — só há RTS | NÃO IMPLEMENTADO (previsto: §95) |
| 32 | Meta de performance | §87: 60 FPS com 200–300 unidades em batalhas grandes | cena máxima real: 2 Workers + 1 Soldier + 2 invasores + 9 painéis de HUD; nenhum benchmark formal | NÃO IMPLEMENTADO (fora do MVP) |
| 33 | Primeiro marco (§104) | "começar com o Núcleo Nv.1 e sobreviver até evoluí-lo para Nv.2, sem comandos especiais de debug" | alcançado de ponta a ponta por teclado e mouse: escavação/coleta por comando de seleção, I Worker, B Ninho, K Quartel, R Soldado, F invasão, V evolução — provado em `tests/test_core_evolution.gd` e no teste visual da Tarefa 14 | IMPLEMENTADO COMO GDD |

### Decisões de design que ficam pendentes

Nenhuma foi tomada por esta tarefa:

```text
D1  MVP com 2 ou 3 Workers                      (linha 2)
D2  Evolução por Essência ou por Cristal        (linhas 6 e 7)
D3  Population base do Nv.2: 12 ou 16           (linha 11)
D4  Mina como sala construída vs depósito atual (linha 8)
D5  Biomassa entra agora ou no Vertical Slice   (linha 4)
D6  Integridade zero: Game Over real ou DEFEAT sem tela (linha 14)
D7  Custo de construção em tempo ou em trabalho (linha 19)
```

Lista preservada como registrada na auditoria. Todas as sete foram decididas depois, na
Tarefa 16 — ver §8 ao final deste documento e `docs/DESIGN_DECISIONS_POST_MVP.md`.

---

## 2. Camadas do projeto

```text
Definition    Resource de dados puros (core/definitions/*.gd + data/**/*.tres).
              Nenhum comportamento, nenhum Node, nenhum número em código.
State         RefCounted com os valores da partida (core/state/*.gd).
              Não conhece cena, câmera, input nem HUD.
Runtime       Node da cena que representa o State no mundo (world/, units/).
Controller    Node de sistema que recebe dependências por setup() e trata input
              (systems/). Não procura nada na árvore nem em registry global.
Visual/UI     Nós de cena e HUDs que só reagem a signal (ui/).
Composition   game/game_main.gd: único lugar que conhece todos os sistemas e os
Root          conecta. Nenhum autoload, nenhum EventBus, nenhum singleton.
```

---

## 3. Estado das famílias

| Família | Definition | State | Runtime | Controller | Visual/UI |
| --- | --- | --- | --- | --- | --- |
| Core | `core_definition.gd` | `core_state.gd` | `world/dungeon/core/core_runtime.gd` | `systems/progression/core_evolution_controller.gd` | `CoreDebugHud`, `CoreEvolutionDebugHud` |
| Worker | `worker_definition.gd` | `worker_state.gd` | `units/workers/worker_runtime.gd` | `systems/population/worker_invocation_controller.gd` | `WorkerInvocationDebugHud` |
| Soldier | `soldier_definition.gd` | `soldier_state.gd` | `units/soldiers/soldier_runtime.gd` | `systems/population/soldier_recruitment_controller.gd` | `MilitaryDebugHud`, `CombatDebugHud` |
| Enemy | `enemy_definition.gd` | `enemy_state.gd` | `units/enemies/enemy_runtime.gd` | `systems/combat/invasion_controller.gd` | `CombatDebugHud` |
| Rock | `rock_definition.gd` | `rock_state.gd` | `world/dungeon/rock/rock_runtime.gd` | — (o Worker é quem escava) | — |
| Resources | `resource_definition.gd` | `resource_pile_state.gd`, `resource_stockpile_state.gd` | `resource_pile_runtime.gd`, `resource_deposit_runtime.gd` | — | `ResourceDebugHud` |
| Nest | `nest_definition.gd` | `nest_state.gd` | `world/dungeon/rooms/nest/nest_runtime.gd` | `systems/construction/construction_controller.gd` | `ConstructionDebugHud` |
| Barracks | `barracks_definition.gd` | `barracks_state.gd` | `world/dungeon/rooms/barracks/barracks_runtime.gd` | `systems/construction/construction_controller.gd` | `MilitaryDebugHud` |
| Invasion | — (usa `enemy_definition.gd`) | — (estado é um enum do controller) | — | `systems/combat/invasion_controller.gd` | `InvasionDebugHud`, `InvasionWarningHud` |
| Evolution | — (usa `core_definition.gd` de destino) | — (vive em `CoreState`) | — (visual está em `CoreRuntime`) | `systems/progression/core_evolution_controller.gd` | `CoreEvolutionDebugHud` |
| RTS | — | — | — | `systems/selection/selection_controller.gd`, `camera/camera_controller.gd` | `SelectionBox` |

Observações de forma:

```text
Invasion  não tem State próprio: o ciclo NOT_STARTED/PREPARATION/ACTIVE/VICTORY/DEFEAT é
          interno ao controller e exposto por invasion_state(). É a única família sem
          separação State/Runtime — aceitável porque não há entidade "invasão" no mundo.
Evolution idem: não criou State nem Runtime próprio (parágrafo 16/25 da Tarefa 14); a
          evolução é uma troca de Definition dentro do CoreState/CoreRuntime existentes.
Core      é a única família com dois níveis de Definition e um único Runtime.
```

---

## 4. Decisões arquiteturais preservadas

```text
Definition → State → Runtime → Visual        em todas as famílias (§83 do GDD)
GameMain como composition root               única origem de toda ligação entre sistemas
Controllers por responsabilidade             construction / population ×2 / selection /
                                             invasion / progression
Injeção explícita por setup()                dependências chegam prontas; nada é buscado
                                             por nome na árvore nem em registro global
Sem EventBus                                 sinal direto entre dois nós que se conhecem
Sem Service Locator                          proibido pelos parágrafos 33-34 da spec
Sem managers globais                         decisão consciente contra §85 do GDD
Sem autoload                                 0 autoloads em project.godot
Resources como dados                         todo número de gameplay está em .tres
States sem Nodes                             RefCounted puro, testável sem cena
HUDs só por signal                           nenhum _process de leitura de estado
mouse_filter IGNORE nos painéis              HUD nunca engole clique do mundo
```

`GameMain._ready()` tem ~65 linhas de composição. Isso é proposital: é o preço de não ter
singleton. Registrar, não "resolver".

---

## 5. Duplicação: o que foi consolidado e o que ficou

### 5.1 Consolidada nesta tarefa (duplicação comprovada por dois tipos independentes)

```text
NestDefinition  ×  BarracksDefinition   →  ConstructionDefinition
  build_resource, build_cost, work_required

NestState       ×  BarracksState        →  ConstructionState
  definition, instance_id, remaining_work, apply_work(), is_completed(),
  work_changed(remaining, total), construction_completed

NestRuntime     ×  BarracksRuntime      →  ConstructionRuntime
  state, definition, ConstructionVisual, CompletedVisual, setup(),
  is_completed(), refresh_visual()

ConstructionController
  eliminado o type switch `if definition is BarracksDefinition` na criação do State:
  build_nest() cria NestState, build_barracks() cria BarracksState, e o helper genérico
  só instancia cena/posição/setup.
```

Motivo para ser agora: já existem **dois** tipos de construção com ciclo de vida idêntico,
e um terceiro (Mina, se o GDD for seguido) tem o mesmo ciclo. Não foi criada Factory,
Registry, Manager, Effect System nem menu genérico de construção.

```text
Limitação documentada do ponto dinâmico (§17 da spec)
  ConstructionState.definition e ConstructionRuntime.definition são tipados como a base
  ConstructionDefinition, não como NestDefinition/BarracksDefinition. GDScript não permite
  que uma subclasse redeclare uma variável herdada com tipo mais estreito, então o tipar
  por nível ficaria fora da base. O ponto dinâmico é proposital e localizado: vive apenas
  nesse campo, e as leituras feitas através dele são só os números da própria base
  (`work_required` no State, `build_resource` e `build_cost` no controller). Quem precisa do
  tipo específico (o bônus populacional, lido pelo controller via `@export` tipado em
  `NestDefinition`) recebe a subclasse pronta pelo construtor ou pelo cast explícito do
  controller — nunca por registro, fábrica ou detecção em tempo de execução.
```

### 5.2 Auditada e NÃO refatorada de propósito (parágrafos 27–30 da spec)

```text
WorkerDefinition / SoldierDefinition / EnemyDefinition
  display_name, max_health, move_speed repetidos — mas Worker tem carga e trabalho,
  Soldier tem custo de recrutamento e ataque, Enemy tem dano ao Núcleo. Uma base comum
  agora só esconderia a diferença.

WorkerState / SoldierState / EnemyState
  health, damage(), health_changed; Soldier e Enemy têm died, Worker não morre no
  gameplay atual. UnitStateBase/HealthComponent ficam adiados até haver um segundo
  combatente real ou morte de Worker em regra de jogo.

WorkerRuntime / SoldierRuntime
  move_to(), seleção, movimento planar, arrival_distance. EnemyRuntime tem movimento com
  ownership do InvasionController (quem cria e remove é a onda, não o jogador), então a
  base comum teria que modelar dois donos diferentes.

WorkerInvocationController / SoldierRecruitmentController
  ambos fazem checar população → checar Essência → instanciar → consumir → +1 população.
  As pré-condições (Ninho? Quartel concluído?) e pós-condições (entrega de recurso vs
  postura de combate) são diferentes, e são só dois casos. PopulationManager/UnitFactory
  ficam adiados até um terceiro tipo de criação.

RockState × ConstructionState
  mesma forma de remaining_work/apply_work/work_changed, mas escavação produz recurso e
  construção consome; não há sinal de que devam ser a mesma classe.
```

---

## 6. Dívida técnica observada

Somente fatos medidos no repositório.

### P0 — ameaça imediata à estabilidade

```text
Nenhum. Nenhuma falha de teste, nenhum vazamento conhecido, nenhuma condição de corrida
registrada nas 15 suítes.
```

### P1 — resolver antes de escalar conteúdo

```text
1. Save/Load inexistente (§75 do GDD). Qualquer fechamento de partida perde tudo;
   impede teste de regressão de campanha longa. FECHADO NA TAREFA 18 — a campanha salva e
   carrega por `user://campaign_save.json`, e `tests/test_save_load.gd` é a regressão de
   campanha que faltava; o que continua aberto aqui é a apresentação (tela de load, slot
   múltiplo), não a persistência.
2. Health duplicado em três States (§5.2) com regras de morte diferentes; um quarto
   combatente vai triplicar o custo de mudança.
3. Transação de spawn duplicada em dois controllers (§5.2); o terceiro tipo de unidade
   vai copiar a sequência de guards de novo.
4. Sem CI remoto: o repositório publicado não executa nenhuma suíte automaticamente.
   Todo o verde atual depende de alguém rodar tests/run_all_tests.ps1 à mão.
5. HUD fragmentado: 9 painéis de debug independentes, cada um reimplementando bind de
   signal e formatação de linha. Não há escala para 20 painéis.
```

### P2 — pode esperar múltiplas implementações

```text
6. GameMain crescendo: 65 linhas de composição em _ready() e 7 @export de Definition.
   Ainda é o desenho desejado, mas vai virar gargalo de merge quando houver salas.
7. Nomes de campo inconsistentes entre famílias (`rock_id`, `nest_id`, `barracks_id`,
   `core_id`, `unit_id`) — cada State usa o próprio prefixo.
8. `InvasionController` não tem State separado (§3), única família fora do padrão.
9. Camadas de física e grupos atribuídos por constante espalhada (`ENEMY_LAYER = 32`,
   collision_layer = 16 nas cenas) sem um único lugar que declare o mapa de camadas.
10. Balanceamento ainda não validado por jogo humano: nenhum dos números foi medido em
    sessão real de playtest, só em testes automatizados.
```

---

## 7. Candidatos a futura generalização

```text
Construction          → generalização AGORA justificada (dois tipos reais, mesmo ciclo)
Units (Definition)    → ainda aguardar
Units (State/Runtime) → ainda aguardar segundo combatente real ou morte de Worker
Population spawning   → ainda aguardar terceiro tipo de criação
Combat                → ainda aguardar segundo inimigo/combatente real
Progression           → ainda aguardar Core Lv.3 (só existe uma aresta Lv.1 → Lv.2)
Rooms/Salas           → ainda aguardar a quarta sala (a Mina depende da decisão D4)
```

---

## 8. Decisões tomadas após a auditoria

Tarefa 16. A tabela do §1 acima **não foi alterada** por esta tarefa: ela é a fotografia do
As-Built no commit `5fff237`, tirada contra o GDD que existia naquele momento. O design mudou
depois disso, e as linhas `IMPLEMENTADO DIFERENTE` / `NÃO IMPLEMENTADO` continuam valendo como
registro histórico daquele instante. As decisões formais, com motivo, impacto e matriz de
alinhamento do código, estão em `docs/DESIGN_DECISIONS_POST_MVP.md`.

| Decisão | Assunto | Resolvido | Linhas da tabela §1 afetadas |
| --- | --- | --- | --- |
| D1 | Trabalhadores no MVP | máximo 2 (1 inicial + 1 invocável) | 2 |
| D2 | Custo da evolução Nv.1 → Nv.2 | 1 Cristal Abissal + 25 Essências | 6, 7 |
| D3 | População base Nv.2 | base 12, Ninho +4, efetiva 16 | 11, 13 |
| D4 | Rochas × Mina × Depósito | papéis distintos; Mina é conteúdo do Nv.2 | 5, 8 |
| D5 | Biomassa | entra na progressão Nv.2, não retroativamente | 4 |
| D6 | Integridade 0 | regra de derrota; tela de Game Over é apresentação futura | 14 |
| D7 | Construção | `work_required` + `work_speed`; sem duração fixa em segundos | 19, 20 |

### D1 — Workers

```text
Oficial: o MVP tem 1 Trabalhador Abissal inicial + 1 invocável, máximo 2.
A linha 2 da tabela (§1) deixa de ser divergência: o código sempre esteve correto;
quem pedia 3 trabalhadores era o GDD, e o GDD foi corrigido (§89).
```

### D2 — Cristal Abissal e evolução

```text
Oficial: Nv.1 → Nv.2 custa 1 Cristal Abissal + 25 Essências, e o Cristal é recompensa
estrutural da primeira vitória na invasão.

Na auditoria este era o único item ainda em aberto no código: as linhas 6 e 7 descreviam
o estado real daquele instante (só Essência), e continuam valendo como registro histórico.
D2 alinhada no código na Tarefa 17 — feat: add abyssal crystal progression key: existe
AbyssalCrystalDefinition/State, a vitória da primeira invasão entrega 1 Cristal e a
evolução cobra 1 Cristal + 25 Essências na mesma transação. A tabela do §1 não foi
tocada por essa tarefa; ela é fotografia, não estado atual.
```

### D3 — População base × efetiva

```text
Oficial: capacidade base do Core (Nv.1 = 8, Nv.2 = 12) + bônus de construção (Ninho +4)
= capacidade efetiva (Nv.1 + Ninho = 12, Nv.2 + Ninho = 16).

As linhas 11 e 13 descreviam o GDD antigo, que não conhecia o conceito de bônus. O código
(`core_level_2.tres` = 12, `CoreState.get_population_capacity()`) agora é a regra oficial,
e o §8 do GDD passou a documentar base / bônus / efetiva.
```

### D4 — Rochas, Mina e Depósito

```text
Oficial: Rochas de Minério = extração finita (exploração e expansão).
         Mina = infraestrutura produtiva permanente/renovável, desbloqueada no Nv.2.
         Depósito de recursos = ponto de entrega/estoque; NÃO é a Mina.

A linha 5 deixa de ser divergência (o GDD agora descreve a rocha como extração finita e
move a Mina para o Nv.2). A linha 8 permanece `NÃO IMPLEMENTADO`, mas passa a ser um item
de escopo: a Mina é conteúdo pós-MVP, não um requisito faltante do MVP.
```

### D5 — Biomassa

```text
Oficial: Biomassa não entra retroativamente no MVP concluído; é recurso da progressão Nv.2.
A linha 4 continua verdadeira sobre o código e deixa de descrever uma obrigação do MVP.
```

### D6 — Núcleo destruído

```text
Oficial: Integridade 0 = estado de derrota da run. O InvasionController.DEFEAT já expressa
a mecânica; tela de Game Over, reinício e load são camada de apresentação posterior.
A linha 14 continua descrevendo a apresentação ausente; a regra mecânica está alinhada.
```

### D7 — Construção por trabalho

```text
Oficial: construções têm `work_required`; Workers têm `work_speed`; o tempo em segundos é
consequência emergente do trabalho combinado, não um campo do prédio.
Linhas 19 e 20: o tempo (`work_required` 4/6, `work_speed = 1.0`) já é a regra oficial; os
outros quatro atributos de §18 continuam fora do MVP.
```

### Situação consolidada

```text
Fechadas por alinhamento do GDD ao código:  D1, D3, D4 (escopo), D5, D6 (regra), D7
Fechadas pelo código:                       D2 — Tarefa 17 implementou o Cristal Abissal
                                            (feat: add abyssal crystal progression key)
Migrada de "faltante" para "pós-MVP":       Mina (D4), Biomassa (D5)
Pós-MVP já entregue:                        Mina Abissal — Tarefa 20
                                            (feat: add level 2 abyssal mine): primeiro
                                            conteúdo do Vertical Slice Nv.2, sala construída
                                            e produtiva gated em Núcleo Nv.2, save em V2
Pendentes do mesmo bloco:                   Biomassa (D5)
```

```text
Este bloco consolidado é o único texto do arquivo que acompanha o código atual. A tabela de
§1 continua sendo a fotografia de 5fff237 e não é reescrita quando uma decisão fecha.
```
