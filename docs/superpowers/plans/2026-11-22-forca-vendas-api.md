# Força de Vendas — mudanças na API — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar à delphi-horse-api tudo o que o app Força de Vendas consome: vendedor no token, refresh token, código de barras, sincronização incremental, pedido/cliente/visita vindos do app com UUID, localização, foto, assinatura, aviso de faturamento do emissor e relatórios PDF em Fortes Report e FastReport.

**Architecture:** Segue as camadas existentes (`Controllers` → `Services` → `Repositories`, `Models`, `Infra`), com interfaces e fakes para os testes de Service. Duas migrações novas (estrutura + seed). Relatórios montados **em código** (sem `.dfm`/`.fr3`) atrás de `IGeradorRelatorio`, um gerador por motor, geração serializada.

**Tech Stack:** Delphi 13 (Win32), Horse 3, FireDAC + Firebird 3/5, delphi-jose-jwt, DUnitX, Fortes Report CE, FastReport 2026.2.1 (opcional por diretiva).

**Spec:** `docs/superpowers/specs/2026-11-22-forca-vendas-design.md` (seção 1 e "Decisões minhas").

## Global Constraints

- `.pas`/`.dpr` em **UTF-8 com BOM**; preservar CRLF.
- **Nunca editar** scripts de `database/` já versionados (001–004). Novos: `005_forca_vendas.sql`, `006_seed_forca_vendas.sql`. Cada script termina com `COMMIT;`, sem `CREATE DATABASE`/`SET SQL DIALECT`, compatível com Firebird 3.0+. Atualizar a tabela de migrações do `README.md`.
- SQL sempre parametrizado; só `Repositories/` tem SQL/FireDAC.
- Units novas: registrar no `uses` do `.dpr` **e** no `.dproj` (CLAUDE.md atualizado em 2026-11-22). Caminhos de busca (delphi-jose-jwt nos testes, Fortes, FastReport) e a diretiva `FASTREPORT` vão direto nos `.dproj` (app e testes); depois de mexer num `.dproj`, compilar com MSBuild.
- Toda regra nova em Service tem teste DUnitX com fakes; erros viram exceções de `Infra.Excecoes` (o middleware responde `{ "erro": ... }`).
- Mensagens curtas e naturais em português; estilo misto do CLAUDE.local.md (Repositories/Controllers mais "dia a dia", Infra de segurança documentada).
- Dados de seed **fictícios**; nenhuma credencial em código; `config.example.ini` com valores de exemplo.
- Commits pequenos, em português, imperativo, com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Datas em JSON: `DateToISO8601(..., False)` (como hoje). Parâmetro `desde` lido com `ISO8601ToDate`.
- Teste: `bash <scratchpad>/build/testes_api.sh` (compila `tests/DelphiHorseApiTests.dpr` com `compilar_api_testes.bat` e roda). App: `msbuild_api.bat`. Os scripts ficam no scratchpad desta sessão; recriar a partir deste plano se sumirem.

## Review Focus

1. **Mesmo pedido enviado duas vezes ao mesmo tempo** (o app reenvia após timeout enquanto o primeiro ainda grava) → um pedido só; a segunda chamada devolve o existente (200), nunca 500. Teste na Tarefa 7.
2. **Registro alterado no mesmo instante da marca `servidorEm`** → não pode ser perdido pela próxima sincronização: a marca é lida **antes** da consulta e o filtro usa `>=`. Teste na Tarefa 5.
3. **Cancelar um pedido já faturado** → 409 "Pedido faturado na NF-e N; cancele a nota primeiro." (não pode devolver estoque de mercadoria que saiu com nota). Teste na Tarefa 8.
4. **Refresh token roubado e reusado depois da rotação** → a família inteira é revogada; o dono legítimo cai para o login com senha. Teste na Tarefa 3.
5. **Upload com conteúdo errado ou grande demais** (PNG declarado mas é texto, base64 inválido, foto > 500 KB) → 400 com mensagem clara, nada gravado. Testes nas Tarefas 6 e 7.

---

### Task 1: Branch, migrações e seed

**Files:**
- Create: `database/005_forca_vendas.sql`, `database/006_seed_forca_vendas.sql`
- Modify: `.gitignore` (acrescentar `.superpowers/`), `README.md` (tabela de migrações)
- Já feito no planejamento: branch `forca-vendas`, spec copiado para `docs/superpowers/specs/`.

