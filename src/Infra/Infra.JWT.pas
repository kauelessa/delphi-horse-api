unit Infra.JWT;

{ Geração e validação de tokens JWT assinados com HS256
  (biblioteca delphi-jose-jwt). }

interface

uses
  Model.Usuario,
  Infra.Config,
  Infra.Token;

type
  TGeradorTokenJWT = class(TInterfacedObject, IGeradorToken)
  private
    FConfig: TConfigJWT;
  public
    constructor Create(const AConfig: TConfigJWT);
    function Gerar(const AUsuario: TUsuario): TTokenAcesso;
  end;

  TValidadorTokenJWT = class
  public
    { True somente se a assinatura confere, o algoritmo é HS256, o emissor
      é o configurado e o token ainda não expirou. Qualquer token
      malformado resulta em False, nunca em exceção. }
    class function Valido(const AToken: string; const AConfig: TConfigJWT): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  JOSE.Core.JWT,
  JOSE.Core.JWK,
  JOSE.Core.Builder;

const
  ALGORITMO = 'HS256';

constructor TGeradorTokenJWT.Create(const AConfig: TConfigJWT);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TGeradorTokenJWT.Gerar(const AUsuario: TUsuario): TTokenAcesso;
var
  LJWT: TJWT;
  LAgora: TDateTime;
begin
  LAgora := Now;
  Result.ExpiraEm := IncMinute(LAgora, FConfig.ExpiracaoMinutos);

  LJWT := TJWT.Create;
  try
    LJWT.Claims.Issuer := FConfig.Emissor;
    LJWT.Claims.Subject := AUsuario.Id.ToString;
    LJWT.Claims.IssuedAt := LAgora;
    LJWT.Claims.Expiration := Result.ExpiraEm;
    LJWT.Claims.SetClaimOfType<string>('nome', AUsuario.Nome);
    LJWT.Claims.SetClaimOfType<string>('login', AUsuario.Login);

    Result.Token := TJOSE.SHA256CompactToken(FConfig.Segredo, LJWT).AsString;
  finally
    LJWT.Free;
  end;
end;

{ TValidadorTokenJWT }

class function TValidadorTokenJWT.Valido(const AToken: string; const AConfig: TConfigJWT): Boolean;
var
  LChave: TJWK;
  LJWT: TJWT;
begin
  if AToken.Trim.IsEmpty then
    Exit(False);

  LChave := TJWK.Create(AConfig.Segredo);
  try
    try
      LJWT := TJOSE.Verify(LChave, AToken);
    except
      // token malformado (base64/JSON inválido) — tratamos como inválido
      Exit(False);
    end;

    if not Assigned(LJWT) then
      Exit(False);

    try
      // Conferir o algoritmo evita aceitar tokens com "alg": "none" ou outro
      // algoritmo que não seja o que emitimos.
      Result := LJWT.Verified
        and (LJWT.Header.Algorithm = ALGORITMO)
        and (LJWT.Claims.Issuer = AConfig.Emissor)
        and LJWT.Claims.HasExpiration
        and (LJWT.Claims.Expiration > Now);
    finally
      LJWT.Free;
    end;
  finally
    LChave.Free;
  end;
end;

end.
