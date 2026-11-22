unit Model.Sessao;

interface

type
  // Uma linha por refresh token emitido. Familia agrupa as renovações do mesmo login.
  TSessao = class
  private
    FId: Integer;
    FFamilia: string;
    FUsuarioId: Integer;
    FTokenHash: string;
    FDispositivo: string;
    FCriadaEm: TDateTime;
    FExpiraEm: TDateTime;
    FRevogada: Boolean;
  public
    function Clonar: TSessao;

    property Id: Integer read FId write FId;
    property Familia: string read FFamilia write FFamilia;
    property UsuarioId: Integer read FUsuarioId write FUsuarioId;
    property TokenHash: string read FTokenHash write FTokenHash;
    property Dispositivo: string read FDispositivo write FDispositivo;
    property CriadaEm: TDateTime read FCriadaEm write FCriadaEm;
    property ExpiraEm: TDateTime read FExpiraEm write FExpiraEm;
    property Revogada: Boolean read FRevogada write FRevogada;
  end;

implementation

function TSessao.Clonar: TSessao;
begin
  Result := TSessao.Create;
  Result.Id := FId;
  Result.Familia := FFamilia;
  Result.UsuarioId := FUsuarioId;
  Result.TokenHash := FTokenHash;
  Result.Dispositivo := FDispositivo;
  Result.CriadaEm := FCriadaEm;
  Result.ExpiraEm := FExpiraEm;
  Result.Revogada := FRevogada;
end;

end.