**Interfaces:**
- Produces: colunas e tabelas abaixo, usadas por todas as tarefas.

- [ ] **Step 1: Escrever `005_forca_vendas.sql`**

  - `PRODUTOS`: `CODIGO_BARRAS VARCHAR(14)` + `CREATE UNIQUE INDEX UQ_PRODUTOS_CODIGO_BARRAS` (Firebird aceita vários NULL num índice único).
  - `CLIENTES`: `UUID CHAR(36)` + índice único, `LATITUDE NUMERIC(9,6)`, `LONGITUDE NUMERIC(9,6)`, `FOTO BLOB SUB_TYPE BINARY`.
  - `PEDIDOS`: `UUID CHAR(36)` + índice único, `USUARIO_ID INTEGER` (FK `USUARIOS`), `LATITUDE`, `LONGITUDE NUMERIC(9,6)`, `PRECISAO_M NUMERIC(9,2)`, `OBSERVACAO VARCHAR(500)`, `ORIGEM VARCHAR(3) DEFAULT 'API' NOT NULL` + check `IN ('API','APP')`, `ASSINATURA BLOB SUB_TYPE BINARY`, `NOTA_NUMERO INTEGER`, `NOTA_SERIE INTEGER`, `NOTA_CHAVE CHAR(44)`, `NOTA_AUTORIZADA_EM TIMESTAMP`.
  - `ATUALIZADO_EM TIMESTAMP DEFAULT LOCALTIMESTAMP NOT NULL` em `CLIENTES`, `PRODUTOS`, `PEDIDOS` + índice em cada.
  - **Triggers `BEFORE UPDATE`** (`SET TERM ^ ;`) que fazem `NEW.ATUALIZADO_EM = LOCALTIMESTAMP` nas três tabelas — cobre também a baixa de estoque feita pelo pedido (o spec dizia "mantido pelo repositório"; trigger é mais seguro — registrar como Ruling).
  - `VISITAS` (ID identity PK, `UUID CHAR(36)` único NOT NULL, `CLIENTE_ID` FK, `USUARIO_ID` FK NOT NULL, `DATA_VISITA TIMESTAMP NOT NULL`, `LATITUDE`, `LONGITUDE`, `PRECISAO_M`, `MOTIVO VARCHAR(20) NOT NULL` check `IN ('AUSENTE','SEM_NECESSIDADE','SEM_ESTOQUE','PRECO','OUTRO')`, `OBSERVACAO VARCHAR(500)`, `CRIADO_EM`, `ATUALIZADO_EM` + trigger) + índice `(USUARIO_ID, ATUALIZADO_EM)`.
  - `SESSOES` (ID identity PK, `FAMILIA CHAR(36) NOT NULL`, `USUARIO_ID` FK NOT NULL, `TOKEN_HASH CHAR(64) NOT NULL` único, `DISPOSITIVO VARCHAR(100)`, `CRIADA_EM`, `EXPIRA_EM TIMESTAMP NOT NULL`, `REVOGADA BOOLEAN DEFAULT FALSE NOT NULL`) + índice em `FAMILIA`. (`FAMILIA` não está no spec; é o que permite revogar toda a cadeia num reuso — Ruling.)
  - `COMMENT ON` nas colunas não óbvias; termina com `COMMIT;`.

- [ ] **Step 2: Escrever `006_seed_forca_vendas.sql`**

  Usuária `ana` (nome "Ana Vendedora", senha fictícia `ana123`; gerar o hash com `TSenhaHash.Gerar` num probe no scratchpad e colar). EANs-13 **válidos** (dígito verificador correto) nos produtos do seed 004, coordenadas fictícias em São Paulo nos clientes do seed 004. Termina com `COMMIT;`.

- [ ] **Step 3: Aplicar no banco de desenvolvimento**

  Run: compilar com `msbuild_api.bat`, subir `DelphiHorseApi.exe` (seeds ligados no `config.ini` local) e conferir
  `SELECT NOME_SCRIPT FROM SCHEMA_VERSAO` (ou a coluna equivalente) via isql.
  Expected: 005 e 006 registrados; `POST /auth/login` com `ana`/`ana123` → 200.

- [ ] **Step 4: Atualizar README (tabela de migrações) e `.gitignore`; commit**

```bash
git add database/005_forca_vendas.sql database/006_seed_forca_vendas.sql README.md .gitignore docs/superpowers
git commit -m "Adiciona estrutura do app Força de Vendas no banco"
```

---

