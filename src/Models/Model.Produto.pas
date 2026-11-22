unit Model.Produto;

interface

type
  TProduto = class
  private
    FId: Integer;
    FDescricao: string;
    FPreco: Currency;
    FEstoque: Integer;
    FCodigoBarras: string;
    FAtivo: Boolean;
    FAtualizadoEm: TDateTime;
  public
    property Id: Integer read FId write FId;
    property Descricao: string read FDescricao write FDescricao;
    property Preco: Currency read FPreco write FPreco;
    property Estoque: Integer read FEstoque write FEstoque;
    property CodigoBarras: string read FCodigoBarras write FCodigoBarras; // vazio = sem código
    property Ativo: Boolean read FAtivo write FAtivo;
    property AtualizadoEm: TDateTime read FAtualizadoEm write FAtualizadoEm;
  end;

implementation

end.
