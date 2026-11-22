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
    function PedidoDoApp: TPedido;
    function ServiceComRelogio: IPedidoService;
    procedure VerificarRecusa(APedido: TPedido; AExcecao: ExceptClass; const AMensagem: string);
    function PedidoGravado: Integer;
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
    [Test]
    procedure PedidoDoAppGuardaVendedorLocalEOrigem;
    [Test]
    procedure MesmoUuidNaoDuplica;
    [Test]
    procedure CorridaNoUuidDevolveOExistente;
    [Test]
    procedure UuidMalformadoRecusado;
    [Test]
    procedure DataForaDoIntervaloRecusada;
    [Test]
    procedure DataDoAppDentroDoIntervaloMantida;
    [Test]
    procedure AssinaturaQueNaoEhPngRecusada;
    [Test]
    procedure AssinaturaGrandeRecusada;
    [Test]
    procedure ObservacaoLongaRecusada;
    [Test]
    procedure PedidoDoAppContinuaConferindoEstoque;
    [Test]
    procedure Faturar_PedidoAberto_GravaANota;
    [Test]
    procedure Faturar_PedidoCancelado_Conflito;
    [Test]
    procedure Faturar_DadosDaNotaInvalidos_RequisicaoInvalida;
    [Test]
    procedure Faturar_MesmaChave_NaoMudaNada;
    [Test]
    procedure Faturar_OutraChave_Conflito;
    [Test]
    procedure Cancelar_PedidoFaturado_Conflito;
    [Test]
    procedure RemoverFaturamento_Faturado_Limpa;
    [Test]
    procedure RemoverFaturamento_NaoFaturado_SemErro;
  end;

implementation

uses
  System.DateUtils,
  Repository.Relogio,
  Infra.Excecoes;

const
  UUID_PEDIDO = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';
  AGORA_TESTE: TDateTime = 46348.5; // 22/11/2026 12:00

function Png(ATamanho: Integer): TBytes;
begin
  SetLength(Result, ATamanho);
  FillChar(Result[0], ATamanho, 0);
  Result[0] := $89; Result[1] := $50; Result[2] := $4E; Result[3] := $47;
  Result[4] := $0D; Result[5] := $0A; Result[6] := $1A; Result[7] := $0A;
end;

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

function TTestsPedidoService.PedidoDoApp: TPedido;
begin
  Result := NovoPedido(FClienteId);
  Result.Uuid := UUID_PEDIDO;
  Result.UsuarioId := 2;
  Result.AdicionarItem(FTecladoId, 1);
end;

function TTestsPedidoService.ServiceComRelogio: IPedidoService;
begin
  Result := TPedidoService.Create(FClientesIntf, FProdutosIntf, FPedidosIntf,
    TRelogioFake.Create(AGORA_TESTE));
end;

procedure TTestsPedidoService.VerificarRecusa(APedido: TPedido; AExcecao: ExceptClass;
  const AMensagem: string);
var
  LService: IPedidoService;
  LJaExistia: Boolean;
begin
  LService := ServiceComRelogio;
  try
    Assert.WillRaiseWithMessage(
      procedure
      begin
        LService.Criar(APedido, LJaExistia);
      end,
      AExcecao, AMensagem);
    Assert.AreEqual(0, FPedidos.Quantidade, 'nada deveria ter sido gravado');
  finally
    APedido.Free;
  end;
end;

procedure TTestsPedidoService.PedidoDoAppGuardaVendedorLocalEOrigem;
var
  LPedido: TPedido;
  LJaExistia: Boolean;
  LGravado: TPedido;
begin
  LPedido := PedidoDoApp;
  try
    LPedido.DefinirLocalizacao(-23.55, -46.63, 8);
    LPedido.Observacao := 'Entregar pela manhã';
    FService.Criar(LPedido, LJaExistia);

    Assert.IsFalse(LJaExistia);
    LGravado := FPedidos.Obter(LPedido.Id);
    Assert.AreEqual(2, LGravado.UsuarioId);
    Assert.IsTrue(LGravado.Origem = opApp);
    Assert.IsTrue(LGravado.TemLocalizacao);
    Assert.AreEqual(8.0, LGravado.Precisao, 0.001);
    Assert.AreEqual('Entregar pela manhã', LGravado.Observacao);
    Assert.AreEqual(UUID_PEDIDO, LGravado.Uuid);
  finally
    LPedido.Free;
  end;
end;

procedure TTestsPedidoService.MesmoUuidNaoDuplica;
var
  P1, P2: TPedido;
  LJaExistia: Boolean;
