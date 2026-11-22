unit Service.Cliente;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Model.Cliente,
  Model.Paginacao,
  Repository.Cliente,
  Repository.Relogio;

type
  IClienteService = interface
    ['{B8F3A9D2-5C14-4E6B-8F27-D1A0C3E5B946}']
    function Listar(const APaginacao: TPaginacao; const ABusca: string; const ASync: TFiltroSync;
      out ATotal: Integer; out AServidorEm: TDateTime): TObjectList<TCliente>;
    function Buscar(AId: Integer): TCliente;
    procedure Criar(ACliente: TCliente); overload;
    procedure Criar(ACliente: TCliente; out AJaExistia: Boolean); overload;
    procedure Atualizar(ACliente: TCliente);
    procedure Excluir(AId: Integer);
    procedure GravarLocalizacao(AId: Integer; ALatitude, ALongitude: Double);
    procedure GravarFoto(AId: Integer; const AFoto: TBytes);
    function LerFoto(AId: Integer): TBytes;
  end;

  TClienteService = class(TInterfacedObject, IClienteService)
  private
    FRepository: IClienteRepository;
    FRelogio: IRelogioRepository;
    procedure NormalizarEValidar(ACliente: TCliente);
    procedure GarantirExistente(AId: Integer);
    procedure ValidarLocalizacao(ALatitude, ALongitude: Double);
    function CarregarPorUuid(ACliente: TCliente): Boolean;
  public
    const TAMANHO_MAXIMO_FOTO = 512000;
    const TAMANHO_MAXIMO_NOME = 100;
    const TAMANHO_MAXIMO_EMAIL = 150;
    const TAMANHO_MAXIMO_TELEFONE = 20;

    constructor Create(const ARepository: IClienteRepository; const ARelogio: IRelogioRepository = nil);
    { AServidorEm: marca para o próximo "desde" do app (ver Repository.Relogio). }
    function Listar(const APaginacao: TPaginacao; const ABusca: string; const ASync: TFiltroSync;
      out ATotal: Integer; out AServidorEm: TDateTime): TObjectList<TCliente>;
    { Levanta ENaoEncontrado se não existir ou estiver inativo. }
    function Buscar(AId: Integer): TCliente;
    { Normaliza, valida e grava. Preenche ACliente.Id. }
    procedure Criar(ACliente: TCliente); overload;
    { Cliente criado no app vem com Uuid: se esse Uuid já existe (reenvio), o
      registro existente é copiado para ACliente e AJaExistia fica True. }
    procedure Criar(ACliente: TCliente; out AJaExistia: Boolean); overload;
    procedure GravarLocalizacao(AId: Integer; ALatitude, ALongitude: Double);
    { Só JPEG, até 500 KB. }
    procedure GravarFoto(AId: Integer; const AFoto: TBytes);
    function LerFoto(AId: Integer): TBytes;
    { ACliente.Id indica o registro a atualizar (PUT: substitui todos os campos). }
    procedure Atualizar(ACliente: TCliente);
    { Exclusão lógica: o cliente é inativado e mantém o histórico de pedidos. }
    procedure Excluir(AId: Integer);
  end;

implementation

uses
  System.RegularExpressions,
  Model.Documento,
  Model.Uuid,
  Model.Imagem,
  Model.EsperaUuid,
  Infra.Excecoes;

const
  // Validação propositalmente simples: algo@algo.algo, sem espaços.
  REGEX_EMAIL = '^[^@\s]+@[^@\s]+\.[^@\s]+$';

constructor TClienteService.Create(const ARepository: IClienteRepository; const ARelogio: IRelogioRepository);
begin
  inherited Create;
  FRepository := ARepository;
  FRelogio := ARelogio;
end;

procedure TClienteService.NormalizarEValidar(ACliente: TCliente);
begin
  ACliente.Nome := ACliente.Nome.Trim;
  ACliente.Documento := TDocumento.Normalizar(ACliente.Documento);
  ACliente.Email := ACliente.Email.Trim.ToLower;
  ACliente.Telefone := ACliente.Telefone.Trim;

  if ACliente.Nome.IsEmpty then
    raise ERequisicaoInvalida.Create('Informe o nome do cliente.');
  if ACliente.Documento.IsEmpty then
    raise ERequisicaoInvalida.Create('Informe o CPF ou CNPJ do cliente.');

  if ACliente.Nome.Length > TAMANHO_MAXIMO_NOME then
    raise ERegraNegocio.CreateFmt('O nome deve ter no máximo %d caracteres.', [TAMANHO_MAXIMO_NOME]);
  if not TDocumento.Valido(ACliente.Documento) then
    raise ERegraNegocio.Create('CPF/CNPJ inválido.');
  if not ACliente.Email.IsEmpty and
    ((ACliente.Email.Length > TAMANHO_MAXIMO_EMAIL) or not TRegEx.IsMatch(ACliente.Email, REGEX_EMAIL)) then
    raise ERegraNegocio.Create('E-mail inválido.');
  if ACliente.Telefone.Length > TAMANHO_MAXIMO_TELEFONE then
    raise ERegraNegocio.CreateFmt('O telefone deve ter no máximo %d caracteres.', [TAMANHO_MAXIMO_TELEFONE]);
end;

procedure TClienteService.GarantirExistente(AId: Integer);
begin
  Buscar(AId).Free;
end;

function TClienteService.Listar(const APaginacao: TPaginacao; const ABusca: string;
  const ASync: TFiltroSync; out ATotal: Integer; out AServidorEm: TDateTime): TObjectList<TCliente>;
