# Save schema v3

## Objetivo

Este arquivo documenta o que mudou no formato `campaign_save.json` na Tarefa 21 e só isso. O
contrato inteiro — caminhos, escrita atômica, ordem de restauração, comportamento em falha —
está em `docs/SAVE_SCHEMA_V1.md` e continua valendo palavra por palavra; este documento é o
delta, não uma segunda leitura do mesmo assunto.

A frase que define o formato continua sendo a da Tarefa 18 (§2/§15):

```text
O save não é uma fotografia da SceneTree. Ele é uma fotografia da campanha.
```

E é exatamente por ela que a Fazenda Fúngica entra no arquivo como **um número de relógio** —
e não como um Node, uma cena, um "sistema de produção salvo" ou um saldo de Biomassa.

Donos do formato, inalterados:

```text
systems/persistence/campaign_snapshot.gd    → a forma do JSON, os nomes e a validação estrutural
systems/persistence/save_game_controller.gd → o caminho, a escrita, as faixas contra as
                                              Definitions injetadas e a restauração
game/game_main.gd                           → a raiz de composição: injeta e apresenta
```

---

## A diferença V2 → V3

Uma única seção ganhou um registro. Nada antigo mudou de nome, de tipo ou de significado:

```text
constructions.nest         igual ao V2
constructions.barracks     igual ao V2
constructions.mine         igual ao V2
constructions.fungal_farm  NOVO — a Fazenda Fúngica
```

`core`, `progression`, `economy`, `units`, `world` e `invasion` são os mesmos do V2. Não houve
renomeio de campo, mudança de faixa nem ajuste de conveniência — V3 é acréscimo, e é isso que
torna a migração uma função curta em vez de um adaptador.

O motivo de a versão subir: um arquivo V2 não tem como expressar "esta campanha tem uma
Fazenda Fúngica operando no meio de um ciclo de 8 s". Ler um V2 como V3 sem migração seria
inventar estado.

```text
format       = "abyss_lord_campaign"   (inalterado)
save_version = 3                        (era 2)
```

---

## O registro `constructions.fungal_farm`

```json
{
  "constructions": {
    "nest":        { "exists": true,  "nest_id": "nest_001", "remaining_work": 0.0, "position": [-5.0, 0.0, -5.0] },
    "barracks":    { "exists": true,  "barracks_id": "barracks_001", "remaining_work": 2.5, "position": [-10.0, 0.0, -5.0] },
    "mine":        { "exists": true,  "mine_id": "mine_001", "remaining_work": 0.0,
                     "position": [0.0, 0.0, -9.0], "production_elapsed": 6.25 },
    "fungal_farm": { "exists": true,  "fungal_farm_id": "fungal_farm_001", "remaining_work": 0.0,
                     "position": [10.0, 0.0, -9.0], "production_elapsed": 8.0 }
  }
}
```

```text
exists               bool   — a obra foi lançada
fungal_farm_id       "fungal_farm_001"  — identidade semântica, nunca instance_id
remaining_work       número ≥ 0  ≤ work_required (6.0 da FungalFarmDefinition)
position             [x, y, z]
production_elapsed   número ≥ 0  ≤ production_interval (8.0) — SOMENTE quando remaining_work == 0
```

É o mesmo formato de `mine` com outro nome de id e **uma faixa superior diferente**, que é a
única sutileza real desta versão:

```text
mine.production_elapsed         < production_interval   (strict)
fungal_farm.production_elapsed  ≤ production_interval   (inclusive)
```

A razão vem do comportamento das duas obras, não do capricho do formato:

- **Mina** — um `elapsed` que alcança o intervalo já virou minério e foi entregue ao estoque
  no mesmo passo. Não existe Mina "com um ciclo acumulado parado", então o topo é exclusive.
