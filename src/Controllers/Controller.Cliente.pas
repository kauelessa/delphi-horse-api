unit Controller.Cliente;

interface

type
  TControllerCliente = class
  public
    class procedure Registrar; static;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, Horse, Horse.Commons,
  Infra.Excecoes,
  Model.Cliente, Model.Paginacao, Repository.Cliente, Repository.Relogio, Service.Cliente,
  Controller.Utils;

function Service: IClienteService;
begin
  Result := TClienteService.Create(TClienteRepository.Create, TRelogioRepository.Create);
end;

function ClienteParaJSON(ACliente: TCliente): TJSONObject;
begin
  Result := TJSONObject.Create
    .AddPair('id', TJSONNumber.Create(ACliente.Id))
    .AddPair('nome', ACliente.Nome)
    .AddPair('documento', ACliente.Documento)
    .AddPair('email', ACliente.Email)
    .AddPair('telefone', ACliente.Telefone)
    .AddPair('ativo', TJSONBool.Create(ACliente.Ativo))
    .AddPair('atualizadoEm', DataJSON(ACliente.AtualizadoEm))
    .AddPair('temFoto', TJSONBool.Create(ACliente.TemFoto));

  if ACliente.Uuid = '' then
    Result.AddPair('uuid', TJSONNull.Create)
  else
    Result.AddPair('uuid', ACliente.Uuid);

  if ACliente.TemLocalizacao then
    Result
      .AddPair('latitude', TJSONNumber.Create(ACliente.Latitude))
      .AddPair('longitude', TJSONNumber.Create(ACliente.Longitude))
  else
    Result
      .AddPair('latitude', TJSONNull.Create)
      .AddPair('longitude', TJSONNull.Create);
end;

function ClienteDoJSON(AJson: TJSONObject): TCliente;
var
  LLat, LLon: Double;
begin
  Result := TCliente.Create;
  try
    Result.Uuid := LerTexto(AJson, 'uuid');
    if LerLocalizacao(AJson, LLat, LLon) then
      Result.DefinirLocalizacao(LLat, LLon);
    Result.Nome := LerTexto(AJson, 'nome');
    Result.Documento := LerTexto(AJson, 'documento');
    Result.Email := LerTexto(AJson, 'email');
    Result.Telefone := LerTexto(AJson, 'telefone');
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
  LLista: TObjectList<TCliente>;
  LDados: TJSONArray;
  LCliente: TCliente;
begin
  LPag := PaginacaoDaQuery(AReq);
  LLista := Service.Listar(LPag, AReq.Query.Field('busca').AsString, FiltroSyncDaQuery(AReq),
    LTotal, LServidorEm);
  try
    LDados := TJSONArray.Create;
    for LCliente in LLista do
      LDados.AddElement(ClienteParaJSON(LCliente));
    ARes.Send<TJSONObject>(RespostaPaginada(LDados, LPag, LTotal, LServidorEm));
  finally
    LLista.Free;
  end;
end;

procedure Buscar(AReq: THorseRequest; ARes: THorseResponse);
var
  LCliente: TCliente;
begin
  LCliente := Service.Buscar(IdDaRota(AReq));
  try
    ARes.Send<TJSONObject>(ClienteParaJSON(LCliente));
  finally
    LCliente.Free;
  end;
end;

procedure Criar(AReq: THorseRequest; ARes: THorseResponse);
var
  LCliente: TCliente;
  LJaExistia: Boolean;
begin
  LCliente := ClienteDoJSON(CorpoJSON(AReq));
  try
    Service.Criar(LCliente, LJaExistia);
    // reenvio do app com o mesmo uuid: 200 com o que já estava gravado
    if LJaExistia then
      ARes.Send<TJSONObject>(ClienteParaJSON(LCliente)).Status(THTTPStatus.OK)
    else
      ARes.Send<TJSONObject>(ClienteParaJSON(LCliente)).Status(THTTPStatus.Created);
  finally
    LCliente.Free;
  end;
end;

procedure Atualizar(AReq: THorseRequest; ARes: THorseResponse);
var
  LCliente: TCliente;
begin
  LCliente := ClienteDoJSON(CorpoJSON(AReq));
  try
    LCliente.Id := IdDaRota(AReq);
    Service.Atualizar(LCliente);
    ARes.Send<TJSONObject>(ClienteParaJSON(LCliente));
  finally
    LCliente.Free;
  end;
end;

procedure GravarLocalizacao(AReq: THorseRequest; ARes: THorseResponse);
var
  LId: Integer;
  LLat, LLon: Double;
  LCliente: TCliente;
begin
  LId := IdDaRota(AReq);
  if not LerLocalizacao(CorpoJSON(AReq), LLat, LLon) then
    raise ERequisicaoInvalida.Create('Informe latitude e longitude.');
  Service.GravarLocalizacao(LId, LLat, LLon);

  LCliente := Service.Buscar(LId);
  try
    ARes.Send<TJSONObject>(ClienteParaJSON(LCliente));
  finally
    LCliente.Free;
  end;
end;

// corpo binário (Content-Type: image/jpeg), não JSON
procedure GravarFoto(AReq: THorseRequest; ARes: THorseResponse);
begin
  Service.GravarFoto(IdDaRota(AReq), AReq.RawWebRequest.RawContent);
  ARes.Status(THTTPStatus.NoContent);
end;

procedure LerFoto(AReq: THorseRequest; ARes: THorseResponse);
var
  LStream: TBytesStream;
begin
  LStream := TBytesStream.Create(Service.LerFoto(IdDaRota(AReq)));
  try
    ARes.SendFile(LStream, 'foto.jpg', 'image/jpeg');
  finally
    LStream.Free;
  end;
end;

procedure Excluir(AReq: THorseRequest; ARes: THorseResponse);
begin
  Service.Excluir(IdDaRota(AReq));
  ARes.Status(THTTPStatus.NoContent);
end;

class procedure TControllerCliente.Registrar;
begin
  THorse.Route('/clientes')
    .Get(Listar)
    .Post(Criar);

  THorse.Route('/clientes/:id')
    .Get(Buscar)
    .Put(Atualizar)
    .Delete(Excluir);

  THorse.Put('/clientes/:id/localizacao', GravarLocalizacao);
  THorse.Route('/clientes/:id/foto')
    .Get(LerFoto)
    .Put(GravarFoto);
end;

end.
