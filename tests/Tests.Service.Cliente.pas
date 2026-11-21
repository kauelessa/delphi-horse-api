unit Tests.Service.Cliente;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Model.Cliente,
  Repository.Cliente,
  Service.Cliente,
  Tests.Fakes;

type
  [TestFixture]
  TTestsClienteService = class
  private
    FRepositorio: TClienteRepositoryFake;
    FRepositorioIntf: IClienteRepository; // mantém o fake vivo pela contagem de referência
    FService: IClienteService;
    function NovoCliente(const ANome, ADocumento: string; const AEmail: string = ''): TCliente;
    procedure VerificarCriacaoFalha(ACliente: TCliente; AExcecao: ExceptClass);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Criar_DadosValidos_GravaEAtribuiId;
    [Test]
    procedure Criar_NormalizaDocumentoNomeEEmail;
    [Test]
    procedure Criar_SemNome_LevantaRequisicaoInvalida;
    [Test]
    procedure Criar_SemDocumento_LevantaRequisicaoInvalida;
    [Test]
    procedure Criar_DocumentoInvalido_LevantaRegraNegocio;
    [Test]
    procedure Criar_DocumentoDuplicado_LevantaRegraNegocio;
    [Test]
    procedure Criar_DocumentoDeClienteInativo_LevantaRegraNegocio;
    [Test]
    procedure Criar_EmailInvalido_LevantaRegraNegocio;
    [Test]
    procedure Buscar_Inexistente_LevantaNaoEncontrado;
    [Test]
    procedure Atualizar_Inexistente_LevantaNaoEncontrado;
    [Test]
    procedure Atualizar_MantendoProprioDocumento_Permite;
    [Test]
    procedure Atualizar_DocumentoDeOutroCliente_LevantaRegraNegocio;
    [Test]
    procedure Excluir_InativaCliente;
  end;

implementation

uses
  Infra.Excecoes;

const
  CPF_VALIDO = '52998224725';
  CPF_VALIDO_2 = '12345678909';
  CNPJ_VALIDO = '11222333000181';

procedure TTestsClienteService.Setup;
begin
  FRepositorio := TClienteRepositoryFake.Create;
  FRepositorioIntf := FRepositorio;
  FService := TClienteService.Create(FRepositorioIntf);
end;

procedure TTestsClienteService.TearDown;
begin
  FService := nil;
  FRepositorioIntf := nil;
  FRepositorio := nil;
end;

function TTestsClienteService.NovoCliente(const ANome, ADocumento, AEmail: string): TCliente;
begin
  Result := TCliente.Create;
  Result.Nome := ANome;
  Result.Documento := ADocumento;
  Result.Email := AEmail;
end;

procedure TTestsClienteService.VerificarCriacaoFalha(ACliente: TCliente; AExcecao: ExceptClass);
begin
  try
    Assert.WillRaise(
      procedure
      begin
        FService.Criar(ACliente);
      end,
      AExcecao);
  finally
    ACliente.Free;
  end;
end;

procedure TTestsClienteService.Criar_DadosValidos_GravaEAtribuiId;
var
  LCliente: TCliente;
begin
  LCliente := NovoCliente('Maria', CPF_VALIDO, 'maria@exemplo.com');
  try
    FService.Criar(LCliente);
    Assert.IsTrue(LCliente.Id > 0);
    Assert.IsNotNull(FRepositorio.Obter(LCliente.Id));
  finally
    LCliente.Free;
  end;
end;

procedure TTestsClienteService.Criar_NormalizaDocumentoNomeEEmail;
var
  LCliente: TCliente;
begin
  LCliente := NovoCliente('  Maria  ', '529.982.247-25', ' Maria@Exemplo.COM ');
  try
    FService.Criar(LCliente);
    Assert.AreEqual('Maria', LCliente.Nome);
    Assert.AreEqual(CPF_VALIDO, LCliente.Documento);
    Assert.AreEqual('maria@exemplo.com', LCliente.Email);
  finally
    LCliente.Free;
  end;
