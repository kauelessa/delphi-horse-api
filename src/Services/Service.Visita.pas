unit Service.Visita;

interface

uses
  System.Generics.Collections,
  Model.Visita,
  Model.Paginacao,
  Repository.Visita,
  Repository.Cliente,
  Repository.Relogio;

type
  IVisitaService = interface
    ['{C5A1E7D3-4B8F-4E2A-B9D6-3F7A0C1E8B52}']
    procedure Criar(AVisita: TVisita; out AJaExistia: Boolean);
    function Listar(const APaginacao: TPaginacao; const ASync: TFiltroSync; out ATotal: Integer;
      out AServidorEm: TDateTime): TObjectList<TVisita>;
  end;

  TVisitaService = class(TInterfacedObject, IVisitaService)
  private
    FVisitas: IVisitaRepository;
    FClientes: IClienteRepository;
    FRelogio: IRelogioRepository;
    function CarregarPorUuid(AVisita: TVisita): Boolean;
    procedure Validar(AVisita: TVisita);
  public
    constructor Create(const AVisitas: IVisitaRepository; const AClientes: IClienteRepository;
      const ARelogio: IRelogioRepository = nil);
    { Visita sempre vem do app, então o uuid é obrigatório; reenvio devolve a
      já gravada (AJaExistia). UsuarioId é preenchido pelo controller. }
    procedure Criar(AVisita: TVisita; out AJaExistia: Boolean);
    function Listar(const APaginacao: TPaginacao; const ASync: TFiltroSync; out ATotal: Integer;
      out AServidorEm: TDateTime): TObjectList<TVisita>;
  end;

implementation

uses
  System.SysUtils, System.DateUtils, Model.Cliente, Model.Uuid, Infra.Excecoes;

const
  TAMANHO_MAXIMO_OBSERVACAO = 500;

constructor TVisitaService.Create(const AVisitas: IVisitaRepository; const AClientes: IClienteRepository;
  const ARelogio: IRelogioRepository);
begin
  inherited Create;
  FVisitas := AVisitas;
  FClientes := AClientes;
  FRelogio := ARelogio;
end;

function TVisitaService.CarregarPorUuid(AVisita: TVisita): Boolean;
var
  LExistente: TVisita;
begin
  LExistente := FVisitas.BuscarPorUuid(AVisita.Uuid);
  try
    Result := LExistente <> nil;
    if Result then
      AVisita.Assign(LExistente);
  finally
    LExistente.Free;
  end;
end;

procedure TVisitaService.Validar(AVisita: TVisita);
var
  LAgora: TDateTime;
  LCliente: TCliente;
begin
  if Assigned(FRelogio) then
    LAgora := FRelogio.AgoraNoServidor
  else
    LAgora := Now;

  // mesma janela do pedido: até 30 dias offline, relógio do celular até 10 min adiantado
  if AVisita.Data = 0 then
    AVisita.Data := LAgora
  else if (AVisita.Data < IncDay(LAgora, -30)) or (AVisita.Data > IncMinute(LAgora, 10)) then
    raise ERegraNegocio.Create('Data da visita fora do intervalo aceito.');

  AVisita.Observacao := AVisita.Observacao.Trim;
  if (AVisita.Motivo = mvOutro) and (AVisita.Observacao = '') then
    raise ERegraNegocio.Create('Descreva o motivo da visita.');
  if AVisita.Observacao.Length > TAMANHO_MAXIMO_OBSERVACAO then
    raise ERegraNegocio.CreateFmt('A observação deve ter no máximo %d caracteres.', [TAMANHO_MAXIMO_OBSERVACAO]);

  if AVisita.TemLocalizacao and ((AVisita.Latitude < -90) or (AVisita.Latitude > 90) or
    (AVisita.Longitude < -180) or (AVisita.Longitude > 180) or (AVisita.Precisao < 0)) then
    raise ERequisicaoInvalida.Create('Localização inválida.');

  if AVisita.ClienteId <= 0 then
    raise ERequisicaoInvalida.Create('Informe o cliente da visita.');
  LCliente := FClientes.BuscarPorId(AVisita.ClienteId);
  try
    if LCliente = nil then
      raise ERegraNegocio.CreateFmt('Cliente %d não encontrado ou inativo.', [AVisita.ClienteId]);
    AVisita.NomeCliente := LCliente.Nome;
  finally
    LCliente.Free;
  end;
end;

procedure TVisitaService.Criar(AVisita: TVisita; out AJaExistia: Boolean);
begin
  AJaExistia := False;
  if AVisita.Uuid.Trim = '' then
    raise ERequisicaoInvalida.Create('Informe o "uuid" da visita.');
  if not TUuid.Valido(AVisita.Uuid.Trim) then
    raise ERequisicaoInvalida.Create('"uuid" inválido.');
  AVisita.Uuid := TUuid.Normalizar(AVisita.Uuid);

  AJaExistia := CarregarPorUuid(AVisita);
  if AJaExistia then
    Exit;

  Validar(AVisita);
  try
    FVisitas.Inserir(AVisita);
  except
    on EUuidDuplicado do
    begin
      AJaExistia := CarregarPorUuid(AVisita);
      if not AJaExistia then
        raise;
    end;
  end;
end;

function TVisitaService.Listar(const APaginacao: TPaginacao; const ASync: TFiltroSync; out ATotal: Integer;
  out AServidorEm: TDateTime): TObjectList<TVisita>;
begin
  AServidorEm := MarcaDeSincronizacao(FRelogio);
  Result := FVisitas.Listar(APaginacao, ASync, ATotal);
end;

end.
