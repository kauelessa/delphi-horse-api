# Força de Vendas (FireMonkey) — design

Data: 2026-11-22 · Repositório novo: `delphi-fmx-forca-vendas` · Também altera: `delphi-horse-api`, `delphi-emissor-nfe`, `delphi-vcl-client`

## Intenção

Último projeto do portfólio de Kauê Lessa (Delphi Sênior). Um app FireMonkey de **força de vendas** para o vendedor externo, rodando de verdade no **Windows e no Android** (sem iOS), que fecha o ciclo do ecossistema:

> pedido nasce no app (na rua, até sem internet) → é gerido no cliente VCL → vira NF-e no emissor → o app mostra "Faturado na NF-e 123".

O objetivo é mostrar domínio de FMX multiplataforma, recursos de dispositivo (câmera, GPS, biometria), offline com SQLite e sincronização, integração REST e relatórios com Fortes Report e FastReport.

## Objetivos

- Login com usuário/senha da API; no Android, biometria a partir do segundo acesso; entrada offline com os dados do último acesso.
- Pedido em três passos (Cliente → Itens → Conferir), com localização capturada sozinha e assinatura do cliente.
- Leitura de código de barras/QR pela câmera (Android).
- Mapa interativo de clientes e pedidos, com a posição atual.
- Trabalho offline: SQLite local + fila de envio + sincronização incremental.
- Relatórios em PDF com escolha do motor (Fortes Report ou FastReport).
- Extras aprovados: assinatura, check-in de visita sem venda, rota até o cliente, foto da fachada (Android), tema claro/escuro, testes DUnitX.

## Não objetivos

- iOS e macOS.
- Biometria e leitura pela câmera no Windows (lá: senha e digitação/busca do código).
- Emitir nota pelo app (a NF-e continua no emissor).
- Mapas offline, notificações push, multiempresa.

## Antiobjetivos (falha mesmo que "funcione")

- Senha guardada no aparelho, em texto ou reversível.
- Pedido duplicado na API por reenvio após queda de conexão.
- Pedido perdido: tudo que o vendedor gravou fica no aparelho até a API confirmar.
- Funcionalidade que só existe no Android sem caminho equivalente ou aviso claro no Windows.
- Credenciais, chaves ou dados reais no repositório.

## Restrições

- Delphi 13 (RAD Studio 37.0), FMX, alvos **Win64** e **Android64**. Android 9+ (BiometricPrompt da plataforma).
- Banco local: **SQLite via FireDAC**, criado e migrado pelo próprio app (mesmo padrão `Infra.Migracao` + `SCHEMA_VERSAO` dos outros projetos, scripts embutidos como recurso).
- Fortes Report CE e FastReport 2026.2.1 instalados são **somente VCL** → relatórios são gerados **na API** (Windows) e o app recebe o PDF.
- `TMapView` não existe no Windows → mapa com **Leaflet + OpenStreetMap** num `TWebBrowser` (mesmo código nas duas plataformas; precisa de internet).
- API Horse em HTTP no desenvolvimento → Android exige `usesCleartextTraffic="true"` no `AndroidManifest.template.xml` (documentar; produção usaria HTTPS).
- Padrões dos outros repositórios: camadas `Views/Controllers/Services/Repositories/Models/Infra`, interfaces para teste, SQL parametrizado, `try..finally`, `Currency`, commits em português no imperativo, migrações numeradas nunca editadas, CLAUDE.md/CLAUDE.local.md (estilo misto IA + humano) replicados no repositório novo.
- Componentes: FMX padrão + TeeChart Standard (vem com o Delphi) + ZXing.Delphi (código aberto, via Boss ou pasta `lib/` com licença). Nada de DevExpress (é VCL).

## Abordagens consideradas

**Navegação:** A) abas embaixo; **B) `TMultiView` — escolhida**: gaveta no Android, painel fixo no Windows, um layout só; C) início com blocos.

**Fluxo do pedido:** A) tela única com rolagem; **B) passo a passo Cliente → Itens → Conferir — escolhida**: cada tela faz uma coisa e cabe no celular.

