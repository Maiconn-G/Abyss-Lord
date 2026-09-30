# Save schema v2

## Objetivo

Este arquivo documenta o que mudou no formato `campaign_save.json` na Tarefa 20 e só isso. O
contrato inteiro — caminhos, escrita atômica, ordem de restauração, comportamento em falha —
está em `docs/SAVE_SCHEMA_V1.md` e continua valendo palavra por palavra; este documento é o
delta, não uma segunda leitura do mesmo assunto.

A frase que define o formato continua sendo a da Tarefa 18 (§2/§15):

```text
O save não é uma fotografia da SceneTree. Ele é uma fotografia da campanha.
```

E é exatamente por ela que a Mina entra no arquivo como **um número de relógio**, e não como
um Node, uma cena ou um "sistema de produção salvo".

Donos do formato, inalterados:

```text
systems/persistence/campaign_snapshot.gd    → a forma do JSON, os nomes e a validação estrutural
systems/persistence/save_game_controller.gd → o caminho, a escrita, as faixas contra as
                                              Definitions injetadas e a restauração
game/game_main.gd                           → a raiz de composição: injeta e apresenta
```

---

## A diferença V1 → V2

Uma única seção ganhou um registro. Nada antigo mudou de nome, de tipo ou de significado:

```text
constructions.nest       igual ao V1
constructions.barracks   igual ao V1
constructions.mine       NOVO — a Mina Abissal
```

`core`, `progression`, `economy`, `units`, `world` e `invasion` são os mesmos do V1. Não houve
renomeio de campo, mudança de faixa nem ajuste de conveniência — V2 é acréscimo, e é isso que
torna a migração uma função de três linhas em vez de um adaptador.

O motivo de a versão subir: um arquivo V1 não tem como expressar "esta campanha tem uma Mina
operando no meio de um ciclo de 10 s". Ler um V1 como V2 sem migração seria inventar estado.

```text
format       = "abyss_lord_campaign"   (inalterado)
save_version = 2                        (era 1)
```

---

## O registro `constructions.mine`

```json
{
  "constructions": {
    "nest":     { "exists": true,  "nest_id": "nest_001",     "remaining_work": 0.0,   "position": [-5.0, 0.0, -5.0] },
    "barracks": { "exists": true,  "barracks_id": "barracks_001", "remaining_work": 2.5, "position": [-10.0, 0.0, -5.0] },
    "mine":     { "exists": true,  "mine_id": "mine_001",     "remaining_work": 0.0,
                  "position": [0.0, 0.0, -9.0], "production_elapsed": 6.25 }
  }
}
```

```text
exists               bool   — a obra foi lançada
mine_id              "mine_001"  — identidade semântica, nunca instance_id
remaining_work       número ≥ 0  ≤ work_required (8.0 da MineDefinition)
position             [x, y, z]
production_elapsed   número ≥ 0  < production_interval (10.0) — SOMENTE quando remaining_work == 0
```

É o mesmo formato de `nest` e `barracks` com um campo a mais, e as mesmas regras:

- `completed` continua **não** ser campo: deriva de `remaining_work <= 0` (§123/T18).
- `exists: false` é o registro inteiro de uma Mina que o jogador ainda não construiu. Uma
  campanha Nv.2 sem Mina é um arquivo normal, não um arquivo incompleto.
- `production_elapsed` só existe com a obra pronta. `remaining_work > 0` com relógio não zero é
  contradição — o canteiro não produz — e é recusado pelo `SaveGameController`, que é quem
  conhece a `MineDefinition` (§50).
- A faixa superior do relógio é a `production_interval` da Definition, e faixa contra Definition
  é domínio: por isso essa checagem mora no controller, não no contrato estrutural.

O que **não** entra no arquivo:

```text
a existência da Mina como Node, o caminho da cena, o collision_layer
production_amount / production_interval / required_core_level / build_cost / work_required
  — todos lidos da MineDefinition injetada pela raiz de composição (§122/§123/T18)
qualquer marca de "quantos minérios esta Mina já deu"
```

Gravar o produto acumulado seria duplicar o que o `economy.stockpile` já diz, e a cópia dos
dois divergiria na primeira carga.

---

## Migração V1 → V2

A migração é uma função nomeada, chamada dentro de `_read_document()` — portanto **antes** de
`_apply()`, nunca durante. A meia aplicação continua proibida (§67).

