unit Tests.Service.Visita;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Model.Visita,
  Repository.Cliente,
  Repository.Visita,
  Service.Visita,
  Tests.Fakes;

type
  [TestFixture]
  TTestsVisitaService = class
  private
    FClientes: TClienteRepositoryFake;
    FVisitas: TVisitaRepositoryFake;
    FClientesIntf: IClienteRepository;
    FVisitasIntf: IVisitaRepository;
    FService: IVisitaService;
    FClienteId: Integer;
    function NovaVisita: TVisita;
    procedure VerificarRecusa(AVisita: TVisita; AExcecao: ExceptClass; const AMensagem: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Criar_Valida_GravaComVendedorELocal;
    [Test]
    procedure Criar_MesmoUuid_DevolveAExistente;
    [Test]
    procedure Criar_CorridaNoUuid_DevolveAExistente;
    [Test]
    procedure Criar_SemUuid_Recusada;
    [Test]
    procedure Criar_ClienteInativo_Recusada;
    [Test]
    procedure Criar_OutroSemObservacao_Recusada;
    [Test]
    procedure Criar_DataForaDoIntervalo_Recusada;
    [Test]
    procedure MotivoDesconhecido_RequisicaoInvalida;
  end;

implementation

uses
  System.DateUtils,
  Infra.Excecoes;

const
  UUID_VISITA = '7c0e3f2a-1b4d-4c6e-9a8b-2d3f4e5a6b7c';
  AGORA_TESTE: TDateTime = 46348.5;

procedure TTestsVisitaService.Setup;
begin
  FClientes := TClienteRepositoryFake.Create;
  FVisitas := TVisitaRepositoryFake.Create;
  FClientesIntf := FClientes;
  FVisitasIntf := FVisitas;
  FService := TVisitaService.Create(FVisitasIntf, FClientesIntf, TRelogioFake.Create(AGORA_TESTE));
  FClienteId := FClientes.Adicionar('Maria', '52998224725');
end;

procedure TTestsVisitaService.TearDown;
begin
  FService := nil;
  FClientesIntf := nil;
  FVisitasIntf := nil;
end;

function TTestsVisitaService.NovaVisita: TVisita;
begin
  Result := TVisita.Create;
  Result.Uuid := UUID_VISITA;
  Result.ClienteId := FClienteId;
  Result.UsuarioId := 2;
  Result.Data := IncHour(AGORA_TESTE, -1);
  Result.Motivo := mvAusente;
end;

procedure TTestsVisitaService.VerificarRecusa(AVisita: TVisita; AExcecao: ExceptClass; const AMensagem: string);
var
  LJaExistia: Boolean;
begin
  try
    Assert.WillRaiseWithMessage(
      procedure
      begin
        FService.Criar(AVisita, LJaExistia);
      end,
      AExcecao, AMensagem);
    Assert.AreEqual(0, FVisitas.Quantidade, 'nada deveria ter sido gravado');
  finally
    AVisita.Free;
  end;
end;

procedure TTestsVisitaService.Criar_Valida_GravaComVendedorELocal;
var
  LVisita: TVisita;
  LJaExistia: Boolean;
begin
  LVisita := NovaVisita;
  try
    LVisita.DefinirLocalizacao(-23.56, -46.65, 12);
    FService.Criar(LVisita, LJaExistia);
    Assert.IsFalse(LJaExistia);
    Assert.IsTrue(LVisita.Id > 0);
    Assert.AreEqual(2, FVisitas.Obter(LVisita.Id).UsuarioId);
    Assert.IsTrue(FVisitas.Obter(LVisita.Id).TemLocalizacao);
    Assert.AreEqual('Maria', LVisita.NomeCliente);
  finally
    LVisita.Free;
  end;
end;

procedure TTestsVisitaService.Criar_MesmoUuid_DevolveAExistente;
var
  V1, V2: TVisita;
  LJaExistia: Boolean;
begin
  V1 := NovaVisita;
  V2 := NovaVisita;
  try
    FService.Criar(V1, LJaExistia);
    FService.Criar(V2, LJaExistia);
    Assert.IsTrue(LJaExistia);
    Assert.AreEqual(V1.Id, V2.Id);
    Assert.AreEqual(1, FVisitas.Quantidade);
  finally
    V1.Free;
    V2.Free;
  end;
end;

procedure TTestsVisitaService.Criar_CorridaNoUuid_DevolveAExistente;
var
  LVisita: TVisita;
  LJaExistia: Boolean;
begin
  FVisitas.SimularCorridaDeUuid := True;
  LVisita := NovaVisita;
  try
    FService.Criar(LVisita, LJaExistia);
    Assert.IsTrue(LJaExistia);
    Assert.AreEqual(1, FVisitas.Quantidade);
  finally
    LVisita.Free;
  end;
end;

procedure TTestsVisitaService.Criar_SemUuid_Recusada;
var
  LVisita: TVisita;
begin
  LVisita := NovaVisita;
  LVisita.Uuid := '';
  VerificarRecusa(LVisita, ERequisicaoInvalida, 'Informe o "uuid" da visita.');
end;

procedure TTestsVisitaService.Criar_ClienteInativo_Recusada;
var
  LVisita: TVisita;
begin
  LVisita := NovaVisita;
  LVisita.ClienteId := FClientes.Adicionar('Inativo', '12345678909', False);
  VerificarRecusa(LVisita, ERegraNegocio, Format('Cliente %d não encontrado ou inativo.', [LVisita.ClienteId]));
end;

procedure TTestsVisitaService.Criar_OutroSemObservacao_Recusada;
var
  LVisita: TVisita;
begin
  LVisita := NovaVisita;
  LVisita.Motivo := mvOutro;
  LVisita.Observacao := '   ';
  VerificarRecusa(LVisita, ERegraNegocio, 'Descreva o motivo da visita.');
end;

procedure TTestsVisitaService.Criar_DataForaDoIntervalo_Recusada;
var
  LVisita: TVisita;
begin
  LVisita := NovaVisita;
  LVisita.Data := IncDay(AGORA_TESTE, -31);
  VerificarRecusa(LVisita, ERegraNegocio, 'Data da visita fora do intervalo aceito.');
end;

procedure TTestsVisitaService.MotivoDesconhecido_RequisicaoInvalida;
begin
  Assert.AreEqual('SEM_ESTOQUE', mvSemEstoque.ToString);
  Assert.IsTrue(TMotivoVisita.DeTexto('preco') = mvPreco);
  Assert.WillRaise(
    procedure
    begin
      TMotivoVisita.DeTexto('FERIADO');
    end,
    ERequisicaoInvalida);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsVisitaService);

end.
