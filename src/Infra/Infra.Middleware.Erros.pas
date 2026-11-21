unit Infra.Middleware.Erros;

// Middleware que converte exceções em respostas JSON padronizadas:
//   { "erro": "mensagem" }
// com o status HTTP adequado. Deve ser registrado depois do Jhonson,
// para que a resposta seja serializada por ele.

interface

uses
  System.SysUtils,
  Horse;

procedure TratarErros(AReq: THorseRequest; ARes: THorseResponse; ANext: TProc);

// Callback de erro do Jhonson (corpo vazio ou JSON malformado em POST/PUT/PATCH
// com Content-Type: application/json). Sem ele o Jhonson responde o texto puro
// "Invalid JSON", fora do padrão { "erro": ... } da API.
procedure ResponderJSONInvalido(ARes: THorseResponse; const AErro: string);

implementation

uses
  System.JSON,
  Horse.Commons,
  Horse.Exception,
  Horse.Exception.Interrupted,
  Infra.Excecoes;

procedure Responder(ARes: THorseResponse; AStatus: Integer; const AMensagem: string);
begin
  ARes
    .Send<TJSONObject>(TJSONObject.Create.AddPair('erro', AMensagem))
    .Status(AStatus);
end;

procedure ResponderJSONInvalido(ARes: THorseResponse; const AErro: string);
var
  LJson: TJSONObject;
begin
  // 'Empty JSON' é a mensagem que o Jhonson usa para corpo vazio; o resto
  // é a mensagem do parser, que não vale a pena expor ao cliente.
  LJson := TJSONObject.Create;
  try
    if SameText(AErro, 'Empty JSON') then
      LJson.AddPair('erro', 'Corpo da requisição vazio.')
    else
      LJson.AddPair('erro', 'JSON inválido no corpo da requisição.');

    // O Jhonson interrompe o pipeline logo depois deste callback, então
    // ninguém serializaria um Send<TJSONObject>: o texto já vai pronto.
    ARes
      .Send(LJson.ToJSON)
      .ContentType('application/json; charset=UTF-8')
      .Status(THTTPStatus.BadRequest);
  finally
    LJson.Free;
  end;
end;

procedure TratarErros(AReq: THorseRequest; ARes: THorseResponse; ANext: TProc);
begin
  try
    ANext();
  except
    // Interrupção intencional do pipeline do Horse: não é erro.
    on E: EHorseCallbackInterrupted do
      raise;
    on E: EApiErro do
      Responder(ARes, E.Status, E.Message);
    // Lançada pelo próprio Horse (ex.: Params.Field(...).Required).
    // A mensagem fica em Error, não necessariamente em Message.
    on E: EHorseException do
      if E.Error.IsEmpty then
        Responder(ARes, Integer(E.Status), E.Message)
      else
        Responder(ARes, Integer(E.Status), E.Error);
    on E: Exception do
    begin
      // Detalhes vão só para o log; o cliente recebe mensagem genérica.
      Writeln(ErrOutput, Format('[%s] %s %s -> %s: %s', [
        FormatDateTime('yyyy-mm-dd hh:nn:ss', Now),
        AReq.RawWebRequest.Method, AReq.RawWebRequest.PathInfo, E.ClassName, E.Message]));
      Responder(ARes, Integer(THTTPStatus.InternalServerError), 'Erro interno do servidor.');
    end;
  end;
end;

end.
