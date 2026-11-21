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
  Repository.Pedido;

type
  TClienteRepositoryFake = class(TInterfacedObject, IClienteRepository)
  private
    FClientes: TObjectList<TCliente>;
    FProximoId: Integer;
    function Localizar(AId: Integer): TCliente;
  public
    constructor Create;
    destructor Destroy; override;
    function Adicionar(const ANome, ADocumento: string; AAtivo: Boolean = True): Integer;
    function Obter(AId: Integer): TCliente; // sem cópia, para asserts

    function Listar(const APaginacao: TPaginacao; out ATotal: Integer): TObjectList<TCliente>;
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
    function Localizar(AId: Integer): TProduto;
  public
    constructor Create;
    destructor Destroy; override;
    function Adicionar(const ADescricao: string; APreco: Currency; AEstoque: Integer;
      AAtivo: Boolean = True): Integer;
    function Obter(AId: Integer): TProduto;

    function Listar(const APaginacao: TPaginacao; out ATotal: Integer): TObjectList<TProduto>;
    function BuscarPorId(AId: Integer): TProduto;
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

    function Listar(const APaginacao: TPaginacao; AClienteId: Integer; out ATotal: Integer): TObjectList<TPedido>;
    function BuscarPorId(AId: Integer): TPedido;
    procedure Inserir(APedido: TPedido);
    procedure Cancelar(APedido: TPedido);
  end;

function ClonarCliente(AOrigem: TCliente): TCliente;
function ClonarProduto(AOrigem: TProduto): TProduto;
function ClonarPedido(AOrigem: TPedido): TPedido;

implementation

function ClonarCliente(AOrigem: TCliente): TCliente;
begin
  Result := TCliente.Create;
  Result.Id := AOrigem.Id;
  Result.Nome := AOrigem.Nome;
  Result.Documento := AOrigem.Documento;
  Result.Email := AOrigem.Email;
  Result.Telefone := AOrigem.Telefone;
  Result.Ativo := AOrigem.Ativo;
end;

function ClonarProduto(AOrigem: TProduto): TProduto;
begin
  Result := TProduto.Create;
  Result.Id := AOrigem.Id;
  Result.Descricao := AOrigem.Descricao;
  Result.Preco := AOrigem.Preco;
  Result.Estoque := AOrigem.Estoque;
  Result.Ativo := AOrigem.Ativo;
end;

function ClonarPedido(AOrigem: TPedido): TPedido;
var
  LItem, LNovo: TPedidoItem;
begin
  Result := TPedido.Create;
  Result.Id := AOrigem.Id;
  Result.ClienteId := AOrigem.ClienteId;
  Result.NomeCliente := AOrigem.NomeCliente;
  Result.Data := AOrigem.Data;
  Result.Status := AOrigem.Status;
  Result.ValorTotal := AOrigem.ValorTotal;
  for LItem in AOrigem.Itens do
  begin
    LNovo := Result.AdicionarItem(LItem.ProdutoId, LItem.Quantidade);
    LNovo.Id := LItem.Id;
    LNovo.DescricaoProduto := LItem.DescricaoProduto;
    LNovo.PrecoUnitario := LItem.PrecoUnitario;
    LNovo.ValorTotal := LItem.ValorTotal;
  end;
end;

{ TClienteRepositoryFake }

constructor TClienteRepositoryFake.Create;
begin
  inherited Create;
  FClientes := TObjectList<TCliente>.Create(True);
  FProximoId := 1;
end;

destructor TClienteRepositoryFake.Destroy;
begin
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

function TClienteRepositoryFake.Listar(const APaginacao: TPaginacao; out ATotal: Integer): TObjectList<TCliente>;
var
  LCliente: TCliente;
begin
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

procedure TClienteRepositoryFake.Inserir(ACliente: TCliente);
begin
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

function TProdutoRepositoryFake.Listar(const APaginacao: TPaginacao; out ATotal: Integer): TObjectList<TProduto>;
var
  LProduto: TProduto;
begin
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
  out ATotal: Integer): TObjectList<TPedido>;
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

procedure TPedidoRepositoryFake.Inserir(APedido: TPedido);
begin
  APedido.Id := FProximoId;
  Inc(FProximoId);
  FPedidos.Add(ClonarPedido(APedido));
end;

procedure TPedidoRepositoryFake.Cancelar(APedido: TPedido);
begin
  Localizar(APedido.Id).Status := spCancelado;
  Inc(FCancelamentos);
end;

end.