**Dados:** **A) offline-first — escolhida**: SQLite é a base de trabalho do app, fila de envio com UUID gerado no aparelho (reenvio idempotente), recebimento incremental por `?desde=`. B) online-first com cache mínimo: descartada porque esvazia o "entrar offline" aprovado. C) sincronização genérica do FireDAC: descartada porque esconde a lógica que o portfólio quer mostrar.

**Relatórios:** gerados na API (VCL roda no servidor Windows) e não no app, porque nenhum dos dois motores instalados roda em FMX/Android.

## Ordem de execução (três frentes, um plano cada)

1. **API** (`delphi-horse-api`) — tudo que o app consome.
2. **Emissor + cliente VCL** — aviso de faturamento e campos novos nas telas.
3. **App** (`delphi-fmx-forca-vendas`).

---

## 1. Mudanças na API

Migrações novas a partir de `005_...` (nunca editar as existentes).

### Dados

| Mudança | Para quê |
|---|---|
| `PRODUTOS.CODIGO_BARRAS VARCHAR(14)` (único quando preenchido) | leitura pela câmera; seed fictício com EANs válidos |
| `CLIENTES.LATITUDE / LONGITUDE NUMERIC(9,6)`, `CLIENTES.FOTO BLOB` | mapa, "mais próximos", foto da fachada |
| `PEDIDOS.UUID CHAR(36)` único, `USUARIO_ID` (vendedor, nulo nos antigos), `LATITUDE/LONGITUDE`, `PRECISAO_M`, `OBSERVACAO`, `ORIGEM` ('API','APP'), `ASSINATURA BLOB` (PNG) | pedido do app, idempotência, local, assinatura |
| `PEDIDOS.NOTA_NUMERO`, `NOTA_SERIE`, `NOTA_CHAVE`, `NOTA_AUTORIZADA_EM` | aviso de faturamento vindo do emissor |
| `CLIENTES.UUID` único | cliente criado offline no app |
| `ATUALIZADO_EM TIMESTAMP` em CLIENTES, PRODUTOS, PEDIDOS (mantido pelo repositório em toda gravação) | recebimento incremental |
| Tabela `VISITAS` (ID, UUID único, CLIENTE_ID, USUARIO_ID, DATA_VISITA, LATITUDE, LONGITUDE, PRECISAO_M, MOTIVO, OBSERVACAO) | check-in sem venda |
| Tabela `SESSOES` (ID, USUARIO_ID, TOKEN_HASH, DISPOSITIVO, CRIADA_EM, EXPIRA_EM, REVOGADA) | token de renovação |

### Endpoints novos ou alterados

- `POST /auth/login` passa a devolver também `refreshToken` (opaco, 32 bytes aleatórios; só o hash SHA-256 fica no banco; validade 30 dias, configurável).
- `POST /auth/renovar` `{refreshToken}` → novo access + **novo** refresh (rotação; o antigo é revogado; reuso de token revogado revoga a sessão inteira).
- `POST /auth/sair` revoga a sessão.
- `GET /clientes`, `/produtos`, `/pedidos` aceitam `?desde=<ISO 8601>` (inclui inativos, para o app saber o que sumiu) e `/pedidos?vendedor=eu`.
- `POST /clientes` e `POST /pedidos` aceitam `uuid`; se o UUID já existe, devolvem **200 com o registro existente** em vez de criar outro.
- `POST /pedidos` aceita `latitude`, `longitude`, `precisao`, `observacao`, `assinatura` (PNG base64, até 200 KB), `dataPedido` (hora do aparelho). Regras atuais mantidas: **a API recalcula preço e confere estoque**.
- `PUT /clientes/:id/localizacao`, `PUT /clientes/:id/foto` (JPEG, até 500 KB), `GET /clientes/:id/foto`.
- `POST /visitas`, `GET /visitas?desde=&vendedor=eu`.
- `PATCH /pedidos/:id/faturamento` `{numero, serie, chave, autorizadaEm}` e `DELETE /pedidos/:id/faturamento` (NF-e cancelada). Pedido cancelado não pode ser faturado (409).
- `GET /produtos/codigo/:codigoBarras`.
- `GET /relatorios/pedidos?inicio=&fim=&motor=fortes|fastreport`, `GET /relatorios/pedido/:id?motor=` (espelho, com assinatura e local), `GET /relatorios/vendas-produto?inicio=&fim=&motor=`, `GET /relatorios/visitas?inicio=&fim=&motor=` → `application/pdf`.

