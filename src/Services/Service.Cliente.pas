unit Service.Cliente;

interface

uses
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
    procedure Criar(ACliente: TCliente);
    procedure Atualizar(ACliente: TCliente);
    procedure Excluir(AId: Integer);
  end;

  TClienteService = class(TInterfacedObject, IClienteService)
  private
    FRepository: IClienteRepository;
    FRelogio: IRelogioRepository;
    procedure NormalizarEValidar(ACliente: TCliente);
    procedure GarantirExistente(AId: Integer);
  public
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
    procedure Criar(ACliente: TCliente);
    { ACliente.Id indica o registro a atualizar (PUT: substitui todos os campos). }
    procedure Atualizar(ACliente: TCliente);
    { Exclusão lógica: o cliente é inativado e mantém o histórico de pedidos. }
    procedure Excluir(AId: Integer);
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  Model.Documento,
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
begin
  NormalizarEValidar(ACliente);

  if FRepository.DocumentoEmUso(ACliente.Documento, 0) then
    raise ERegraNegocio.Create('Já existe um cliente com este CPF/CNPJ.');

  ACliente.Ativo := True;
  FRepository.Inserir(ACliente);
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
