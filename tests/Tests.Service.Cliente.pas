unit Tests.Service.Cliente;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Model.Cliente,
  Repository.Cliente,
  Service.Cliente,
  Model.Paginacao,
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
    [Test]
    procedure Listar_RepassaBuscaSemEspacosAoRepositorio;
    [Test]
    procedure Listar_ServidorEmLidoAntesDaConsultaComMargem;
    [Test]
    procedure Criar_ComUuidNovo_Cria;
    [Test]
    procedure Criar_MesmoUuid_DevolveOExistenteSemDuplicar;
    [Test]
    procedure Criar_UuidMalformado_LevantaRequisicaoInvalida;
    [Test]
    procedure Criar_LocalizacaoForaDaFaixa_LevantaRequisicaoInvalida;
    [Test]
    procedure GravarLocalizacao_Valida_Grava;
    [Test]
    procedure GravarLocalizacao_ForaDaFaixa_NaoGrava;
    [Test]
    procedure GravarFoto_Jpeg_Grava;
    [Test]
    procedure GravarFoto_Png_NaoGrava;
    [Test]
    procedure GravarFoto_MaiorQue500KB_NaoGrava;
    [Test]
    procedure LerFoto_SemFoto_LevantaNaoEncontrado;
    [Test]
    procedure Criar_CorridaNoMesmoUuidBatendoNoDocumento_DevolveOExistente;
    [Test]
    procedure Criar_DocumentoDeOutroClienteNaCorrida_ContinuaRecusado;
  end;

implementation

uses
  System.DateUtils,
  Repository.Relogio,
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

procedure TTestsClienteService.Listar_RepassaBuscaSemEspacosAoRepositorio;
var
  LTotal: Integer;
  LServidorEm: TDateTime;
begin
  FService.Listar(TPaginacao.Criar(1, 20), '  maria  ', TFiltroSync.Nenhum, LTotal, LServidorEm).Free;
  Assert.AreEqual('maria', FRepositorio.UltimaBusca);
end;

procedure TTestsClienteService.Listar_ServidorEmLidoAntesDaConsultaComMargem;
var
  LRelogio: TRelogioFake;
  LRelogioIntf: IRelogioRepository;
  LService: IClienteService;
  LTotal: Integer;
  LServidorEm: TDateTime;
begin
  LRelogio := TRelogioFake.Create(EncodeDateTime(2026, 11, 22, 10, 0, 0, 0));
  LRelogioIntf := LRelogio;
  FRepositorio.Registro := LRelogio.Chamadas;
  LService := TClienteService.Create(FRepositorioIntf, LRelogioIntf);

  LService.Listar(TPaginacao.Criar(1, 20), '', TFiltroSync.APartirDe(EncodeDate(2026, 11, 1)),
    LTotal, LServidorEm).Free;

  // a marca é lida antes da consulta: o que mudar durante a consulta entra na próxima
  Assert.AreEqual('AgoraNoServidor,Listar', LRelogio.Chamadas.CommaText);
  // e volta 2 minutos para cobrir transação que começou antes e gravou depois
  Assert.AreEqual(EncodeDateTime(2026, 11, 22, 9, 58, 0, 0), LServidorEm);
end;

const
  UUID_APP = '3F2B8C1E-9D4A-4E7B-8C21-5A6F0E9D1B23';

function Jpeg(ATamanho: Integer): TBytes;
begin
  SetLength(Result, ATamanho);
  FillChar(Result[0], ATamanho, 0);
  Result[0] := $FF;
  Result[1] := $D8;
  Result[2] := $FF;
end;

procedure TTestsClienteService.Criar_ComUuidNovo_Cria;
var
  LCliente: TCliente;
  LJaExistia: Boolean;
begin
  LCliente := NovoCliente('Maria', CPF_VALIDO, '');
  try
    LCliente.Uuid := UUID_APP;
    FService.Criar(LCliente, LJaExistia);
    Assert.IsFalse(LJaExistia);
    Assert.IsTrue(LCliente.Id > 0);
    Assert.AreEqual(LowerCase(UUID_APP), FRepositorio.Obter(LCliente.Id).Uuid);
  finally
    LCliente.Free;
  end;
end;

procedure TTestsClienteService.Criar_MesmoUuid_DevolveOExistenteSemDuplicar;
var
  LPrimeiro, LSegundo: TCliente;
  LJaExistia: Boolean;
begin
  LPrimeiro := NovoCliente('Maria', CPF_VALIDO, '');
  LSegundo := NovoCliente('Maria', CPF_VALIDO, '');
  try
    LPrimeiro.Uuid := UUID_APP;
    LSegundo.Uuid := LowerCase(UUID_APP);
    FService.Criar(LPrimeiro, LJaExistia);
    FService.Criar(LSegundo, LJaExistia); // reenvio depois de uma queda de conexão

    Assert.IsTrue(LJaExistia);
    Assert.AreEqual(LPrimeiro.Id, LSegundo.Id);
    Assert.AreEqual(1, FRepositorio.Insercoes);
  finally
    LPrimeiro.Free;
    LSegundo.Free;
  end;