begin
  AServidorEm := MarcaDeSincronizacao(FRelogio); // antes da consulta, de propósito
  Result := FRepository.Listar(APaginacao, Trim(ABusca), ASync, ATotal);
end;

function TClienteService.Buscar(AId: Integer): TCliente;
begin
  Result := FRepository.BuscarPorId(AId);
  if Result = nil then
    raise ENaoEncontrado.CreateFmt('Cliente %d não encontrado.', [AId]);
end;

procedure TClienteService.Criar(ACliente: TCliente);
var
  LJaExistia: Boolean;
begin
  Criar(ACliente, LJaExistia);
end;

procedure CopiarCliente(AOrigem, ADestino: TCliente);
begin
  ADestino.Id := AOrigem.Id;
  ADestino.Nome := AOrigem.Nome;
  ADestino.Documento := AOrigem.Documento;
  ADestino.Email := AOrigem.Email;
  ADestino.Telefone := AOrigem.Telefone;
  ADestino.Ativo := AOrigem.Ativo;
  ADestino.AtualizadoEm := AOrigem.AtualizadoEm;
  ADestino.Uuid := AOrigem.Uuid;
  if AOrigem.TemLocalizacao then
    ADestino.DefinirLocalizacao(AOrigem.Latitude, AOrigem.Longitude);
  ADestino.TemFoto := AOrigem.TemFoto;
end;

function TClienteService.CarregarPorUuid(ACliente: TCliente): Boolean;
var
  LExistente: TCliente;
begin
  LExistente := FRepository.BuscarPorUuid(ACliente.Uuid);
  try
    Result := LExistente <> nil;
    if Result then
      CopiarCliente(LExistente, ACliente);
  finally
    LExistente.Free;
  end;
end;

procedure TClienteService.Criar(ACliente: TCliente; out AJaExistia: Boolean);
begin
  AJaExistia := False;
  if ACliente.Uuid.Trim <> '' then
  begin
    if not TUuid.Valido(ACliente.Uuid.Trim) then
      raise ERequisicaoInvalida.Create('"uuid" inválido.');
    ACliente.Uuid := TUuid.Normalizar(ACliente.Uuid);
    AJaExistia := CarregarPorUuid(ACliente);
    if AJaExistia then
      Exit;
  end
  else
    ACliente.Uuid := '';

  NormalizarEValidar(ACliente);
  if ACliente.TemLocalizacao then
    ValidarLocalizacao(ACliente.Latitude, ACliente.Longitude);

  if FRepository.DocumentoEmUso(ACliente.Documento, 0) then
    raise ERegraNegocio.Create('Já existe um cliente com este CPF/CNPJ.');

  ACliente.Ativo := True;
  try
    FRepository.Inserir(ACliente);
  except
    // outro envio do mesmo UUID gravou entre a consulta e o insert
    on EUuidDuplicado do
    begin
      AJaExistia := EsperarPorUuid(
        function: Boolean
        begin
          Result := CarregarPorUuid(ACliente);
        end);
      if not AJaExistia then
        raise EConflito.Create('Este cliente ainda está sendo gravado por outro envio; tente de novo em instantes.');
    end;
    // o mesmo cliente enviado duas vezes ao mesmo tempo esbarra primeiro no índice do
    // CPF/CNPJ; se o outro envio tinha o nosso UUID, é o mesmo cadastro
    on ERegraNegocio do
    begin
      if ACliente.Uuid = '' then
        raise;
      AJaExistia := EsperarPorUuid(
        function: Boolean
        begin
          Result := CarregarPorUuid(ACliente);
        end);
      if not AJaExistia then
        raise;
    end;
  end;
end;

procedure TClienteService.ValidarLocalizacao(ALatitude, ALongitude: Double);
begin
  if (ALatitude < -90) or (ALatitude > 90) or (ALongitude < -180) or (ALongitude > 180) then
    raise ERequisicaoInvalida.Create('Localização inválida.');
end;

procedure TClienteService.GravarLocalizacao(AId: Integer; ALatitude, ALongitude: Double);
begin
  GarantirExistente(AId);
  ValidarLocalizacao(ALatitude, ALongitude);
  FRepository.GravarLocalizacao(AId, ALatitude, ALongitude);
end;

procedure TClienteService.GravarFoto(AId: Integer; const AFoto: TBytes);
begin
  GarantirExistente(AId);
  if not TImagem.EhJpeg(AFoto) then
    raise ERequisicaoInvalida.Create('A foto deve ser JPEG.');
  if Length(AFoto) > TAMANHO_MAXIMO_FOTO then
    raise ERequisicaoInvalida.Create('Foto maior que 500 KB.');
  FRepository.GravarFoto(AId, AFoto);
end;

function TClienteService.LerFoto(AId: Integer): TBytes;
begin
  GarantirExistente(AId);
  Result := FRepository.LerFoto(AId);
  if Length(Result) = 0 then
    raise ENaoEncontrado.CreateFmt('Cliente %d não tem foto.', [AId]);
end;

procedure TClienteService.Atualizar(ACliente: TCliente);
begin
  GarantirExistente(ACliente.Id);
  NormalizarEValidar(ACliente);

  if FRepository.DocumentoEmUso(ACliente.Documento, ACliente.Id) then
    raise ERegraNegocio.Create('Já existe um cliente com este CPF/CNPJ.');

  ACliente.Ativo := True;
  FRepository.Atualizar(ACliente);
end;

procedure TClienteService.Excluir(AId: Integer);
begin
  GarantirExistente(AId);
  FRepository.Inativar(AId);
end;

end.
