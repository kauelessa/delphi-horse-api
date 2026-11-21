unit Model.Produto;

interface

type
  TProduto = class
  private
    FId: Integer;
    FDescricao: string;
    FPreco: Currency;
    FEstoque: Integer;
    FAtivo: Boolean;
  public
    property Id: Integer read FId write FId;
    property Descricao: string read FDescricao write FDescricao;
    property Preco: Currency read FPreco write FPreco;
    property Estoque: Integer read FEstoque write FEstoque;
    property Ativo: Boolean read FAtivo write FAtivo;
  end;

implementation

end.
