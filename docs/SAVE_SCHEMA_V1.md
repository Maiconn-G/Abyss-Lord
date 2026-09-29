# Save schema v1

## Objetivo

Este arquivo documenta o formato de `campaign_save.json`: o que é gravado, onde, em que
ordem a campanha volta e o que acontece quando o arquivo é ruim. É documentação técnica do
contrato, não design de jogo — as regras de gameplay continuam no GDD e não se duplicam aqui.

A frase que define o formato (Tarefa 18, §2/§15):

```text
O save não é uma fotografia da SceneTree. Ele é uma fotografia da campanha.
```

Por isso o arquivo contém **dados de domínio**: números de `CoreState`, `AbyssalCrystalState`,
`ResourceStockpileState`, `WorkerState`, `RockState`, `ConstructionState`, `SoldierState`,
`EnemyState` e do ciclo de invasão. Não contém Node, caminho de cena, `instance_id`, seleção,
ordem de movimento nem nenhum valor que a Definition derive na carga.

Donos do formato:

```text
systems/persistence/campaign_snapshot.gd  → a forma do JSON, os nomes e a validação estrutural
systems/persistence/save_game_controller.gd → o caminho, a escrita, as faixas contra as
                                              Definitions injetadas e a restauração
game/game_main.gd                           → a raiz de composição: cria o controller, injeta
                                              as dependências e apresenta as Rochas canônicas
```

Nenhum dos três é Autoload e não existe `SaveManager`.

---

## Onde o arquivo mora

| Papel | Caminho | Origem do nome |
| --- | --- | --- |
| Save primário | `user://campaign_save.json` | `SaveGameController.DEFAULT_PRIMARY_PATH` |
| Backup do save anterior | `user://campaign_save.bak` | `save_path().get_basename() + ".bak"` |
| Escrita temporária | `user://campaign_save.tmp` | `save_path().get_basename() + ".tmp"` |

`user://` é o diretório de dados do usuário que o Godot reserva ao projeto. Em Windows, para
este jogo, é `%APPDATA%/Godot/app_userdata/Abyss Lord/`. Escrever em `res://` não é uma
opção: o save do jogador não pode viver dentro do pacote do jogo (§108).

`configure_save_path(path)` troca o primário. O backup e o temporário são sempre derivados
dele, então um teste que aponta para `user://tests/save_load/...` produz backup e temporário
isolados e nunca encosta no save real do jogador (§107).

### Escrita atômica

Salvar nunca escreve direto no primário. A sequência é:

```text
1. snapshot_campaign()          — lê o domínio, não a cena
2. validate_campaign()          — um arquivo inconsistente não chega ao disco
3. escrever em <primário>.tmp   — com file.flush()
4. reler o .tmp e validá-lo     — o que sobreviveu à própria escrita
5. copiar o primário vigente para .bak
6. renomear .tmp sobre o primário
```

Se qualquer passo 3–6 falhar, o `.tmp` é removido e o primário anterior continua sendo o
arquivo bom. O jogador nunca fica com um save meio escrito.

---

## Versão e raiz do documento

```text
format       = "abyss_lord_campaign"
save_version = 1
```

`save_version` é a única chave de versionamento do formato (§7). A carga aceita o número 1 e
recusa qualquer outro — inclusive `2`, `1.5` ou ausente — com o mundo atual intacto. Não há
adivinhação de schema e não há migration implementada (§119).

A raiz tem exatamente quatro chaves:

```text
format / save_version / metadata / campaign
```

`metadata` é informativo (§72/§73): `saved_at_unix` e `engine_version`. Nenhum caminho de
jogo depende dele, e versionar o formato **não** é papel dele — é de `save_version`.

`campaign` tem as sete seções obrigatórias (§69). Falta de qualquer uma é recusa estrutural,
não "campanha vazia":

```text
core / progression / economy / units / constructions / world / invasion
```

---

## O documento real

Fragmento com a forma exata que `JSON.stringify(document, "  ")` produz (recuo de dois
espaços faz parte do formato, porque o arquivo do jogador é lível em editor de texto — §110).
Os valores são de uma campanha do meio do jogo, e todos respeitam a whitelist de ids e as
faixas das Definitions.