### Relatórios na API

- Unit por motor (`Report.Fortes.*`, `Report.FastReport.*`) atrás de uma interface `IGeradorRelatorio` escolhida pelo parâmetro `motor`; os dados vêm dos repositórios já existentes.
- Fortes e FastReport são VCL e não são seguros para threads: a geração é **serializada** (um `TMonitor`/seção crítica por motor). Aceitável para o volume do portfólio; documentado.
- Layouts dos relatórios: em `.dfm` (Fortes) e `.fr3` (FastReport) versionados; mesmo conteúdo nos dois motores, rodapé indicando o motor usado.

---

## 2. Emissor e cliente VCL

**Emissor:** ao autorizar uma NF-e com `PedidoApiId > 0`, chama `PATCH /pedidos/:id/faturamento`; ao cancelar, `DELETE`. Se a API estiver fora, grava a pendência na nota (`FATURAMENTO_PENDENTE`, migração nova) e tenta de novo ao abrir a tela de pedidos da API e ao abrir o sistema. Falha no aviso **nunca** desfaz nem bloqueia a operação fiscal; só registra log.

**Cliente VCL:** campo Código de barras no cadastro de produto; na lista de pedidos, colunas Origem (API/App), Vendedor e NF-e; no detalhe do pedido, local ("ver no mapa" abre o OpenStreetMap no navegador) e a assinatura.

---

## 3. O app

### Telas (aprovadas nos esboços)

Navegação: `TMultiView` com Início, Clientes, Produtos, Pedidos, Mapa, Visitas, Relatórios, Sincronizar, Configurações. Cabeçalho do menu com o nome do vendedor.

| Tela | Conteúdo |
|---|---|
| **Login** | Usuário, senha, chave "Entrar com biometria nas próximas vezes" (só Android), link do servidor (URL editável). Próximos acessos no Android: "Entrar com biometria", "Usar senha", "Trocar de usuário". Sem API: "Entrar offline" / "Tentar de novo". |
| **Início** | Vendas de hoje (qtd e valor), gráfico dos últimos 7 dias (TeeChart), avisos: pendentes de envio, recusados, faturados desde a última sincronização. |
| **Clientes** | Lista com busca (nome, CPF/CNPJ), ordenada por distância quando há posição. Detalhe: dados, foto da fachada (Android), "Usar minha localização", "Novo pedido", "Check-in", "Rota". Novo cliente: nome, CPF/CNPJ (validado), e-mail, telefone, localização. |
| **Produtos** | Lista com busca por nome ou código; botão câmera (Android). Preço e estoque da última sincronização. |
| **Pedido (3 passos)** | 1. Cliente (busca, mais próximos primeiro, "+ Novo cliente"). 2. Itens: busca/código/câmera, quantidade −/+, total. 3. Conferir: resumo, mapinha do local, observação, assinatura, "Gravar pedido". |
| **Pedidos** | Lista com status: Pendente de envio, Enviado, Recusado (motivo), Faturado (NF-e nº), Cancelado. Pendente/Recusado pode ser editado e reenviado; detalhe mostra o preço confirmado pela API quando diferir. |
| **Mapa** | Leaflet/OSM; alterna Clientes / Pedidos / Visitas; posição atual; toque no marcador abre cartão com distância e atalhos Novo pedido / Rota. Offline: aviso "mapa precisa de internet". |
| **Visitas** | Check-in: cliente, motivo (lista: comprador ausente, sem necessidade, sem estoque, preço, outro), observação, local automático. Lista das visitas. |
| **Relatórios** | Pedidos por período, Espelho do pedido, Vendas por produto, Visitas. Seletor Fortes Report / FastReport (padrão nas Configurações). "Gerar PDF" → abre no visualizador do sistema; no Android, compartilhar. Precisa de internet. |
| **Sincronizar** | Enviar (contagem por tipo), Receber, "Sincronizar agora", resultado da última, lista de recusados com motivo. |
| **Configurações** | URL da API, motor padrão de relatório, tema (claro/escuro/sistema), biometria ligada/desligada, sair (revoga a sessão e apaga dados locais após confirmação se houver pendências). |

