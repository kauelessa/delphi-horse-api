unit Infra.Relatorio.FastReport;

{ Os mesmos relatórios do Infra.Relatorio.Fortes, agora com o FastReport VCL,
  também montados em código (sem .fr3).

  O FastReport é comercial, então esta unit só tem conteúdo com a diretiva
  FASTREPORT (Project > Options > Delphi Compiler > Conditional defines).
  Sem ela a API compila só com o Fortes e o motor "fastreport" responde 501.

  Para rodar dentro do servidor: EngineOptions.EnableThreadSafe e
  UseGlobalDataSetList = False (cada relatório enxerga só os próprios
  datasets), SilentMode (erro vira exceção, nunca diálogo) e nada de
  progresso/diálogo na exportação. A serialização fica em TRegistroGeradores. }

interface

{$IFDEF FASTREPORT}
uses
  System.SysUtils, Model.Relatorio, Infra.Relatorio;

type
  TGeradorFastReport = class(TInterfacedObject, IGeradorRelatorio)
  public
    function PedidosPorPeriodo(const ADados: TRelPedidos): TBytes;
    function EspelhoPedido(const ADados: TRelEspelho): TBytes;
    function VendasPorProduto(const ADados: TRelVendasProduto): TBytes;
    function Visitas(const ADados: TRelVisitas): TBytes;
  end;
{$ENDIF}

implementation

{$IFDEF FASTREPORT}
uses
  System.Classes, System.IOUtils, System.StrUtils, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  Vcl.Graphics, Vcl.Imaging.pngimage, frBaseGraphicsTypes, frxClass, frxDBSet, frxExportPDF, Model.Pedido;

const
  LARGURA_UTIL = 700; // A4 em retrato com margens de 10 mm, em pixels do FastReport

type
  TColuna = record
    Titulo: string;
    Campo: string;
    Largura: Integer;
    Direita: Boolean;
  end;

  TMontador = class
  private
    FRel: TfrxReport;
    FPagina: TfrxReportPage;
    FTabela: TFDMemTable;
    FDados: TfrxDBDataset;
    FResumo: TfrxReportSummary;
    FCabecalhoColunas: TfrxBand;
    FTopo: Double; // próxima posição livre para empilhar as bandas no "desenho"
  public
    { AEspacoAcima reserva altura na banda dos títulos das colunas para dados que
      saem uma vez, logo abaixo do cabeçalho (no FastReport o ReportTitle sairia
      antes do PageHeader). }
    constructor Create(const ACab: TCabecalhoRel; const AColunas: TArray<TColuna>; AEspacoAcima: Integer = 0);
    destructor Destroy; override;
    function Banda(AClasse: TfrxBandClass; AAltura: Double): TfrxBand;
    function Texto(ABanda: TfrxBand; const ATexto: string; AEsquerda, ATopo, ALargura: Double;
      ADireita: Boolean = False; ANegrito: Boolean = False; ATamanho: Integer = 9): TfrxMemoView;
    procedure Linha(const AValores: array of string);
    function GerarPdf: TBytes;
    property Resumo: TfrxReportSummary read FResumo;
    property CabecalhoColunas: TfrxBand read FCabecalhoColunas;
  end;

var
  FormatoBR: TFormatSettings;

function Dinheiro(AValor: Currency): string;
begin
  Result := FormatFloat('#,##0.00', AValor, FormatoBR);
end;

function Coluna(const ATitulo, ACampo: string; ALargura: Integer; ADireita: Boolean = False): TColuna;
begin
  Result.Titulo := ATitulo;
  Result.Campo := ACampo;
  Result.Largura := ALargura;
  Result.Direita := ADireita;
end;

{ TMontador }

constructor TMontador.Create(const ACab: TCabecalhoRel; const AColunas: TArray<TColuna>; AEspacoAcima: Integer);
var
  LBanda: TfrxBand;
  LDetalhe: TfrxMasterData;
  LCol: TColuna;
  LEsq: Integer;
  LMemo: TfrxMemoView;
  LSub: string;