### Task 2: Vendedor do token disponível nas rotas

**Files:**
- Modify: `src/Infra/Infra.JWT.pas`, `src/Infra/Infra.Middleware.Autenticacao.pas`, `src/Controllers/Controller.Utils.pas`
- Create: `tests/Tests.Infra.JWT.pas`
- Modify: `tests/DelphiHorseApiTests.dpr`, script de compilação dos testes (incluir as pastas do delphi-jose-jwt listadas no `DCC_UnitSearchPath` do `DelphiHorseApi.dproj`)

**Interfaces:**
- Produces:
  - `class function TValidadorTokenJWT.UsuarioDoToken(const AToken: string; const AConfig: TConfigJWT): Integer; static;` — id do `sub` se válido, **0** se inválido/expirado. `Valido` passa a chamar este.
  - Middleware guarda o id na requisição: `AReq.Session(TUsuarioLogado.Create(AId), True)` com `TUsuarioLogado = class Id: Integer end` (em `Infra.Middleware.Autenticacao`).
  - `function UsuarioLogado(AReq: THorseRequest): Integer;` em `Controller.Utils` (0 em rota pública).

- [ ] **Step 1: Testes que falham** (`Tests.Infra.JWT`, config com segredo fictício de 32+ caracteres)
  - `TokenGeradoDevolveIdDoUsuario`: `Gerar(usuario Id=7)` → `UsuarioDoToken = 7`.
  - `TokenAdulteradoDevolveZero`: troca um caractere da assinatura → `0`.
  - `TokenDeOutroEmissorDevolveZero`: config com `Emissor` diferente → `0`.
- [ ] **Step 2: Rodar** — Expected: FAIL (`UsuarioDoToken` não existe).
- [ ] **Step 3: Implementar** os três itens de Produces.
- [ ] **Step 4: Rodar** — Expected: PASS, suíte inteira verde.
- [ ] **Step 5: Commit** — `Expõe o usuário do token para as rotas`

---

### Task 3: Refresh token com rotação

**Files:**
- Create: `src/Models/Model.Sessao.pas`, `src/Repositories/Repository.Sessao.pas`
- Modify: `src/Infra/Infra.Senha.pas` (mover `BytesAleatorios` para a interface), `src/Infra/Infra.Token.pas`, `src/Infra/Infra.Config.pas` (`[JWT] RefreshDias`, padrão 30, > 0), `src/Services/Service.Auth.pas`, `src/Controllers/Controller.Auth.pas`, `src/Infra/Infra.Middleware.Autenticacao.pas` (rotas públicas `/auth/renovar`, `/auth/sair`), `config.example.ini`
- Modify: `tests/Tests.Fakes.pas` (`TSessaoRepositoryFake`), `tests/Tests.Service.Auth.pas`

**Interfaces:**
- Consumes: `BytesAleatorios(ATamanho: Integer): TBytes` (Infra.Senha).
- Produces:
  - `TTokenAcesso` ganha `RefreshToken: string; RefreshExpiraEm: TDateTime`.
  - `TSessao` (Id, Familia, UsuarioId, TokenHash, Dispositivo, CriadaEm, ExpiraEm, Revogada).
  - `ISessaoRepository`: `procedure Inserir(ASessao: TSessao); function BuscarPorHash(const AHash: string): TSessao; procedure Revogar(AId: Integer); procedure RevogarFamilia(const AFamilia: string);`
  - `IAuthService`: `function Login(const ALogin, ASenha, ADispositivo: string): TTokenAcesso; function Renovar(const ARefreshToken: string): TTokenAcesso; procedure Sair(const ARefreshToken: string);`
  - `TAuthService.Create(const AUsuarios: IUsuarioRepository; const ASessoes: ISessaoRepository; const AGeradorToken: IGeradorToken; ARefreshDias: Integer; const AAgora: TFunc<TDateTime> = nil)` (nil → `Now`).
  - Refresh = 32 bytes aleatórios em base64url sem `=`; banco guarda só `THashSHA2.GetHashString(token)` (hex minúsculo, 64).
  - JSON: login/renovar respondem `{token, tipo, expiraEm, refreshToken, refreshExpiraEm}`; `POST /auth/sair {refreshToken}` → 204. Login aceita `dispositivo` opcional.

