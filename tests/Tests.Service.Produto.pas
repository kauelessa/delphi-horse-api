unit Tests.Service.Produto;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Model.Produto,
  Repository.Produto,
  Service.Produto,
  Model.Paginacao,
  Tests.Fakes;

type
  [TestFixture]
  TTestsProdutoService = class
  private
    FRepositorio: TProdutoRepositoryFake;
    FRepositorioIntf: IProdutoRepository;
    FService: IProdutoService;
    function NovoProduto(const ADescricao: string; APreco: Currency; AEstoque: Integer): TProduto;
    procedure VerificarCriacaoFalha(AProduto: TProduto; AExcecao: ExceptClass);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Criar_DadosValidos_GravaEAtribuiId;
    [Test]
    procedure Listar_RepassaBuscaSemEspacosAoRepositorio;
    [Test]
    procedure Criar_SemDescricao_LevantaRequisicaoInvalida;
    [Test]
    procedure Criar_PrecoZero_LevantaRegraNegocio;
    [Test]
    procedure Criar_EstoqueNegativo_LevantaRegraNegocio;
    [Test]
    procedure Atualizar_AlteraPrecoEEstoque;
    [Test]
    procedure Excluir_Inexistente_LevantaNaoEncontrado;
    [Test]
    procedure Excluir_InativaProduto;
    [Test]
    procedure Criar_CodigoBarrasInvalido_LevantaRegraNegocio;
    [Test]
    procedure Criar_SemCodigoBarras_Aceita;
    [Test]
    procedure Criar_CodigoBarrasDeOutroProduto_LevantaRegraNegocio;
    [Test]
    procedure Atualizar_MantendoOProprioCodigo_Aceita;
    [Test]
    procedure BuscarPorCodigoBarras_Existente_DevolveProduto;
    [Test]
    procedure BuscarPorCodigoBarras_Inexistente_LevantaNaoEncontrado;
  end;

implementation

uses
  Infra.Excecoes;

procedure TTestsProdutoService.Setup;
begin
  FRepositorio := TProdutoRepositoryFake.Create;
  FRepositorioIntf := FRepositorio;
  FService := TProdutoService.Create(FRepositorioIntf);
end;

procedure TTestsProdutoService.TearDown;
begin
  FService := nil;
  FRepositorioIntf := nil;
  FRepositorio := nil;
end;

function TTestsProdutoService.NovoProduto(const ADescricao: string; APreco: Currency;
  AEstoque: Integer): TProduto;
begin
  Result := TProduto.Create;
  Result.Descricao := ADescricao;
  Result.Preco := APreco;
  Result.Estoque := AEstoque;
end;

procedure TTestsProdutoService.VerificarCriacaoFalha(AProduto: TProduto; AExcecao: ExceptClass);
begin
  try
    Assert.WillRaise(
      procedure
      begin
        FService.Criar(AProduto);
      end,
      AExcecao);
  finally
    AProduto.Free;
  end;
end;

procedure TTestsProdutoService.Criar_DadosValidos_GravaEAtribuiId;
var
  LProduto: TProduto;
begin
  LProduto := NovoProduto(' Teclado ', 349.90, 10);
  try
    FService.Criar(LProduto);
    Assert.IsTrue(LProduto.Id > 0);
    Assert.AreEqual('Teclado', FRepositorio.Obter(LProduto.Id).Descricao);
  finally
    LProduto.Free;
  end;
end;

procedure TTestsProdutoService.Criar_SemDescricao_LevantaRequisicaoInvalida;
begin
  VerificarCriacaoFalha(NovoProduto('', 10, 1), ERequisicaoInvalida);
end;

procedure TTestsProdutoService.Criar_PrecoZero_LevantaRegraNegocio;
begin
  VerificarCriacaoFalha(NovoProduto('Teclado', 0, 1), ERegraNegocio);
end;

procedure TTestsProdutoService.Criar_EstoqueNegativo_LevantaRegraNegocio;
begin
  VerificarCriacaoFalha(NovoProduto('Teclado', 10, -1), ERegraNegocio);
end;

procedure TTestsProdutoService.Atualizar_AlteraPrecoEEstoque;
var
  LProduto: TProduto;