begin
  inherited Create;
  FTabela := TFDMemTable.Create(nil);
  for LCol in AColunas do
    FTabela.FieldDefs.Add(LCol.Campo, ftWideString, 200);
  if Length(AColunas) > 0 then
    FTabela.CreateDataSet;

  FRel := TfrxReport.Create(nil);
  FRel.EngineOptions.SilentMode := True;
  FRel.EngineOptions.EnableThreadSafe := True;
  FRel.EngineOptions.UseGlobalDataSetList := False;
  FRel.EngineOptions.DestroyForms := False;
  FRel.ShowProgress := False;

  FDados := TfrxDBDataset.Create(nil);
  FDados.UserName := 'Dados';
  FDados.DataSet := FTabela;
  FRel.DataSets.Add(FDados);

  FPagina := TfrxReportPage.Create(FRel);
  FPagina.CreateUniqueName;
  FPagina.SetDefaults; // A4, margens de 10 mm
  FPagina.Font.Name := 'Arial';

  // cabeçalho (todas as páginas)
  LBanda := Banda(TfrxPageHeader, 56);
  Texto(LBanda, ACab.Titulo, 0, 0, LARGURA_UTIL, False, True, 14);
  LSub := '';
  if ACab.Inicio > 0 then
    LSub := Format('Período: %s a %s', [FormatDateTime('dd/mm/yyyy', ACab.Inicio),
      FormatDateTime('dd/mm/yyyy', ACab.Fim)]);
  if ACab.Vendedor <> '' then
    LSub := LSub + IfThen(LSub <> '', '   ·   ', '') + 'Vendedor: ' + ACab.Vendedor;
  LMemo := Texto(LBanda, LSub, 0, 32, LARGURA_UTIL);
  LMemo.Frame.Typ := [ftBottom];

  if Length(AColunas) > 0 then
  begin
    LBanda := Banda(TfrxHeader, 20 + AEspacoAcima);
    FCabecalhoColunas := LBanda;
    LEsq := 0;
    for LCol in AColunas do
    begin
      // largura cheia para o sublinhado sair contínuo; o GapX do memo dá o respiro
      LMemo := Texto(LBanda, LCol.Titulo, LEsq, AEspacoAcima + 2, LCol.Largura, LCol.Direita, True);
      LMemo.Frame.Typ := [ftBottom];
      Inc(LEsq, LCol.Largura);
    end;

    LDetalhe := TfrxMasterData(Banda(TfrxMasterData, 18));
    LDetalhe.DataSet := FDados;
    LEsq := 0;
    for LCol in AColunas do
    begin
      LMemo := TfrxMemoView.Create(LDetalhe);
      LMemo.CreateUniqueName;
      LMemo.SetBounds(LEsq, 2, LCol.Largura, 16);
      LMemo.DataSet := FDados;
      LMemo.DataField := LCol.Campo;
      LMemo.Font.Name := 'Arial';
      LMemo.Font.Size := 9;
      if LCol.Direita then
        LMemo.HAlign := haRight;
      Inc(LEsq, LCol.Largura);
    end;
  end;

  FResumo := TfrxReportSummary(Banda(TfrxReportSummary, 30));

  // rodapé com o motor e a paginação
  LBanda := Banda(TfrxPageFooter, 20);
  LMemo := Texto(LBanda, Format('Gerado com FastReport em %s · delphi-horse-api',
    [FormatDateTime('dd/mm/yyyy hh:nn', Now)]), 0, 4, LARGURA_UTIL, False, False, 7);
  LMemo.Frame.Typ := [ftTop];
  LMemo := TfrxMemoView.Create(LBanda);
  LMemo.CreateUniqueName;
  LMemo.SetBounds(LARGURA_UTIL - 100, 4, 100, 14);
  LMemo.Text := 'Página [Page#]';
  LMemo.HAlign := haRight;
  LMemo.Font.Name := 'Arial';
  LMemo.Font.Size := 7;
end;

destructor TMontador.Destroy;
begin
  FRel.Free; // leva a página, as bandas e os memos
  FDados.Free;
  FTabela.Free;
  inherited;
end;

function TMontador.Banda(AClasse: TfrxBandClass; AAltura: Double): TfrxBand;
begin
  Result := AClasse.Create(FPagina);
  Result.CreateUniqueName;
  Result.Top := FTopo;
  Result.Height := AAltura;
  FTopo := FTopo + AAltura + 4;
end;

function TMontador.Texto(ABanda: TfrxBand; const ATexto: string; AEsquerda, ATopo, ALargura: Double;
  ADireita, ANegrito: Boolean; ATamanho: Integer): TfrxMemoView;
begin
  Result := TfrxMemoView.Create(ABanda);
  Result.CreateUniqueName;
  Result.SetBounds(AEsquerda, ATopo, ALargura, Round(ATamanho * 1.9) + 2);
  Result.AllowExpressions := False; // texto fixo: "[" no meio do texto não vira expressão
  Result.Text := ATexto;
  Result.Font.Name := 'Arial';
  Result.Font.Size := ATamanho;
  if ANegrito then
    Result.Font.Style := [fsBold];
  if ADireita then
    Result.HAlign := haRight;