end;

procedure TTestsClienteService.Criar_SemNome_LevantaRequisicaoInvalida;
begin
  VerificarCriacaoFalha(NovoCliente('   ', CPF_VALIDO), ERequisicaoInvalida);
end;

procedure TTestsClienteService.Criar_SemDocumento_LevantaRequisicaoInvalida;
begin
  VerificarCriacaoFalha(NovoCliente('Maria', ''), ERequisicaoInvalida);
end;

procedure TTestsClienteService.Criar_DocumentoInvalido_LevantaRegraNegocio;
begin
  VerificarCriacaoFalha(NovoCliente('Maria', '52998224724'), ERegraNegocio);
end;

procedure TTestsClienteService.Criar_DocumentoDuplicado_LevantaRegraNegocio;
begin
  FRepositorio.Adicionar('Outro', CNPJ_VALIDO);
  VerificarCriacaoFalha(NovoCliente('Maria', '11.222.333/0001-81'), ERegraNegocio);
end;

procedure TTestsClienteService.Criar_DocumentoDeClienteInativo_LevantaRegraNegocio;
begin
  FRepositorio.Adicionar('Antigo', CPF_VALIDO, False);
  VerificarCriacaoFalha(NovoCliente('Maria', CPF_VALIDO), ERegraNegocio);
end;

procedure TTestsClienteService.Criar_EmailInvalido_LevantaRegraNegocio;
begin
  VerificarCriacaoFalha(NovoCliente('Maria', CPF_VALIDO, 'maria.exemplo.com'), ERegraNegocio);
end;

procedure TTestsClienteService.Buscar_Inexistente_LevantaNaoEncontrado;
begin
  Assert.WillRaise(
    procedure
    begin
      FService.Buscar(999).Free;
    end,
    ENaoEncontrado);
end;

procedure TTestsClienteService.Atualizar_Inexistente_LevantaNaoEncontrado;
var
  LCliente: TCliente;
begin
  LCliente := NovoCliente('Maria', CPF_VALIDO);
  try
    LCliente.Id := 999;
    Assert.WillRaise(
      procedure
      begin
        FService.Atualizar(LCliente);
      end,
      ENaoEncontrado);
  finally
    LCliente.Free;
  end;
end;

procedure TTestsClienteService.Atualizar_MantendoProprioDocumento_Permite;
var
  LCliente: TCliente;
begin
  LCliente := NovoCliente('Maria Souza', CPF_VALIDO);
  try
    LCliente.Id := FRepositorio.Adicionar('Maria', CPF_VALIDO);
    FService.Atualizar(LCliente);
    Assert.AreEqual('Maria Souza', FRepositorio.Obter(LCliente.Id).Nome);
  finally
    LCliente.Free;
  end;
end;

procedure TTestsClienteService.Atualizar_DocumentoDeOutroCliente_LevantaRegraNegocio;
var
  LCliente: TCliente;
begin
  FRepositorio.Adicionar('João', CPF_VALIDO_2);
  LCliente := NovoCliente('Maria', CPF_VALIDO_2);
  try
    LCliente.Id := FRepositorio.Adicionar('Maria', CPF_VALIDO);
    Assert.WillRaise(
      procedure
      begin
        FService.Atualizar(LCliente);
      end,
      ERegraNegocio);
  finally
    LCliente.Free;
  end;
end;

procedure TTestsClienteService.Excluir_InativaCliente;
var
  LId: Integer;
begin
  LId := FRepositorio.Adicionar('Maria', CPF_VALIDO);

  FService.Excluir(LId);

  Assert.IsFalse(FRepositorio.Obter(LId).Ativo);
  Assert.WillRaise(
    procedure
    begin
      FService.Buscar(LId).Free;
    end,
    ENaoEncontrado);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsClienteService);

end.