- [ ] **Step 1: Testes que falham** (em `Tests.Service.Auth`, relógio fixo injetado)
  - `LoginDevolveRefreshEGuardaSoOHash`: refresh não vazio; sessão gravada com `TokenHash <> RefreshToken`, `Length = 64`, `ExpiraEm = agora + 30`.
  - `RenovarRotacionaOToken`: renovar(r1) → r2 ≠ r1; sessão de r1 revogada; renovar(r2) funciona.
  - `ReusoDeTokenRevogadoDerrubaAFamilia`: renovar(r1) → r2; renovar(r1) → `ENaoAutorizado`; renovar(r2) → `ENaoAutorizado`.
  - `RefreshExpiradoRecusado`: relógio + 31 dias → `ENaoAutorizado`.
  - `RefreshDeUsuarioInativoRecusado`.
  - `SairRevogaASessao`: sair(r1) → renovar(r1) `ENaoAutorizado`; sair de token desconhecido não levanta erro.
  - Os testes atuais de `Login` continuam passando (atualizar a chamada com `ADispositivo = ''`).
- [ ] **Step 2: Rodar** — Expected: FAIL de compilação/asserção.
- [ ] **Step 3: Implementar** Produces. Mensagem única para refresh inválido/expirado/revogado: `'Sessão expirada. Entre com usuário e senha.'`.
- [ ] **Step 4: Rodar** — Expected: PASS.
- [ ] **Step 5: Commit** — `Adiciona refresh token com rotação`

---

### Task 4: Código de barras do produto

**Files:**
- Create: `src/Models/Model.CodigoBarras.pas`, `tests/Tests.Model.CodigoBarras.pas`
- Modify: `Model.Produto` (`CodigoBarras: string`), `Repository.Produto` (ler/gravar; `BuscarPorCodigoBarras(const ACodigo: string): TProduto` só ativos; `CodigoBarrasEmUso(const ACodigo: string; AIgnorarId: Integer): Boolean`; busca `?busca=` também casa código exato), `Service.Produto`, `Controller.Produto` (campo `codigoBarras` no JSON; `GET /produtos/codigo/:codigo`), `Tests.Fakes`, `Tests.Service.Produto`, `Tests.Repository.Filtro`

**Interfaces:**
- Produces: `TCodigoBarras.Valido(const ACodigo: string): Boolean` (só dígitos, tamanho 8/12/13/14, dígito verificador GTIN); `IProdutoService.BuscarPorCodigoBarras(const ACodigo: string): TProduto` (404 `'Nenhum produto com o código %s.'`).

- [ ] **Step 1: Testes que falham**
  - Model: `7891000315507` válido; `7891000315508` inválido; `96385074` (EAN-8) válido; `789100031550A` inválido; `''` inválido.
  - Service: criar com código inválido → `ERegraNegocio('Código de barras inválido.')`; código vazio é aceito (campo opcional); código já usado por outro produto → `ERegraNegocio('Código de barras já usado pelo produto %d.')`; atualizar mantendo o próprio código passa; `BuscarPorCodigoBarras` inexistente → `ENaoEncontrado`.
  - Filtro: com busca, o SQL contém `CODIGO_BARRAS = :BUSCA_CODIGO`.
- [ ] **Step 2: Rodar** — Expected: FAIL.
- [ ] **Step 3: Implementar.** Rota `/produtos/codigo/:codigo` registrada **antes** de `/produtos/:id`.
- [ ] **Step 4: Rodar** — Expected: PASS.
- [ ] **Step 5: Commit** — `Adiciona código de barras ao produto`

---

### Task 5: Sincronização incremental (`?desde=`)

**Files:**
- Modify: `Model.Cliente`/`Model.Produto`/`Model.Pedido` (`AtualizadoEm: TDateTime`), repositórios das três entidades, `Model.Paginacao` (ou novo record `TFiltroSync`), controllers, `Controller.Utils`, `Tests.Repository.Filtro`, `Tests.Service.*`, `Tests.Fakes`

**Interfaces:**
- Produces:
  - `TFiltroSync = record Desde: TDateTime; Ativo: Boolean; UsuarioId: Integer; end` (Desde ativo só se `Ativo`; `UsuarioId > 0` filtra o vendedor).
  - `function FiltroSyncDaQuery(AReq: THorseRequest): TFiltroSync;` em `Controller.Utils` (`desde` inválido → 400 `'"desde" deve ser uma data ISO 8601.'`; `vendedor=eu` → `UsuarioLogado(AReq)`).
  - Listagens recebem o filtro. Com `desde`: **incluem inativos/cancelados**, ordenam por `ATUALIZADO_EM, ID`, filtro `ATUALIZADO_EM >= :DESDE`.
  - Resposta paginada ganha `servidorEm` (ISO) — **lido do banco (`SELECT LOCALTIMESTAMP FROM RDB$DATABASE`) antes da consulta**, por um método de repositório `function AgoraNoServidor: TDateTime` (um só, no repositório que fizer mais sentido, exposto pelo Service).
  - JSON de cliente, produto e pedido ganham `ativo` (quando faltar) e `atualizadoEm`.

