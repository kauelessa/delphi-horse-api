unit Model.CodigoBarras;

interface

type
  TCodigoBarras = class
  public
    // GTIN-8, GTIN-12 (UPC-A), GTIN-13 (EAN-13) ou GTIN-14, só dígitos, com dígito verificador
    class function Valido(const ACodigo: string): Boolean; static;
  end;

implementation

uses
  System.SysUtils;

class function TCodigoBarras.Valido(const ACodigo: string): Boolean;
var
  I, LSoma, LPeso: Integer;
begin
  if not (Length(ACodigo) in [8, 12, 13, 14]) then
    Exit(False);
  for I := 1 to Length(ACodigo) do
    if not CharInSet(ACodigo[I], ['0'..'9']) then
      Exit(False);

  // da direita para a esquerda, sem o verificador: pesos 3, 1, 3, 1...
  LSoma := 0;
  LPeso := 3;
  for I := Length(ACodigo) - 1 downto 1 do
  begin
    Inc(LSoma, (Ord(ACodigo[I]) - Ord('0')) * LPeso);
    LPeso := 4 - LPeso;
  end;
  Result := (10 - LSoma mod 10) mod 10 = Ord(ACodigo[Length(ACodigo)]) - Ord('0');
end;

end.
