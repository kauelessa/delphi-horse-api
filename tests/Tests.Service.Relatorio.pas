unit Tests.Service.Relatorio;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Model.Relatorio,
  Repository.Relatorio,
  Repository.Pedido,
  Infra.Relatorio,
  Service.Relatorio,
  Tests.Fakes;

type
  TRelatorioRepositoryFake = class(TInterfacedObject, IRelatorioRepository)
  public
    UltimoUsuario: Integer;
    function PedidosPorPeriodo(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelPedido>;
    function VendasPorProduto(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelVendaProduto>;
    function Visitas(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelVisita>;
    function NomeDoUsuario(AUsuarioId: Integer): string;
  end;

  // grava o que chegou para desenhar e devolve um "PDF" de mentira
  TGeradorFake = class(TInterfacedObject, IGeradorRelatorio)
  public
    class var UltimoPedidos: TRelPedidos;
    class var UltimoEspelhoId: Integer;
    class var UltimoEspelhoTemAssinatura: Boolean;
    function PedidosPorPeriodo(const ADados: TRelPedidos): TBytes;
    function EspelhoPedido(const ADados: TRelEspelho): TBytes;
    function VendasPorProduto(const ADados: TRelVendasProduto): TBytes;
    function Visitas(const ADados: TRelVisitas): TBytes;
  end;

  // só o Fortes "instalado", como numa compilação sem a diretiva FASTREPORT
  TExecutorFake = class(TInterfacedObject, IExecutorRelatorio)
  public
    UltimoMotor: TMotorRelatorio;
    function Executar(AMotor: TMotorRelatorio; const AGerar: TFunc<IGeradorRelatorio, TBytes>): TBytes;
  end;

  [TestFixture]
  TTestsRelatorioService = class
  private
    FRepo: TRelatorioRepositoryFake;
    FRepoIntf: IRelatorioRepository;
    FPedidos: TPedidoRepositoryFake;
    FPedidosIntf: IPedidoRepository;
    FExecutor: TExecutorFake;
    FExecutorIntf: IExecutorRelatorio;
    FService: IRelatorioService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure MotorDesconhecido_RequisicaoInvalida;
    [Test]
    procedure PeriodoInvertido_RequisicaoInvalida;
    [Test]
    procedure PeriodoMaiorQueUmAno_RequisicaoInvalida;
    [Test]
    procedure FastReportNaoDisponivel_NaoImplementado;
    [Test]
    procedure PedidosPorPeriodo_EntregaAsLinhasDoRepositorioAoGerador;
    [Test]
    procedure Espelho_PedidoInexistente_NaoEncontrado;
    [Test]
    procedure Espelho_LevaPedidoEAssinatura;
    [Test]
    procedure DataSemFuso_ValeComoHoraLocal;
    [Test]
    procedure DataComFuso_ConvertidaParaHoraLocal;
    [Test]
    procedure DataInvalida_Falso;
  end;

implementation

uses
  System.DateUtils,
  Model.Paginacao,
  Model.Pedido,
  Infra.Excecoes;

{ TRelatorioRepositoryFake }

function TRelatorioRepositoryFake.PedidosPorPeriodo(AInicio, AFim: TDateTime;
  AUsuarioId: Integer): TArray<TLinhaRelPedido>;
begin
  UltimoUsuario := AUsuarioId;
  SetLength(Result, 2);
  Result[0].Id := 10; Result[0].Cliente := 'Maria'; Result[0].Status := 'ABERTO'; Result[0].Valor := 100;
  Result[1].Id := 11; Result[1].Cliente := 'João'; Result[1].Status := 'CANCELADO'; Result[1].Valor := 50;
end;

function TRelatorioRepositoryFake.VendasPorProduto(AInicio, AFim: TDateTime;
  AUsuarioId: Integer): TArray<TLinhaRelVendaProduto>;
begin
  Result := nil;
end;

function TRelatorioRepositoryFake.Visitas(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelVisita>;
begin
  Result := nil;
end;

function TRelatorioRepositoryFake.NomeDoUsuario(AUsuarioId: Integer): string;
begin
  Result := 'Ana Vendedora';
end;

{ TGeradorFake }

function TGeradorFake.PedidosPorPeriodo(const ADados: TRelPedidos): TBytes;
begin
  UltimoPedidos := ADados;
  Result := TEncoding.ANSI.GetBytes('%PDF-fake');
end;

function TGeradorFake.EspelhoPedido(const ADados: TRelEspelho): TBytes;
begin
  UltimoEspelhoId := ADados.Pedido.Id;
  UltimoEspelhoTemAssinatura := Length(ADados.Assinatura) > 0;
  Result := TEncoding.ANSI.GetBytes('%PDF-fake');
end;

function TGeradorFake.VendasPorProduto(const ADados: TRelVendasProduto): TBytes;
begin
  Result := TEncoding.ANSI.GetBytes('%PDF-fake');
end;

function TGeradorFake.Visitas(const ADados: TRelVisitas): TBytes;
begin
  Result := TEncoding.ANSI.GetBytes('%PDF-fake');
end;

{ TExecutorFake }

function TExecutorFake.Executar(AMotor: TMotorRelatorio; const AGerar: TFunc<IGeradorRelatorio, TBytes>): TBytes;
begin
  UltimoMotor := AMotor;
  if AMotor <> mrFortes then
    raise ENaoImplementado.CreateFmt('%s não está disponível nesta compilação da API.', [AMotor.Nome]);
  Result := AGerar(TGeradorFake.Create);
end;

{ TTestsRelatorioService }

const
  INICIO: TDateTime = 46327; // 01/11/2026
  FIM: TDateTime = 46356;    // 30/11/2026

procedure TTestsRelatorioService.Setup;
begin
  FRepo := TRelatorioRepositoryFake.Create;
  FRepoIntf := FRepo;
  FPedidos := TPedidoRepositoryFake.Create;
  FPedidosIntf := FPedidos;
  FExecutor := TExecutorFake.Create;
  FExecutorIntf := FExecutor;
  FService := TRelatorioService.Create(FRepoIntf, FPedidosIntf, FExecutorIntf);
end;

procedure TTestsRelatorioService.TearDown;
begin
  FService := nil;
  FRepoIntf := nil;
  FPedidosIntf := nil;
  FExecutorIntf := nil;
end;

procedure TTestsRelatorioService.MotorDesconhecido_RequisicaoInvalida;
begin
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TMotorRelatorio.DeTexto('crystal');
    end,
    ERequisicaoInvalida, 'Motor de relatório desconhecido. Use fortes ou fastreport.');
  Assert.IsTrue(TMotorRelatorio.DeTexto('FastReport') = mrFastReport);
end;

procedure TTestsRelatorioService.PeriodoInvertido_RequisicaoInvalida;
begin
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.PedidosPorPeriodo(mrFortes, FIM, INICIO, 2);
    end,
    ERequisicaoInvalida, 'A data final deve ser igual ou posterior à inicial.');
end;

procedure TTestsRelatorioService.PeriodoMaiorQueUmAno_RequisicaoInvalida;
begin
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.VendasPorProduto(mrFortes, INICIO, IncDay(INICIO, 367), 2);
    end,
    ERequisicaoInvalida, 'O período deve ter no máximo 366 dias.');
end;

procedure TTestsRelatorioService.FastReportNaoDisponivel_NaoImplementado;
begin
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.PedidosPorPeriodo(mrFastReport, INICIO, FIM, 2);
    end,
    ENaoImplementado, 'FastReport não está disponível nesta compilação da API.');