```json
{
  "format": "abyss_lord_campaign",
  "save_version": 1,
  "metadata": {
    "saved_at_unix": 1759172340,
    "engine_version": "4.6.1.stable.official.14d19694e"
  },
  "campaign": {
    "core": {
      "core_id": "main_core",
      "level": 1,
      "integrity": 78.0,
      "essence": 27.5,
      "population": 3,
      "population_capacity_bonus": 4
    },
    "progression": {
      "abyssal_crystal": {
        "amount": 0
      }
    },
    "economy": {
      "stockpile": {
        "iron_ore": 6
      }
    },
    "units": {
      "workers": [
        {
          "unit_id": "worker_001",
          "unit_type_id": "abyss_worker",
          "health": 50.0,
          "level": 1,
          "experience": 0.0,
          "position": [-2.0, 0.0, 3.0],
          "carried_resource": "iron_ore",
          "carried_amount": 3
        },
        {
          "unit_id": "worker_002",
          "unit_type_id": "abyss_worker",
          "health": 41.0,
          "level": 1,
          "experience": 2.0,
          "position": [4.0, 0.0, 1.0],
          "carried_resource": null,
          "carried_amount": 0
        }
      ],
      "worker_002_summoned": true,
      "soldier": {
        "recruited": true,
        "alive": true,
        "unit_id": "soldier_001",
        "unit_type_id": "abyss_soldier",
        "health": 60.0,
        "level": 1,
        "experience": 12.0,
        "position": [1.0, 0.0, -5.0]
      }
    },
    "constructions": {
      "nest": {
        "exists": true,
        "nest_id": "nest_001",
        "remaining_work": 0.0,
        "position": [6.0, 0.0, -4.0]
      },
      "barracks": {
        "exists": true,
        "barracks_id": "barracks_001",
        "remaining_work": 2.5,
        "position": [-6.0, 0.0, -4.0]
      }
    },
    "world": {
      "rocks": [
        { "rock_id": "rock_001", "remaining_work": 4.0, "excavated": false },
        { "rock_id": "rock_002", "remaining_work": 1.5, "excavated": false },
        { "rock_id": "rock_003", "remaining_work": 0.0, "excavated": true },
        { "rock_id": "iron_ore_001", "remaining_work": 2.0, "excavated": false },
        { "rock_id": "iron_ore_002", "remaining_work": 0.0, "excavated": true }
      ],
      "piles": [
        {
          "pile_id": "iron_ore_002_drop",
          "resource_id": "iron_ore",
          "amount": 3,
          "position": [8.0, 0.0, 2.0]
        }
      ]
    },
    "invasion": {
      "state": "PREPARATION",
      "preparation_time_remaining": 4.7,
      "invaders": []
    }
  }
}
```

---

## As sete seções

### `core`

```text
core_id                  = "main_core"   (identidade semântica; nunca instance_id)
level                    inteiro ≥ 1     → resolve a CoreDefinition na whitelist
integrity                número ≥ 0      ≤ max_integrity da Definition do nível
essence                  número ≥ 0      ≤ max_essence da Definition do nível
population               inteiro ≥ 0     ≤ population_capacity + population_capacity_bonus
population_capacity_bonus inteiro ≥ 0    (o bônus do Ninho concluído)
```

O que **não** está aqui é o que faz o save ser dados e não cena: `max_integrity`,
`max_essence`, `population_capacity` e `essence_generation_rate` vêm da `CoreDefinition`
resolvida pelo `level`. Gravar o teto seria congelar um número que pertence ao jogo, não à
campanha (§122/§123). Na carga, o Núcleo que já está em cena é restaurado no próprio Runtime;
não se recria um segundo Núcleo (§18/§19).

`population_capacity_bonus` é salvo justamente porque ele é consequence de uma conclusão
passada: o Ninho pronto o aplicou uma vez. Reconstruí-lo a partir de `nest.remaining_work == 0`
seria reaplicar o bônus por cima do `population` que já veio do arquivo.

### `progression`

```text
abyssal_crystal.amount   inteiro ≥ 0
```

A chave do nome exato `abyssal_crystal` é obrigatória (§69): uma campanha salva antes da
Tarefa 17 não existe, então não há compatibilidade a simular. O contador volta como número;
a `AbyssalCrystalDefinition` (display name, custos) nunca entra no arquivo.

### `economy`

```text
stockpile   mapa resource_id → inteiro > 0
```

Zero é ausência, não saldo: um recurso zerado não é gravado e um recurso gravado com zero é
recusado. O `resource_id` é resolvido contra as `ResourceDefinition` injetadas por GameMain;
um id que o jogo não conhece derruba o load inteiro (§70/§106).

### `units`

```text
workers                 Array de registros de Worker
worker_002_summoned     bool  — a flag histórica da invocação
soldier                 registro do Soldado
```

Registro de Worker:

```text
unit_id            "worker_001" | "worker_002"
unit_type_id       "abyss_worker"
health             número > 0    ≤ max_health
level              inteiro ≥ 1
experience         número ≥ 0
position           [x, y, z]
carried_resource   resource_id | null
carried_amount     inteiro ≥ 0   ≤ carry_capacity
```