- [ ] **Step 1: Testes que falham**
  - Filtro (SQL gerado): com `desde` → contém `ATUALIZADO_EM >= :DESDE` e **não** contém `ATIVO = TRUE`; sem `desde` → como hoje.
  - Pedidos com `UsuarioId=3` → SQL contém `USUARIO_ID = :USUARIO_ID`.
  - Service: a marca `servidorEm` devolvida é a que o fake de `AgoraNoServidor` respondeu **antes** de `Listar` ser chamado (fake registra a ordem das chamadas).
- [ ] **Step 2: Rodar** — Expected: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** — Expected: PASS.
- [ ] **Step 5: Commit** — `Adiciona sincronização incremental nas listagens`

---

### Task 6: Cliente vindo do app (UUID, localização, foto)

**Files:**
- Create: `src/Models/Model.Imagem.pas` (validação de imagem), `tests/Tests.Model.Imagem.pas`
- Modify: `Model.Cliente` (`Uuid`, `Latitude`, `Longitude: Double`, `TemLocalizacao: Boolean`), `Repository.Cliente` (`BuscarPorUuid`, `GravarLocalizacao`, `GravarFoto(AId; const AFoto: TBytes)`, `LerFoto(AId): TBytes`), `Service.Cliente`, `Controller.Cliente`, fakes e testes

**Interfaces:**
- Produces:
  - `TImagem.EhJpeg(const ABytes: TBytes): Boolean` (`FF D8 FF`), `TImagem.EhPng(const ABytes: TBytes): Boolean` (`89 50 4E 47 0D 0A 1A 0A`), `TImagem.DeBase64(const ATexto: string): TBytes` (texto inválido → `ERequisicaoInvalida('Imagem em base64 inválida.')`).
  - `IClienteService.Criar` idempotente: UUID existente → devolve o existente e sinaliza (out `AJaExistia: Boolean`) para o controller responder **200** em vez de 201.
  - `procedure GravarLocalizacao(AId: Integer; ALatitude, ALongitude: Double)` (fora de [-90,90]/[-180,180] → 400 `'Localização inválida.'`).
  - `procedure GravarFoto(AId: Integer; const AFoto: TBytes)` (não JPEG → 400 `'A foto deve ser JPEG.'`; > 512000 bytes → 400 `'Foto maior que 500 KB.'`). `function LerFoto(AId: Integer): TBytes` (sem foto → 404).
  - Rotas: `PUT /clientes/:id/localizacao {latitude, longitude}`, `PUT /clientes/:id/foto` (corpo **binário** `image/jpeg`), `GET /clientes/:id/foto` (`image/jpeg`). JSON do cliente: `uuid`, `latitude`, `longitude` (null sem local), `temFoto`.
  - UUID validado no formato `8-4-4-4-12` hexadecimal → senão 400 `'"uuid" inválido.'`.

- [ ] **Step 1: Testes que falham** — imagem (JPEG/PNG/texto, base64 inválido); criar com UUID novo cria; mesmo UUID devolve o mesmo Id e `AJaExistia=True` sem criar outro; UUID malformado 400; localização fora da faixa 400; foto PNG 400; foto de 512001 bytes 400; nada gravado nesses casos (fake conta gravações).
- [ ] **Step 2: Rodar** — FAIL. **Step 3: Implementar.** **Step 4: Rodar** — PASS.
- [ ] **Step 5: Commit** — `Recebe cliente do app com localização e foto`

---

### Task 7: Pedido vindo do app

**Files:**
- Modify: `Model.Pedido` (`Uuid`, `UsuarioId`, `NomeVendedor`, `Latitude/Longitude/Precisao: Double`, `TemLocalizacao`, `Observacao`, `Origem: TOrigemPedido (opApi, opApp)`, `Assinatura: TBytes`, `TemAssinatura`), `Repository.Pedido` (gravar/ler os campos; `BuscarPorUuid`; `LerAssinatura`), `Service.Pedido`, `Controller.Pedido`, fakes e `Tests.Service.Pedido`
- Create (Infra): exceção `EUuidDuplicado` lançada pelo repositório quando o índice único de UUID estoura (`EFDDBEngineException` com `Kind = ekUKViolated`)

