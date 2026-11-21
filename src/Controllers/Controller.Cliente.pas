unit Controller.Cliente;

interface

type
  TControllerCliente = class
  public
    class procedure Registrar; static;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.Generics.Collections, Horse, Horse.Commons,
  Model.Cliente, Model.Paginacao, Repository.Cliente, Service.Cliente, Controller.Utils;

function Service: IClienteService;
begin
  Result := TClienteService.Create(TClienteRepository.Create);
end;

function ClienteParaJSON(ACliente: TCliente): TJSONObject;
begin
  Result := TJSONObject.Create
    .AddPair('id', TJSONNumber.Create(ACliente.Id))
    .AddPair('nome', ACliente.Nome)
    .AddPair('documento', ACliente.Documento)
    .AddPair('email', ACliente.Email)
    .AddPair('telefone', ACliente.Telefone);
end;

function ClienteDoJSON(AJson: TJSONObject): TCliente;
begin
  Result := TCliente.Create;
  try
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
  LLista: TObjectList<TCliente>;
  LDados: TJSONArray;
  LCliente: TCliente;
begin
  LPag := PaginacaoDaQuery(AReq);
  LLista := Service.Listar(LPag, LTotal);
  try
    LDados := TJSONArray.Create;
    for LCliente in LLista do
      LDados.AddElement(ClienteParaJSON(LCliente));
    ARes.Send<TJSONObject>(RespostaPaginada(LDados, LPag, LTotal));
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
begin
  LCliente := ClienteDoJSON(CorpoJSON(AReq));
  try
    Service.Criar(LCliente);
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
end;

end.
