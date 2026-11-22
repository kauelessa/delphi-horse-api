unit Tests.Model.Imagem;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsImagem = class
  public
    [Test]
    procedure JpegReconhecido;
    [Test]
    procedure PngReconhecido;
    [Test]
    procedure TextoNaoEhImagem;
    [Test]
    procedure VazioNaoEhImagem;
    [Test]
    procedure Base64ValidoVoltaOsBytes;
    [Test]
    procedure Base64InvalidoLevantaRequisicaoInvalida;
  end;

  [TestFixture]
  TTestsUuid = class
  public
    [Test]
    [TestCase('Minusculo', '3f2b8c1e-9d4a-4e7b-8c21-5a6f0e9d1b23')]
    [TestCase('Maiusculo', '3F2B8C1E-9D4A-4E7B-8C21-5A6F0E9D1B23')]
    procedure Valido(const AUuid: string);
    [Test]
    [TestCase('SemHifen', '3f2b8c1e9d4a4e7b8c215a6f0e9d1b23')]
    [TestCase('Curto', '3f2b8c1e-9d4a-4e7b-8c21-5a6f0e9d1b2')]
    [TestCase('Letra', '3f2b8c1e-9d4a-4e7b-8c21-5a6f0e9d1bzz')]
    [TestCase('ComChaves', '{3f2b8c1e-9d4a-4e7b-8c21-5a6f0e9d1b23}')]
    [TestCase('Vazio', '')]
    procedure Invalido(const AUuid: string);
  end;

implementation

uses
  System.SysUtils, Model.Imagem, Model.Uuid, Infra.Excecoes;

procedure TTestsImagem.JpegReconhecido;
begin
  Assert.IsTrue(TImagem.EhJpeg(TBytes.Create($FF, $D8, $FF, $E0, 0, 16)));
  Assert.IsFalse(TImagem.EhPng(TBytes.Create($FF, $D8, $FF, $E0, 0, 16)));
end;

procedure TTestsImagem.PngReconhecido;
begin
  Assert.IsTrue(TImagem.EhPng(TBytes.Create($89, $50, $4E, $47, $0D, $0A, $1A, $0A, 0)));
  Assert.IsFalse(TImagem.EhJpeg(TBytes.Create($89, $50, $4E, $47, $0D, $0A, $1A, $0A, 0)));
end;

procedure TTestsImagem.TextoNaoEhImagem;
begin
  Assert.IsFalse(TImagem.EhPng(TEncoding.UTF8.GetBytes('isto é texto, não PNG')));
  Assert.IsFalse(TImagem.EhJpeg(TEncoding.UTF8.GetBytes('isto é texto, não JPEG')));
end;

procedure TTestsImagem.VazioNaoEhImagem;
begin
  Assert.IsFalse(TImagem.EhPng(nil));
  Assert.IsFalse(TImagem.EhJpeg(nil));
end;

procedure TTestsImagem.Base64ValidoVoltaOsBytes;
var
  LBytes: TBytes;
begin
  LBytes := TImagem.DeBase64('iVBORw0KGgo=');
  Assert.AreEqual(8, Length(LBytes));
  Assert.IsTrue(TImagem.EhPng(LBytes));
end;

procedure TTestsImagem.Base64InvalidoLevantaRequisicaoInvalida;
begin
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TImagem.DeBase64('isto não é base64!!');
    end,
    ERequisicaoInvalida, 'Imagem em base64 inválida.');
end;

procedure TTestsUuid.Valido(const AUuid: string);
begin
  Assert.IsTrue(TUuid.Valido(AUuid), AUuid);
end;

procedure TTestsUuid.Invalido(const AUuid: string);
begin
  Assert.IsFalse(TUuid.Valido(AUuid), AUuid);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsImagem);
  TDUnitX.RegisterTestFixture(TTestsUuid);

end.