As invariantes cruzadas são recusadas, não corrigidas: `carried_amount > 0` exige
`carried_resource` e `carried_amount == 0` exige `null` (§25). `worker_001` tem de estar
listado — a ausência dele é campanha corrompida, não partida nova, porque o Worker inicial é
da SceneTree canônica e §84 não o recria.

`worker_002_summoned` é salva separada do registro da unidade porque as duas metades sobrevivem
a momentos diferentes: o segundo Worker pode morrer, e `I` continua bloqueado para sempre
naquela campanha (§26/§33).

Registro do Soldado:

```text
recruited   bool  — a regra histórica (bloqueia um segundo recrutamento)
alive       bool  — a entidade existe
unit_id     "soldier_001"
unit_type_id "abyss_soldier"
health / level / experience / position   — só quando alive == true
```

Morto continua recrutado (§27/§28): `{recruited: true, alive: false}` é um arquivo
perfeitamente válido, e é exatamente ele que faz `R` continuar bloqueado depois do load. As
combinações impossíveis `recruited: false, alive: true` e o `alive: true` sem registro
completo são recusadas.

### `constructions`

```text
nest:      exists | nest_id      | remaining_work | position
barracks:  exists | barracks_id  | remaining_work | position
```

`exists: false` é a única chave de uma obra que não foi lançada. `completed` **não** é campo:
ela é derivada de `remaining_work <= 0` (§123). A obra volta montada com o trabalho restante
do arquivo, e nenhuma conclusão é reemitida na carga — nem `construction_completed`, nem
`barracks_completed`, porque reemitir reaplicaria efeitos de gameplay que já estão nos números
(§32/§35/§75). Restaurar não é jogar: não se faz `apply_work(999)` para "simular" a conclusão
(§36).

### `world`

```text
rocks   Array de {rock_id, remaining_work, excavated}
piles   Array de {pile_id, resource_id, amount, position}
```

`rocks` é o livro-razão das Rochas canônicas apresentadas pelo GameMain (`rock_001`,
`rock_002`, `rock_003`, `iron_ore_001`, `iron_ore_002`). Ele existe porque uma Rocha escavada
deixou de ser um Node: varrer a cena não diria o que o mundo ainda tem (§38/§39). Duas
regras fecham o arquivo:

```text
toda rock_id do ledger aparece no arquivo   (cobertura)
nenhum rock_id fora do ledger aparece       (whitelist)
```

`excavated: true` com `remaining_work > 0` é uma Rocha impossível e é recusada. Um monte com
`amount <= 0` também: monte zerado não é estado de campanha, é um Node que já está indo
embora (§44).

`pile_id` é o id semântico derivado da Rocha de origem, com o sufixo `_drop` que o Runtime
usa — `iron_ore_002_drop` volta como monte de `iron_ore` na posição gravada.

### `invasion`

```text
state                       "NOT_STARTED" | "PREPARATION" | "ACTIVE" | "VICTORY" | "DEFEAT"
preparation_time_remaining  número ≥ 0 (segundos)
invaders                    Array de {invader_id, enemy_type_id, health, position}
```

O ciclo de vida é texto legível, não um inteiro de enum. As invariantes (§48/§131):

```text
fora de ACTIVE            → invaders precisa ser vazio
ACTIVE                    → invaders não pode ser vazio
mais que INVADER_COUNT    → recusado
fora de PREPARATION       → preparation_time_remaining == 0
health <= 0               → invasor sem vida é recusado
```

É por isso que o snapshot decide o exército pelo **estado**, não pela varredura: na `DEFEAT`
as Feras ainda estão em cena, em stance terminal, e gravá-las produziria a campanha
impossível que a validação recusaria (§45/§99).

Alvo de combate, `aggro`, o progresso do ataque e o `move_to` em curso são transitórios. Cada
invasor restaurado retoma `ADVANCE`. `VICTORY` e `DEFEAT` voltam terminais e **sem recompensa**:
quem concede o Cristal é a morte real do invasor, nunca a carga (§49/§75).

---

## Estado transitório — o que não é salvo

```text
seleção do jogador e a caixa de seleção
ordem de movimento de Worker e de Soldado (move_to, waypoints, stance de combate)
ordem de prioridade das Rochas/obras
alvo atual de qualquer unidade
câmera: posição do rig, zoom, inclinação
textos e estado visual de todo HUD
timers internos de animação e cooldowns de ataque
max_integrity / max_essence / population_capacity / essence_generation_rate
work_required / build_cost / carry_capacity / move_speed / attack_damage
todo Node, PackedScene, caminho de recurso e Object.get_instance_id()
```

A câmera tem um caso próprio: ela **pode** ler o mundo (o `movement_bound` é do cenário), mas
nenhum número de câmera entra no arquivo. Carregar uma campanha não move a view do jogador.

