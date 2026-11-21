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
