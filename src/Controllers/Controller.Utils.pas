unit Controller.Utils;

// Funções de apoio dos controllers: leitura de parâmetros/corpo e montagem
// de respostas. Erros de formato viram 400 aqui mesmo, antes de chegar no Service.

interface

uses
  System.JSON, Horse, Model.Paginacao;

function IdDaRota(AReq: THorseRequest): Integer;
function PaginacaoDaQuery(AReq: THorseRequest): TPaginacao;
function CorpoJSON(AReq: THorseRequest): TJSONObject;
function UsuarioLogado(AReq: THorseRequest): Integer; // 0 em rota pública

// campo ausente ou null devolve vazio/zero; tipo errado levanta 400
function LerTexto(AJson: TJSONObject; const ACampo: string): string;
function LerInteiro(AJson: TJSONObject; const ACampo: string): Integer;
function LerValor(AJson: TJSONObject; const ACampo: string): Currency;

function NumeroJSON(AValor: Currency): TJSONNumber;
function RespostaPaginada(ADados: TJSONArray; const APaginacao: TPaginacao; ATotal: Integer): TJSONObject;

implementation

uses
  System.SysUtils, Infra.Excecoes, Infra.Middleware.Autenticacao;

function UsuarioLogado(AReq: THorseRequest): Integer;
var
  LSessao: TUsuarioLogado;
begin
  LSessao := AReq.Session<TUsuarioLogado>;
  if Assigned(LSessao) then
    Result := LSessao.Id
  else
    Result := 0;
end;

function IdDaRota(AReq: THorseRequest): Integer;
begin
  // Field/Required do Horse já devolve 400 se vier "abc" no lugar do id
  Result := AReq.Params.Field('id')
    .Required
    .RequiredMessage('Informe o id.')
    .InvalidFormatMessage('Id inválido.')
    .AsInteger;

  if Result <= 0 then
    raise ERequisicaoInvalida.Create('Id inválido.');
end;

function PaginacaoDaQuery(AReq: THorseRequest): TPaginacao;
begin
  Result := TPaginacao.Criar(
    AReq.Query.Field('pagina').InvalidFormatMessage('"pagina" deve ser um número.').AsInteger,
    AReq.Query.Field('limite').InvalidFormatMessage('"limite" deve ser um número.').AsInteger);
end;

function CorpoJSON(AReq: THorseRequest): TJSONObject;
begin
  Result := AReq.Body<TJSONObject>;
  if Result = nil then
    raise ERequisicaoInvalida.Create('Body inválido, envie um objeto JSON.');
end;

function Campo(AJson: TJSONObject; const ACampo: string): TJSONValue;
begin
  Result := AJson.GetValue(ACampo);
  if Result is TJSONNull then
    Result := nil;
end;

function LerTexto(AJson: TJSONObject; const ACampo: string): string;
var
  LValor: TJSONValue;
begin
  LValor := Campo(AJson, ACampo);
  if LValor = nil then
    Exit('');
  if not (LValor is TJSONString) then
    raise ERequisicaoInvalida.CreateFmt('"%s" deve ser texto.', [ACampo]);
  Result := LValor.Value;
end;

function LerInteiro(AJson: TJSONObject; const ACampo: string): Integer;
var
  LValor: TJSONValue;
begin
  LValor := Campo(AJson, ACampo);
  if LValor = nil then
    Exit(0);
  if not (LValor is TJSONNumber) or not TryStrToInt(LValor.Value, Result) then
    raise ERequisicaoInvalida.CreateFmt('"%s" deve ser um número inteiro.', [ACampo]);
end;

function LerValor(AJson: TJSONObject; const ACampo: string): Currency;
var
  LValor: TJSONValue;
begin
  LValor := Campo(AJson, ACampo);
  if LValor = nil then
    Exit(0);
  if not (LValor is TJSONNumber) or not TryStrToCurr(LValor.Value, Result, TFormatSettings.Invariant) then
    raise ERequisicaoInvalida.CreateFmt('"%s" deve ser um número.', [ACampo]);
end;

function NumeroJSON(AValor: Currency): TJSONNumber;
var
  LValor: Double;
begin
  // não dá pra fazer Double(AValor): é cast de bits, não conversão
  LValor := AValor;
  Result := TJSONNumber.Create(LValor);
end;

function RespostaPaginada(ADados: TJSONArray; const APaginacao: TPaginacao; ATotal: Integer): TJSONObject;
begin
  Result := TJSONObject.Create
    .AddPair('dados', ADados)
    .AddPair('pagina', TJSONNumber.Create(APaginacao.Pagina))
    .AddPair('limite', TJSONNumber.Create(APaginacao.Limite))
    .AddPair('total', TJSONNumber.Create(ATotal));
end;

end.
