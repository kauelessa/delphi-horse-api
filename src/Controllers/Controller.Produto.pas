unit Controller.Produto;

interface

type
  TControllerProduto = class
  public
    class procedure Registrar; static;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.Generics.Collections, Horse, Horse.Commons,
  Model.Produto, Model.Paginacao, Repository.Produto, Service.Produto, Controller.Utils;

function NovoService: IProdutoService;
begin
  Result := TProdutoService.Create(TProdutoRepository.Create);
end;

function ParaJSON(AProduto: TProduto): TJSONObject;
begin
  Result := TJSONObject.Create
    .AddPair('id', TJSONNumber.Create(AProduto.Id))
    .AddPair('descricao', AProduto.Descricao)
    .AddPair('preco', NumeroJSON(AProduto.Preco))
    .AddPair('estoque', TJSONNumber.Create(AProduto.Estoque));
end;

function DoBody(AReq: THorseRequest): TProduto;
var
  LJson: TJSONObject;
begin
  LJson := CorpoJSON(AReq);
  Result := TProduto.Create;
  try
    Result.Descricao := LerTexto(LJson, 'descricao');
    Result.Preco := LerValor(LJson, 'preco');
    Result.Estoque := LerInteiro(LJson, 'estoque');
  except
    Result.Free;
    raise;
  end;
end;

class procedure TControllerProduto.Registrar;
begin
  THorse.Route('/produtos')
    .Get(
      procedure(AReq: THorseRequest; ARes: THorseResponse)
      var
        LPag: TPaginacao;
        LTotal: Integer;
        LLista: TObjectList<TProduto>;
        LDados: TJSONArray;
        LProduto: TProduto;
      begin
        LPag := PaginacaoDaQuery(AReq);
        LLista := NovoService.Listar(LPag, LTotal);
        try
          LDados := TJSONArray.Create;
          for LProduto in LLista do
            LDados.AddElement(ParaJSON(LProduto));
          ARes.Send<TJSONObject>(RespostaPaginada(LDados, LPag, LTotal));
        finally
          LLista.Free;
        end;
      end)
    .Post(
      procedure(AReq: THorseRequest; ARes: THorseResponse)
      var
        LProduto: TProduto;
      begin
        LProduto := DoBody(AReq);
        try
          NovoService.Criar(LProduto);
          ARes.Send<TJSONObject>(ParaJSON(LProduto)).Status(THTTPStatus.Created);
        finally
          LProduto.Free;
        end;
      end);

  THorse.Route('/produtos/:id')
    .Get(
      procedure(AReq: THorseRequest; ARes: THorseResponse)
      var
        LProduto: TProduto;
      begin
        LProduto := NovoService.Buscar(IdDaRota(AReq));
        try
          ARes.Send<TJSONObject>(ParaJSON(LProduto));
        finally
          LProduto.Free;
        end;
      end)
    .Put(
      procedure(AReq: THorseRequest; ARes: THorseResponse)
      var
        LProduto: TProduto;
      begin
        LProduto := DoBody(AReq);
        try
          LProduto.Id := IdDaRota(AReq);
          NovoService.Atualizar(LProduto);
          ARes.Send<TJSONObject>(ParaJSON(LProduto));
        finally
          LProduto.Free;
        end;
      end)
    .Delete(
      procedure(AReq: THorseRequest; ARes: THorseResponse)
      begin
        NovoService.Excluir(IdDaRota(AReq));
        ARes.Status(THTTPStatus.NoContent);
      end);
end;

end.
