unit Tests.Service.Pedido;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Model.Pedido,
  Repository.Cliente,
  Repository.Produto,
  Repository.Pedido,
  Service.Pedido,
  Tests.Fakes;

type
  [TestFixture]
  TTestsPedidoService = class
  private
    FClientes: TClienteRepositoryFake;
    FProdutos: TProdutoRepositoryFake;
    FPedidos: TPedidoRepositoryFake;
    FClientesIntf: IClienteRepository;
    FProdutosIntf: IProdutoRepository;
    FPedidosIntf: IPedidoRepository;
    FService: IPedidoService;
    FClienteId: Integer;
    FTecladoId: Integer;
    FMouseId: Integer;
    function NovoPedido(AClienteId: Integer): TPedido;
    procedure VerificarCriacaoFalha(APedido: TPedido; AExcecao: ExceptClass);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Criar_Valido_CopiaPrecosECalculaTotais;
    [Test]
    procedure Criar_Valido_GravaComStatusAberto;
    [Test]
    procedure Criar_SemCliente_LevantaRequisicaoInvalida;
    [Test]
    procedure Criar_ClienteInexistente_LevantaRegraNegocio;
    [Test]
    procedure Criar_ClienteInativo_LevantaRegraNegocio;
    [Test]
    procedure Criar_SemItens_LevantaRegraNegocio;
    [Test]
    procedure Criar_QuantidadeZero_LevantaRegraNegocio;
    [Test]
    procedure Criar_ProdutoRepetido_LevantaRegraNegocio;
    [Test]
    procedure Criar_ProdutoInexistente_LevantaRegraNegocio;
    [Test]
    procedure Criar_ProdutoInativo_LevantaRegraNegocio;
    [Test]
    procedure Criar_EstoqueInsuficiente_LevantaRegraNegocioENaoGrava;
    [Test]
    procedure Cancelar_PedidoAberto_MudaStatus;
    [Test]
    procedure Cancelar_PedidoJaCancelado_LevantaRegraNegocio;
    [Test]
    procedure Cancelar_Inexistente_LevantaNaoEncontrado;
  end;

implementation

uses
  Infra.Excecoes;

procedure TTestsPedidoService.Setup;
begin
  FClientes := TClienteRepositoryFake.Create;
  FProdutos := TProdutoRepositoryFake.Create;
  FPedidos := TPedidoRepositoryFake.Create;
  FClientesIntf := FClientes;
  FProdutosIntf := FProdutos;
  FPedidosIntf := FPedidos;
  FService := TPedidoService.Create(FClientesIntf, FProdutosIntf, FPedidosIntf);

  FClienteId := FClientes.Adicionar('Maria', '52998224725');
  FTecladoId := FProdutos.Adicionar('Teclado', 349.90, 10);
  FMouseId := FProdutos.Adicionar('Mouse', 129.90, 2);
end;

procedure TTestsPedidoService.TearDown;
begin
  FService := nil;
  FClientesIntf := nil;
  FProdutosIntf := nil;
  FPedidosIntf := nil;
end;

function TTestsPedidoService.NovoPedido(AClienteId: Integer): TPedido;
begin
  Result := TPedido.Create;
  Result.ClienteId := AClienteId;
end;

procedure TTestsPedidoService.VerificarCriacaoFalha(APedido: TPedido; AExcecao: ExceptClass);
begin
  try
    Assert.WillRaise(
      procedure
      begin
        FService.Criar(APedido);
      end,
      AExcecao);
  finally
    APedido.Free;
  end;
end;

procedure TTestsPedidoService.Criar_Valido_CopiaPrecosECalculaTotais;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  try
    LPedido.AdicionarItem(FTecladoId, 2);
    LPedido.AdicionarItem(FMouseId, 1);

    FService.Criar(LPedido);

    Assert.AreEqual<Currency>(349.90, LPedido.Itens[0].PrecoUnitario);
    Assert.AreEqual<Currency>(699.80, LPedido.Itens[0].ValorTotal);
    Assert.AreEqual<Currency>(129.90, LPedido.Itens[1].ValorTotal);
    Assert.AreEqual<Currency>(829.70, LPedido.ValorTotal);
    Assert.AreEqual('Teclado', LPedido.Itens[0].DescricaoProduto);
    Assert.AreEqual('Maria', LPedido.NomeCliente);
  finally
    LPedido.Free;
  end;
