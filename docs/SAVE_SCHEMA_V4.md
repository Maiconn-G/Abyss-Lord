# Save schema v4

## Objetivo

Este arquivo documenta o que mudou no formato `campaign_save.json` na Tarefa 22 e só isso. O
contrato inteiro — caminhos, escrita atômica, ordem de restauração, comportamento em falha —
continua em `docs/SAVE_SCHEMA_V1.md`, e os deltas anteriores em `docs/SAVE_SCHEMA_V2.md` (Mina)
e `docs/SAVE_SCHEMA_V3.md` (Fazenda Fúngica). Este documento é o delta V3 → V4.

A frase que define o formato continua sendo a da Tarefa 18:

```text
O save não é uma fotografia da SceneTree. Ele é uma fotografia da campanha.
```

E é por ela que o terceiro Trabalhador entra no arquivo como **uma flag histórica e um registro
de unidade** — e não como receita, fila de invocação ou saldo de Biomassa gasto.

Donos do formato, inalterados:

```text
systems/persistence/campaign_snapshot.gd    → a forma do JSON, os nomes e a validação estrutural
systems/persistence/save_game_controller.gd → o caminho, a escrita, as faixas contra as
                                              Definitions injetadas e a restauração
game/game_main.gd                           → a raiz de composição: injeta e apresenta
```

---

## A diferença V3 → V4

A seção `units` ganhou uma chave e passou a aceitar mais uma identidade de Worker:

```text
units.workers               aceita worker_001, worker_002 e, só no V4, worker_003
units.worker_002_summoned   igual ao V3
units.worker_003_summoned   NOVO — a flag histórica da expansão por Biomassa
units.soldier               igual ao V3
```

`core`, `progression`, `economy`, `constructions`, `world` e `invasion` são os mesmos do V3.
Nada antigo mudou de nome, de tipo ou de significado — V4 é acréscimo.

O motivo de a versão subir: um arquivo V3 não tem como expressar "esta campanha invocou o
terceiro Trabalhador". O validador V3 recusa o registro `worker_003`, e ler um V3 como V4 sem
migração seria inventar estado.

```text
format       = "abyss_lord_campaign"   (inalterado)
save_version = 4                        (era 3)
```

---

## Os registros novos

```json
{
  "units": {
    "workers": [
      { "unit_id": "worker_001", "unit_type_id": "abyss_worker", "health": 50.0, "level": 1,
        "experience": 0.0, "position": [2.0, 0.0, 2.0], "carried_resource": null, "carried_amount": 0 },
      { "unit_id": "worker_003", "unit_type_id": "abyss_worker", "health": 50.0, "level": 1,
        "experience": 0.0, "position": [3.0, 0.0, 3.0], "carried_resource": "iron_ore", "carried_amount": 2 }
    ],
    "worker_002_summoned": false,
    "worker_003_summoned": true,
    "soldier": { "recruited": false, "alive": false }
  }
}
```

```text
worker_003_summoned   bool — obrigatório no V4; true depois da primeira invocação, para sempre
worker_003            registro de Worker idêntico aos outros dois (mesmo unit_type_id abyss_worker)
```

Regras do V4:

- `worker_003_summoned` é obrigatório. Ausente → recusa estrutural (`units precisa de
  worker_003_summoned`).
- Um registro `worker_003` com `worker_003_summoned: false` é contradição — a unidade não pode
  existir sem ter sido invocada — e é recusado no contrato estrutural.
- A flag `true` sem registro é legítima: é o terceiro Worker que existiu e morreu. É a mesma
  regra do segundo Worker.
- `worker_003_summoned: true` com o Núcleo abaixo do nível que a receita exige (Nv.2) descreve
  uma campanha impossível, porque o Núcleo não regride. Essa faixa é domínio — vem da
  `WorkerExpansionDefinition` injetada — e por isso é conferida pelo `SaveGameController`, não
  pelo contrato estrutural.
- A população continua fechando com as unidades vivas: o terceiro Worker conta como mais uma.

### A receita não vai para o arquivo

O que **não** entra no arquivo:

```text
required_core_level, biomass_cost, essence_cost   — lidos da WorkerExpansionDefinition
o saldo de Biomassa                               — já mora em economy.stockpile
o saldo de Essência                               — já mora em core.essence
```

A Biomassa e a Essência que a invocação gastou já estão refletidas nos saldos do estoque e do
Núcleo. Gravar o custo criaria uma segunda verdade sobre o preço; gravar "o que foi pago"
duplicaria os saldos.

---

## Migração V3 → V4 (com a cadeia completa)

```text
CampaignSnapshot.migrate_to_current(document)
  ├─ se save_version == 1 → migrate_v1_to_v2(document)
  ├─ se save_version == 2 → migrate_v2_to_v3(document)
  └─ se save_version == 3 → migrate_v3_to_v4(document)
```

| Degrau | O que acrescenta |
| --- | --- |
| V1 → V2 | `campaign.constructions.mine = { "exists": false }` |
| V2 → V3 | `campaign.constructions.fungal_farm = { "exists": false }` |
| V3 → V4 | `campaign.units.worker_003_summoned = false` |

Cada degrau sobe exatamente uma versão. Uma campanha V1 percorre os três degraus, na ordem, e
chega ao V4 sem Mina, sem Fazenda e sem terceiro Trabalhador — nunca por atalho. Não há unidade a
converter no degrau V3 → V4, porque o V3 não sabia registrar `worker_003`.

Depois de um load migrado, o próximo save já é escrito como V4. Os arquivos V1, V2 e V3 nunca são
reescritos no disco em nome de "atualizar".

### Sem framework de migração

Continua não existindo `MigrationRegistry`, `MigrationManager` nem `SchemaGraph`. São quatro
funções de validação (`validate_v1` a `validate_v4`) e três degraus nomeados.

---

## Versão desconhecida = recusa

```text
SUPPORTED_VERSIONS = [1, 2, 3, 4]
```

`save_version` `0`, `5`, `999`, `1.5`, `null` ou ausente produz recusa com o mundo intacto.

---

## Restauração do terceiro Worker na ordem existente

O terceiro Worker entra no passo 12 (`Workers`), logo depois do segundo, por rota própria:

```text
_expansion.restore_expansion_history(worker_003_summoned)
_expansion.restore_expanded_worker(health, level, experience, cargo, amount, position)
  — ou —
_expansion.remove_expanded_worker()   (arquivo sem registro worker_003)
```

- Montar não é invocar: nenhuma Biomassa ou Essência é cobrada, nenhuma população é somada (ela
  volta pelo `CoreState`) e `worker_expanded` não é reemitido.
- Load repetido encontra o Runtime da carga anterior e ajusta os números dele; nunca cria um
  quarto Worker.
- Arquivo sem `worker_003` desmonta o Runtime que porventura exista.

Nenhum outro passo da ordem mudou.

---

## Como isto é testado

`tests/test_worker_expansion.gd` cobre: o roundtrip V4 com o terceiro Worker carregando minério,
a carga que desmonta o Worker ausente do arquivo, loads repetidos sem duplicação, a migração
V3 → V4 (o V3 carrega, a flag nasce false, a campanha pode expandir e o re-save sai V4) e a
corrente V1 → V2 → V3 → V4, além das recusas: V3 com `worker_003`, registro sem a flag, flag no
Nv.1 e `save_version = 5` — todas com o mundo intacto.