**Interfaces:**
- Consumes: `TImagem.*` (Tarefa 6), `UsuarioLogado` (Tarefa 2).
- Produces:
  - `procedure Criar(APedido: TPedido; out AJaExistia: Boolean)` no `IPedidoService`.
  - Regras: com `uuid` → `Origem = opApp`; UUID existente → carrega o existente, `AJaExistia = True`, nada muda; `EUuidDuplicado` durante o `Inserir` (corrida) → busca por UUID e devolve como existente. `dataPedido` do app aceita entre `agora - 30 dias` e `agora + 10 min`, senão 422 `'Data do pedido fora do intervalo aceito.'`; sem `dataPedido` usa `Now`. Assinatura: base64 PNG até 204800 bytes (senão 400 `'A assinatura deve ser PNG.'` / `'Assinatura maior que 200 KB.'`). Observação até 500 caracteres. `UsuarioId` sempre vem do token (nunca do corpo).
  - JSON: `uuid`, `origem`, `vendedor {id, nome}` (null nos antigos), `localizacao {latitude, longitude, precisao}` ou null, `observacao`, `temAssinatura`, `atualizadoEm`. `GET /pedidos/:id/assinatura` → `image/png` (404 sem assinatura).
  - `POST /pedidos` responde 201 (novo) ou 200 (já existia).

- [ ] **Step 1: Testes que falham**
  - `PedidoDoAppGuardaVendedorLocalEOrigem`.
  - `MesmoUuidNaoDuplica`: duas chamadas, `Quantidade = 1`, segunda com `AJaExistia`.
  - `CorridaNoUuidDevolveOExistente`: fake de repositório lança `EUuidDuplicado` no `Inserir` e já tem o pedido gravado → service devolve o existente, sem erro.
  - `DataForaDoIntervaloRecusada` (31 dias atrás; 11 min no futuro), relógio injetado.
  - `AssinaturaQueNaoEhPngRecusada`, `AssinaturaGrandeRecusada`, `Base64InvalidoRecusado` — nenhum pedido gravado.
  - Regras atuais (preço do produto, estoque) continuam valendo para pedidos do app.
- [ ] **Step 2: Rodar** — FAIL. **Step 3: Implementar.** **Step 4: Rodar** — PASS.
- [ ] **Step 5: Commit** — `Recebe pedido do app com local e assinatura`

---

### Task 8: Aviso de faturamento do emissor

**Files:**
- Modify: `Infra.Excecoes` (`EConflito` → 409), `Model.Pedido` (`NotaNumero`, `NotaSerie`, `NotaChave`, `NotaAutorizadaEm`, `Faturado: Boolean`), `Repository.Pedido` (`GravarFaturamento`, `LimparFaturamento`), `Service.Pedido`, `Controller.Pedido`, fakes e testes

**Interfaces:**
- Produces:
  - `function Faturar(AId, ANumero, ASerie: Integer; const AChave: string; AAutorizadaEm: TDateTime): TPedido;` e `function RemoverFaturamento(AId: Integer): TPedido;` no `IPedidoService`.
  - Rotas: `PATCH /pedidos/:id/faturamento {numero, serie, chave, autorizadaEm}` → 200 com o pedido; `DELETE /pedidos/:id/faturamento` → 200.
  - Regras: pedido cancelado → `EConflito('Pedido cancelado não pode ser faturado.')`; `numero > 0`, `serie >= 0`, `chave` com 44 dígitos → senão 400; já faturado com **a mesma chave** → 200 sem mudar (idempotente); com chave diferente → `EConflito('Pedido já faturado na NF-e %d.')`. `Cancelar` de pedido faturado → `EConflito('Pedido faturado na NF-e %d; cancele a nota primeiro.')`. `RemoverFaturamento` de pedido não faturado → 200 sem mudar.
  - JSON do pedido: `nota {numero, serie, chave, autorizadaEm}` ou null.

- [ ] **Step 1: Testes que falham** — os sete comportamentos acima, um teste cada.
- [ ] **Step 2: Rodar** — FAIL. **Step 3: Implementar.** **Step 4: Rodar** — PASS.
- [ ] **Step 5: Commit** — `Recebe o faturamento do pedido pelo emissor`

