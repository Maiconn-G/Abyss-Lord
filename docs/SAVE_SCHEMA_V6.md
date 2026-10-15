# Save schema v6

## Objetivo

Este arquivo documenta só o delta V5 → V6 da Tarefa 24. O contrato inteiro continua em
`docs/SAVE_SCHEMA_V1.md`, e os deltas anteriores em `SAVE_SCHEMA_V2.md` (Mina), `V3` (Fazenda
Fúngica), `V4` (terceiro Trabalhador) e `V5` (Notoriedade e Incursão).

```text
O save não é uma fotografia da SceneTree. Ele é uma fotografia da campanha.
```

A Tarefa 24 trouxe o primeiro Povo Nativo (GDD §51.1), a **Guarda Decapitada**. Ela entra no
arquivo como números de campanha: quanto do Selo Antigo já foi rompido, a Legitimidade, quantos
pedidos foram cumpridos, se o juramento foi prestado e o Guardião, se ele está vivo.

---

## A diferença V5 → V6

Uma seção nova, a nona. As oito do V5 continuam obrigatórias e não mudaram.

```text
core, progression, economy, units, constructions, world, invasion, surface   iguais ao V5
natives                                                                       NOVA
```

```text
format       = "abyss_lord_campaign"   (inalterado)
save_version = 6                        (era 5)
```

---

## A seção `natives`

```json
{
  "natives": {
    "decapitated_guard": {
      "seal_work_done": 10.0,
      "legitimacy": 65,
      "requests_fulfilled": 2,
      "oath_sworn": true,
      "guardian": { "alive": true, "health": 100.0, "level": 1, "experience": 0.0,
                    "position": [8.0, 0.0, 3.0] }
    }
  }
}
```

```text
seal_work_done       número ≥ 0 e ≤ work_required do selo (10)
legitimacy           int 0..100
requests_fulfilled   int ≥ 0 e ≤ número de pedidos da Definition (2)
oath_sworn           bool
guardian.alive       bool; quando true: health (> 0, ≤ 140), level ≥ 1, experience ≥ 0, position
```

A Guarda **encontrada** não é campo: ela deriva de `seal_work_done >= work_required`, do mesmo jeito
que "obra concluída" deriva de `remaining_work <= 0`. O selo existe no mundo quando o `core.level`
gravado é ≥ 2; não há campo de existência para ele.

Invariantes de domínio (conferidas no `SaveGameController`, contra a `NativePeopleDefinition`):

- Núcleo abaixo do Nv.2 → `seal_work_done == 0`.
- Guarda não encontrada → `legitimacy == 0`, `requests_fulfilled == 0`, `oath_sworn == false`.
- Encontrada com `legitimacy >= oath_threshold` (61) → `oath_sworn == true` (o juramento é prestado
  no instante em que a Legitimidade cruza o limiar).
- Guardião vivo → `oath_sworn == true` (conferido já no contrato estrutural).
- Vida do Guardião ≤ `max_health` da Definition.

O juramento é histórico: `oath_sworn: true` com Legitimidade abaixo de 61 é legítimo (a Guarda
perdeu confiança depois de jurar), e `oath_sworn: true` com Guardião morto também (ele caiu).

### O que não vai para o arquivo

```text
starting_legitimacy, requests (recurso, quantidade, ganho), pesos dos atos, oath_threshold,
work_required do selo, atributos do Guardião                     — NativePeopleDefinition
o Minério e a Biomassa entregues nos pedidos                     — já saíram de economy.stockpile
```

---

## Migração V5 → V6 (com a cadeia completa)

```text
CampaignSnapshot.migrate_to_current(document)
  ├─ save_version == 1 → migrate_v1_to_v2
  ├─ save_version == 2 → migrate_v2_to_v3
  ├─ save_version == 3 → migrate_v3_to_v4
  ├─ save_version == 4 → migrate_v4_to_v5
  └─ save_version == 5 → migrate_v5_to_v6
```

| Degrau | O que acrescenta |
| --- | --- |
| V1 → V2 | `constructions.mine = { "exists": false }` |
| V2 → V3 | `constructions.fungal_farm = { "exists": false }` |
| V3 → V4 | `units.worker_003_summoned = false` |
| V4 → V5 | `surface = { notoriety, incursion NOT_STARTED }` |
| V5 → V6 | `natives.decapitated_guard` intocado (selo sem trabalho, Guarda não encontrada) |

Nada é inventado: uma campanha V5 que já estava no Nv.2 carrega com o selo desperto e intacto,
porque o selo existe pelo nível gravado. Os arquivos antigos nunca são reescritos no disco; o
próximo save já sai V6.

---

## Versão desconhecida = recusa

```text
SUPPORTED_VERSIONS = [1, 2, 3, 4, 5, 6]
```

`save_version` `0`, `7`, `999`, ausente ou não inteiro → recusa com o mundo intacto.

---

## Restauração

O povo é o último passo de dados da ordem de restauração, depois da superfície:

```text
_natives.restore_natives(core_level, seal_work_done, legitimacy, requests_fulfilled,
                         oath_sworn, guardian)
```

- Nada é reemitido como conquista: nem `seal_awakened`, nem `people_discovered`, nem
  `request_fulfilled`, nem `oath_sworn`. Nenhum recurso é cobrado de novo.
- O selo é recriado se o nível o desperta, com o trabalho restante do arquivo e o visual certo
  (porta selada ou salão aberto). Campanha no Nv.1 não tem selo.
- O Guardião é recriado só se o arquivo o descreve vivo, com vida, nível, experiência e posição.
  Loads repetidos nunca deixam dois Guardiões nem dois selos.

---

## Como isto é testado

`tests/test_native_people.gd`: o selo pela metade volta pela metade; a Guarda encontrada volta com
Legitimidade e pedidos sem reanunciar a descoberta; o Guardião ferido volta ferido, e três loads
deixam um único Guardião; um arquivo Nv.1 remove o selo; a migração V5 no Nv.1 (sem selo) e no Nv.2
(selo intacto); a corrente V1 → V6; e as recusas — V6 sem `natives`, selo acima do trabalho, selo
trabalhado no Nv.1, Legitimidade antes da descoberta, pedidos demais, limiar sem juramento,
Guardião sem juramento, Guardião acima da vida máxima, Legitimidade acima de 100 e
`save_version = 7` — todas com o mundo intacto.
