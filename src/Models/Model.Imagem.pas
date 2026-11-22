unit Model.Imagem;

interface

uses
  System.SysUtils;

type
  // confere o tipo pela assinatura dos primeiros bytes, não pelo que o cliente declarou
  TImagem = class
  public
    class function EhJpeg(const ABytes: TBytes): Boolean; static;
    class function EhPng(const ABytes: TBytes): Boolean; static;
    class function DeBase64(const ATexto: string): TBytes; static;
  end;

implementation

uses
  System.NetEncoding, Infra.Excecoes;

function ComecaCom(const ABytes: TBytes; const AAssinatura: array of Byte): Boolean;
var
  I: Integer;
begin
  if Length(ABytes) < Length(AAssinatura) then
    Exit(False);
  for I := 0 to High(AAssinatura) do
    if ABytes[I] <> AAssinatura[I] then
      Exit(False);
  Result := True;
end;

class function TImagem.EhJpeg(const ABytes: TBytes): Boolean;
begin
  Result := ComecaCom(ABytes, [$FF, $D8, $FF]);
end;

class function TImagem.EhPng(const ABytes: TBytes): Boolean;
begin
  Result := ComecaCom(ABytes, [$89, $50, $4E, $47, $0D, $0A, $1A, $0A]);
end;

class function TImagem.DeBase64(const ATexto: string): TBytes;
var
  LTexto: string;
  C: Char;
begin
  // o decodificador do Delphi ignora lixo em silêncio; aqui lixo é erro
  LTexto := ATexto.Trim;
  if (LTexto = '') or (Length(LTexto) mod 4 <> 0) then
    raise ERequisicaoInvalida.Create('Imagem em base64 inválida.');
  for C in LTexto do
    if not CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '+', '/', '=']) then
      raise ERequisicaoInvalida.Create('Imagem em base64 inválida.');
  Result := TNetEncoding.Base64.DecodeStringToBytes(LTexto);
end;

end.
