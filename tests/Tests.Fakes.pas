unit Tests.Fakes;

{ Repositórios em memória para os testes de Service.
  Seguem o mesmo contrato dos reais: devolvem cópias (o chamador libera)
  e BuscarPorId ignora registros inativos. }

interface

uses
  System.Generics.Collections,
  Model.Cliente,
  Model.Produto,
  Model.Pedido,
  Model.Paginacao,
  Repository.Cliente,
  Repository.Produto,
  Repository.Pedido,
  Model.Sessao,
  Repository.Sessao,
  Repository.Relogio,
  Model.Visita,
  Repository.Visita,
  System.SysUtils,
  System.Classes;

type
  TClienteRepositoryFake = class(TInterfacedObject, IClienteRepository)
  private
    FClientes: TObjectList<TCliente>;
    FRegistro: TStrings;
    FFotos: TDictionary<Integer, TBytes>;
    FInsercoes: Integer;
    FProximoId: Integer;
    FUltimaBusca: string;
    function Localizar(AId: Integer): TCliente;
  public
    constructor Create;
    destructor Destroy; override;
    function Adicionar(const ANome, ADocumento: string; AAtivo: Boolean = True): Integer;
    function Obter(AId: Integer): TCliente; // sem cópia, para asserts
    property UltimaBusca: string read FUltimaBusca;

    // se atribuído, cada Listar anota 'Listar' aqui (para conferir a ordem das chamadas)
    property Registro: TStrings read FRegistro write FRegistro;
    property Insercoes: Integer read FInsercoes;
    // Inserir grava "o outro envio" com o mesmo UUID e recusa pelo documento, como o
    // índice do CPF/CNPJ faria antes do índice do UUID
    var SimularCorridaPorDocumento: Boolean;
    function FotosGravadas: Integer;
    function BuscarPorUuid(const AUuid: string): TCliente;
    procedure GravarLocalizacao(AId: Integer; ALatitude, ALongitude: Double);
    procedure GravarFoto(AId: Integer; const AFoto: TBytes);
    function LerFoto(AId: Integer): TBytes;
    function Listar(const APaginacao: TPaginacao; const ABusca: string; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TCliente>;
    function BuscarPorId(AId: Integer): TCliente;
    function DocumentoEmUso(const ADocumento: string; AIgnorarId: Integer): Boolean;
    procedure Inserir(ACliente: TCliente);
    procedure Atualizar(ACliente: TCliente);
    procedure Inativar(AId: Integer);
  end;

  TProdutoRepositoryFake = class(TInterfacedObject, IProdutoRepository)
  private
    FProdutos: TObjectList<TProduto>;
    FProximoId: Integer;
    FUltimaBusca: string;
    function Localizar(AId: Integer): TProduto;
  public
    constructor Create;
    destructor Destroy; override;
    function Adicionar(const ADescricao: string; APreco: Currency; AEstoque: Integer;
      AAtivo: Boolean = True): Integer;
    function Obter(AId: Integer): TProduto;
    property UltimaBusca: string read FUltimaBusca;

    function Listar(const APaginacao: TPaginacao; const ABusca: string; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TProduto>;
    function BuscarPorId(AId: Integer): TProduto;
    function BuscarPorCodigoBarras(const ACodigo: string): TProduto;
    function CodigoBarrasEmUso(const ACodigo: string; AIgnorarId: Integer): Integer;
    procedure Inserir(AProduto: TProduto);
    procedure Atualizar(AProduto: TProduto);
    procedure Inativar(AId: Integer);
  end;

  TPedidoRepositoryFake = class(TInterfacedObject, IPedidoRepository)
  private
    FPedidos: TObjectList<TPedido>;
    FProximoId: Integer;
    FCancelamentos: Integer;
    function Localizar(AId: Integer): TPedido;
  public
    constructor Create;
    destructor Destroy; override;
    function Obter(AId: Integer): TPedido;
    property Cancelamentos: Integer read FCancelamentos;
    function Quantidade: Integer;
    // Inserir grava "a outra requisição" e levanta EUuidDuplicado, como o índice único faria
    var SimularCorridaDeUuid: Boolean;
    // quantas leituras por UUID ainda não enxergam o pedido do "outro" envio (-1 = nunca)
    var LeiturasAteConfirmar: Integer;
    function BuscarPorUuid(const AUuid: string): TPedido;
    function LerAssinatura(AId: Integer): TBytes;

    function Listar(const APaginacao: TPaginacao; AClienteId: Integer; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TPedido>;
    function BuscarPorId(AId: Integer): TPedido;
    procedure Inserir(APedido: TPedido);
    procedure Cancelar(APedido: TPedido);
    procedure GravarFaturamento(AId, ANumero, ASerie: Integer; const AChave: string; AAutorizadaEm: TDateTime);
    procedure LimparFaturamento(AId: Integer);
    var Faturamentos: Integer;
  end;

  TSessaoRepositoryFake = class(TInterfacedObject, ISessaoRepository)
  private
    FSessoes: TObjectList<TSessao>;
    FProximoId: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    property Sessoes: TObjectList<TSessao> read FSessoes; // para asserts

    procedure Inserir(ASessao: TSessao);
    function BuscarPorHash(const AHash: string): TSessao;
    function Revogar(AId: Integer): Boolean;
    procedure RevogarFamilia(const AFamilia: string);
  end;

  TVisitaRepositoryFake = class(TInterfacedObject, IVisitaRepository)
  private
    FVisitas: TObjectList<TVisita>;
    FProximoId: Integer;
  public
    var SimularCorridaDeUuid: Boolean;
    constructor Create;
    destructor Destroy; override;
    function Quantidade: Integer;
    function Obter(AId: Integer): TVisita; // sem cópia, para asserts

    function Listar(const APaginacao: TPaginacao; const ASync: TFiltroSync; out ATotal: Integer): TObjectList<TVisita>;
    function BuscarPorUuid(const AUuid: string): TVisita;
    procedure Inserir(AVisita: TVisita);
  end;

  TRelogioFake = class(TInterfacedObject, IRelogioRepository)
  private
    FAgora: TDateTime;
    FChamadas: TStringList;
  public
    constructor Create(AAgora: TDateTime);
    destructor Destroy; override;
    function AgoraNoServidor: TDateTime;
    property Chamadas: TStringList read FChamadas;
  end;

function ClonarCliente(AOrigem: TCliente): TCliente;
function ClonarProduto(AOrigem: TProduto): TProduto;
function ClonarPedido(AOrigem: TPedido): TPedido;

implementation

uses
  Infra.Excecoes;

function ClonarCliente(AOrigem: TCliente): TCliente;
begin
  Result := TCliente.Create;
  Result.Id := AOrigem.Id;
  Result.Nome := AOrigem.Nome;
  Result.Documento := AOrigem.Documento;
  Result.Email := AOrigem.Email;
  Result.Telefone := AOrigem.Telefone;
  Result.Uuid := AOrigem.Uuid;
  if AOrigem.TemLocalizacao then
    Result.DefinirLocalizacao(AOrigem.Latitude, AOrigem.Longitude);
  Result.TemFoto := AOrigem.TemFoto;
  Result.Ativo := AOrigem.Ativo;
end;

function ClonarProduto(AOrigem: TProduto): TProduto;
begin
  Result := TProduto.Create;
  Result.Id := AOrigem.Id;
  Result.Descricao := AOrigem.Descricao;
  Result.Preco := AOrigem.Preco;
  Result.Estoque := AOrigem.Estoque;
  Result.CodigoBarras := AOrigem.CodigoBarras;
  Result.Ativo := AOrigem.Ativo;
end;

function ClonarPedido(AOrigem: TPedido): TPedido;
begin
  Result := TPedido.Create;
  Result.Assign(AOrigem);
end;

{ TClienteRepositoryFake }

constructor TClienteRepositoryFake.Create;
begin
  inherited Create;
  FFotos := TDictionary<Integer, TBytes>.Create;
  FClientes := TObjectList<TCliente>.Create(True);
  FProximoId := 1;
end;

destructor TClienteRepositoryFake.Destroy;
begin
  FFotos.Free;
  FClientes.Free;
  inherited;
end;

function TClienteRepositoryFake.Localizar(AId: Integer): TCliente;
var
  LCliente: TCliente;
begin
  for LCliente in FClientes do
    if LCliente.Id = AId then
      Exit(LCliente);
  Result := nil;
end;

function TClienteRepositoryFake.Adicionar(const ANome, ADocumento: string; AAtivo: Boolean): Integer;
var
  LCliente: TCliente;
begin
  LCliente := TCliente.Create;
  LCliente.Id := FProximoId;
  LCliente.Nome := ANome;
  LCliente.Documento := ADocumento;
  LCliente.Ativo := AAtivo;
  FClientes.Add(LCliente);
  Inc(FProximoId);
  Result := LCliente.Id;
end;

function TClienteRepositoryFake.Obter(AId: Integer): TCliente;
begin
  Result := Localizar(AId);
end;

function TClienteRepositoryFake.Listar(const APaginacao: TPaginacao; const ABusca: string;
  const ASync: TFiltroSync; out ATotal: Integer): TObjectList<TCliente>;
var
  LCliente: TCliente;
begin
  if Assigned(Registro) then
    Registro.Add('Listar');
  // o filtro real é SQL (testado em Tests.Repository.Filtro); aqui só registra o que chegou
  FUltimaBusca := ABusca;
  Result := TObjectList<TCliente>.Create(True);
  for LCliente in FClientes do
    if LCliente.Ativo then
      Result.Add(ClonarCliente(LCliente));
  ATotal := Result.Count;
end;

function TClienteRepositoryFake.BuscarPorId(AId: Integer): TCliente;
var
  LCliente: TCliente;
begin
  LCliente := Localizar(AId);
  if (LCliente = nil) or not LCliente.Ativo then
    Exit(nil);
  Result := ClonarCliente(LCliente);
end;

function TClienteRepositoryFake.DocumentoEmUso(const ADocumento: string; AIgnorarId: Integer): Boolean;
var
  LCliente: TCliente;
begin
  for LCliente in FClientes do
    if (LCliente.Documento = ADocumento) and (LCliente.Id <> AIgnorarId) then
      Exit(True);
  Result := False;
end;

function TClienteRepositoryFake.FotosGravadas: Integer;
begin
  Result := FFotos.Count;
end;

function TClienteRepositoryFake.BuscarPorUuid(const AUuid: string): TCliente;
var
  LCliente: TCliente;
begin
  for LCliente in FClientes do
    if (LCliente.Uuid <> '') and (LCliente.Uuid = AUuid) then
      Exit(ClonarCliente(LCliente));
  Result := nil;
end;

procedure TClienteRepositoryFake.GravarLocalizacao(AId: Integer; ALatitude, ALongitude: Double);
begin
  Localizar(AId).DefinirLocalizacao(ALatitude, ALongitude);
end;

procedure TClienteRepositoryFake.GravarFoto(AId: Integer; const AFoto: TBytes);
begin
  FFotos.AddOrSetValue(AId, Copy(AFoto));
  Localizar(AId).TemFoto := True;
end;

function TClienteRepositoryFake.LerFoto(AId: Integer): TBytes;
begin
  if not FFotos.TryGetValue(AId, Result) then
    Result := nil;
end;

procedure TClienteRepositoryFake.Inserir(ACliente: TCliente);
var
  LOutro: TCliente;
begin
  if SimularCorridaPorDocumento then
  begin
    SimularCorridaPorDocumento := False;
    LOutro := ClonarCliente(ACliente);
    LOutro.Id := FProximoId;
    Inc(FProximoId);
    FClientes.Add(LOutro);
    raise ERegraNegocio.Create('Já existe um cliente com este CPF/CNPJ.');
  end;
  Inc(FInsercoes);
  ACliente.Id := FProximoId;
  Inc(FProximoId);
  FClientes.Add(ClonarCliente(ACliente));
end;

procedure TClienteRepositoryFake.Atualizar(ACliente: TCliente);
var
  LCliente: TCliente;
begin
  LCliente := Localizar(ACliente.Id);
  LCliente.Nome := ACliente.Nome;
  LCliente.Documento := ACliente.Documento;
  LCliente.Email := ACliente.Email;
  LCliente.Telefone := ACliente.Telefone;
  LCliente.Ativo := ACliente.Ativo;
end;

procedure TClienteRepositoryFake.Inativar(AId: Integer);
begin
  Localizar(AId).Ativo := False;
end;

{ TProdutoRepositoryFake }

constructor TProdutoRepositoryFake.Create;
begin
  inherited Create;
  FProdutos := TObjectList<TProduto>.Create(True);
  FProximoId := 1;
end;

destructor TProdutoRepositoryFake.Destroy;
begin
  FProdutos.Free;
  inherited;
end;

function TProdutoRepositoryFake.Localizar(AId: Integer): TProduto;
var
  LProduto: TProduto;
begin
  for LProduto in FProdutos do
    if LProduto.Id = AId then
      Exit(LProduto);
  Result := nil;
end;

function TProdutoRepositoryFake.Adicionar(const ADescricao: string; APreco: Currency;
  AEstoque: Integer; AAtivo: Boolean): Integer;
var
  LProduto: TProduto;
begin
  LProduto := TProduto.Create;
  LProduto.Id := FProximoId;
  LProduto.Descricao := ADescricao;
  LProduto.Preco := APreco;
  LProduto.Estoque := AEstoque;
  LProduto.Ativo := AAtivo;
  FProdutos.Add(LProduto);
  Inc(FProximoId);
  Result := LProduto.Id;
end;

function TProdutoRepositoryFake.Obter(AId: Integer): TProduto;
begin
  Result := Localizar(AId);
end;

function TProdutoRepositoryFake.Listar(const APaginacao: TPaginacao; const ABusca: string;
  const ASync: TFiltroSync; out ATotal: Integer): TObjectList<TProduto>;
var
  LProduto: TProduto;
begin
  FUltimaBusca := ABusca;
  Result := TObjectList<TProduto>.Create(True);
  for LProduto in FProdutos do
    if LProduto.Ativo then
      Result.Add(ClonarProduto(LProduto));
  ATotal := Result.Count;
end;

function TProdutoRepositoryFake.BuscarPorId(AId: Integer): TProduto;
var
  LProduto: TProduto;
begin
  LProduto := Localizar(AId);
  if (LProduto = nil) or not LProduto.Ativo then
    Exit(nil);
  Result := ClonarProduto(LProduto);
end;

function TProdutoRepositoryFake.BuscarPorCodigoBarras(const ACodigo: string): TProduto;
var
  LProduto: TProduto;
begin
  for LProduto in FProdutos do
    if LProduto.Ativo and (LProduto.CodigoBarras <> '') and (LProduto.CodigoBarras = ACodigo) then
      Exit(ClonarProduto(LProduto));
  Result := nil;
end;

function TProdutoRepositoryFake.CodigoBarrasEmUso(const ACodigo: string; AIgnorarId: Integer): Integer;
var
  LProduto: TProduto;
begin
  for LProduto in FProdutos do
    if (LProduto.Id <> AIgnorarId) and (LProduto.CodigoBarras = ACodigo) then
      Exit(LProduto.Id);
  Result := 0;
end;

procedure TProdutoRepositoryFake.Inserir(AProduto: TProduto);
begin
  AProduto.Id := FProximoId;
  Inc(FProximoId);
  FProdutos.Add(ClonarProduto(AProduto));
end;

procedure TProdutoRepositoryFake.Atualizar(AProduto: TProduto);
var
  LProduto: TProduto;
begin
  LProduto := Localizar(AProduto.Id);
  LProduto.Descricao := AProduto.Descricao;
  LProduto.Preco := AProduto.Preco;
  LProduto.Estoque := AProduto.Estoque;
  LProduto.CodigoBarras := AProduto.CodigoBarras;
  LProduto.Ativo := AProduto.Ativo;
end;

procedure TProdutoRepositoryFake.Inativar(AId: Integer);
begin
  Localizar(AId).Ativo := False;
end;

{ TPedidoRepositoryFake }

constructor TPedidoRepositoryFake.Create;
begin
  inherited Create;
  FPedidos := TObjectList<TPedido>.Create(True);
  FProximoId := 1;
end;

destructor TPedidoRepositoryFake.Destroy;
begin
  FPedidos.Free;
  inherited;
end;

function TPedidoRepositoryFake.Localizar(AId: Integer): TPedido;
var
  LPedido: TPedido;
begin
  for LPedido in FPedidos do
    if LPedido.Id = AId then
      Exit(LPedido);
  Result := nil;
end;

function TPedidoRepositoryFake.Obter(AId: Integer): TPedido;
begin
  Result := Localizar(AId);
end;

function TPedidoRepositoryFake.Quantidade: Integer;
begin
  Result := FPedidos.Count;
end;

function TPedidoRepositoryFake.Listar(const APaginacao: TPaginacao; AClienteId: Integer;
  const ASync: TFiltroSync; out ATotal: Integer): TObjectList<TPedido>;
var
  LPedido: TPedido;
begin
  Result := TObjectList<TPedido>.Create(True);
  for LPedido in FPedidos do
    if (AClienteId = 0) or (LPedido.ClienteId = AClienteId) then
      Result.Add(ClonarPedido(LPedido));
  ATotal := Result.Count;
end;

function TPedidoRepositoryFake.BuscarPorId(AId: Integer): TPedido;
var
  LPedido: TPedido;
begin
  LPedido := Localizar(AId);
  if LPedido = nil then
    Exit(nil);
  Result := ClonarPedido(LPedido);
end;

function TPedidoRepositoryFake.BuscarPorUuid(const AUuid: string): TPedido;
var
  LPedido: TPedido;
begin
  if LeiturasAteConfirmar <> 0 then
  begin
    if LeiturasAteConfirmar > 0 then
      Dec(LeiturasAteConfirmar);
    Exit(nil);
  end;
  for LPedido in FPedidos do
    if (LPedido.Uuid <> '') and (LPedido.Uuid = AUuid) then
      Exit(ClonarPedido(LPedido));
  Result := nil;
end;

function TPedidoRepositoryFake.LerAssinatura(AId: Integer): TBytes;
var
  LPedido: TPedido;
begin
  LPedido := Localizar(AId);
  if LPedido = nil then
    Exit(nil);
  Result := Copy(LPedido.Assinatura);
end;

procedure TPedidoRepositoryFake.Inserir(APedido: TPedido);
var
  LOutro: TPedido;
begin
  if SimularCorridaDeUuid then
  begin
    SimularCorridaDeUuid := False;
    LOutro := ClonarPedido(APedido);
    LOutro.Id := FProximoId;
    Inc(FProximoId);
    FPedidos.Add(LOutro);
    raise EUuidDuplicado.Create('UQ_PEDIDOS_UUID');
  end;
  APedido.Id := FProximoId;
  Inc(FProximoId);
  FPedidos.Add(ClonarPedido(APedido));
  // como o JOIN com USUARIOS do repositório real: o nome só aparece na leitura
  if APedido.UsuarioId = 2 then
    FPedidos.Last.NomeVendedor := 'Ana Vendedora';
end;

procedure TPedidoRepositoryFake.Cancelar(APedido: TPedido);
begin
  Localizar(APedido.Id).Status := spCancelado;
  Inc(FCancelamentos);
end;

procedure TPedidoRepositoryFake.GravarFaturamento(AId, ANumero, ASerie: Integer; const AChave: string;
  AAutorizadaEm: TDateTime);
begin
  Localizar(AId).DefinirNota(ANumero, ASerie, AChave, AAutorizadaEm);
  Inc(Faturamentos);
end;

procedure TPedidoRepositoryFake.LimparFaturamento(AId: Integer);
begin
  Localizar(AId).LimparNota;
end;

{ TVisitaRepositoryFake }

constructor TVisitaRepositoryFake.Create;
begin
  inherited Create;
  FVisitas := TObjectList<TVisita>.Create(True);
  FProximoId := 1;
end;

destructor TVisitaRepositoryFake.Destroy;
begin
  FVisitas.Free;
  inherited;
end;

function TVisitaRepositoryFake.Quantidade: Integer;
begin
  Result := FVisitas.Count;
end;

function TVisitaRepositoryFake.Obter(AId: Integer): TVisita;
var
  LVisita: TVisita;
begin
  for LVisita in FVisitas do
    if LVisita.Id = AId then
      Exit(LVisita);
  Result := nil;
end;

function TVisitaRepositoryFake.Listar(const APaginacao: TPaginacao; const ASync: TFiltroSync;
  out ATotal: Integer): TObjectList<TVisita>;
var
  LVisita, LCopia: TVisita;
begin
  Result := TObjectList<TVisita>.Create(True);
  for LVisita in FVisitas do
    if (ASync.UsuarioId = 0) or (LVisita.UsuarioId = ASync.UsuarioId) then
    begin
      LCopia := TVisita.Create;
      LCopia.Assign(LVisita);
      Result.Add(LCopia);
    end;
  ATotal := Result.Count;
end;

function TVisitaRepositoryFake.BuscarPorUuid(const AUuid: string): TVisita;
var
  LVisita: TVisita;
begin
  for LVisita in FVisitas do
    if LVisita.Uuid = AUuid then
    begin
      Result := TVisita.Create;
      Result.Assign(LVisita);
      Exit;
    end;
  Result := nil;
end;

procedure TVisitaRepositoryFake.Inserir(AVisita: TVisita);
var
  LCopia: TVisita;
begin
  LCopia := TVisita.Create;
  LCopia.Assign(AVisita);
  LCopia.Id := FProximoId;
  Inc(FProximoId);
  FVisitas.Add(LCopia);
  if SimularCorridaDeUuid then
  begin
    // "a outra requisição" gravou primeiro
    SimularCorridaDeUuid := False;
    raise EUuidDuplicado.Create('UQ_VISITAS_UUID');
  end;
  AVisita.Id := LCopia.Id;
end;

{ TRelogioFake }

constructor TRelogioFake.Create(AAgora: TDateTime);
begin
  inherited Create;
  FAgora := AAgora;
  FChamadas := TStringList.Create;
end;

destructor TRelogioFake.Destroy;
begin
  FChamadas.Free;
  inherited;
end;

function TRelogioFake.AgoraNoServidor: TDateTime;
begin
  FChamadas.Add('AgoraNoServidor');
  Result := FAgora;
end;

{ TSessaoRepositoryFake }

constructor TSessaoRepositoryFake.Create;
begin
  inherited Create;
  FSessoes := TObjectList<TSessao>.Create(True);
  FProximoId := 1;
end;

destructor TSessaoRepositoryFake.Destroy;
begin
  FSessoes.Free;
  inherited;
end;

procedure TSessaoRepositoryFake.Inserir(ASessao: TSessao);
begin
  ASessao.Id := FProximoId;
  Inc(FProximoId);
  FSessoes.Add(ASessao.Clonar);
end;

function TSessaoRepositoryFake.BuscarPorHash(const AHash: string): TSessao;
var
  LSessao: TSessao;
begin
  for LSessao in FSessoes do
    if LSessao.TokenHash = AHash then
      Exit(LSessao.Clonar);
  Result := nil;
end;

function TSessaoRepositoryFake.Revogar(AId: Integer): Boolean;
var
  LSessao: TSessao;
begin
  for LSessao in FSessoes do
    if (LSessao.Id = AId) and not LSessao.Revogada then
    begin
      LSessao.Revogada := True;
      Exit(True);
    end;
  Result := False;
end;

procedure TSessaoRepositoryFake.RevogarFamilia(const AFamilia: string);
var
  LSessao: TSessao;
begin
  for LSessao in FSessoes do
    if LSessao.Familia = AFamilia then
      LSessao.Revogada := True;
end;

end.
