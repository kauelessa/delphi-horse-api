unit Controller.Auth;

interface

type
  TControllerAuth = class
  public
    class procedure Registrar; static;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.DateUtils, Horse, Horse.Commons,
  Infra.Config, Infra.Excecoes, Infra.JWT, Infra.Token, Repository.Usuario,
  Repository.Sessao, Service.Auth;

function Service: IAuthService;
begin
  Result := TAuthService.Create(TUsuarioRepository.Create, TSessaoRepository.Create,
    TGeradorTokenJWT.Create(TConfig.JWT), TConfig.JWT.RefreshDias);
end;

function Corpo(AReq: THorseRequest): TJSONObject;
begin
  Result := AReq.Body<TJSONObject>;
  if not Assigned(Result) then
    raise ERequisicaoInvalida.Create('Body inválido, envie um JSON');
end;

procedure EnviarToken(ARes: THorseResponse; const AToken: TTokenAcesso);
begin
  ARes.Send<TJSONObject>(
    TJSONObject.Create
      .AddPair('token', AToken.Token)
      .AddPair('tipo', 'Bearer')
      .AddPair('expiraEm', DateToISO8601(AToken.ExpiraEm, False))
      .AddPair('refreshToken', AToken.RefreshToken)
      .AddPair('refreshExpiraEm', DateToISO8601(AToken.RefreshExpiraEm, False))
  ).Status(THTTPStatus.OK);
end;

procedure PostLogin(AReq: THorseRequest; ARes: THorseResponse);
var
  LBody: TJSONObject;
begin
  LBody := Corpo(AReq);
  EnviarToken(ARes, Service.Login(LBody.GetValue<string>('login', ''),
    LBody.GetValue<string>('senha', ''), LBody.GetValue<string>('dispositivo', '')));
end;

// { "refreshToken": "..." } -> par novo; o refresh enviado deixa de valer
procedure PostRenovar(AReq: THorseRequest; ARes: THorseResponse);
begin
  EnviarToken(ARes, Service.Renovar(Corpo(AReq).GetValue<string>('refreshToken', '')));
end;

procedure PostSair(AReq: THorseRequest; ARes: THorseResponse);
begin
  Service.Sair(Corpo(AReq).GetValue<string>('refreshToken', ''));
  ARes.Status(THTTPStatus.NoContent);
end;

class procedure TControllerAuth.Registrar;
begin
  THorse.Post('/auth/login', PostLogin);
  THorse.Post('/auth/renovar', PostRenovar);
  THorse.Post('/auth/sair', PostSair);
end;

end.
