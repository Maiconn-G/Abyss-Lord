# Decisões pós-MVP

Registro oficial das sete decisões que `docs/POST_MVP_AUDIT.md` deixou pendentes na
Tarefa 15. Elas foram tomadas pelo designer e fecham, nesta tarefa, apenas o **design**:
nenhum `.gd`, `.tscn` ou `.tres` de produção foi alterado aqui.

```text
auditadas em        = 5fff237 feat: add level 2 abyssal core evolution
decididas em        = Tarefa 16 (documental)
GDD atualizado por  = esta tarefa (seções §8, §9, §10, §11, §17, §18, §88, §89, §90,
                      §91, §95, §104)
jogo executado      = o mesmo da Tarefa 15: mesmos números, mesmo loop, mesmas teclas
```

Nenhuma decisão termina em `PENDENTE`. Onde o código ainda não bate com a decisão, isso
aparece na **matriz de alinhamento** no final deste arquivo — não como decisão aberta.

---

## D1 — Workers

**Decisão:**

```text
MVP = 1 Trabalhador inicial + 1 invocável.
Máximo do MVP = 2 Workers.
O GDD não exige mais "3 trabalhadores" como condição de MVP.
Workers adicionais são progressão posterior ao Nv.2.
```

**Motivo:**

Dois Workers já provam tudo que o terceiro provaria, e provam de verdade: invocação,
população, multi-seleção, ordens independentes e trabalho cooperativo na mesma obra. O
terceiro não acrescentaria um sistema novo, só um número maior na cena. O loop foi
medido na Tarefa 15: Ninho em ~4 s com 1 Worker, Quartel cooperativo a 2.0 trabalho/s
com 2.

**Impacto:**

§88 e §89 do GDD reescritos. Nenhum impacto no código: o jogo já era exatamente isso.

**Evidência no código:** `game/game_main.gd:22` (`Worker001`),
`systems/population/worker_invocation_controller.gd` (`SUMMONED_UNIT_ID = "worker_002"`,
com guarda de instância única).

**STATUS: DECIDIDO**

---

## D2 — Evolução do Núcleo

**Decisão:**

```text
Nv.1 → Nv.2 exige, ao mesmo tempo:
  - ter sobrevivido à primeira invasão
  - possuir 1 Cristal Abissal
  - possuir 25 Essências

Custo consumido na evolução: 1 Cristal Abissal + 25 Essências.
```

**Motivo:**

A auditoria mostrou que o fechamento do MVP era a única parte do loop sem **chave
estrutural**: 25 Essências se pagam sozinhas com o tempo de geração do Núcleo, então a
evolução virava "esperar o contador", não "conquistar o marco". O Cristal separa as duas
coisas sem inventar economia nova: Essência continua sendo a energia operacional, e o
Cristal passa a ser o registro de que o jogador atravessou um marco.

**Impacto:**

§10, §11, §88, §89 e §90 do GDD atualizados. É a **única** decisão desta lista que o
código ainda não implementa — ver matriz de alinhamento.

**Evidência no código hoje:** `data/core/core_level_2.tres` (`evolution_essence_cost =
25`), `systems/progression/core_evolution_controller.gd` (destrava por vitória na
invasão, cobra Essência, tecla V). Não existe `CristalDefinition`, estoque de cristal nem
recompensa por invasão.

**STATUS: DECIDIDO**

---

## D3 — Population base do Nv.2

**Decisão:**

```text
Core Nv.1: base = 8
Core Nv.2: base = 12
Ninho:     +4 de bônus

Efetiva Nv.1 + Ninho = 12
Efetiva Nv.2 + Ninho = 16
```

**Motivo:**

A curva 8 → 16 do §8 antigo era uma progressão de *nível*, e o jogo já tinha descoberto
uma segunda alavanca: *infraestrutura*. Manter base 12 no Nv.2 faz o Ninho continuar
significativo depois de evoluir (12 → 16) em vez de virar ruído comparado a um salto de
nível. O valor também é o que já está rodando e balanceado no loop medido.

**Impacto:**

