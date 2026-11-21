# CLAUDE.md

Instruções para o Claude Code neste repositório.

## Sobre o projeto

API REST em Delphi usando o framework Horse e banco Firebird 5.0. Faz parte do portfólio público de Kauê Lessa (Desenvolvedor Delphi Sênior), então o código deve ser limpo, bem organizado e servir de vitrine de boas práticas.

## Ambiente

- Delphi / RAD Studio (Community Edition ou superior). A compilação e o design de forms são feitos no RAD Studio; o Claude Code edita `.pas`, `.dpr`, scripts SQL e documentação pelo VS Code.
- Não altere manualmente `.dproj`, `.res` ou `.dfm`, a menos que seja pedido explicitamente. Se uma unit nova precisar ser adicionada ao projeto, avise para incluí-la pelo RAD Studio (ou atualize o `uses` do `.dpr` e informe).
- Codificação: todo `.pas` e `.dpr` deve ser salvo em **UTF-8 com BOM**. Sem o BOM, o compilador do Delphi lê o arquivo como ANSI (Windows-1252) e corrompe strings acentuadas (`'Configuração'` vira `'ConfiguraÃ§Ã£o'`). Ao criar um arquivo novo, garanta o BOM (`EF BB BF`) no início; ao editar, preserve-o.
- Dependências gerenciadas pelo Boss (`boss.json`). Não versionar a pasta `modules/`.
- Banco: Firebird 5.0 via FireDAC. Scripts SQL ficam em `database/`, numerados (`001_create_tables.sql`, `002_...`).

## Arquitetura

Camadas, em `src/`:

- `Controllers/` — registram rotas do Horse, leem a requisição, chamam o Service e devolvem JSON. Sem regra de negócio e sem SQL.
- `Services/` — regras de negócio e validações. Dependem de interfaces de repositório.
- `Repositories/` — único lugar com SQL/FireDAC. Sempre usar parâmetros (nunca concatenar valores em SQL).
- `Models/` — entidades e DTOs.
- `Infra/` — conexão, configuração (arquivo `.ini`/`.env`), logs e utilitários.

Use interfaces (`IClienteService`, `IClienteRepository`) para permitir testes com DUnitX.

## Padrões de código

- Nomes de units: `<Camada>.<Entidade>.pas` (ex.: `Controller.Cliente.pas`, `Service.Cliente.pas`, `Repository.Cliente.pas`).
- Classes com prefixo `T`, interfaces com `I`, campos privados com `F`, parâmetros com `A` (ex.: `AId`).
- Identificadores em português para o domínio (Cliente, Produto, Pedido); termos técnicos podem ficar em inglês.
- Sempre liberar objetos com `try..finally` ou usar interfaces com contagem de referência.
- Respostas JSON padronizadas; erros no formato `{ "erro": "mensagem" }` com o status HTTP correto (400, 401, 404, 422, 500).
- Nada de credenciais, senhas ou caminhos de máquina no código: tudo vem de configuração, com um arquivo de exemplo versionado (`config.example.ini`).

## Testes

- DUnitX em `tests/`. Toda regra nova em Service deve ter teste.
- Repositórios são substituídos por mocks/fakes nos testes de Service.

## Git

- Commits pequenos, em português, no imperativo: `Adiciona endpoint de clientes`, `Corrige validação de CPF`.
- Ao concluir uma funcionalidade, atualizar a tabela de endpoints e o status no `README.md`.
