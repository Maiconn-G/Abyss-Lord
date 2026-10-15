# Save schema v7

## Objetivo

O delta V6 → V7 da Tarefa 25: as Incursões da Superfície passam a ser **recorrentes**. O contrato
inteiro continua em `docs/SAVE_SCHEMA_V1.md`; a seção `surface` foi criada no V5
(`SAVE_SCHEMA_V5.md`).

```text
O save não é uma fotografia da SceneTree. Ele é uma fotografia da campanha.
```

Depois de cada incursão vem uma **calmaria**; ao fim dela, a próxima guilda começa a preparação. O
tamanho da guilda é lido da Notoriedade no instante da largada (2 até 40, 3 até 60, 4 até 80, 5
acima). Três números passam a descrever isso.

---

## A diferença V6 → V7

Só `surface.incursion` mudou, ganhando três campos. Nenhum campo antigo mudou de nome, tipo ou
significado.

```json
{
  "surface": {
    "notoriety": 45,
    "incursion": {
      "state": "ENDED",
      "preparation_time_remaining": 0.0,
      "raiders": [],
      "repelled": 1,
      "escaped": 2,
      "incursion_number": 2,
      "guild_size": 3,
      "cooldown_remaining": 61.5
    }
  }
}
```

```text
incursion_number     int ≥ 0 — quantas incursões já foram largadas (0 antes da primeira)
guild_size           int 0..5 — o tamanho da incursão atual, ou da última
cooldown_remaining   número ≥ 0 — a calmaria que falta; > 0 só em ENDED
repelled, escaped    passam a ser os da incursão atual (zerados a cada largada)
```

```text
save_version = 7   (era 6)
```

Regras:

- NOT_STARTED → `incursion_number == 0` e `guild_size == 0` (a primeira guilda ainda não veio).
- ACTIVE e ENDED → `incursion_number ≥ 1` e `guild_size ≥ 2`.
- `cooldown_remaining > 0` só em ENDED.
- Saqueadores em campo nunca passam de `guild_size`, e cada `raider_id` é `raider_001` até o
  tamanho da guilda.
- O fechamento da guilda continua (conferido no `SaveGameController`): em ACTIVE,
  `em campo + repelled + escaped == guild_size`; em ENDED, `repelled + escaped == guild_size`.

O que **não** vai para o arquivo: a duração da calmaria (90 s) e a da preparação (120 s), e a tabela
de tamanho por faixa — tudo isso é do controller.

---

## Migração V6 → V7

| Degrau | O que acrescenta |
| --- | --- |
| V1 → V2 | `constructions.mine` |
| V2 → V3 | `constructions.fungal_farm` |
| V3 → V4 | `units.worker_003_summoned` |
| V4 → V5 | `surface` |
| V5 → V6 | `natives` |
| V6 → V7 | `incursion_number`, `guild_size`, `cooldown_remaining` |

Um V6 conhecia uma única incursão, sempre de 2. Em ACTIVE ou ENDED ela vira a **incursão 1, de 2
saqueadores**; antes dela, `0` e `0`. A calmaria migra **zerada**: uma campanha V6 que tinha
terminado a incursão vê a próxima guilda começar a preparação logo depois da carga. Isso é a regra
nova aplicada a um estado antigo, não um evento inventado. Os arquivos antigos nunca são reescritos
no disco.

```text
SUPPORTED_VERSIONS = [1, 2, 3, 4, 5, 6, 7]
```

`save_version` `0`, `8`, `999` → recusa com o mundo intacto.

---

## Restauração

`restore_surface` recebe também número, tamanho e calmaria. ENDED volta com o relógio da calmaria
ligado e no segundo exato do arquivo; nenhum sinal de largada ou desfecho é reemitido.

---

## Como isto é testado

`tests/test_recurring_incursions.gd`: a calmaria no meio volta no segundo exato e continua contando;
uma guilda de 4 com 3 em campo volta igual, e três loads não duplicam; a migração V6 de uma
incursão encerrada vira incursão 1 e chama a próxima guilda; a de uma campanha sem incursão continua
zerada; recusas de guilda de 6, calmaria em ACTIVE, ACTIVE sem número, saqueadores além da guilda,
`raider_id` além da guilda e `save_version = 8`.