end;

procedure TMontador.Linha(const AValores: array of string);
var
  I: Integer;
begin
  FTabela.Append;
  for I := 0 to High(AValores) do
    FTabela.Fields[I].AsWideString := AValores[I];
  FTabela.Post;
end;

function TMontador.GerarPdf: TBytes;
var
  LPdf: TfrxPDFExport;
  LArquivo: string;
begin
  if FTabela.Active then
    FTabela.First;
  if not FRel.PrepareReport then
    raise Exception.Create('O FastReport não conseguiu preparar o relatório.');

  LArquivo := TPath.Combine(TPath.GetTempPath, 'rel_fr_' + TGUID.NewGuid.ToString.Trim(['{', '}']) + '.pdf');
  LPdf := TfrxPDFExport.Create(nil);
  try
    LPdf.ShowDialog := False;
    LPdf.ShowProgress := False;
    LPdf.OverwritePrompt := False;
    LPdf.FileName := LArquivo;
    if not FRel.Export(LPdf) then
      raise Exception.Create('O FastReport não conseguiu exportar o PDF.');
    Result := TFile.ReadAllBytes(LArquivo);
  finally
    LPdf.Free;
    if TFile.Exists(LArquivo) then
      TFile.Delete(LArquivo);
  end;
end;

{ TGeradorFastReport }

function TGeradorFastReport.PedidosPorPeriodo(const ADados: TRelPedidos): TBytes;
var
  M: TMontador;
  L: TLinhaRelPedido;
  LNota: string;
begin
  M := TMontador.Create(ADados.Cabecalho, [Coluna('Nº', 'ID', 60, True), Coluna('Data', 'DATA', 120),
    Coluna('Cliente', 'CLIENTE', 250), Coluna('Status', 'STATUS', 90), Coluna('NF-e', 'NOTA', 70, True),
    Coluna('Valor (R$)', 'VALOR', 110, True)]);
  try
    for L in ADados.Linhas do
    begin
      LNota := '';
      if L.NotaNumero > 0 then
        LNota := L.NotaNumero.ToString;
      M.Linha([L.Id.ToString, FormatDateTime('dd/mm/yyyy hh:nn', L.Data), L.Cliente, L.Status, LNota,
        Dinheiro(L.Valor)]);
    end;

    if Length(ADados.Linhas) = 0 then
      M.Texto(M.Resumo, 'Nenhum pedido no período.', 0, 8, LARGURA_UTIL)
    else
      M.Texto(M.Resumo, Format('%d pedido(s)   ·   Total sem cancelados: R$ %s',
        [Length(ADados.Linhas), Dinheiro(ADados.Total)]), 0, 8, LARGURA_UTIL, True, True);
    Result := M.GerarPdf;
  finally
    M.Free;
  end;
end;

function TGeradorFastReport.VendasPorProduto(const ADados: TRelVendasProduto): TBytes;
var
  M: TMontador;
  L: TLinhaRelVendaProduto;
begin
  M := TMontador.Create(ADados.Cabecalho, [Coluna('Produto', 'PRODUTO', 430),
    Coluna('Quantidade', 'QTD', 120, True), Coluna('Valor (R$)', 'VALOR', 150, True)]);
  try
    for L in ADados.Linhas do
      M.Linha([L.Produto, L.Quantidade.ToString, Dinheiro(L.Valor)]);

    if Length(ADados.Linhas) = 0 then
      M.Texto(M.Resumo, 'Nenhuma venda no período.', 0, 8, LARGURA_UTIL)
    else
      M.Texto(M.Resumo, 'Total: R$ ' + Dinheiro(ADados.Total), 0, 8, LARGURA_UTIL, True, True);
    Result := M.GerarPdf;
  finally
    M.Free;
  end;
end;

function TGeradorFastReport.Visitas(const ADados: TRelVisitas): TBytes;
var
  M: TMontador;
  L: TLinhaRelVisita;
begin
  M := TMontador.Create(ADados.Cabecalho, [Coluna('Data', 'DATA', 120), Coluna('Cliente', 'CLIENTE', 220),
    Coluna('Motivo', 'MOTIVO', 120), Coluna('Observação', 'OBS', 240)]);
  try
    for L in ADados.Linhas do
      M.Linha([FormatDateTime('dd/mm/yyyy hh:nn', L.Data), L.Cliente, L.Motivo, L.Observacao]);

    if Length(ADados.Linhas) = 0 then
      M.Texto(M.Resumo, 'Nenhuma visita no período.', 0, 8, LARGURA_UTIL)
    else
      M.Texto(M.Resumo, Format('%d visita(s)', [Length(ADados.Linhas)]), 0, 8, LARGURA_UTIL, True, True);
    Result := M.GerarPdf;
  finally
    M.Free;
  end;
