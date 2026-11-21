unit Tests.Infra.Senha;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsSenhaHash = class
  public
    // Vetor de teste do RFC 7914, seção 11 (PBKDF2-HMAC-SHA256)
    [Test]
    procedure PBKDF2_VetorRFC7914_GeraHashEsperado;
    [Test]
    procedure Verificar_HashGeradoExternamente_RetornaTrue;
    [Test]
    procedure Verificar_SenhaCorreta_RetornaTrue;
    [Test]
    procedure Verificar_SenhaErrada_RetornaFalse;
    [Test]
    procedure Gerar_MesmaSenha_GeraHashesDiferentes;
    [Test]
    procedure Verificar_HashVazio_RetornaFalse;
    [Test]
    [TestCase('PrefixoErrado', 'md5$1000$c2Fs$aGFzaA==')]
    [TestCase('IteracoesInvalidas', 'pbkdf2-sha256$abc$c2Fs$aGFzaA==')]
    [TestCase('PartesFaltando', 'pbkdf2-sha256$1000$c2Fs')]
    procedure Verificar_HashMalformado_RetornaFalse(const AHash: string);
  end;

implementation

uses
  System.SysUtils,
  Infra.Senha;

const
  // Poucas iterações para os testes rodarem rápido.
  ITERACOES_TESTE = 1000;

procedure TTestsSenhaHash.PBKDF2_VetorRFC7914_GeraHashEsperado;
var
  LHash: TBytes;
  LHex: string;
  LByte: Byte;
begin
  LHash := TSenhaHash.PBKDF2SHA256(
    TEncoding.ASCII.GetBytes('passwd'), TEncoding.ASCII.GetBytes('salt'), 1, 64);

  LHex := '';
  for LByte in LHash do
    LHex := LHex + IntToHex(LByte, 2);

  Assert.AreEqual(
    '55AC046E56E3089FEC1691C22544B605F94185216DDE0465E68B9D57C20DACBC' +
    '49CA9CCCF179B645991664B39D77EF317C71B845B1E30BD509112041D3A19783', LHex);
end;

procedure TTestsSenhaHash.Verificar_HashGeradoExternamente_RetornaTrue;
begin
  // Gerado com Python: hashlib.pbkdf2_hmac('sha256', b'senha', b'sal-fixo-teste', 1000, 32)
  Assert.IsTrue(TSenhaHash.Verificar('senha',
    'pbkdf2-sha256$1000$c2FsLWZpeG8tdGVzdGU=$ximxcwpyclKeSdbKxWoRXF90a4Ijx7O1Bi8+5MPro/A='));
end;

procedure TTestsSenhaHash.Verificar_SenhaCorreta_RetornaTrue;
var
  LHash: string;
begin
  LHash := TSenhaHash.Gerar('S3nh@Forte', ITERACOES_TESTE);
  Assert.IsTrue(TSenhaHash.Verificar('S3nh@Forte', LHash));
end;

procedure TTestsSenhaHash.Verificar_SenhaErrada_RetornaFalse;
var
  LHash: string;
begin
  LHash := TSenhaHash.Gerar('S3nh@Forte', ITERACOES_TESTE);
  Assert.IsFalse(TSenhaHash.Verificar('s3nh@forte', LHash));
end;

procedure TTestsSenhaHash.Gerar_MesmaSenha_GeraHashesDiferentes;
begin
  Assert.AreNotEqual(
    TSenhaHash.Gerar('mesma', ITERACOES_TESTE),
    TSenhaHash.Gerar('mesma', ITERACOES_TESTE));
end;

procedure TTestsSenhaHash.Verificar_HashVazio_RetornaFalse;
begin
  Assert.IsFalse(TSenhaHash.Verificar('qualquer', ''));
end;

procedure TTestsSenhaHash.Verificar_HashMalformado_RetornaFalse(const AHash: string);
begin
  Assert.IsFalse(TSenhaHash.Verificar('qualquer', AHash));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsSenhaHash);

end.
