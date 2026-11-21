unit Model.Usuario;

interface

type
  TUsuario = class
  private
    FId: Integer;
    FNome: string;
    FLogin: string;
    FSenhaHash: string;
    FAtivo: Boolean;
  public
    property Id: Integer read FId write FId;
    property Nome: string read FNome write FNome;
    property Login: string read FLogin write FLogin;
    property SenhaHash: string read FSenhaHash write FSenhaHash;
    property Ativo: Boolean read FAtivo write FAtivo;
  end;

implementation

end.
