unit Model.Uuid;

interface

type
  // UUID gerado pelo app (8-4-4-4-12, hexadecimal, sem chaves)
  TUuid = class
  public
    class function Valido(const AUuid: string): Boolean; static;
    class function Normalizar(const AUuid: string): string; static; // minúsculo, sem espaços
  end;

implementation

uses
  System.SysUtils, System.RegularExpressions;

class function TUuid.Valido(const AUuid: string): Boolean;
begin
  Result := TRegEx.IsMatch(AUuid,
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
end;

class function TUuid.Normalizar(const AUuid: string): string;
begin
  Result := LowerCase(Trim(AUuid));
end;

end.
