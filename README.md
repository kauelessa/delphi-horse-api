# delphi-horse-api

API REST desenvolvida em **Delphi** com o framework **[Horse](https://github.com/HashLoad/horse)** e banco de dados **Firebird**, com autenticação **JWT** e arquitetura em camadas.

> Faz parte do meu portfólio. É a base de um ecossistema que terá também um cliente desktop (VCL) e um app mobile (FireMonkey) consumindo esta API.

## 🎯 Objetivo

Demonstrar boas práticas no desenvolvimento back-end com Delphi:

- Endpoints REST com JSON (CRUD de clientes, produtos e pedidos)
- Autenticação e autorização com JWT
- Separação em camadas (Controller → Service → Repository)
- Acesso a dados com FireDAC + Firebird
- Testes unitários com DUnitX
- Tratamento padronizado de erros e validações

## 🧱 Tecnologias

| Item | Versão / Ferramenta |
|---|---|
| Linguagem | Delphi (Object Pascal) |
| Framework HTTP | Horse |
| Middlewares | jhonson (JSON), horse-cors, tratamento de erros próprio |
| JWT | delphi-jose-jwt (HS256) |
| Banco de dados | Firebird 5.0 |
| Acesso a dados | FireDAC |
| Gerenciador de pacotes | Boss |
| Testes | DUnitX |

## 📁 Estrutura

```
delphi-horse-api/
├── src/
│   ├── Controllers/   # Rotas e tratamento das requisições HTTP
│   ├── Services/      # Regras de negócio
│   ├── Repositories/  # Acesso ao banco (FireDAC)
│   ├── Models/        # Entidades e DTOs
│   └── Infra/         # Conexão, configuração, utilitários
├── database/          # Scripts SQL de criação do banco
├── tests/             # Testes unitários (DUnitX)
└── docs/
    └── screenshots/   # Prints e exemplos de requisições
```

## ▶️ Como executar

1. Instale o [Firebird 5.0](https://firebirdsql.org/) (os scripts também funcionam no 3.0 e no 4.0) e crie um banco vazio, por exemplo pelo `isql`:
   ```sql
   CREATE DATABASE 'localhost:C:\Dados\DELPHI_HORSE_API.FDB'
     USER 'SYSDBA' PASSWORD '<sua senha>' DEFAULT CHARACTER SET UTF8;
   ```
   As tabelas são criadas pela própria API na primeira execução (veja [Migrações](#migrações)).
2. Instale o [Boss](https://github.com/HashLoad/boss) e, na pasta do projeto (com o projeto **fechado** no RAD Studio), rode:
   ```
   boss install
   ```
   O Boss baixa as dependências em `modules/` e grava os caminhos no Search Path do `DelphiHorseApi.dproj`, que já vem versionado com esses caminhos.
3. Copie `config.example.ini` para `config.ini` (na pasta do executável) e preencha a conexão com o banco e o `Segredo` do JWT (mínimo de 32 caracteres).
4. Abra `DelphiHorseApi.dproj` no RAD Studio, compile e execute.
5. A API sobe por padrão em `http://localhost:9000`.

Testes: abra `tests/DelphiHorseApiTests.dpr` (requer DUnitX, que já vem com o RAD Studio) e execute. Os testes não usam Horse nem JWT, então não dependem de `modules/`.

### Migrações

Ao subir, a API aplica os scripts de `database/` que ainda não rodaram naquele banco, em ordem de nome, e registra cada um na tabela `SCHEMA_VERSAO`:

| Script | Conteúdo | Quando roda |
|---|---|---|
| `001_create_tables.sql` | usuários | sempre |
| `002_seed_usuario_admin.sql` | usuário `admin` / senha `admin123` | só com `ExecutarSeeds=1` |
| `003_create_tables_vendas.sql` | clientes, produtos e pedidos | sempre |
| `004_seed_dados_exemplo.sql` | clientes e produtos de exemplo | só com `ExecutarSeeds=1` |

Configuração na seção `[Migracao]` do `config.ini`:

| Chave | Padrão | Descrição |
|---|---|---|
| `Executar` | `1` | `0` desliga as migrações (o schema passa a ser responsabilidade de quem implanta) |
| `ExecutarSeeds` | `0` | aplica os scripts com `_seed_` no nome. **Use só em desenvolvimento** |
| `Pasta` | `database` | pasta dos scripts, absoluta ou relativa ao executável |

Regras: um script já aplicado nunca roda de novo, então mudanças no banco vão sempre em um **script novo** com o próximo número. Um seed pulado não é registrado; se `ExecutarSeeds` for ligado depois, ele roda na próxima subida. Se um script falhar, a API não sobe e mostra o erro.

#### Problemas comuns na instalação

**`F2613 Unit 'Horse' not found`**: o Search Path do projeto não aponta para `modules/`. Isso acontece quando o `boss install` roda antes de existir o `.dproj` ou com o projeto aberto (o RAD Studio sobrescreve o arquivo ao salvar). Feche o projeto, rode `boss install` de novo e reabra. Se continuar, adicione manualmente em *Project → Options → Building → Delphi Compiler → Search path* (alvo *All configurations – All platforms*):

```
modules\.dcp;modules\.dcu;modules\github_com_hashload_horse\src;modules\github_com_hashload_jhonson\src;modules\github_com_hashload_horse-cors\src;modules\github_com_hashload_handle-exception\src;modules\github_com_paolo-rossi_delphi-jose-jwt\Source;modules\github_com_paolo-rossi_delphi-jose-jwt\Source\Common;modules\github_com_paolo-rossi_delphi-jose-jwt\Source\JOSE
```

**`failed to load package ... hashlib4pascal\boss.json`**: o pacote `horse-jwt` depende do `hashlib4pascal`, que não tem `boss.json`. Isso interrompe o `boss install` inteiro. Este projeto valida o JWT com middleware próprio (`delphi-jose-jwt`) e não usa o `horse-jwt`, então não o adicione ao `boss.json`.

### Autenticação

Todas as rotas, exceto `/health` e `/auth/login`, exigem o cabeçalho `Authorization: Bearer <token>`.

```
curl -X POST http://localhost:9000/auth/login   -H "Content-Type: application/json"   -d '{"login": "admin", "senha": "admin123"}'
```

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tipo": "Bearer",
  "expiraEm": "2026-11-19T22:30:00.000-03:00"
}
```

### Exemplo: criar um pedido

```
curl -X POST http://localhost:9000/pedidos   -H "Authorization: Bearer <token>"   -H "Content-Type: application/json"   -d '{"clienteId": 1, "itens": [{"produtoId": 1, "quantidade": 2}, {"produtoId": 2, "quantidade": 1}]}'
```

```json
{
  "id": 1,
  "cliente": { "id": 1, "nome": "Maria Souza" },
  "data": "2026-11-20T10:15:00.000-03:00",
  "status": "ABERTO",
  "valorTotal": 829.7,
  "itens": [
    { "id": 1, "produtoId": 1, "descricao": "Teclado mecânico", "quantidade": 2, "precoUnitario": 349.9, "valorTotal": 699.8 },
    { "id": 2, "produtoId": 2, "descricao": "Mouse sem fio", "quantidade": 1, "precoUnitario": 129.9, "valorTotal": 129.9 }
  ]
}
```

Outros corpos de requisição prontos (válidos e inválidos, para ver as respostas de erro) ficam em [`docs/exemplos/`](docs/exemplos/). Com curl, use `-d @docs/exemplos/pedido.json`.

### Listagens paginadas

`GET /clientes`, `/produtos` e `/pedidos` aceitam `?pagina=1&limite=20` (limite máximo 100) e respondem:

```json
{ "dados": [ ... ], "pagina": 1, "limite": 20, "total": 57 }
```

`GET /pedidos` também aceita `?clienteId=1`.

### Erros

Formato `{ "erro": "mensagem" }`:

| Status | Quando |
|---|---|
| 400 | JSON inválido, campo obrigatório ausente ou com tipo errado |
| 401 | Token ausente, inválido ou expirado; login ou senha incorretos |
| 404 | Recurso não encontrado (ou inativo) |
| 422 | Regra de negócio violada (CPF/CNPJ inválido ou duplicado, estoque insuficiente, pedido já cancelado...) |
| 500 | Erro inesperado (detalhes só no log do servidor) |

## 📐 Regras de negócio

- **Clientes**: nome e CPF ou CNPJ obrigatórios. O documento é validado pelos dígitos verificadores, aceita o novo **CNPJ alfanumérico** e é único. E-mail opcional, mas validado se informado.
- **Produtos**: preço maior que zero, estoque não negativo.
- **Exclusão lógica**: `DELETE` de cliente ou produto apenas inativa o registro. Ele some das consultas e não pode entrar em novos pedidos, mas o histórico de pedidos é preservado.
- **Pedidos**:
  - O cliente e os produtos precisam estar ativos, a quantidade deve ser maior que zero e cada produto aparece uma vez só.
  - O preço do produto é copiado para o item no momento da venda.
  - O estoque é baixado na mesma transação da gravação, com proteção contra pedidos simultâneos.
  - Só pedidos `ABERTO` podem ser cancelados, e o cancelamento devolve o estoque.

## 🔌 Endpoints

| Método | Rota | Descrição | Status |
|---|---|---|---|
| GET | `/health` | Verifica se a API está no ar | ✅ Pronto |
| POST | `/auth/login` | Gera o token JWT | ✅ Pronto |
| GET | `/clientes` | Lista clientes (paginado) | ✅ Pronto |
| GET | `/clientes/:id` | Busca cliente por ID | ✅ Pronto |
| POST | `/clientes` | Cadastra cliente | ✅ Pronto |
| PUT | `/clientes/:id` | Atualiza cliente | ✅ Pronto |
| DELETE | `/clientes/:id` | Inativa cliente | ✅ Pronto |
| GET | `/produtos` | Lista produtos (paginado) | ✅ Pronto |
| GET | `/produtos/:id` | Busca produto por ID | ✅ Pronto |
| POST | `/produtos` | Cadastra produto | ✅ Pronto |
| PUT | `/produtos/:id` | Atualiza produto (inclui ajuste de estoque) | ✅ Pronto |
| DELETE | `/produtos/:id` | Inativa produto | ✅ Pronto |
| GET | `/pedidos` | Lista pedidos (paginado, filtro por cliente) | ✅ Pronto |
| GET | `/pedidos/:id` | Busca pedido com itens | ✅ Pronto |
| POST | `/pedidos` | Cria pedido e baixa estoque | ✅ Pronto |
| PATCH | `/pedidos/:id/cancelar` | Cancela pedido e devolve estoque | ✅ Pronto |

## 👤 Autor

**Kauê Lessa** — Desenvolvedor Delphi Sênior
[GitHub](https://github.com/kauelessa)