---

### Task 9: Visitas

**Files:**
- Create: `src/Models/Model.Visita.pas`, `src/Repositories/Repository.Visita.pas`, `src/Services/Service.Visita.pas`, `src/Controllers/Controller.Visita.pas`, `tests/Tests.Service.Visita.pas`
- Modify: `DelphiHorseApi.dpr` (registrar), `Tests.Fakes`, `tests/DelphiHorseApiTests.dpr`

**Interfaces:**
- Produces:
  - `TMotivoVisita = (mvAusente, mvSemNecessidade, mvSemEstoque, mvPreco, mvOutro)` com helper `ToString`/`DeTexto` nos textos do check do banco.
  - `IVisitaService`: `procedure Criar(AVisita: TVisita; out AJaExistia: Boolean); function Listar(const APaginacao: TPaginacao; const AFiltro: TFiltroSync; out ATotal: Integer): TObjectList<TVisita>;`
  - Regras: `uuid` obrigatório e válido; cliente existente e ativo (422); `mvOutro` exige observação (422 `'Descreva o motivo da visita.'`); mesma janela de data da Tarefa 7; `UsuarioId` do token; UUID repetido → existente (200).
  - Rotas: `POST /visitas`, `GET /visitas` (`?desde=`, `vendedor=eu`, paginação, `servidorEm`).

- [ ] **Step 1: Testes que falham** — criação válida; UUID repetido; cliente inativo; motivo desconhecido (400); `OUTRO` sem observação; data fora da janela.
- [ ] **Step 2: Rodar** — FAIL. **Step 3: Implementar.** **Step 4: Rodar** — PASS.
- [ ] **Step 5: Commit** — `Adiciona registro de visitas`

---

### Task 10: Relatórios — serviço e Fortes Report

**Files:**
- Create: `src/Models/Model.Relatorio.pas` (DTOs: linhas de cada relatório), `src/Repositories/Repository.Relatorio.pas` (consultas agregadas), `src/Services/Service.Relatorio.pas`, `src/Infra/Infra.Relatorio.pas` (`IGeradorRelatorio`, registro por motor, serialização), `src/Infra/Infra.Relatorio.Fortes.pas`, `src/Controllers/Controller.Relatorio.pas`, `tests/Tests.Service.Relatorio.pas`, `tests/Tests.Infra.Relatorio.Fortes.pas`
- Modify: `Infra.Excecoes` (`ENaoImplementado` → 501), `DelphiHorseApi.dpr`, script de compilação (caminho do Fortes: `C:\fortesreport-ce\Binary\LibD37\Win32\Release`)

**Interfaces:**
- Produces:
  - `TMotorRelatorio = (mrFortes, mrFastReport)`; `DeTexto('fortes'|'fastreport')`, outro → 400 `'Motor de relatório desconhecido. Use fortes ou fastreport.'`.
  - `IGeradorRelatorio`: `function PedidosPorPeriodo(const ADados: TRelPedidos): TBytes; function EspelhoPedido(const APedido: TPedido): TBytes; function VendasPorProduto(const ADados: TRelVendasProduto): TBytes; function Visitas(const ADados: TRelVisitas): TBytes;` — cada um devolve o **PDF**.
  - `IRelatorioService` com os quatro métodos recebendo `(AMotor, AInicio, AFim, AUsuarioId)` ou `(AMotor, APedidoId)`; valida período (`fim >= inicio`, no máximo 366 dias → 400) e chama o gerador do motor. Gerador ausente (FastReport sem diretiva) → `ENaoImplementado('FastReport não está disponível nesta compilação da API.')`.
  - `TRegistroGeradores.Executar(AMotor; AProc: TFunc<IGeradorRelatorio, TBytes>): TBytes` — **serializa por motor** com `TMonitor` (Fortes/FastReport não são thread-safe).
  - Fortes: relatórios **montados em código** (`TRLReport` + bandas + `TRLLabel/TRLDBText` ou `TRLMemo`, criados em runtime, sem `.dfm`), exportação com `TRLPDFFilter` para stream. Rodapé: `'Gerado com Fortes Report'` + data/hora. Espelho mostra local (lat/long) e a assinatura (PNG) quando houver.
  - Rotas: `GET /relatorios/pedidos?inicio=&fim=&motor=`, `/relatorios/pedido/:id?motor=`, `/relatorios/vendas-produto?inicio=&fim=&motor=`, `/relatorios/visitas?inicio=&fim=&motor=` → `application/pdf`. Pedidos e visitas são do vendedor logado.

