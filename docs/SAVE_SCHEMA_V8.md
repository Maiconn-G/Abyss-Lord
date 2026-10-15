# Save schema v8

## Objetivo

O delta V7 → V8 da Tarefa 26: a **Ascensão** do Núcleo (Nv.2 → Nv.3) e o **Cristal da primeira
guilda inteiramente repelida**. O contrato inteiro continua em `docs/SAVE_SCHEMA_V1.md`.

```text
O save não é uma fotografia da SceneTree. Ele é uma fotografia da campanha.
```

---

## A diferença V7 → V8

Um único campo novo, em `surface`:

```json
{
  "surface": {
    "notoriety": 60,
    "clean_repel_milestone": true,
    "incursion": { "...": "igual ao V7" }
  }
}
```

```text
clean_repel_milestone  bool — o Cristal da primeira guilda repelida sem nenhuma fuga já foi entregue
save_version           8 (era 7)
```

Regra: `clean_repel_milestone: true` exige `incursion_number ≥ 1` — o marco só existe se alguma
incursão já aconteceu.

### O Núcleo Nv.3 não precisa de campo novo

`core.level` já diz o nível. A Definition do Nv.3 (`data/core/core_level_3.tres`) entra na
whitelist de Definitions do `SaveGameController`, e a faixa de Integridade, Essência e população é
conferida contra ela como já era para Nv.1 e Nv.2. Nível 4 ou acima continua sendo recusado como
nível desconhecido.

O que **não** vai para o arquivo: o preço da Ascensão (1 Cristal Abissal + 40 Essência + 10
Biomassa) e a recompensa do marco (1 Cristal) — são dados da Definition e do controller. O Cristal
entregue já está em `progression.abyssal_crystal`, e o que a Ascensão cobrou já saiu dos saldos.

---

## Migração V7 → V8

| Degrau | O que acrescenta |
| --- | --- |
| V6 → V7 | `incursion_number`, `guild_size`, `cooldown_remaining` |
| V7 → V8 | `surface.clean_repel_milestone = false` |

O V7 não conhecia o marco, então ele nunca foi entregue. Nada é inventado: nem uma incursão V7 já
encerrada sem fugas vira Cristal na carga; a **próxima** guilda inteira repelida é que o concede.

```text
SUPPORTED_VERSIONS = [1, 2, 3, 4, 5, 6, 7, 8]
```

`save_version` `0`, `9`, `999` → recusa com o mundo intacto.

---

## Restauração

`restore_surface` recebe também a flag. A carga não emite `clean_repel_crystal_granted` nem
`ascension_completed`, e o Núcleo Nv.3 volta pela mesma rota de nível (`restore_level_view`), com a
escala do Nv.3 e sem cobrar nada.

---

## Como isto é testado

`tests/test_core_ascension.gd`: guilda inteira repelida entrega 1 Cristal, uma vez; guilda com fuga
não entrega; portas da Ascensão em ordem (Nv.2, Cristal, Essência, Biomassa) e atômicas; a tecla V
real ascende; uma tecla V nunca sobe dois níveis; o Nv.3 salva e volta com o marco; a migração V7 não
reconhece marco; recusas de marco sem incursão, V8 sem a flag, Núcleo Nv.4 e `save_version = 9`.