begin
  LProduto := NovoProduto('Teclado', 399.90, 3);
  try
    LProduto.Id := FRepositorio.Adicionar('Teclado', 349.90, 10);
    FService.Atualizar(LProduto);

    Assert.AreEqual<Currency>(399.90, FRepositorio.Obter(LProduto.Id).Preco);
    Assert.AreEqual(3, FRepositorio.Obter(LProduto.Id).Estoque);
  finally
    LProduto.Free;
  end;
end;

procedure TTestsProdutoService.Excluir_Inexistente_LevantaNaoEncontrado;
begin
  Assert.WillRaise(
    procedure
    begin
      FService.Excluir(999);
    end,
    ENaoEncontrado);
end;

procedure TTestsProdutoService.Excluir_InativaProduto;
var
  LId: Integer;
begin
  LId := FRepositorio.Adicionar('Teclado', 349.90, 10);
  FService.Excluir(LId);
  Assert.IsFalse(FRepositorio.Obter(LId).Ativo);
end;

procedure TTestsProdutoService.Criar_CodigoBarrasInvalido_LevantaRegraNegocio;
var
  LProduto: TProduto;
begin
  LProduto := NovoProduto('Teclado', 10, 1);
  LProduto.CodigoBarras := '7891000315508';
  try
    Assert.WillRaiseWithMessage(
      procedure
      begin
        FService.Criar(LProduto);
      end,
      ERegraNegocio, 'Código de barras inválido.');
  finally
    LProduto.Free;
  end;
end;

procedure TTestsProdutoService.Criar_SemCodigoBarras_Aceita;
var
  LProduto: TProduto;
begin
  LProduto := NovoProduto('Teclado', 10, 1);
  LProduto.CodigoBarras := '  ';
  try
    FService.Criar(LProduto);
    Assert.AreEqual('', FRepositorio.Obter(LProduto.Id).CodigoBarras);
  finally
    LProduto.Free;
  end;
end;

procedure TTestsProdutoService.Criar_CodigoBarrasDeOutroProduto_LevantaRegraNegocio;
var
  LId: Integer;
  LProduto: TProduto;
begin
  LId := FRepositorio.Adicionar('Mouse', 129.90, 5);
  FRepositorio.Obter(LId).CodigoBarras := '7891000000021';
  LProduto := NovoProduto('Teclado', 10, 1);
  LProduto.CodigoBarras := ' 7891000000021 ';
  try
    Assert.WillRaiseWithMessage(
      procedure
      begin
        FService.Criar(LProduto);
      end,
      ERegraNegocio, Format('Código de barras já usado pelo produto %d.', [LId]));
  finally
    LProduto.Free;
  end;
end;

procedure TTestsProdutoService.Atualizar_MantendoOProprioCodigo_Aceita;
var
  LProduto: TProduto;
begin
  LProduto := NovoProduto('Mouse', 139.90, 5);
  try
    LProduto.Id := FRepositorio.Adicionar('Mouse', 129.90, 5);
    FRepositorio.Obter(LProduto.Id).CodigoBarras := '7891000000021';
    LProduto.CodigoBarras := '7891000000021';
    FService.Atualizar(LProduto);
    Assert.AreEqual<Currency>(139.90, FRepositorio.Obter(LProduto.Id).Preco);
  finally
    LProduto.Free;
  end;
end;

procedure TTestsProdutoService.BuscarPorCodigoBarras_Existente_DevolveProduto;
var
  LId: Integer;
  LProduto: TProduto;
begin
  LId := FRepositorio.Adicionar('Mouse', 129.90, 5);
  FRepositorio.Obter(LId).CodigoBarras := '7891000000021';
  LProduto := FService.BuscarPorCodigoBarras(' 7891000000021');
  try
    Assert.AreEqual(LId, LProduto.Id);
  finally
    LProduto.Free;
  end;
end;

procedure TTestsProdutoService.BuscarPorCodigoBarras_Inexistente_LevantaNaoEncontrado;
begin
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.BuscarPorCodigoBarras('7891000000014');
    end,
    ENaoEncontrado, 'Nenhum produto com o código 7891000000014.');
end;

procedure TTestsProdutoService.Listar_RepassaBuscaSemEspacosAoRepositorio;
var
  LTotal: Integer;
begin
  FService.Listar(TPaginacao.Criar(1, 20), '  maria  ', LTotal).Free;
  Assert.AreEqual('maria', FRepositorio.UltimaBusca);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsProdutoService);

end.
