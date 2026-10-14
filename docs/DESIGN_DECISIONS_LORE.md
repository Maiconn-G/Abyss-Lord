# Decisões de lore — alinhamento com a inspiração

Registro das decisões que alinham a narrativa de Abyss Lord à sua inspiração, o manhwa
*Dungeon Odyssey*. Elas continuam a numeração de `docs/DESIGN_DECISIONS_POST_MVP.md`
(D1–D7) e fecham apenas **design e narrativa**: nenhum `.gd`, `.tscn` ou `.tres` de
produção foi alterado.

```text
decididas em        = após a Tarefa 21 (documental), 14/10/2026
base                = main @ fa45c82 (Tarefa 21 — Biomassa e Fazenda Fúngica)
GDD atualizado      = cabeçalho, §1.1, §2, §12, §31, §51.1, §58.1, §63, §64, §65,
                      §66, §68, §69, §91, §97, §104
código alterado     = nenhum
```

Princípio que vale para as três: **inspiração, não cópia**. Premissa e tom vêm da obra;
nomes, termos próprios, personagens, eventos e arte são criação deste projeto (§1.1).

---

## D8 — Protagonista

**Decisão:**

```text
O Regente é um humano, Marcado pelo Abismo, que reprimiu a afinidade abissal e
trabalhava como guia de incursões. Uma incursão dá errado e o Núcleo moribundo
se ata a ele. Ele herda o domínio por acidente, não por escolha.
O mistério da linhagem do Núcleo (assimilação, destruição deliberada) é mantido
e passa a se ligar ao fim da Guerra da Fronteira.
```

**Motivo:**

Dá ao protagonista um conflito interno (identidade, dois mundos) que o Regente amnésico
não tinha, sem perder o mistério que sustenta a campanha longa.

**Impacto:** §31, §63, §64, §68, §97. Nenhum impacto no código: o avatar do Regente ainda
não está implementado.

**STATUS: DECIDIDO**

---

## D9 — Superfície e Incursões

**Decisão:**

```text
O mundo vive depois da Guerra da Fronteira entre superfície e subterrâneo.
Invasões passam a ter duas origens: subterrâneo e superfície.
Incursões da Superfície são guildas humanas que saqueiam e recuam.
Notoriedade é a faceta da Ameaça voltada para a superfície.
Entrada: Vertical Slice (pelo menos um dos 3 tipos de inimigo é uma guilda).
```

**Motivo:**

Transforma o passado do protagonista em mecânica (reconhecimento contra guildas) e cria
um tipo de invasor com comportamento diferente das criaturas: objetivo de saque e
retirada.

**Impacto:** §13 (via §58.1), §58.1, §59, §65, §66, §69, §91. A invasão do MVP (Feras
Cavernosas) continua do tipo subterrâneo e não muda.

**STATUS: DECIDIDO**

---

## D10 — Povos Nativos e Legitimidade

**Decisão:**

```text
A masmorra herdada tem Povos Nativos do antigo domínio, encontrados ao escavar.
Povos iniciais (nomes provisórios): Guarda Decapitada, Elfos Cinzentos e
o Dragão Adormecido (marco de campanha).
Cada povo tem Legitimidade 0–100 em cinco faixas (hostil → devoto).
Legitimidade muda por decisões e atos; não é moeda e não mora no estoque.
Entrada: Vertical Slice (1 povo encontrado).
```

**Motivo:**

Coloca a política *dentro* da masmorra antes da diplomacia externa: o Regente aprende a
governar em casa. Reaproveita a Lealdade que o GDD já previa (§12), agora em versão
coletiva.

**Impacto:** §12, §51.1, §65, §66, §91. Quando for implementado, o estado de Legitimidade
entra no save em uma versão nova e explícita do schema — não retroativamente no V3.

**STATUS: DECIDIDO**

---

## O que não mudou

* D1–D7 continuam valendo como estão.
* MVP, Mina Abissal, Biomassa, Fazenda Fúngica e Save Schema V3: sem alteração.
* Ordem do Vertical Slice: os Trabalhadores adicionais (Tarefa 22) vêm antes de Povos
  Nativos e Incursões.
