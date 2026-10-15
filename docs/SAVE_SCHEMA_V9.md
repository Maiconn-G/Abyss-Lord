# Save schema v9

## Objetivo

O delta V8 → V9 da Tarefa 27: o segundo Povo Nativo, os **Elfos Cinzentos**, e a primeira
**disputa** entre povos, "O Salão contra as Raízes". O contrato inteiro continua em
`docs/SAVE_SCHEMA_V1.md`; a seção `natives` foi criada no V6 (`SAVE_SCHEMA_V6.md`).

```text
O save não é uma fotografia da SceneTree. Ele é uma fotografia da campanha.
```

---

## A diferença V8 → V9

`natives` ganhou dois registros. O da Guarda (`decapitated_guard`) não mudou.

```json
{
  "natives": {
    "decapitated_guard": { "seal_work_done": 10.0, "legitimacy": 50, "...": "igual ao V8" },
    "grey_elves": {
      "seal_work_done": 14.0,
      "legitimacy": 75,
      "requests_fulfilled": 2,
      "oath_sworn": true,
      "guardian": { "alive": false }
    },
    "dispute": { "resolution": "SECOND" }
  }
}
```

```text
grey_elves            mesma forma do registro da Guarda (selo, Legitimidade, pedidos, juramento, guardian)
dispute.resolution    "UNRESOLVED" | "FIRST" (Guarda favorecida) | "SECOND" (Elfos favorecidos)
save_version          9 (era 8)
```

Regras de domínio (no `SaveGameController`, contra as Definitions de cada povo):

- Cada povo é conferido contra a **própria** Definition: o selo dos Elfos exige 14 de trabalho e só
  pode ter sido trabalhado a partir do Nv.3; o da Guarda, 10 a partir do Nv.2.
- Os Elfos não têm Guardião: `grey_elves.guardian.alive == true` é recusado.
- `dispute.resolution` diferente de `"UNRESOLVED"` exige os **dois** povos encontrados.
- A disputa "aberta" não é campo: é a leitura de "os dois encontrados e nada decidido".

### O bônus do juramento élfico não é duplicado

O juramento dos Elfos abre +4 de capacidade populacional. Esse bônus entra no `CoreState` uma vez,
no instante do juramento, e passa a morar em `core.population_capacity_bonus`, que o arquivo já
grava. A carga restaura o número e **não** soma o bônus de novo, porque não reemite o juramento.

O que **não** vai para o arquivo: os lados da disputa, o peso (±15), os pedidos e textos de cada
povo — tudo isso é das Definitions.

---

## Migração V8 → V9

| Degrau | O que acrescenta |
| --- | --- |
| V7 → V8 | `surface.clean_repel_milestone` |
| V8 → V9 | `natives.grey_elves` intocado e `natives.dispute = { "resolution": "UNRESOLVED" }` |

Uma campanha V8 que já estava no Nv.3 carrega com o selo das Raízes desperto e intacto, pela regra
viva do controller. Os arquivos antigos nunca são reescritos no disco.

```text
SUPPORTED_VERSIONS = [1, 2, 3, 4, 5, 6, 7, 8, 9]
```

`save_version` `0`, `10`, `999` → recusa com o mundo intacto.

---

## Restauração

Cada povo volta pelo próprio controller (`restore_natives`), e a disputa volta depois deles
(`restore_dispute`), porque "aberta" é lida dos povos. Nenhum sinal de descoberta, juramento ou
decisão é reemitido, e nenhuma Legitimidade é movida de novo.

---

## Como isto é testado

`tests/test_grey_elves_dispute.gd`: a decisão e o juramento élfico voltam, três loads não somam a
capacidade de novo nem reanunciam nada, e há dois selos no mundo; a migração V8 no Nv.3 ganha o selo
das Raízes intacto e a disputa sem decisão; recusas de Guardião élfico, disputa decidida sem os Elfos
encontrados, decisão desconhecida, V9 sem os Elfos, selo das Raízes trabalhado no Nv.2 e
`save_version = 10`.
