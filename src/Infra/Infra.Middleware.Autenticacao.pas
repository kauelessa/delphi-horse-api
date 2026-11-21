unit Infra.Middleware.Autenticacao;

// Middleware de autenticação por Bearer token (JWT).
//
// Registrado globalmente com THorse.Use, no mesmo modelo do horse-jwt:
// toda rota exige token, exceto as listadas em ROTAS_PUBLICAS. Assim uma
// rota nova nasce protegida por padrão — esquecer de proteger é mais
// perigoso do que esquecer de liberar.
//
// Precisa vir depois do Infra.Middleware.Erros no pipeline, para que o
// ENaoAutorizado vire { "erro": ... } com status 401.

interface

uses
  System.SysUtils,
  Horse;

procedure Autenticar(AReq: THorseRequest; ARes: THorseResponse; ANext: TProc);

implementation

uses
  System.StrUtils,
  Infra.Config,
  Infra.Excecoes,
  Infra.JWT;

const
  ROTAS_PUBLICAS: array[0..1] of string = ('/health', '/auth/login');
  PREFIXO_BEARER = 'Bearer ';

function RotaPublica(const ACaminho: string): Boolean;
var
  LCaminho: string;
begin
  LCaminho := ACaminho.ToLower;
  if (LCaminho.Length > 1) and LCaminho.EndsWith('/') then
    LCaminho := LCaminho.Remove(LCaminho.Length - 1);
  Result := MatchText(LCaminho, ROTAS_PUBLICAS);
end;

procedure Autenticar(AReq: THorseRequest; ARes: THorseResponse; ANext: TProc);
var
  LAuthorization: string;
begin
  // Preflight de CORS não carrega o token.
  if SameText(AReq.RawWebRequest.Method, 'OPTIONS') or RotaPublica(AReq.RawWebRequest.PathInfo) then
  begin
    ANext();
    Exit;
  end;

  LAuthorization := AReq.RawWebRequest.Authorization;
  if not LAuthorization.StartsWith(PREFIXO_BEARER, True) then
    raise ENaoAutorizado.Create('Token não informado. Use o cabeçalho Authorization: Bearer <token>.');

  if not TValidadorTokenJWT.Valido(LAuthorization.Substring(Length(PREFIXO_BEARER)).Trim, TConfig.JWT) then
    raise ENaoAutorizado.Create('Token inválido ou expirado.');

  ANext();
end;

end.