- [ ] **Step 1: Testes que falham**
  - Service (gerador fake): motor inválido 400; período invertido 400; 367 dias 400; FastReport não registrado → `ENaoImplementado`; o gerador recebe as linhas que o repositório fake devolveu.
  - Fortes (real, sem banco): `EspelhoPedido` de um `TPedido` montado no teste → bytes começam com `%PDF` e têm mais de 1000 bytes; `PedidosPorPeriodo` com lista vazia também gera PDF ("Nenhum pedido no período").
- [ ] **Step 2: Rodar** — FAIL. **Step 3: Implementar.** **Step 4: Rodar** — PASS.
- [ ] **Step 5: Smoke manual:** API no ar, `curl -o pedidos.pdf "…/relatorios/pedidos?inicio=2026-11-01&fim=2026-11-30&motor=fortes" -H "Authorization: Bearer …"`; abrir o PDF e conferir (print para o README).
- [ ] **Step 6: Commit** — `Adiciona relatórios em PDF com Fortes Report`

---

### Task 11: Relatórios com FastReport

**Files:**
- Create: `src/Infra/Infra.Relatorio.FastReport.pas`, `tests/Tests.Infra.Relatorio.FastReport.pas`
- Modify: `DelphiHorseApi.dpr` e `tests/DelphiHorseApiTests.dpr` (unit e registro entre `{$IFDEF FASTREPORT}`), script de compilação com `-DFASTREPORT` e o caminho de `C:\FastReport and FastCube 2026.2.1\LibRS37\VCL` (conferir a subpasta Win32 Release)

**Interfaces:**
- Consumes: `IGeradorRelatorio`, `TRegistroGeradores` (Tarefa 10).
- Produces: `TGeradorFastReport` com os quatro relatórios montados em código (`TfrxReport` + `TfrxMasterData`/`TfrxMemoView` criados em runtime, `TfrxUserDataSet` alimentado pelos DTOs), exportação com `TfrxPDFExport` para stream, rodapé `'Gerado com FastReport'`. Mesmo conteúdo do Fortes.

- [ ] **Step 1: Testes que falham** (compilados só com `FASTREPORT`) — mesmos dois testes de PDF da Tarefa 10 para o FastReport.
- [ ] **Step 2: Rodar com `-DFASTREPORT`** — FAIL. **Step 3: Implementar.** **Step 4: Rodar** — PASS. Rodar **também sem** a diretiva — compila e os testes de FastReport não existem; o de `ENaoImplementado` passa.
- [ ] **Step 5: Smoke manual** igual ao da Tarefa 10 com `motor=fastreport`; print.
- [ ] **Step 6: Commit** — `Adiciona relatórios em PDF com FastReport`

---

### Task 12: Documentação, configuração e verificação ponta a ponta

**Files:**
- Modify: `README.md`, `config.example.ini`
- Create (scratchpad, não versionado): roteiro `smoke_forca_vendas.sh` com curl

- [ ] **Step 1: README** — seção do app Força de Vendas no ecossistema; endpoints novos (tabela); refresh token e rotação; `?desde=` e `servidorEm`; UUID/idempotência; faturamento; relatórios e a diretiva `FASTREPORT` (como compilar sem); acesso pela rede local (porta 9000 no firewall do Windows; o celular usa o IP do PC); migrações 005/006; usuária de exemplo `ana`; roadmap. Prints dos PDFs em `docs/screenshots/`.
- [ ] **Step 2: `config.example.ini`** — `[JWT] RefreshDias=30` comentado.
- [ ] **Step 3: Roteiro ponta a ponta contra a API real** — login `ana` → refresh → renovar → reuso recusado; produto por código; cliente com UUID (2×); localização; foto; pedido com UUID (2×, mesma resposta) e assinatura; `?desde=`; faturar, refaturar com outra chave (409), cancelar faturado (409), remover faturamento; visita; os quatro relatórios nos dois motores. Expected: todos os status como no plano; limpar os dados criados no fim.
- [ ] **Step 4: Conferir os `.dproj`** — app e testes compilam por MSBuild com todas as units novas, os caminhos do Fortes/FastReport e `FASTREPORT` ligado; sem a diretiva, o app ainda compila.
- [ ] **Step 5: Commit** — `Documenta as mudanças para o app Força de Vendas`
