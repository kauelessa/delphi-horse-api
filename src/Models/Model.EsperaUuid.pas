unit Model.EsperaUuid;

interface

uses
  System.SysUtils;

{ Dois envios com o mesmo UUID ao mesmo tempo: o segundo bate no índice único
  enquanto o primeiro ainda não confirmou a transação, e por isso ainda não
  enxerga o registro. Tenta reler algumas vezes (até ~1 s) antes de desistir;
  quem chama devolve 409 e o app reenvia. }
function EsperarPorUuid(const ACarregar: TFunc<Boolean>): Boolean;

implementation

const
  TENTATIVAS = 10;
  INTERVALO_MS = 100;

function EsperarPorUuid(const ACarregar: TFunc<Boolean>): Boolean;
var
  I: Integer;
begin
  for I := 1 to TENTATIVAS do
  begin
    if ACarregar() then
      Exit(True);
    Sleep(INTERVALO_MS);
  end;
  Result := False;
end;

end.