### Autenticação e biometria

- Login online: `POST /auth/login`. O app guarda: access token em memória; **refresh token protegido** — Android: cifrado com chave do **Android Keystore** que exige autenticação biométrica (`BiometricPrompt` com `CryptoObject`), Windows: **DPAPI** (`CryptProtectData`, escopo do usuário).
- Para entrar offline o app guarda um **hash PBKDF2 local da senha** (com sal, iterações ≥ 100 mil), nunca a senha.
- Biometria aprovada → decifra o refresh → `POST /auth/renovar`. Sem internet → entra offline (o desbloqueio biométrico já prova o usuário). Biometria trocada no aparelho (chave invalidada) → volta para senha e pede para reativar.
- 401 com access expirado → renova uma vez e repete a chamada (mesmo padrão do `Infra.ApiPedidos` do emissor).

### Banco local (SQLite)

Tabelas espelho: `CLIENTE`, `PRODUTO`, `PEDIDO`, `PEDIDO_ITEM`, `VISITA`, mais `SESSAO_LOCAL` (usuário, hash local, refresh cifrado, última sincronização por entidade) e `CONFIG`. Registros criados no app têm `UUID`, `ID_SERVIDOR` (nulo até enviar) e `SITUACAO_SYNC` (`PENDENTE`, `ENVIADO`, `RECUSADO`, `SINCRONIZADO`) + `MOTIVO_RECUSA`. Assinatura e foto como BLOB.

### Sincronização

Ordem de **envio**: clientes novos → atualizações de localização/foto → pedidos → visitas. Pedido de cliente novo espera o cliente ganhar `ID_SERVIDOR` (mapeamento UUID → id). Cada item é independente: erro de regra (422/409) marca **Recusado** com a mensagem da API e segue para o próximo; erro de rede interrompe e mantém tudo pendente.

**Recebimento**: `GET ...?desde=` por entidade, gravando a marca de tempo do servidor (resposta) e não a do aparelho. Cadastros: o servidor vence. Pedidos: atualiza status, preço confirmado e dados da NF-e; nunca sobrescreve um pedido local ainda pendente.

Disparo: botão Sincronizar, ao entrar online e ao gravar pedido quando há conexão. Roda em `TTask` com a interface liberada; progresso na tela; um sincronismo por vez.

### Recursos de dispositivo (abstraídos para teste)

Interfaces em `Infra.Plataforma`: `ILocalizacao`, `ILeitorCodigo`, `IBiometria`, `ICofreSegredos`, `IAbrirArquivo` (abrir/compartilhar PDF, rota). Implementações por `{$IFDEF ANDROID}` / `{$IFDEF MSWINDOWS}` e fakes nos testes.