end;

procedure TTestsClienteService.Criar_UuidMalformado_LevantaRequisicaoInvalida;
var
  LCliente: TCliente;
  LJaExistia: Boolean;
begin
  LCliente := NovoCliente('Maria', CPF_VALIDO, '');
  try
    LCliente.Uuid := 'abc';
    Assert.WillRaiseWithMessage(
      procedure
      begin
        FService.Criar(LCliente, LJaExistia);
      end,
      ERequisicaoInvalida, '"uuid" inválido.');
    Assert.AreEqual(0, FRepositorio.Insercoes);
  finally
    LCliente.Free;
  end;
end;

procedure TTestsClienteService.Criar_LocalizacaoForaDaFaixa_LevantaRequisicaoInvalida;
var
  LCliente: TCliente;
begin
  LCliente := NovoCliente('Maria', CPF_VALIDO, '');
  LCliente.DefinirLocalizacao(-91, -46.6);
  VerificarCriacaoFalha(LCliente, ERequisicaoInvalida);
  Assert.AreEqual(0, FRepositorio.Insercoes);
end;

procedure TTestsClienteService.GravarLocalizacao_Valida_Grava;
var
  LId: Integer;
begin
  LId := FRepositorio.Adicionar('Maria', CPF_VALIDO);
  FService.GravarLocalizacao(LId, -23.561414, -46.655881);
  Assert.IsTrue(FRepositorio.Obter(LId).TemLocalizacao);
  Assert.AreEqual(-23.561414, FRepositorio.Obter(LId).Latitude, 0.0000001);
end;

procedure TTestsClienteService.GravarLocalizacao_ForaDaFaixa_NaoGrava;
var
  LId: Integer;
begin
  LId := FRepositorio.Adicionar('Maria', CPF_VALIDO);
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.GravarLocalizacao(LId, -23.5, 181);
    end,
    ERequisicaoInvalida, 'Localização inválida.');
  Assert.IsFalse(FRepositorio.Obter(LId).TemLocalizacao);
end;

procedure TTestsClienteService.GravarFoto_Jpeg_Grava;
var
  LId: Integer;
begin
  LId := FRepositorio.Adicionar('Maria', CPF_VALIDO);
  FService.GravarFoto(LId, Jpeg(1000));
  Assert.AreEqual(1000, Length(FService.LerFoto(LId)));
end;

procedure TTestsClienteService.GravarFoto_Png_NaoGrava;
var
  LId: Integer;
begin
  LId := FRepositorio.Adicionar('Maria', CPF_VALIDO);
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.GravarFoto(LId, TBytes.Create($89, $50, $4E, $47, $0D, $0A, $1A, $0A));
    end,
    ERequisicaoInvalida, 'A foto deve ser JPEG.');
  Assert.AreEqual(0, FRepositorio.FotosGravadas);
end;

procedure TTestsClienteService.GravarFoto_MaiorQue500KB_NaoGrava;
var
  LId: Integer;
begin
  LId := FRepositorio.Adicionar('Maria', CPF_VALIDO);
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FService.GravarFoto(LId, Jpeg(512001));
    end,
    ERequisicaoInvalida, 'Foto maior que 500 KB.');
  Assert.AreEqual(0, FRepositorio.FotosGravadas);
end;

procedure TTestsClienteService.LerFoto_SemFoto_LevantaNaoEncontrado;
var
  LId: Integer;
begin
  LId := FRepositorio.Adicionar('Maria', CPF_VALIDO);
  Assert.WillRaise(
    procedure
    begin
      FService.LerFoto(LId);
    end,
    ENaoEncontrado);
end;

procedure TTestsClienteService.Criar_CorridaNoMesmoUuidBatendoNoDocumento_DevolveOExistente;
var
  LCliente: TCliente;
  LJaExistia: Boolean;
begin
  FRepositorio.SimularCorridaPorDocumento := True;
  LCliente := NovoCliente('Maria', CPF_VALIDO, '');
  try
    LCliente.Uuid := UUID_APP;
    FService.Criar(LCliente, LJaExistia);
    Assert.IsTrue(LJaExistia);
    Assert.IsTrue(LCliente.Id > 0);
  finally
    LCliente.Free;
  end;
end;

procedure TTestsClienteService.Criar_DocumentoDeOutroClienteNaCorrida_ContinuaRecusado;
var
  LCliente: TCliente;
  LJaExistia: Boolean;
begin
  // outro cliente (sem o nosso UUID) gravou o mesmo CPF entre a conferência e o insert
  FRepositorio.SimularCorridaPorDocumento := True;
  LCliente := NovoCliente('Maria', CPF_VALIDO, '');
  try
    Assert.WillRaiseWithMessage(
      procedure
      begin
        FService.Criar(LCliente, LJaExistia); // sem uuid: não há o que esperar
      end,
      ERegraNegocio, 'Já existe um cliente com este CPF/CNPJ.');
  finally
    LCliente.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsClienteService);

end.
