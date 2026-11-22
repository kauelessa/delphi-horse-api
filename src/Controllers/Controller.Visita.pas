unit Controller.Visita;

interface

type
  TControllerVisita = class
  public
    class procedure Registrar; static;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.DateUtils, System.Generics.Collections, Horse, Horse.Commons,
  Model.Visita, Model.Paginacao, Repository.Visita, Repository.Cliente, Repository.Relogio,
  Service.Visita, Controller.Utils;

function Service: IVisitaService;
begin
  Result := TVisitaService.Create(TVisitaRepository.Create, TClienteRepository.Create, TRelogioRepository.Create);
end;

function VisitaParaJSON(AVisita: TVisita): TJSONObject;
begin
  Result := TJSONObject.Create
    .AddPair('id', TJSONNumber.Create(AVisita.Id))
    .AddPair('uuid', AVisita.Uuid)
    .AddPair('cliente', TJSONObject.Create
      .AddPair('id', TJSONNumber.Create(AVisita.ClienteId))
      .AddPair('nome', AVisita.NomeCliente))
    .AddPair('vendedorId', TJSONNumber.Create(AVisita.UsuarioId))
    .AddPair('data', DateToISO8601(AVisita.Data, False))
    .AddPair('motivo', AVisita.Motivo.ToString)
    .AddPair('observacao', AVisita.Observacao)
    .AddPair('atualizadoEm', DataJSON(AVisita.AtualizadoEm));

  if AVisita.TemLocalizacao then
    Result.AddPair('localizacao', TJSONObject.Create
      .AddPair('latitude', TJSONNumber.Create(AVisita.Latitude))
      .AddPair('longitude', TJSONNumber.Create(AVisita.Longitude))
      .AddPair('precisao', TJSONNumber.Create(AVisita.Precisao)))
  else
    Result.AddPair('localizacao', TJSONNull.Create);
end;

// { "uuid": "...", "clienteId": 1, "dataVisita": "...", "motivo": "AUSENTE", "observacao": "",
//   "latitude": -23.5, "longitude": -46.6, "precisao": 10 }
function VisitaDoJSON(AJson: TJSONObject): TVisita;
var
  LLat, LLon, LPrecisao: Double;
  LData: string;
begin
  Result := TVisita.Create;
  try
    Result.Uuid := LerTexto(AJson, 'uuid');
    Result.ClienteId := LerInteiro(AJson, 'clienteId');
    Result.Motivo := TMotivoVisita.DeTexto(LerTexto(AJson, 'motivo'));
    Result.Observacao := LerTexto(AJson, 'observacao');
    LData := LerTexto(AJson, 'dataVisita');
    if LData <> '' then
      Result.Data := ISO8601ToDateValidado(LData, 'dataVisita');
    if LerLocalizacao(AJson, LLat, LLon) then
    begin
      LerDouble(AJson, 'precisao', LPrecisao);
      Result.DefinirLocalizacao(LLat, LLon, LPrecisao);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure Listar(AReq: THorseRequest; ARes: THorseResponse);
var
  LPag: TPaginacao;
  LTotal: Integer;
  LServidorEm: TDateTime;
  LLista: TObjectList<TVisita>;
  LDados: TJSONArray;
  LVisita: TVisita;
begin
  LPag := PaginacaoDaQuery(AReq);
  LLista := Service.Listar(LPag, FiltroSyncDaQuery(AReq), LTotal, LServidorEm);
  try
    LDados := TJSONArray.Create;
    for LVisita in LLista do
      LDados.AddElement(VisitaParaJSON(LVisita));
    ARes.Send<TJSONObject>(RespostaPaginada(LDados, LPag, LTotal, LServidorEm));
  finally
    LLista.Free;
  end;
end;

procedure Criar(AReq: THorseRequest; ARes: THorseResponse);
var
  LVisita: TVisita;
  LJaExistia: Boolean;
begin
  LVisita := VisitaDoJSON(CorpoJSON(AReq));
  try
    LVisita.UsuarioId := UsuarioLogado(AReq);
    Service.Criar(LVisita, LJaExistia);
    if LJaExistia then
      ARes.Send<TJSONObject>(VisitaParaJSON(LVisita)).Status(THTTPStatus.OK)
    else
      ARes.Send<TJSONObject>(VisitaParaJSON(LVisita)).Status(THTTPStatus.Created);
  finally
    LVisita.Free;
  end;
end;

class procedure TControllerVisita.Registrar;
begin
  THorse.Route('/visitas')
    .Get(Listar)
    .Post(Criar);
end;

end.