Tabela do §8 corrigida (16 → 12) e o conceito base/bônus/efetiva foi escrito no GDD, que
não o tinha. Nenhum impacto no código: `core_level_2.tres` sempre foi 12.

**Evidência no código:** `data/core/core_level_1.tres` (`population_capacity = 8`),
`data/core/core_level_2.tres` (`population_capacity = 12`),
`data/rooms/abyss_nest.tres` (`population_capacity_bonus = 4`),
`CoreState.get_population_capacity()` (base + bônus).

**STATUS: DECIDIDO**

---

## D4 — Rochas, Depósito e Mina

**Decisão:**

```text
Rochas de Minério = extração finita. Esgotam. Movem a expansão.
Mina              = produção renovável. Desbloqueada no Nv.2.
Depósito          = ponto de entrega e estoque. NÃO é a Mina.
Mina sai dos requisitos do MVP e vira conteúdo inicial do Nv.2 / Vertical Slice.
```

**Motivo:**

As rochas não eram um placeholder da Mina — elas são o outro lado do par. Extração finita
cria a decisão "cavar mais fundo", que é o motor do §14/§15 do GDD; produção renovável
cria economia estável, que só faz sentido depois que o jogador tem Núcleo Nv.2 para
pagá-la. Fundir os dois apagaria essa diferença. O Depósito entrou na decisão porque a
auditoria o achou sendo lido como "a Mina que falta": ele entrega e guarda, não produz.

**Impacto:**

§11 e §17 do GDD ganharam a distinção explícita; §88 tirou a Mina das salas do MVP; §91
a colocou como candidato de abertura do Vertical Slice. Nenhum impacto no código — as
rochas e o Depósito ficam exatamente como estão.

**Evidência no código:** `data/environment/iron_ore_rock.tres` +
`world/dungeon/rock/rock_runtime.gd` (esgotável, com `yield_resource`),
`world/dungeon/storage/ResourceDepositRuntime.tscn` (entrega/estoque). Não existe sala
`Mina`.

**STATUS: DECIDIDO**

---

## D5 — Biomassa

**Decisão:**

```text
Biomassa NÃO entra retroativamente no MVP concluído.
MVP  = Essência + Minério + Cristal Abissal (chave final).
Biomassa entra durante a progressão do Nv.2 (Vertical Slice).
Identidade conceitual preservada: recurso orgânico, usado em criaturas, salas
biológicas e evoluções orgânicas.
```

**Motivo:**

Retroativamente, Biomassa só existiria como um segundo contador de coleta sem segundo
consumidor: nenhuma sala, unidade ou evolução do MVP a pediria. Isso é conteúdo sem
decisão. O valor dela aparece junto das fazendas, criaturas e evoluções orgânicas, que
são Nv.2+.

**Impacto:**

§11 marca Biomassa como pós-MVP; §88 passa a listar Essência/Minério/Cristal como os
três recursos do MVP; §95 registra a exclusão. Nenhuma receita nova foi inventada nesta
tarefa — as receitas de Biomassa continuam sendo decisão do slice. Nenhum impacto no
código.

**Evidência no código:** inexistente, de propósito. `data/resources/` só tem
`iron_ore.tres`.

**STATUS: DECIDIDO**

---

## D6 — Núcleo destruído

**Decisão:**

```text
Integridade 0 = estado de derrota da campanha/run. Essa é a regra.
Tela de Game Over, reinício e load são APRESENTAÇÃO, e podem ser implementados depois.
A mecânica não fica incompleta enquanto a apresentação não existir.
```

**Motivo:**

A auditoria classificou o item como `IMPLEMENTADO DIFERENTE` porque o GDD dizia "Game
Over" e o código entregava um estado `DEFEAT` sem tela. Isso misturava duas camadas: a
regra já existia e funcionava; faltava só o feedback. Exigir tela de Game Over para
validar a regra faria o design cobrar do código algo que não é a regra.

**Impacto:**

§9 do GDD agora separa regra de apresentação. Nenhum impacto no código — `DEFEAT` já é o
estado de derrota correto. A tela entra no backlog junto de Save/Load (P1-1 da auditoria),
porque restart sem save não tem o que reiniciar.

