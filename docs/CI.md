# CI — regressão automática do Abyss Lord

## Fonte única

A regressão tem **um só definidor**: `tests/run_all_tests.ps1`.

Ele descobre as suítes pelo padrão `tests/test_*.gd` (ordem alfabética) e decide
verde/vermelho pelo **exit code** de cada suíte, nunca por regex de log. O GitHub
Actions não mantém uma segunda lista de testes: o workflow baixa a engine, inicializa
o projeto e chama exatamente o mesmo script.

```text
local   powershell -File tests/run_all_tests.ps1
CI      pwsh ./tests/run_all_tests.ps1
```

Como a descoberta é automática, **criar uma nova suíte `test_*.gd` não exige alterar o
workflow** — ela entra na regressão local e na CI na mesma hora.

## Engine congelada

O workflow pinna:

```text
4.6.1-stable
```

Baixada da distribuição oficial `github.com/godotengine/godot-builds`
(asset `Godot_v4.6.1-stable_linux.x86_64.zip`), sem action de terceiro e sem imagem
Docker de terceiros. Um step executa `"$GODOT_BIN" --version` e **falha o job** se a
saída não contiver `4.6.1`, então a CI nunca roda em engine diferente da oficial do
projeto (`4.6.1.stable.official.14d19694e`).

Para mudar de engine é uma decisão deliberada, e exige alterar em conjunto:

```text
projeto (project.godot / baseline local)
workflow (GODOT_VERSION e o gate de versão)
documentação
baseline de asserts das suítes
```

## Workflow

```text
.github/workflows/ci.yml        nome: Abyss Lord CI
job: Godot Regression           id: regression
runner: ubuntu-latest           timeout-minutes: 30
permissions: contents: read     (nenhuma permissão de escrita, nenhum secret)
concurrency: cancela runs antigos da mesma ref
```

### Steps

```text
1. actions/checkout@v7
2. download do Godot oficial pinado (curl --fail --retry, unzip em RUNNER_TEMP)
3. Godot --version validado contra 4.6.1
4. bootstrap: Godot --headless --editor --quit  (import + global_script_class_cache,
   porque um checkout limpo não tem .godot/; SCRIPT ERROR / Parse Error no log falha o job)
5. pwsh ./tests/run_all_tests.ps1
```

Não há export de jogo, artefatos, Steam nem deploy nesta pipeline — ela é de regressão.

## Triggers

```text
push            em main
pull_request    em main
workflow_dispatch (execução manual, sem precisar de commit)
```

## Check obrigatório

O nome exibido do job é o nome usado como required status check:

```text
Godot Regression
```

Esse nome é uma string estável: proteção de branch depende dele. Não renomeie o job
sem reconfigurar a proteção, e não reuse esse nome em outro workflow.

## Quando a CI falha

1. Abra o log do run e leia a suíte que reportou `FAIL` (o runner imprime nome, exit
   code e a linha-resumo por suíte; o log completo fica em `%TEMP%/abyss_lord_test_logs`
   localmente).
2. Reproduza localmente com `tests/run_all_tests.ps1`, ou só a suíte:
   `Godot --headless --path . --script res://tests/test_<suite>.gd`.
3. Corrija o **código ou a infraestrutura**. Se o defeito for de portabilidade
   (path Windows-only, chmod, working directory, cache de `class_name`), corrija o
   runner/workflow com um commit normal do tipo `fix: ...`.
4. Nunca: `continue-on-error`, ignorar exit code, remover suíte, afrouxar um teste de
   gameplay ou alterar o Save Schema V1 para deixar a CI verde.

O número de asserts aparece no log por diagnóstico e **não é gate**: novas tarefas
aumentam a contagem legitimamente. O gate é `17 suítes → 0 FAIL → exit 0` por suíte.

## Política da `main`

Depois da Tarefa 19, `main` é branch estável e protegida:

```text
require pull request antes do merge
approving reviews obrigatórios = 0 (projeto individual)
status checks obrigatórios = Godot Regression
require branches up to date antes do merge
force push bloqueado
deletion da branch bloqueada
```

Fluxo de desenvolvimento a partir de agora:

```text
main atualizada
↓
git switch -c task-20-<descricao>      (task-NN-..., feat/..., fix/...)
↓
implementar + testes locais (run_all_tests.ps1)
↓
commit
↓
git push -u origin task-20-<descricao>
↓
Pull Request para main
↓
Godot Regression precisa estar verde
↓
merge
```

Nenhum desenvolvimento futuro começa direto na `main`, e nenhum commit de teste é feito
nela enquanto estiver protegida.