end;

procedure TTestsRelatorioService.PedidosPorPeriodo_EntregaAsLinhasDoRepositorioAoGerador;
var
  LPdf: TBytes;
begin
  LPdf := FService.PedidosPorPeriodo(mrFortes, INICIO, FIM, 2);

  Assert.AreEqual(9, Length(LPdf));
  Assert.AreEqual(2, FRepo.UltimoUsuario);
  Assert.AreEqual(2, Length(TGeradorFake.UltimoPedidos.Linhas));
  Assert.AreEqual('Ana Vendedora', TGeradorFake.UltimoPedidos.Cabecalho.Vendedor);
  Assert.AreEqual(INICIO, TGeradorFake.UltimoPedidos.Cabecalho.Inicio);
  Assert.AreEqual<Currency>(100, TGeradorFake.UltimoPedidos.Total); // cancelado não soma
end;

procedure TTestsRelatorioService.Espelho_PedidoInexistente_NaoEncontrado;
begin
  Assert.WillRaise(
    procedure
    begin
      FService.EspelhoPedido(mrFortes, 999);
    end,
    ENaoEncontrado);
end;

procedure TTestsRelatorioService.Espelho_LevaPedidoEAssinatura;
var
  LPedido: TPedido;
begin
  LPedido := TPedido.Create;
  try
    LPedido.ClienteId := 1;
    LPedido.AdicionarItem(1, 1);
    LPedido.Assinatura := TBytes.Create($89, $50, $4E, $47);
    FPedidos.Inserir(LPedido);
  finally
    LPedido.Free;
  end;

  FService.EspelhoPedido(mrFortes, 1);
  Assert.AreEqual(1, TGeradorFake.UltimoEspelhoId);
  Assert.IsTrue(TGeradorFake.UltimoEspelhoTemAssinatura);
end;

procedure TTestsRelatorioService.DataSemFuso_ValeComoHoraLocal;
var
  LData: TDateTime;
begin
  // "2026-11-01" é o dia 1 de quem pediu, não meia-noite UTC convertida (31/10 21:00 no Brasil)
  Assert.IsTrue(LerDataISO('2026-11-01', LData));
  Assert.AreEqual(EncodeDate(2026, 11, 1), LData);
  Assert.IsTrue(LerDataISO('2026-11-01T08:30:00', LData));
  Assert.AreEqual(EncodeDateTime(2026, 11, 1, 8, 30, 0, 0), LData);
end;

procedure TTestsRelatorioService.DataComFuso_ConvertidaParaHoraLocal;
var
  LData: TDateTime;
begin
  Assert.IsTrue(LerDataISO('2026-11-01T12:00:00Z', LData));
  Assert.AreEqual(TTimeZone.Local.ToLocalTime(EncodeDateTime(2026, 11, 1, 12, 0, 0, 0)), LData);
end;

procedure TTestsRelatorioService.DataInvalida_Falso;
var
  LData: TDateTime;
begin
  Assert.IsFalse(LerDataISO('ontem', LData));
  Assert.IsFalse(LerDataISO('', LData));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsRelatorioService);

end.