begin
  P1 := PedidoDoApp;
  P2 := PedidoDoApp;
  try
    FService.Criar(P1, LJaExistia);
    FService.Criar(P2, LJaExistia);
    Assert.IsTrue(LJaExistia);
    Assert.AreEqual(P1.Id, P2.Id);
    Assert.AreEqual(1, FPedidos.Quantidade);
    Assert.AreEqual<Currency>(P1.ValorTotal, P2.ValorTotal);
  finally
    P1.Free;
    P2.Free;
  end;
end;

procedure TTestsPedidoService.CorridaNoUuidDevolveOExistente;
var
  LPedido: TPedido;
  LJaExistia: Boolean;
begin
  // outra requisição com o mesmo UUID grava entre a consulta e o insert
  FPedidos.SimularCorridaDeUuid := True;
  LPedido := PedidoDoApp;
  try
    FService.Criar(LPedido, LJaExistia);
    Assert.IsTrue(LJaExistia);
    Assert.AreEqual(1, FPedidos.Quantidade);
    Assert.IsTrue(LPedido.Id > 0);
  finally
    LPedido.Free;
  end;
end;

procedure TTestsPedidoService.UuidMalformadoRecusado;
var
  LPedido: TPedido;
begin
  LPedido := PedidoDoApp;
  LPedido.Uuid := 'nao-e-uuid';
  VerificarRecusa(LPedido, ERequisicaoInvalida, '"uuid" inválido.');
end;

procedure TTestsPedidoService.DataForaDoIntervaloRecusada;
var
  LPedido: TPedido;
begin
  LPedido := PedidoDoApp;
  LPedido.Data := IncDay(AGORA_TESTE, -31);
  VerificarRecusa(LPedido, ERegraNegocio, 'Data do pedido fora do intervalo aceito.');

  LPedido := PedidoDoApp;
  LPedido.Data := IncMinute(AGORA_TESTE, 11);
  VerificarRecusa(LPedido, ERegraNegocio, 'Data do pedido fora do intervalo aceito.');
end;

procedure TTestsPedidoService.DataDoAppDentroDoIntervaloMantida;
var
  LPedido: TPedido;
  LJaExistia: Boolean;
begin
  LPedido := PedidoDoApp;
  try
    // feito offline ontem, sincronizado hoje: vale a hora do aparelho
    LPedido.Data := IncDay(AGORA_TESTE, -1);
    ServiceComRelogio.Criar(LPedido, LJaExistia);
    Assert.AreEqual(IncDay(AGORA_TESTE, -1), FPedidos.Obter(LPedido.Id).Data);
  finally
    LPedido.Free;
  end;
end;

procedure TTestsPedidoService.AssinaturaQueNaoEhPngRecusada;
var
  LPedido: TPedido;
begin
  LPedido := PedidoDoApp;
  LPedido.Assinatura := TEncoding.UTF8.GetBytes('não sou png');
  VerificarRecusa(LPedido, ERequisicaoInvalida, 'A assinatura deve ser PNG.');
end;

procedure TTestsPedidoService.AssinaturaGrandeRecusada;
var
  LPedido: TPedido;
begin
  LPedido := PedidoDoApp;
  LPedido.Assinatura := Png(204801);
  VerificarRecusa(LPedido, ERequisicaoInvalida, 'Assinatura maior que 200 KB.');
end;

procedure TTestsPedidoService.ObservacaoLongaRecusada;
var
  LPedido: TPedido;
begin
  LPedido := PedidoDoApp;
  LPedido.Observacao := StringOfChar('x', 501);
  VerificarRecusa(LPedido, ERegraNegocio, 'A observação deve ter no máximo 500 caracteres.');
end;

procedure TTestsPedidoService.PedidoDoAppContinuaConferindoEstoque;
var
  LPedido: TPedido;
begin
  LPedido := PedidoDoApp;
  LPedido.Itens[0].Quantidade := 999;
  VerificarRecusa(LPedido, ERegraNegocio, 'Estoque insuficiente para "Teclado" (disponível: 10).');
end;

const
  CHAVE_A = '35261111222333000181550010000001231000001234';
  CHAVE_B = '35261111222333000181550010000001241000001240';
  AUTORIZADA_EM: TDateTime = 46348.6;

function TTestsPedidoService.PedidoGravado: Integer;
var
  LPedido: TPedido;
begin
  LPedido := NovoPedido(FClienteId);
  try
    LPedido.AdicionarItem(FTecladoId, 1);
    FService.Criar(LPedido);
    Result := LPedido.Id;
  finally
    LPedido.Free;
  end;
end;