- **Fazenda** — §17 define que um ciclo pronto **parado esperando Essência** é um estado
  legítimo. Enquanto a Essência não chega, o relógio satura exatamente em `production_interval`
  e ali permanece. Gravar `8.0` é gravar a verdade, então o topo é inclusive.

As mesmas regras do V2 continuam valendo, aplicadas ao registro novo:

- `completed` continua **não** ser campo: deriva de `remaining_work <= 0`.
- `exists: false` é o registro inteiro de uma Fazenda que o jogador ainda não construiu.
- `production_elapsed` só existe com a obra pronta. `remaining_work > 0` com relógio não zero é
  contradição — o canteiro não produz — e é recusado pelo `SaveGameController` (§50).
- A faixa superior é a `production_interval` da Definition, e faixa contra Definition é domínio:
  por isso essa checagem mora no controller, não no contrato estrutural.

### A Essência não é duplicada

O que **não** entra no arquivo:

```text
a existência da Fazenda como Node, o caminho da cena, o collision_layer
production_amount / production_interval / required_core_level / build_cost / work_required
  — lidos da FungalFarmDefinition injetada pela raiz de composição
essence_cost_per_cycle  — lido da FungalFarmDefinition; é configuração, não estado
o saldo de Biomassa     — já mora em economy.stockpile
o saldo de Essência     — já mora em core.essence
```

Dois pontos merecem ser ditos em voz alta, porque são a tentação natural desta versão:

1. **A Essência que a Fazenda gasta por ciclo não vai para o arquivo.** O *custo* é
   configuração (vem da Definition) e o *saldo* já é `core.essence`. Gravar
   `essence_cost_per_cycle` criaria uma segunda verdade sobre o preço; gravar o saldo de novo
   duplicaria `core.essence`. Nenhum dos dois acontece.
2. **O estoque da Fazenda é o mesmo `economy.stockpile` do Minério.** A Biomassa é um
   `resource_id` como `iron_ore`, no mesmo mapa. Não há segundo estoque, nem pilha, nem
   depósito próprios — e por isso não há nenhuma seção nova de economia no V3.

Gravar o produto acumulado seria duplicar o que `economy.stockpile` já diz, e a cópia dos dois
divergiria na primeira carga.

---

## Migração V2 → V3 (com a cadeia completa)

A migração é uma sequência de funções nomeadas, chamadas dentro de `_read_document()` —
portanto **antes** de `_apply()`, nunca durante. A meia aplicação continua proibida (§67).

```text
CampaignSnapshot.migrate_to_current(document)
  ├─ se document.save_version == 1 → CampaignSnapshot.migrate_v1_to_v2(document)
  └─ se document.save_version == 2 → CampaignSnapshot.migrate_v2_to_v3(document)
```

Cada degrau sobe **exatamente uma** versão, e acrescenta só o que é seu:

| Degrau | O que acrescenta |
| --- | --- |
| V1 → V2 | `campaign.constructions.mine = { "exists": false }` |
| V2 → V3 | `campaign.constructions.fungal_farm = { "exists": false }` |

Uma campanha V1 percorre os dois degraus, na ordem, e chega ao V3 com as duas obras
inexistentes — nunca por um atalho `migrate_v1_to_v3`. Isso garante que cada fato do arquivo
antigo tenha um único dono de migração, e que acrescentar um V4 seja mais um `if` nesta mesma
lista, não uma reescrita.

Nenhum outro número é tocado. As migrações não reescrevem integridade, não recontam população
e não inferem nada — o documento migrado passa a ser validado como V3 e, se não passar, o
resultado é recusa com o mundo intacto, como qualquer arquivo ruim.

Os três formatos entram no jogo pelos mesmos dois caminhos, e a migração cobre todos:

| Origem | O que acontece |
| --- | --- |
| primário com `save_version: 2` | migra, valida como V3 e aplica |
| primário com `save_version: 1` | sobe V1→V2→V3, valida e aplica |
| backup `.bak` em qualquer versão antiga (primário corrompido) | o fallback lê, migra e aplica; `load_succeeded` anuncia o caminho `.bak` |

