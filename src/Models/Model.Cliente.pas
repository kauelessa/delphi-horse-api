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
  public
    property Id: Integer read FId write FId;
    property Nome: string read FNome write FNome;
    property Documento: string read FDocumento write FDocumento;
    property Email: string read FEmail write FEmail;
    property Telefone: string read FTelefone write FTelefone;
    property Ativo: Boolean read FAtivo write FAtivo;
    property AtualizadoEm: TDateTime read FAtualizadoEm write FAtualizadoEm;
  end;

implementation

end.