- **Localização:** `TLocationSensor` nas duas plataformas (Windows usa o serviço de localização do sistema). Precisão registrada; sem posição em 15 s ou permissão negada → grava sem local e mostra o aviso (não bloqueia a venda).
- **Câmera/código:** `TCameraComponent` + ZXing.Delphi (EAN-13, EAN-8, Code128, QR). QR pode conter o código de barras ou `produto:<id>`. No Windows o botão câmera não aparece.
- **Rota:** Android: Intent `geo:` / `google.navigation:` (abre Maps ou Waze); Windows: URL do OpenStreetMap no navegador.
- **PDF:** salvo na pasta de cache; Android abre via Intent com FileProvider (opção "Secure File Sharing" do projeto); Windows via `ShellExecute`.
- **Mapa:** HTML com Leaflet carregado do CDN; Delphi → JS via `EvaluateJavaScript`; JS → Delphi por navegação para esquema próprio `forcavendas://cliente/<id>` interceptado em `OnShouldStartLoadWithRequest`.
- **Assinatura:** componente próprio sobre `TPaintBox`/`TPath`, exporta PNG; obrigatória? **não** (opcional, mas o espelho indica "sem assinatura").
- **Tema:** dois StyleBooks (claro/escuro) + opção seguir o sistema.

### Arquitetura do app

`src/Views` (forms e frames FMX, sem SQL nem HTTP), `Controllers`, `Services` (Pedido, Sincronizacao, Auth, Relatorio), `Repositories` (FireDAC SQLite), `Models`, `Infra` (Conexao SQLite, Migracao, ApiCliente com `IHttpTransporte`, Plataforma, Config). Testes DUnitX em `tests/` (Win64) com fakes de transporte HTTP, repositórios em SQLite de memória e plataforma.

### Testes que devem existir

- Totais do pedido e regras locais (quantidade > 0, item repetido soma).
- Sincronização: ordem de envio, cliente novo antes do pedido, recusa individual não para a fila, queda de rede mantém pendentes, reenvio com mesmo UUID não duplica (fake devolve 200 existente), recebimento incremental e "servidor vence".
- Auth: renovação após 401, refresh rotacionado gravado, hash local confere/recusa.
- API: idempotência por UUID, `?desde=`, faturamento (inclusive pedido cancelado → 409), rotação e reuso de refresh, geração de PDF dos dois motores (PDF não vazio, começa com `%PDF`).

### Documentação e portfólio

README do app no padrão dos outros (ecossistema, prints Windows e Android, como executar, configuração do Android/cleartext, migrações, testes, roadmap); READMEs da API, emissor e cliente VCL atualizados com o ecossistema completo (diagrama do ciclo pedido → NF-e). Prints em `docs/screenshots/`.

## Decisões minhas (para você conferir)

1. Alvos Win64 e Android64 (sem Win32/Android32).
2. API reprecifica e confere estoque no envio (regra atual mantida); o preço do app offline é estimativa e o pedido pode voltar **Recusado** por estoque.
3. Cliente criado no app vai para a API com UUID; cadastro completo continua no cliente VCL.
4. Assinatura opcional.
5. Localização do cliente vem do vendedor ("usar minha localização") ou do primeiro pedido feito nele; não há geocodificação de endereço (a API não guarda endereço).
6. Relatórios só online; mapa só online.
7. Geração de relatório serializada na API.
8. ZXing.Delphi como dependência de terceiros (licença Apache 2.0).
9. O emissor nunca bloqueia operação fiscal por falha no aviso à API.
10. Vendedor = qualquer usuário ativo da API (sem papéis novos); seed fictício com uma vendedora ("ana"). Todos veem todos os clientes; a lista de pedidos do app mostra só os do vendedor logado.
11. FastReport é comercial: na API ele entra atrás da diretiva `FASTREPORT` (ligada no `.dproj` do Kauê). Sem ela a API compila só com Fortes (livre) e `motor=fastreport` responde 501 com mensagem clara — quem clonar o repositório continua conseguindo compilar.
12. Validação no Android com o SDK já configurado na IDE (Android API 36.1, Delphi Enterprise): compilação Android64 pela linha de comando (MSBuild), instalação e roteiros no celular do Kauê via USB (`adb` do SDK do RAD Studio), com prints do Android para o README. O celular acessa a API pela rede local (IP do PC, porta 9000, liberada no firewall do Windows).

## Deixado para quem constrói

Layout fino das telas (espaçamentos, ícones), nomes internos de units além dos padrões, desenho dos relatórios, textos de mensagens no estilo dos outros projetos, seeds fictícios (EANs, coordenadas em São Paulo).