end;

function TGeradorFastReport.EspelhoPedido(const ADados: TRelEspelho): TBytes;
var
  M: TMontador;
  P: TPedido;
  LCab: TCabecalhoRel;
  LItem: TPedidoItem;
  LTitulo: TfrxBand;
  LImagem: TfrxPictureView;
  LPng: TPngImage;
  LStream: TBytesStream;
  LTopo: Integer;
  LNota, LStatus: string;
begin
  P := ADados.Pedido;
  LCab.Titulo := Format('Pedido nº %d', [P.Id]);
  LCab.Inicio := 0;
  LCab.Fim := 0;
  LCab.Vendedor := P.NomeVendedor;

  M := TMontador.Create(LCab, [Coluna('Produto', 'PRODUTO', 320), Coluna('Qtd', 'QTD', 70, True),
    Coluna('Unitário (R$)', 'UNIT', 150, True), Coluna('Total (R$)', 'TOTAL', 160, True)], 64);
  try
    LTitulo := M.CabecalhoColunas;
    if P.Status = spCancelado then
      LStatus := 'CANCELADO'
    else
      LStatus := 'ABERTO';
    LNota := 'não faturado';
    if P.Faturado then
      LNota := Format('NF-e %d (série %d)', [P.NotaNumero, P.NotaSerie]);
    M.Texto(LTitulo, 'Cliente: ' + P.NomeCliente, 0, 4, LARGURA_UTIL, False, True, 10);
    M.Texto(LTitulo, Format('Data: %s   ·   Status: %s   ·   Faturamento: %s',
      [FormatDateTime('dd/mm/yyyy hh:nn', P.Data), LStatus, LNota]), 0, 24, LARGURA_UTIL);
    if P.Observacao <> '' then
      M.Texto(LTitulo, 'Observação: ' + P.Observacao, 0, 42, LARGURA_UTIL);

    for LItem in P.Itens do
      M.Linha([LItem.DescricaoProduto, LItem.Quantidade.ToString, Dinheiro(LItem.PrecoUnitario),
        Dinheiro(LItem.ValorTotal)]);

    M.Resumo.Height := 150;
    M.Texto(M.Resumo, 'Total do pedido: R$ ' + Dinheiro(P.ValorTotal), LARGURA_UTIL - 300, 6, 300,
      True, True, 11);
    LTopo := 32;
    if P.TemLocalizacao then
      M.Texto(M.Resumo, Format('Local da venda: %s, %s (precisão de %s m)',
        [FormatFloat('0.000000', P.Latitude, FormatoBR), FormatFloat('0.000000', P.Longitude, FormatoBR),
         FormatFloat('0', P.Precisao, FormatoBR)]), 0, LTopo, LARGURA_UTIL)
    else
      M.Texto(M.Resumo, 'Local da venda: não registrado', 0, LTopo, LARGURA_UTIL);

    if Length(ADados.Assinatura) > 0 then
    begin
      M.Texto(M.Resumo, 'Assinatura do cliente:', 0, LTopo + 22, 200);
      LPng := TPngImage.Create;
      LStream := TBytesStream.Create(ADados.Assinatura);
      try
        try
          LPng.LoadFromStream(LStream);
          LImagem := TfrxPictureView.Create(M.Resumo);
          LImagem.CreateUniqueName;
          LImagem.SetBounds(0, LTopo + 40, 240, 70);
          LImagem.Stretched := True;
          LImagem.KeepAspectRatio := True;
          LImagem.Picture.Assign(LPng);
        except
          // PNG quebrado (só o começo do arquivo é conferido na API) não derruba o espelho
          on Exception do
            M.Texto(M.Resumo, '(a imagem da assinatura está corrompida e não pôde ser exibida)',
              0, LTopo + 40, LARGURA_UTIL);
        end;
      finally
        LStream.Free;
        LPng.Free;
      end;
    end
    else
      M.Texto(M.Resumo, 'Sem assinatura do cliente.', 0, LTopo + 22, LARGURA_UTIL);

    Result := M.GerarPdf;
  finally
    M.Free;
  end;
end;

initialization
  FormatoBR := TFormatSettings.Create('pt-BR');
{$ENDIF}

end.
