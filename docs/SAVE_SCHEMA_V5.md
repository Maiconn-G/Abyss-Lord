# Save schema v5

## Objetivo

Este arquivo documenta o que mudou no formato `campaign_save.json` na Tarefa 23 e só isso: o
delta V4 → V5. O contrato inteiro continua em `docs/SAVE_SCHEMA_V1.md`, e os deltas anteriores em
`SAVE_SCHEMA_V2.md` (Mina), `SAVE_SCHEMA_V3.md` (Fazenda Fúngica) e `SAVE_SCHEMA_V4.md` (terceiro
Trabalhador).

```text
O save não é uma fotografia da SceneTree. Ele é uma fotografia da campanha.
```

A Tarefa 23 trouxe a superfície para o jogo: a **Notoriedade** e a primeira **Incursão da
Superfície** (GDD §58.1). As duas entram no arquivo como números de campanha — o valor da
Notoriedade, o estado do ciclo e, para cada saqueador em campo, vida, posição, fase e saque.

Donos do formato, inalterados:

```text
systems/persistence/campaign_snapshot.gd    → forma do JSON, nomes e validação estrutural
systems/persistence/save_game_controller.gd → caminho, escrita, faixas contra Definitions e restauração
game/game_main.gd                           → raiz de composição
```

---

## A diferença V4 → V5

Uma seção nova, a oitava. As sete do V1 continuam obrigatórias e não mudaram:

```text
core, progression, economy, units, constructions, world, invasion   iguais ao V4
surface                                                             NOVA
```

```text
format       = "abyss_lord_campaign"   (inalterado)
save_version = 5                        (era 4)
```

O motivo de a versão subir: um V4 não tem como expressar "a guilda está a 47 s" nem "raider_002
recuando com 2 de Biomassa". Ler um V4 como V5 sem migração seria inventar estado.

---

## A seção `surface`

```json
{
  "surface": {
    "notoriety": 20,
    "incursion": {
      "state": "ACTIVE",
      "preparation_time_remaining": 0.0,
      "raiders": [
        { "raider_id": "raider_001", "health": 40.0, "position": [-1.2, 0.0, 1.4],
          "phase": "LOOT", "loot": { "biomass": 2 } },
        { "raider_id": "raider_002", "health": 22.5, "position": [-4.0, 0.0, 9.0],
          "phase": "RETREAT", "loot": { "biomass": 1, "iron_ore": 2 } }
      ],
      "repelled": 0,
      "escaped": 0
    }
  }
}
```

```text
notoriety                    int 0..100
incursion.state              "NOT_STARTED" | "PREPARATION" | "ACTIVE" | "ENDED"
preparation_time_remaining   número ≥ 0; > 0 só em PREPARATION
raiders                      só em ACTIVE, e nunca vazio em ACTIVE
  raider_id                  "raider_001" | "raider_002"
  health                     > 0 e ≤ max_health da RaiderDefinition (40)
  position                   [x, y, z]
  phase                      "APPROACH" | "LOOT" | "RETREAT"
  loot                       resource_id → int > 0; ids que a guilda saqueia; total ≤ loot_capacity (3)
repelled, escaped            int ≥ 0
```

Invariantes de domínio (conferidas no `SaveGameController`, contra a Definition e o tamanho da
guilda):

- NOT_STARTED e PREPARATION não têm desfecho registrado (`repelled + escaped == 0`).
- ACTIVE fecha com a guilda: `raiders + repelled + escaped == 2`.
- ENDED: `repelled + escaped == 2` — ninguém ficou para trás.
- `raider_id` canônico e sem repetição.

### O que não vai para o arquivo

```text
loot_capacity, steal_interval, retreat_health_ratio, loot_priority, loot_range   — RaiderDefinition
preparation_duration, limiar e pesos da Notoriedade                               — controller
o que já foi roubado e fugiu                                                      — já saiu de economy.stockpile
```

O saque em curso **é** estado (está no bolso daquele saqueador e volta ao estoque se ele morrer).
O saque que fugiu não é: ele saiu do estoque no instante do roubo, e o saldo de
`economy.stockpile` já diz isso. Gravar "o que a guilda levou" duplicaria o estoque.

---

## Migração V4 → V5 (com a cadeia completa)

```text
CampaignSnapshot.migrate_to_current(document)
  ├─ save_version == 1 → migrate_v1_to_v2
  ├─ save_version == 2 → migrate_v2_to_v3
  ├─ save_version == 3 → migrate_v3_to_v4
  └─ save_version == 4 → migrate_v4_to_v5
```

| Degrau | O que acrescenta |
| --- | --- |
| V1 → V2 | `constructions.mine = { "exists": false }` |
| V2 → V3 | `constructions.fungal_farm = { "exists": false }` |
| V3 → V4 | `units.worker_003_summoned = false` |
| V4 → V5 | `surface = { notoriety, incursion NOT_STARTED sem saqueadores }` |

A Notoriedade migrada não é inventada: ela é **20 se o `core.level` gravado for ≥ 2** e 0 no Nv.1.
É o mesmo fato que, jogado, soma 20 (a evolução para o Nv.2). Como 20 é o limiar da guilda, uma
campanha V4 que já estava no Nv.2 carrega com a incursão em NOT_STARTED e a regra viva do gatilho
abre a preparação ao fim da carga — a guilda passa a vir também para a campanha antiga.

Cada degrau sobe exatamente uma versão; uma campanha V1 percorre os quatro, na ordem. Os arquivos
antigos nunca são reescritos no disco; quem atualiza é o próximo save, que já sai V5.

---

## Versão desconhecida = recusa

```text
SUPPORTED_VERSIONS = [1, 2, 3, 4, 5]
```

`save_version` `0`, `6`, `999`, ausente ou não inteiro → recusa com o mundo intacto.

---

## Restauração

A superfície é o último passo de dados da ordem de restauração, depois da evolução derivada:

```text
_incursion.restore_surface(notoriety, state, remaining, raiders, repelled, escaped)
```

- Nada é reemitido como conquista: nem `incursion_started`, nem `incursion_ended`, nem
  Notoriedade somada. O valor volta exatamente como estava.
- PREPARATION retoma o segundo exato do arquivo; o tempo com o jogo fechado não é simulado.
- ACTIVE recria só os saqueadores do arquivo, cada um com vida, posição, fase e saque, e retoma o
  saque na fase em que estava.
- A carga restaura o nível do Núcleo sem o sinal `evolved`, então a evolução nunca soma
  Notoriedade duas vezes.

---

## Como isto é testado

`tests/test_surface_incursion.gd`: save e load em PREPARATION (segundo exato), em ACTIVE no meio
do saque (saque, fase e vida voltam; a incursão segue até o fim), em ENDED (terminal), loads
repetidos sem duplicar saqueador, a migração V4 no Nv.1 (Notoriedade 0) e no Nv.2 (Notoriedade 20
e a guilda a caminho), a corrente V1 → V5, e as recusas — V5 sem `surface`, ACTIVE sem
saqueador, saque acima da capacidade, `raider_id` desconhecido, ENDED que não fecha a guilda,
Notoriedade acima de 100 e `save_version = 6` — todas com o mundo intacto.