---

## Ordem de restauração

`load_campaign()` trava o input de persistência (`_is_loading`), lê, valida **por inteiro** e
só então aplica (§67). Nenhum caminho de carga aplica metade do JSON. A ordem implementada em
`_apply()`:

```text
1.  input de persistência bloqueado (no chamador)
2.  snapshot validado (no chamador)
3.  seleção e ordens transitórias limpas        SelectionController.reset_transient_input()
4.  ciclo de vida parado e esvaziado            InvasionController.restore_lifecycle(NOT_STARTED)
5.  montes do chão limpos                       _clear_piles()
6.  Núcleo: Definition pelo nível + os números  _restore_core()
7.  Cristal                                     AbyssalCrystalState.restore()
8.  Estoque                                     ResourceStockpileState.replace_contents()
9.  Rochas                                      _restore_rocks()
10. Montes de recurso                           _restore_piles()
11. Ninho e Quartel                             restore_nest / restore_barracks
12. Workers                                     _restore_units()
13. Soldado                                     SoldierRecruitmentController.restore_soldier()
14. Invasão                                     _restore_invasion()
15. Evolução derivada                           CoreEvolutionController.restore_progression()
16. refresh dos painéis                         emissão de load_succeeded, na raiz de composição
17. input liberado (no chamador)
```

A ordem não é arbitrária: o ciclo de vida precisa ser zerado antes para que os invasores do
arquivo sejam criados sobre um exército vazio; as Rochas vêm antes dos montes porque o monte
é consequência do mundo; o Núcleo vem antes das unidades porque `population` é a conta delas;
e o refresh de HUD é o último passo justamente porque a UI lê estado terminado, não sinal de
conquista (§77).

Passos de reconcenação usam apenas a whitelist: `_rock_scene` e `_pile_scene` injetadas, e as
`Definitions` apresentadas pelo GameMain. Não existe `load("res://" + id_vindo_do_arquivo)`
em lugar nenhum (§16/§71).

---

## Comportamento em falha

A regra é única: **recusar é não tocar**. Toda recusa devolve `false`, emite
`operation_failed(operation, reason)` com o motivo legível e deixa a campanha em curso
exatamente como estava.

| Situação | Resultado |
| --- | --- |
| JSON sintaticamente inválido no primário | tenta o backup; se o backup também for ruim, `false` e mundo intacto |
| `save_version` ≠ 1 | `false`, motivo `save_version não suportado`, nada é aplicado |
| seção obrigatória ausente | `false`, `seção obrigatória ausente ou inválida: <seção>` |
| tipo errado, número negativo, fração onde é inteiro | `false`, com o campo nomeado |
| id fora da whitelist (`rock_id`, `resource_id`, `unit_type_id`, `enemy_type_id`, `level`) | `false` — nunca vira argumento de `load()` |
| número acima do que a Definition permite | `false` |
| invariante do domínio furada (population ≠ unidades, `ACTIVE` sem invasor, monte zerado) | `false` |
| arquivo inexistente | `false` com `nenhum arquivo de campanha em <path>` — não é corrupção, é "nada para carregar" |
| primário corrompido, backup válido | carrega o backup, `load_succeeded(backup)`, e o fallback é dito em voz alta no console |
| save inválido | o snapshot é validado antes de escrever: um arquivo inconsistente nunca chega ao disco |

Duas notas de contrato:

- O `int` do contrato é "número sem parte fracionária". O `JSON` do Godot devolve `float` para
  todo número lido, então `1` no arquivo chega como `1.0` e é aceito; o que não é aceito é
  fração — nível, montante e população meio inteiro não existem nesta campanha.
- Validação estrutural (`CampaignSnapshot`) e validação de domínio (`SaveGameController`)
  são duas passagens distintas e obrigatórias. A primeira não conhece o jogo; a segunda só
  conhece o jogo pelas Definitions que a raiz de composição injetou.

---

## Política de migração futura

```text
v1 é a primeira versão do formato.
```

Hoje não há migration, porque não há de quê: não existiu v0. Implementar migração fictícia
seria código morto com cara de segurança (§119).

Quando o schema mudar:

```text
1. incrementar save_version no novo writer
2. adicionar migration explícita, versionada, com teste próprio
3. nunca adivinhar schema: um save_version desconhecido continua recusado
4. metadata nunca é usado para versionar — só save_version
```

Uma migration é uma função que recebe um documento **válido de uma versão anterior** e devolve
o documento da versão nova. Ela roda antes de `_apply()`, nunca durante: a meia aplicação
continua proibida. Se a migration não puder produzir um documento que passe na validação, o
resultado é recusa com o mundo intacto, exatamente como hoje.
