unit Infra.Senha;

{ Hash de senhas com PBKDF2-HMAC-SHA256 e salt aleatório.

  Formato armazenado:
    pbkdf2-sha256$<iteracoes>$<salt em base64>$<hash em base64>

  O número de iterações fica gravado junto do hash, então é possível
  aumentá-lo no futuro sem invalidar as senhas já existentes. }

interface

uses
  System.SysUtils;

type
  TSenhaHash = class
  public
    const ITERACOES_PADRAO = 100000;

    class function Gerar(const ASenha: string;
      AIteracoes: Integer = ITERACOES_PADRAO): string; static;
    class function Verificar(const ASenha, AHashArmazenado: string): Boolean; static;
    class function PBKDF2SHA256(const ASenha, ASalt: TBytes;
      AIteracoes, ATamanho: Integer): TBytes; static;
  end;

{ Bytes de um gerador criptograficamente seguro (Random() não serve para
  salt nem para token). }
function BytesAleatorios(ATamanho: Integer): TBytes;

implementation

uses
  System.Math,
  System.Hash,
  System.NetEncoding;

const
  PREFIXO = 'pbkdf2-sha256';
  SEPARADOR = '$';
  TAMANHO_SALT = 16;
  TAMANHO_HASH = 32;

{$IFDEF MSWINDOWS}
const
  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;

function BCryptGenRandom(AAlgoritmo: Pointer; ABuffer: PByte; ATamanho: Cardinal;
  AFlags: Cardinal): Integer; stdcall; external 'bcrypt.dll';
{$ENDIF}

function BytesAleatorios(ATamanho: Integer): TBytes;
begin
  SetLength(Result, ATamanho);
  {$IFDEF MSWINDOWS}
  if BCryptGenRandom(nil, @Result[0], ATamanho, BCRYPT_USE_SYSTEM_PREFERRED_RNG) <> 0 then
    raise Exception.Create('Falha ao gerar bytes aleatórios.');
  {$ELSE}
  raise ENotSupportedException.Create('Gerador aleatório seguro não implementado para esta plataforma.');
  {$ENDIF}
end;

{ Compara em tempo constante para não vazar, pelo tempo de resposta,
  quantos bytes iniciais do hash coincidem. }
function IguaisTempoConstante(const A, B: TBytes): Boolean;
var
  I: Integer;
  LDiferenca: Byte;
begin
  if Length(A) <> Length(B) then
    Exit(False);

  LDiferenca := 0;
  for I := 0 to High(A) do
    LDiferenca := LDiferenca or (A[I] xor B[I]);
  Result := LDiferenca = 0;
end;

class function TSenhaHash.PBKDF2SHA256(const ASenha, ASalt: TBytes;
  AIteracoes, ATamanho: Integer): TBytes;
var
  LBloco, LIteracao, I, LPosicao, LQuantidade: Integer;
  LU, LT: TBytes;
begin
  if AIteracoes < 1 then
    raise EArgumentException.Create('Número de iterações deve ser maior que zero.');

  SetLength(Result, ATamanho);
  LPosicao := 0;
  LBloco := 1;

  while LPosicao < ATamanho do
  begin
    // U1 = HMAC(senha, salt || INT_32_BE(bloco))
    LU := THashSHA2.GetHMACAsBytes(
      ASalt + [Byte(LBloco shr 24), Byte(LBloco shr 16), Byte(LBloco shr 8), Byte(LBloco)],
      ASenha, THashSHA2.TSHA2Version.SHA256);
    LT := Copy(LU);

    // Ui = HMAC(senha, Ui-1);  T = U1 xor U2 xor ... xor Uc
    for LIteracao := 2 to AIteracoes do
    begin
      LU := THashSHA2.GetHMACAsBytes(LU, ASenha, THashSHA2.TSHA2Version.SHA256);
      for I := 0 to High(LT) do
        LT[I] := LT[I] xor LU[I];
    end;

    LQuantidade := Min(Length(LT), ATamanho - LPosicao);
    Move(LT[0], Result[LPosicao], LQuantidade);
    Inc(LPosicao, LQuantidade);
    Inc(LBloco);
  end;
end;

class function TSenhaHash.Gerar(const ASenha: string; AIteracoes: Integer): string;
var
  LSalt, LHash: TBytes;
begin
  LSalt := BytesAleatorios(TAMANHO_SALT);
  LHash := PBKDF2SHA256(TEncoding.UTF8.GetBytes(ASenha), LSalt, AIteracoes, TAMANHO_HASH);

  Result := string.Join(SEPARADOR, [
    PREFIXO,
    AIteracoes.ToString,
    TNetEncoding.Base64.EncodeBytesToString(LSalt),
    TNetEncoding.Base64.EncodeBytesToString(LHash)]);
end;

class function TSenhaHash.Verificar(const ASenha, AHashArmazenado: string): Boolean;
var
  LPartes: TArray<string>;
  LIteracoes: Integer;
  LSalt, LEsperado, LCalculado: TBytes;
begin
  LPartes := AHashArmazenado.Split([SEPARADOR]);
  if (Length(LPartes) <> 4) or (LPartes[0] <> PREFIXO) then
    Exit(False);

  if not TryStrToInt(LPartes[1], LIteracoes) or (LIteracoes < 1) then
    Exit(False);

  try
    LSalt := TNetEncoding.Base64.DecodeStringToBytes(LPartes[2]);
    LEsperado := TNetEncoding.Base64.DecodeStringToBytes(LPartes[3]);
  except
    Exit(False);
  end;

  if (Length(LSalt) = 0) or (Length(LEsperado) = 0) then
    Exit(False);

  LCalculado := PBKDF2SHA256(TEncoding.UTF8.GetBytes(ASenha), LSalt, LIteracoes, Length(LEsperado));
  Result := IguaisTempoConstante(LCalculado, LEsperado);
end;

end.
