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
  Service.Auth;

procedure PostLogin(AReq: THorseRequest; ARes: THorseResponse);
var
  LBody: TJSONObject;
  LService: IAuthService;
  LToken: TTokenAcesso;
begin
  LBody := AReq.Body<TJSONObject>;
  if not Assigned(LBody) then
    raise ERequisicaoInvalida.Create('Body inválido, envie um JSON');

  LService := TAuthService.Create(TUsuarioRepository.Create, TGeradorTokenJWT.Create(TConfig.JWT));
  LToken := LService.Login(LBody.GetValue<string>('login', ''), LBody.GetValue<string>('senha', ''));

  ARes.Send<TJSONObject>(
    TJSONObject.Create
      .AddPair('token', LToken.Token)
      .AddPair('tipo', 'Bearer')
      .AddPair('expiraEm', DateToISO8601(LToken.ExpiraEm, False))
  ).Status(THTTPStatus.OK);
end;

class procedure TControllerAuth.Registrar;
begin
  THorse.Post('/auth/login', PostLogin);
end;

end.
