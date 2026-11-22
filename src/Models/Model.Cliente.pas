unit Model.Cliente;

interface

type
  TCliente = class
  private
    FId: Integer;
    FNome: string;
    FDocumento: string;
    FEmail: string;
    FTelefone: string;
    FAtivo: Boolean;
    FAtualizadoEm: TDateTime;
    FUuid: string;
    FLatitude: Double;
    FLongitude: Double;
    FTemLocalizacao: Boolean;
    FTemFoto: Boolean;
  public
    procedure DefinirLocalizacao(ALatitude, ALongitude: Double);

    property Id: Integer read FId write FId;
    property Nome: string read FNome write FNome;
    property Documento: string read FDocumento write FDocumento;
    property Email: string read FEmail write FEmail;
    property Telefone: string read FTelefone write FTelefone;
    property Ativo: Boolean read FAtivo write FAtivo;
    property AtualizadoEm: TDateTime read FAtualizadoEm write FAtualizadoEm;
    property Uuid: string read FUuid write FUuid; // só nos criados pelo app
    property Latitude: Double read FLatitude;
    property Longitude: Double read FLongitude;
    property TemLocalizacao: Boolean read FTemLocalizacao;
    property TemFoto: Boolean read FTemFoto write FTemFoto;
  end;

implementation

procedure TCliente.DefinirLocalizacao(ALatitude, ALongitude: Double);
begin
  FLatitude := ALatitude;
  FLongitude := ALongitude;
  FTemLocalizacao := True;
end;

end.