procedure TTestsPedidoService.Faturar_PedidoAberto_GravaANota;
var
  LId: Integer;
begin
  LId := PedidoGravado;
  FService.Faturar(LId, 123, 1, CHAVE_A, AUTORIZADA_EM).Free;

  Assert.IsTrue(FPedidos.Obter(LId).Faturado);
  Assert.AreEqual(123, FPedidos.Obter(LId).NotaNumero);
  Assert.AreEqual(1, FPedidos.Obter(LId).NotaSerie);
  Assert.AreEqual(CHAVE_A, FPedidos.Obter(LId).NotaChave);
  Assert.AreEqual(AUTORIZADA_EM, FPedidos.Obter(LId).NotaAutorizadaEm);
end;

procedure TTestsPedidoService.Faturar_PedidoCancelado_Conflito;
var
  LId: Integer;
begin
  LId := PedidoGravado;
  FService.Cancelar(LId).Free;
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.Faturar(LId, 123, 1, CHAVE_A, AUTORIZADA_EM).Free;
    end,
    EConflito, 'Pedido cancelado não pode ser faturado.');
end;

procedure TTestsPedidoService.Faturar_DadosDaNotaInvalidos_RequisicaoInvalida;
var
  LId: Integer;
begin
  LId := PedidoGravado;
  Assert.WillRaise(procedure begin FService.Faturar(LId, 0, 1, CHAVE_A, AUTORIZADA_EM).Free; end,
    ERequisicaoInvalida, 'número zero');
  Assert.WillRaise(procedure begin FService.Faturar(LId, 123, -1, CHAVE_A, AUTORIZADA_EM).Free; end,
    ERequisicaoInvalida, 'série negativa');
  Assert.WillRaise(procedure begin FService.Faturar(LId, 123, 1, Copy(CHAVE_A, 1, 43), AUTORIZADA_EM).Free; end,
    ERequisicaoInvalida, 'chave com 43 dígitos');
  Assert.WillRaise(procedure begin FService.Faturar(LId, 123, 1, Copy(CHAVE_A, 1, 43) + 'X', AUTORIZADA_EM).Free; end,
    ERequisicaoInvalida, 'chave com letra');
  Assert.IsFalse(FPedidos.Obter(LId).Faturado);
end;

procedure TTestsPedidoService.Faturar_MesmaChave_NaoMudaNada;
var
  LId: Integer;
begin
  LId := PedidoGravado;
  FService.Faturar(LId, 123, 1, CHAVE_A, AUTORIZADA_EM).Free;
  // o emissor reenvia depois de não receber a resposta
  FService.Faturar(LId, 123, 1, CHAVE_A, AUTORIZADA_EM).Free;
  Assert.AreEqual(1, FPedidos.Faturamentos);
end;

procedure TTestsPedidoService.Faturar_OutraChave_Conflito;
var
  LId: Integer;
begin
  LId := PedidoGravado;
  FService.Faturar(LId, 123, 1, CHAVE_A, AUTORIZADA_EM).Free;
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.Faturar(LId, 124, 1, CHAVE_B, AUTORIZADA_EM).Free;
    end,
    EConflito, 'Pedido já faturado na NF-e 123.');
  Assert.AreEqual(CHAVE_A, FPedidos.Obter(LId).NotaChave);
end;

procedure TTestsPedidoService.Cancelar_PedidoFaturado_Conflito;
var
  LId: Integer;
begin
  LId := PedidoGravado;
  FService.Faturar(LId, 123, 1, CHAVE_A, AUTORIZADA_EM).Free;
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.Cancelar(LId).Free;
    end,
    EConflito, 'Pedido faturado na NF-e 123; cancele a nota primeiro.');
  Assert.AreEqual(0, FPedidos.Cancelamentos);
end;

procedure TTestsPedidoService.RemoverFaturamento_Faturado_Limpa;
var
  LId: Integer;
begin
  LId := PedidoGravado;
  FService.Faturar(LId, 123, 1, CHAVE_A, AUTORIZADA_EM).Free;
  FService.RemoverFaturamento(LId).Free; // NF-e cancelada no emissor
  Assert.IsFalse(FPedidos.Obter(LId).Faturado);
  Assert.AreEqual('', FPedidos.Obter(LId).NotaChave);
  FService.Cancelar(LId).Free; // agora pode cancelar
end;

procedure TTestsPedidoService.RemoverFaturamento_NaoFaturado_SemErro;
var
  LId: Integer;
begin
  LId := PedidoGravado;
  FService.RemoverFaturamento(LId).Free;
  Assert.IsFalse(FPedidos.Obter(LId).Faturado);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsPedidoService);

end.