Depois de um load migrado, o próximo save já é escrito como V3 e passa a dizer a verdade sobre
a Fazenda que o jogador vier a construir. O documento V1 e o V2 nunca são reescritos no disco em
nome de "atualizar"; quem atualiza é o save.

### Sem framework de migração

Não existe `MigrationRegistry`, `MigrationManager`, `SchemaGraph`, `MigrationDefinition`,
`MigrationV2` nem `MigrationV3`. Há uma função de validação por versão (`validate_v1`,
`validate_v2`, `validate_v3`) e uma rota explícita entre elas. Com três versões coexistindo, a
sequência continua sendo duas funções de `if` — o dia de discutir estrutura é o dia em que ela
deixar de caber em uma tela.

---

## Versão desconhecida = recusa

O contrato aceita exatamente três números:

```text
SUPPORTED_VERSIONS = [1, 2, 3]
```

`save_version` `0`, `4`, `999`, `1.5`, `null` ou ausente produz:

```text
load_campaign() → false
operation_failed("load", "save_version não suportado: <valor>")
mundo                             → intacto
```

Isso vale também para o número do **futuro**: um save de uma build mais nova — `4`, por
exemplo — não é lido "com o que der". Recusar antes de tocar em um único número é o que permite
a uma versão nova conviver com um arquivo que ela não conhece.

---

## Progresso offline: não

```text
O relógio da Fazenda avança enquanto o jogo roda. Nunca enquanto ele está fechado.
```

Não há timestamp de "última produção", não há contas de quanto tempo passou desde o save e não
há concessão de Biomassa nem consumo retroativo de Essência na carga (§52/§63). O que volta é
`production_elapsed`: o resto do ciclo em curso, e nada mais.

A consequência observável, que é também o teste:

```text
save com production_elapsed = 5.2   (Fazenda pronta, ciclo de 8 s)
load  → a Fazenda volta produzindo, com o relógio em 5.2, saldo inalterado,
        fungal_farm_completed não reemitido, Essência inalterada
+2.8 s de mundo → a primeira Biomassa desde o load (se houver Essência)
```

Um load que "pusesse o atraso" seria o pior tipo de bug de persistência: duplicaria produção a
cada salvamento e transformaria tempo de relógio em moeda.

---

## Restauração da Fazenda na ordem existente

A Fazenda entra no passo 11 (`Ninho, Quartel e Mina`), pela mesma rota dos outros canteiros com
relógio:

```text
_construction.restore_fungal_farm(exists, remaining_work, position, production_elapsed)
```

- Sem Fazenda no arquivo → `restore_fungal_farm(false, 0, ZERO, 0)` remove a obra que porventura
  exista na cena, mantendo `fungal_farm()` único em carga repetida.
- Fazenda já em cena → escreve `remaining_work` e `production_elapsed` pelos caminhos de
  restauração dos States; não recria Node.
- Fazenda nova em campanha que não a tinha → instancia pelo `FUNGAL_FARM_SCENE` injetado na raiz
  de composição, vincula **os dois** (o `ResourceStockpileState` e o `CoreState`) e só então
  restaura os números.
- Fazenda concluída → `_sync_production()` liga o `_process` no mesmo passo, sem emitir conclusão
  e sem produzir.

Nenhum outro passo da ordem mudou.

---

## Como isto é testado

```text
tests/test_save_load.gd              → o contrato: fixture V1 e V2 byte a byte, cadeia de
                                       migração, backup antigo, roundtrip, recusa de versão,
                                       idempotência de carga
tests/test_biomass_fungal_farm.gd    → a economia orgânica: a Fazenda no arquivo incompleta e no
                                       meio do ciclo, o ciclo saturado esperando Essência,
                                       carga repetida, V2 migrado que pode construir a Fazenda,
                                       save_version 4/999 recusado com o mundo intacto
```
