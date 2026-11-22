unit Model.Relatorio;

// Dados já prontos para imprimir: os geradores (Fortes, FastReport) só desenham.

interface

uses
  System.SysUtils, Model.Pedido;

type
  TCabecalhoRel = record
    Titulo: string;
    Inicio: TDateTime;
    Fim: TDateTime;
    Vendedor: string;
  end;

  TLinhaRelPedido = record
    Id: Integer;
    Data: TDateTime;
    Cliente: string;
    Status: string;
    NotaNumero: Integer; // 0 = não faturado
    Valor: Currency;
  end;

  TRelPedidos = record
    Cabecalho: TCabecalhoRel;
    Linhas: TArray<TLinhaRelPedido>;
    function Total: Currency; // só os não cancelados
  end;

  TLinhaRelVendaProduto = record
    Produto: string;
    Quantidade: Integer;
    Valor: Currency;
  end;

  TRelVendasProduto = record
    Cabecalho: TCabecalhoRel;
    Linhas: TArray<TLinhaRelVendaProduto>; // já ordenadas do que mais vendeu
    function Total: Currency;
  end;

  TLinhaRelVisita = record
    Data: TDateTime;
    Cliente: string;
    Motivo: string;
    Observacao: string;
  end;

  TRelVisitas = record
    Cabecalho: TCabecalhoRel;
    Linhas: TArray<TLinhaRelVisita>;
  end;

  // espelho de um pedido (para mandar ao cliente); Pedido pertence a quem criou o record
  TRelEspelho = record
    Pedido: TPedido;
    Assinatura: TBytes; // PNG; vazio = sem assinatura
  end;

implementation

function TRelPedidos.Total: Currency;
var
  L: TLinhaRelPedido;
begin
  Result := 0;
  for L in Linhas do
    if L.Status <> 'CANCELADO' then
      Result := Result + L.Valor;
end;

function TRelVendasProduto.Total: Currency;
var
  L: TLinhaRelVendaProduto;
begin
  Result := 0;
  for L in Linhas do
    Result := Result + L.Valor;
end;

end.