**Evidência no código:** `CoreState.damage()` → `destroyed` →
`systems/combat/invasion_controller.gd` entra em `InvasionState.DEFEAT`. Não há HUD de
Game Over.

**STATUS: DECIDIDO**

---

## D7 — Custo de construção

**Decisão:**

```text
Construção não tem duração fixa em segundos.
Cada construção tem work_required; cada Worker tem work_speed.
tempo ≈ work_required ÷ trabalho combinado dos Workers na obra.
Não existe mínimo de trabalhadores por sala: qualquer Worker capaz pode contribuir, e
múltiplos aceleram.
```

**Motivo:**

"Tempo de construção" pressupõe um relógio por prédio, e o jogo já media outra coisa:
trabalho aplicado. Modelar como trabalho deixa a obra reagir à mão de obra do jogador —
que é exatamente o laço população → construção que o MVP quer provar — e apaga a
pergunta "quantos segundos custam?" que o §18 antigo fazia sem ter como responder.
Exemplos oficiais: Ninho 4 → ~4 s com 1 Worker, ~2 s com 2; Quartel 6 → ~6 s / ~3 s.

**Impacto:**

§18 reescrito em torno de `work_required`, com os exemplos medidos; "espaço",
"requisitos" e "manutenção" foram movidos para fora do MVP explicitamente, em vez de
sumirem. Nenhum impacto no código: o modelo sempre foi esse.

**Evidência no código:** `core/definitions/construction_definition.gd`
(`build_resource`, `build_cost`, `work_required`), `core/state/construction_state.gd`
(`apply_work()`, `work_changed`, `construction_completed`),
`data/units/workers/abyss_worker.tres` (`work_speed = 1.0`).

**STATUS: DECIDIDO**

---

## Próximas alterações necessárias no código

Isto é planejamento, não implementação. Nada desta coluna mudou nesta tarefa.

```text
Decisão / regra                       | Código                                        | Ação
------------------------------------- | --------------------------------------------- | -------------------------
D1  MVP com no máximo 2 Workers       | 1 cena + 1 invocável                        | já alinhado
D2  1 Cristal + 25 Essências          | só 25 Essências; Cristal não existe         | CÓDIGO PRECISA ALINHAR
D3  Nv.2 base 12, Ninho +4, efet. 16  | core_level_2.tres 12, Ninho +4              | já alinhado
D4  Rochas finitas / Mina Nv.2        | rochas esgotáveis, Depósito de entrega      | já alinhado (Mina = feature futura)
D5  Biomassa pós-MVP                  | inexistente                                 | já alinhado (feature futura)
D6  Integridade 0 = derrota           | destroyed → InvasionState.DEFEAT            | mecânica já alinhada (UI futura)
D7  work_required, não segundos       | ConstructionDefinition/State + work_speed   | já alinhado
```

Seis das sete decisões já eram o jogo. A sétima é o único trabalho de gameplay aberto.

---

## Próxima alteração de gameplay

**Cristal Abissal** — recompensa da primeira invasão e pré-requisito da evolução
Nv.1 → Nv.2.

É a única divergência imediata entre design canônico e código, e ela altera o fechamento
do MVP, então vem antes de qualquer outro conteúdo. Escopo previsto quando for implementado
(não implementado aqui):

```text
Definition e State do Cristal (recurso não-operacional, estoque próprio do Núcleo)
recompensa de 1 Cristal na victory da primeira invasão
custo de evolução: 1 Cristal + 25 Essências, consumidos atomicamente
pré-requisito de unlock: possuir o Cristal, além da vitória e da Essência
HUD: painel de evolução mostra o Cristal como condição faltante
testes: nova suíte + suítes existentes invertidas onde a regra antiga era assertada
```

Até lá, o estado oficial é o registrado em §104 do GDD:

```text
DESIGN CANÔNICO: 1 Cristal Abissal + 25 Essências
AS-BUILT:        25 Essências somente
```

Isso é intencional e temporário. O design mudou primeiro; o código é alinhado depois.
