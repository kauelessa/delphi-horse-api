unit Tests.Infra.JWT;

interface

uses
  DUnitX.TestFramework,
  Infra.Config;

type
  [TestFixture]
  TTestsJWT = class
  private
    function Config(const AEmissor: string = 'delphi-horse-api'): TConfigJWT;
    function TokenDoUsuario(AId: Integer): string;
  public
    [Test]
    procedure TokenGeradoDevolveIdDoUsuario;
    [Test]
    procedure TokenAdulteradoDevolveZero;
    [Test]
    procedure TokenDeOutroEmissorDevolveZero;
    [Test]
    procedure TokenVazioOuLixoDevolveZero;
  end;

implementation

uses
  System.SysUtils,
  Model.Usuario,
  Infra.JWT;

function TTestsJWT.Config(const AEmissor: string): TConfigJWT;
begin
  Result.Segredo := 'segredo-ficticio-de-teste-com-mais-de-32-caracteres';
  Result.Emissor := AEmissor;
  Result.ExpiracaoMinutos := 60;
end;

function TTestsJWT.TokenDoUsuario(AId: Integer): string;
var
  LUsuario: TUsuario;
begin
  LUsuario := TUsuario.Create;
  try
    LUsuario.Id := AId;
    LUsuario.Nome := 'Ana Vendedora';
    LUsuario.Login := 'ana';
    Result := TGeradorTokenJWT.Create(Config).Gerar(LUsuario).Token;
  finally
    LUsuario.Free;
  end;
end;

procedure TTestsJWT.TokenGeradoDevolveIdDoUsuario;
begin
  Assert.AreEqual(7, TValidadorTokenJWT.UsuarioDoToken(TokenDoUsuario(7), Config));
end;

procedure TTestsJWT.TokenAdulteradoDevolveZero;
var
  LToken: string;
begin
  LToken := TokenDoUsuario(7);
  // troca o último caractere da assinatura
  if LToken.EndsWith('A') then
    LToken := LToken.Remove(LToken.Length - 1) + 'B'
  else
    LToken := LToken.Remove(LToken.Length - 1) + 'A';
  Assert.AreEqual(0, TValidadorTokenJWT.UsuarioDoToken(LToken, Config));
end;

procedure TTestsJWT.TokenDeOutroEmissorDevolveZero;
begin
  Assert.AreEqual(0, TValidadorTokenJWT.UsuarioDoToken(TokenDoUsuario(7), Config('outro-emissor')));
end;

procedure TTestsJWT.TokenVazioOuLixoDevolveZero;
begin
  Assert.AreEqual(0, TValidadorTokenJWT.UsuarioDoToken('', Config));
  Assert.AreEqual(0, TValidadorTokenJWT.UsuarioDoToken('abc.def.ghi', Config));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsJWT);

end.