```text
CampaignSnapshot.migrate_to_current(document)
  └─ se document.save_version == 1 → CampaignSnapshot.migrate_v1_to_v2(document)
```

O único fato novo de um V1 migrado é que aquela campanha não tem Mina:

```text
campaign.constructions.mine = { "exists": false }
save_version                = 2
```

Nenhum outro número é tocado. O `migrate_v1_to_v2` não reescreve integridade, não reconta
população e não infere nada — o documento migrado passa a ser validado como V2 e, se não
passar, o resultado é recusa com o mundo intacto, como qualquer arquivo ruim.

Um V1 entra no jogo por dois caminhos, e a migração cobre os dois:

| Origem | O que acontece |
| --- | --- |
| primário `campaign_save.json` com `save_version: 1` | migra, valida como V2 e aplica |
| backup `.bak` com `save_version: 1` (primário corrompido) | o fallback lê o backup, migra e aplica; `load_succeeded` anuncia o caminho `.bak` |

Depois de um load migrado, o próximo save já é escrito como V2 e passa a dizer a verdade sobre
a Mina que o jogador vier a construir (§101). O documento V1 nunca é reescrito no disco em
nome de "atualizar"; quem atualiza é o save.

### Sem framework de migração

Não existe `MigrationRegistry`, `MigrationManager`, `SchemaGraph`, `MigrationDefinition` nem
`MigrationV2`. Há duas funções estáticas por versão (`validate_v1`, `validate_v2`) e uma rota
explícita entre elas. Quando existir um V3, ele entra como mais um passo nomeado nessa mesma
sequência — se três versões coexistirem um dia, aí então se discute se a lista virou estrutura.

---

## Versão desconhecida = recusa

O contrato aceita exatamente dois números:

```text
SUPPORTED_VERSIONS = [1, 2]
```

`save_version` `0`, `3`, `999`, `1.5`, `null` ou ausente produz:

```text
load_campaign() → false
operation_failed("load", "save_version não suportado: <valor>")
mundo                             → intacto
```

Isso vale também para o número do **futuro**: um save de uma build mais nova não é lido "com o
que der". Recusar antes de tocar em um único número é o que permite a uma versão nova conviver
com um arquivo que ela não conhece (§57/§103).

---

## Progresso offline: não

```text
O relógio da Mina avança enquanto o jogo roda. Nunca enquanto ele está fechado.
```

Não há timestamp de "última produção", não há contas de quanto tempo passou desde o save e não
há concessão de minério na carga (§52/§63). O que volta é `production_elapsed`: o resto do
ciclo em curso, e nada mais.

A consequência observável, que é também o teste:

```text
save com production_elapsed = 6.25
load  → a Mina volta produzindo, com o relógio em 6.25, saldo inalterado,
        mine_completed não reemitido
+3.75 s de mundo → o primeiro minério desde o load
```

Um load que "pusesse o atraso" seria o pior tipo de bug de persistência: duplicaria produção a
cada salvamento e transformaria tempo de relógio em moeda.

---

## Restauração da Mina na ordem existente

A Mina entra no passo 11 (`Ninho e Quartel`), pela mesma rota dos outros canteiros:

```text
_construction.restore_mine(exists, remaining_work, position, production_elapsed)
```

- Sem Mina no arquivo → `restore_mine(false, 0, ZERO, 0)` remove a obra que porventura exista
  na cena, mantendo `mine()` único em carga repetida (§66/§104).
- Mina já em cena → escreve `remaining_work` e `production_elapsed` pelos caminhos de
  restauração dos States; não recria Node.
- Mina nova em campanha que não a tinha → instancia pelo `MINE_SCENE` injetado na raiz de
  composição, vincula o `ResourceStockpileState` e só então restaura os números.
- Mina concluída → `_sync_production()` liga o `_process` no mesmo passo, sem emitir conclusão
  e sem produzir (§21/T20, §64).

Nenhum outro passo da ordem mudou.

---

## Como isto é testado

```text
tests/test_save_load.gd        → o contrato: fixture V1 byte a byte, migração, backup V1,
                                 roundtrip, recusa de versão, idempotência de carga
tests/test_abyssal_mine.gd     → a economia: a Mina no arquivo incompleta e no meio do ciclo,
                                 carga repetida, V1 migrado que pode construir a Mina,
                                 save_version 999 recusado com o mundo intacto
```
