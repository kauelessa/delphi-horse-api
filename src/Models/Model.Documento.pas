unit Model.Documento;

{ Validação de CPF e CNPJ pelos dígitos verificadores (módulo 11).

  Desde julho/2026 a Receita Federal emite CNPJ alfanumérico: as 12
  primeiras posições aceitam 0-9 e A-Z, e os 2 dígitos verificadores
  continuam numéricos. O cálculo é o mesmo do CNPJ tradicional, usando
  como valor de cada caractere o seu código ASCII menos 48 — o que
  mantém os dígitos 0-9 com o valor de sempre e dá A=17, B=18 ... Z=42. }

interface

type
  TDocumento = class
  public
    { Remove máscara (pontos, barra, traço, espaços) e converte para maiúsculas. }
    class function Normalizar(const AValor: string): string; static;
    class function CPFValido(const ACPF: string): Boolean; static;
    class function CNPJValido(const ACNPJ: string): Boolean; static;
    { CPF (11 caracteres) ou CNPJ (14). Espera o valor já normalizado. }
    class function Valido(const ADocumento: string): Boolean; static;
  end;

implementation

uses
  System.SysUtils;

function TodosIguais(const AValor: string): Boolean;
var
  I: Integer;
begin
  for I := 2 to Length(AValor) do
    if AValor[I] <> AValor[1] then
      Exit(False);
  Result := True;
end;

function SomenteDigitos(const AValor: string): Boolean;
var
  LCaractere: Char;
begin
  for LCaractere in AValor do
    if not CharInSet(LCaractere, ['0'..'9']) then
      Exit(False);
  Result := True;
end;

class function TDocumento.Normalizar(const AValor: string): string;
var
  LCaractere: Char;
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create(Length(AValor));
  try
    for LCaractere in AValor.ToUpper do
      if CharInSet(LCaractere, ['0'..'9', 'A'..'Z']) then
        LBuilder.Append(LCaractere);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TDocumento.CPFValido(const ACPF: string): Boolean;

  function Digito(ATamanho: Integer): Integer;
  var
    I, LSoma: Integer;
  begin
    LSoma := 0;
    for I := 1 to ATamanho do
      LSoma := LSoma + (Ord(ACPF[I]) - Ord('0')) * (ATamanho + 2 - I);
    Result := (LSoma * 10) mod 11;
    if Result = 10 then
      Result := 0;
  end;

begin
  if (Length(ACPF) <> 11) or not SomenteDigitos(ACPF) or TodosIguais(ACPF) then
    Exit(False);

  Result := (Digito(9) = Ord(ACPF[10]) - Ord('0')) and
            (Digito(10) = Ord(ACPF[11]) - Ord('0'));
end;

class function TDocumento.CNPJValido(const ACNPJ: string): Boolean;
const
  PESOS: array[1..13] of Integer = (6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);

  function Digito(ATamanho: Integer): Integer;
  var
    I, LSoma, LDesloc: Integer;
  begin
    // 1º dígito usa os pesos 5..2, 9..2; o 2º usa 6..2, 9..2
    LDesloc := 13 - ATamanho;
    LSoma := 0;
    for I := 1 to ATamanho do
      LSoma := LSoma + (Ord(ACNPJ[I]) - Ord('0')) * PESOS[I + LDesloc];
    Result := LSoma mod 11;
    if Result < 2 then
      Result := 0
    else
      Result := 11 - Result;
  end;

var
  I: Integer;
begin
  if (Length(ACNPJ) <> 14) or TodosIguais(ACNPJ) then
    Exit(False);

  for I := 1 to 12 do
    if not CharInSet(ACNPJ[I], ['0'..'9', 'A'..'Z']) then
      Exit(False);

  if not SomenteDigitos(Copy(ACNPJ, 13, 2)) then
    Exit(False);

  Result := (Digito(12) = Ord(ACNPJ[13]) - Ord('0')) and
            (Digito(13) = Ord(ACNPJ[14]) - Ord('0'));
end;

class function TDocumento.Valido(const ADocumento: string): Boolean;
begin
  case Length(ADocumento) of
    11: Result := CPFValido(ADocumento);
    14: Result := CNPJValido(ADocumento);
  else
    Result := False;
  end;
end;

end.