end;

procedure TTestsPedidoService.Criar_Valido_GravaComStatusAberto;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  try
    LPedido.AdicionarItem(FTecladoId, 1);
    FService.Criar(LPedido);

    Assert.IsTrue(LPedido.Id > 0);
    Assert.AreEqual(1, FPedidos.Quantidade);
    Assert.IsTrue(FPedidos.Obter(LPedido.Id).Status = spAberto);
  finally
    LPedido.Free;
  end;
end;

procedure TTestsPedidoService.Criar_SemCliente_LevantaRequisicaoInvalida;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(0);
  LPedido.AdicionarItem(FTecladoId, 1);
  VerificarCriacaoFalha(LPedido, ERequisicaoInvalida);
end;

procedure TTestsPedidoService.Criar_ClienteInexistente_LevantaRegraNegocio;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(999);
  LPedido.AdicionarItem(FTecladoId, 1);
  VerificarCriacaoFalha(LPedido, ERegraNegocio);
end;

procedure TTestsPedidoService.Criar_ClienteInativo_LevantaRegraNegocio;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClientes.Adicionar('Inativo', '12345678909', False));
  LPedido.AdicionarItem(FTecladoId, 1);
  VerificarCriacaoFalha(LPedido, ERegraNegocio);
end;

procedure TTestsPedidoService.Criar_SemItens_LevantaRegraNegocio;
begin
  VerificarCriacaoFalha(NovoPedido(FClienteId), ERegraNegocio);
end;

procedure TTestsPedidoService.Criar_QuantidadeZero_LevantaRegraNegocio;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  LPedido.AdicionarItem(FTecladoId, 0);
  VerificarCriacaoFalha(LPedido, ERegraNegocio);
end;

procedure TTestsPedidoService.Criar_ProdutoRepetido_LevantaRegraNegocio;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  LPedido.AdicionarItem(FTecladoId, 1);
  LPedido.AdicionarItem(FTecladoId, 2);
  VerificarCriacaoFalha(LPedido, ERegraNegocio);
end;

procedure TTestsPedidoService.Criar_ProdutoInexistente_LevantaRegraNegocio;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  LPedido.AdicionarItem(999, 1);
  VerificarCriacaoFalha(LPedido, ERegraNegocio);
end;

procedure TTestsPedidoService.Criar_ProdutoInativo_LevantaRegraNegocio;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  LPedido.AdicionarItem(FProdutos.Adicionar('Fora de linha', 10, 100, False), 1);
  VerificarCriacaoFalha(LPedido, ERegraNegocio);
end;

procedure TTestsPedidoService.Criar_EstoqueInsuficiente_LevantaRegraNegocioENaoGrava;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  LPedido.AdicionarItem(FMouseId, 3); // só tem 2
  VerificarCriacaoFalha(LPedido, ERegraNegocio);
  Assert.AreEqual(0, FPedidos.Quantidade);
end;

procedure TTestsPedidoService.Cancelar_PedidoAberto_MudaStatus;
var
  LPedido, LCancelado: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  try
    LPedido.AdicionarItem(FTecladoId, 1);
    FService.Criar(LPedido);

    LCancelado := FService.Cancelar(LPedido.Id);
    try
      Assert.IsTrue(LCancelado.Status = spCancelado);
      Assert.AreEqual(1, FPedidos.Cancelamentos);
    finally
      LCancelado.Free;
    end;
  finally
    LPedido.Free;
  end;
end;

procedure TTestsPedidoService.Cancelar_PedidoJaCancelado_LevantaRegraNegocio;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  try
    LPedido.AdicionarItem(FTecladoId, 1);
    FService.Criar(LPedido);
    FService.Cancelar(LPedido.Id).Free;

    Assert.WillRaise(
      procedure
      begin
        FService.Cancelar(LPedido.Id).Free;
      end,
      ERegraNegocio);
    Assert.AreEqual(1, FPedidos.Cancelamentos);
  finally
    LPedido.Free;
  end;
end;

procedure TTestsPedidoService.Cancelar_Inexistente_LevantaNaoEncontrado;
begin
  Assert.WillRaise(
    procedure
    begin
      FService.Cancelar(999).Free;
    end,
    ENaoEncontrado);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsPedidoService);

end.
