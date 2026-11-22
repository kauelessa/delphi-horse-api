unit Model.Visita;

interface

type
  TMotivoVisita = (mvAusente, mvSemNecessidade, mvSemEstoque, mvPreco, mvOutro);

  TMotivoVisitaHelper = record helper for TMotivoVisita
    function ToString: string;
    // texto desconhecido levanta ERequisicaoInvalida
    class function DeTexto(const AValor: string): TMotivoVisita; static;
  end;

  // check-in do vendedor num cliente que não comprou
  TVisita = class
  private
    FId: Integer;
    FUuid: string;
    FClienteId: Integer;
    FNomeCliente: string;
    FUsuarioId: Integer;
    FData: TDateTime;
    FLatitude: Double;
    FLongitude: Double;
    FPrecisao: Double;
    FTemLocalizacao: Boolean;
    FMotivo: TMotivoVisita;
    FObservacao: string;
    FAtualizadoEm: TDateTime;
  public
    procedure DefinirLocalizacao(ALatitude, ALongitude, APrecisao: Double);
    procedure Assign(AOrigem: TVisita);

    property Id: Integer read FId write FId;
    property Uuid: string read FUuid write FUuid;
    property ClienteId: Integer read FClienteId write FClienteId;
    property NomeCliente: string read FNomeCliente write FNomeCliente;
    property UsuarioId: Integer read FUsuarioId write FUsuarioId;
    property Data: TDateTime read FData write FData;
    property Latitude: Double read FLatitude;
    property Longitude: Double read FLongitude;
    property Precisao: Double read FPrecisao;
    property TemLocalizacao: Boolean read FTemLocalizacao;
    property Motivo: TMotivoVisita read FMotivo write FMotivo;
    property Observacao: string read FObservacao write FObservacao;
    property AtualizadoEm: TDateTime read FAtualizadoEm write FAtualizadoEm;
  end;

implementation

uses
  System.SysUtils, Infra.Excecoes;

const
  TEXTOS: array[TMotivoVisita] of string = ('AUSENTE', 'SEM_NECESSIDADE', 'SEM_ESTOQUE', 'PRECO', 'OUTRO');

function TMotivoVisitaHelper.ToString: string;
begin
  Result := TEXTOS[Self];
end;

class function TMotivoVisitaHelper.DeTexto(const AValor: string): TMotivoVisita;
var
  M: TMotivoVisita;
begin
  for M := Low(TMotivoVisita) to High(TMotivoVisita) do
    if SameText(TEXTOS[M], AValor.Trim) then
      Exit(M);
  raise ERequisicaoInvalida.Create(
    'Motivo de visita desconhecido. Use AUSENTE, SEM_NECESSIDADE, SEM_ESTOQUE, PRECO ou OUTRO.');
end;

procedure TVisita.DefinirLocalizacao(ALatitude, ALongitude, APrecisao: Double);
begin
  FLatitude := ALatitude;
  FLongitude := ALongitude;
  FPrecisao := APrecisao;
  FTemLocalizacao := True;
end;

procedure TVisita.Assign(AOrigem: TVisita);
begin
  FId := AOrigem.Id;
  FUuid := AOrigem.Uuid;
  FClienteId := AOrigem.ClienteId;
  FNomeCliente := AOrigem.NomeCliente;
  FUsuarioId := AOrigem.UsuarioId;
  FData := AOrigem.Data;
  FLatitude := AOrigem.Latitude;
  FLongitude := AOrigem.Longitude;
  FPrecisao := AOrigem.Precisao;
  FTemLocalizacao := AOrigem.TemLocalizacao;
  FMotivo := AOrigem.Motivo;
  FObservacao := AOrigem.Observacao;
  FAtualizadoEm := AOrigem.AtualizadoEm;
end;

end.
