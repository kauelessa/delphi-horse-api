# delphi-horse-api

API REST desenvolvida em **Delphi** com o framework **[Horse](https://github.com/HashLoad/horse)** e banco de dados **Firebird**, com autenticação **JWT** e arquitetura em camadas.

> 🚧 Projeto em desenvolvimento — faz parte do meu portfólio. É a base de um ecossistema que terá também um cliente desktop (VCL) e um app mobile (FireMonkey) consumindo esta API.

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
| Middlewares | horse-jhonson (JSON), horse-jwt, horse-cors, horse-handle-exception |
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

1. Instale o [Firebird 5.0](https://firebirdsql.org/) e execute o script em `database/` para criar o banco.
2. Instale o [Boss](https://github.com/HashLoad/boss) e, na pasta do projeto, rode:
   ```
   boss install
   ```
3. Configure a conexão com o banco no arquivo de configuração (ver `src/Infra`).
4. Abra o projeto `.dproj` no RAD Studio, compile e execute.
5. A API sobe por padrão em `http://localhost:9000`.

## 🔌 Endpoints (planejados)

| Método | Rota | Descrição |
|---|---|---|
| POST | `/auth/login` | Gera o token JWT |
| GET | `/clientes` | Lista clientes |
| GET | `/clientes/:id` | Busca cliente por ID |
| POST | `/clientes` | Cadastra cliente |
| PUT | `/clientes/:id` | Atualiza cliente |
| DELETE | `/clientes/:id` | Remove cliente |
| GET/POST | `/produtos` | Produtos |
| GET/POST | `/pedidos` | Pedidos |

## 👤 Autor

**Kauê Lessa** — Desenvolvedor Delphi Sênior
[GitHub](https://github.com/kauelessa)
