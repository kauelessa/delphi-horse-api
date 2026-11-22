unit Infra.Relatorio.Fortes;

{ Relatórios com o Fortes Report CE, montados em código (sem .dfm).

  O Fortes é um componente visual: o TRLReport precisa de um form como pai
  para preparar as páginas, mesmo que esse form nunca apareça. Cada geração
  cria o form, monta as bandas, prepara, exporta com o TRLPDFFilter para um
  arquivo temporário e devolve os bytes. A serialização entre threads fica
  por conta de TRegistroGeradores (Infra.Relatorio).

  Os valores vão formatados para texto antes de chegar ao relatório
  (pt-BR fixo), para o PDF não depender do locale da máquina da API. }

interface

uses
  System.SysUtils, Model.Relatorio, Infra.Relatorio;

type
  TGeradorFortes = class(TInterfacedObject, IGeradorRelatorio)
  public
    function PedidosPorPeriodo(const ADados: TRelPedidos): TBytes;
    function EspelhoPedido(const ADados: TRelEspelho): TBytes;
    function VendasPorProduto(const ADados: TRelVendasProduto): TBytes;
    function Visitas(const ADados: TRelVisitas): TBytes;
  end;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  Vcl.Forms, Vcl.Graphics, Vcl.Imaging.pngimage, RLReport, RLTypes, RLFilters, RLPDFFilter,
  Model.Pedido;

const
  LARGURA_UTIL = 700; // A4 em retrato, dentro das margens padrão do Fortes

type
  TColuna = record
    Titulo: string;
    Campo: string;
    Largura: Integer;
    Direita: Boolean;
  end;

  { Monta um relatório: cabeçalho, colunas, detalhe ligado a um TFDMemTable,
    resumo e rodapé com motor/página. Usa-se uma vez e libera. }
  TMontador = class
  private
    FForm: TForm;
    FRel: TRLReport;
    FTabela: TFDMemTable;
    FFonte: TDataSource;
    FColunas: TArray<TColuna>;
    FResumo: TRLBand;
  public
    constructor Create(const ACab: TCabecalhoRel; const AColunas: TArray<TColuna>);
    destructor Destroy; override;
    function Banda(ATipo: TRLBandType; AAltura: Integer): TRLBand;
    function Rotulo(ABanda: TRLBand; const ATexto: string; AEsquerda, ATopo, ALargura: Integer;
      ADireita: Boolean = False; ANegrito: Boolean = False; ATamanho: Integer = 9): TRLLabel;
    procedure Linha(const AValores: array of string);
    function GerarPdf: TBytes;
    property Resumo: TRLBand read FResumo;
    property Tabela: TFDMemTable read FTabela;
    property Rel: TRLReport read FRel;
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

constructor TMontador.Create(const ACab: TCabecalhoRel; const AColunas: TArray<TColuna>);
var
  LBanda: TRLBand;
  LCol: TColuna;
  LEsq: Integer;
  LTexto: TRLDBText;
  LInfo: TRLSystemInfo;
  LSub: string;
begin
  inherited Create;
  FColunas := AColunas;

  FTabela := TFDMemTable.Create(nil);
  for LCol in AColunas do
    FTabela.FieldDefs.Add(LCol.Campo, ftWideString, 200);
  if Length(AColunas) > 0 then
    FTabela.CreateDataSet;
  FFonte := TDataSource.Create(nil);
  FFonte.DataSet := FTabela;

  FForm := TForm.CreateNew(nil);
  FRel := TRLReport.Create(FForm);
  FRel.Parent := FForm;
  FRel.ShowProgress := False;
  FRel.PrintDialog := False;
  if Length(AColunas) > 0 then
    FRel.DataSource := FFonte;
  FRel.Font.Name := 'Arial';
  FRel.Font.Size := 9;

  // cabeçalho (todas as páginas)
  LBanda := Banda(btHeader, 56);
  LBanda.Borders.Sides := sdCustom;
  LBanda.Borders.DrawBottom := True;
  Rotulo(LBanda, ACab.Titulo, 0, 2, LARGURA_UTIL, False, True, 14);
  LSub := '';
  if ACab.Inicio > 0 then
    LSub := Format('Período: %s a %s', [FormatDateTime('dd/mm/yyyy', ACab.Inicio),
      FormatDateTime('dd/mm/yyyy', ACab.Fim)]);
  if ACab.Vendedor <> '' then
    LSub := LSub + IfThen(LSub <> '', '   ·   ', '') + 'Vendedor: ' + ACab.Vendedor;
  Rotulo(LBanda, LSub, 0, 34, LARGURA_UTIL);

  // títulos das colunas e detalhe
  if Length(AColunas) > 0 then
  begin
    LBanda := Banda(btColumnHeader, 20);
    LBanda.Borders.Sides := sdCustom;
    LBanda.Borders.DrawBottom := True;
    LEsq := 0;
    for LCol in AColunas do
    begin
      Rotulo(LBanda, LCol.Titulo, LEsq, 3, LCol.Largura - 6, LCol.Direita, True);
      Inc(LEsq, LCol.Largura);
    end;

    LBanda := Banda(btDetail, 18);
    LEsq := 0;
    for LCol in AColunas do
    begin
      LTexto := TRLDBText.Create(FRel);
      LTexto.Parent := LBanda;
      LTexto.DataSource := FFonte;
      LTexto.DataField := LCol.Campo;
      LTexto.AutoSize := False;
      LTexto.Left := LEsq;
      LTexto.Top := 2;
      LTexto.Width := LCol.Largura - 6;
      if LCol.Direita then
        LTexto.Alignment := taRightJustify;
      Inc(LEsq, LCol.Largura);
    end;
  end;

  FResumo := Banda(btSummary, 30);

  // rodapé com o motor e a paginação
  LBanda := Banda(btFooter, 20);
  LBanda.Borders.Sides := sdCustom;
  LBanda.Borders.DrawTop := True;
  Rotulo(LBanda, Format('Gerado com Fortes Report em %s · delphi-horse-api',
    [FormatDateTime('dd/mm/yyyy hh:nn', Now)]), 0, 4, 500, False, False, 7);
  LInfo := TRLSystemInfo.Create(FRel);
  LInfo.Parent := LBanda;
  LInfo.Info := itPageNumber;
  LInfo.Text := 'Página ';
  LInfo.AutoSize := False;
  LInfo.Left := LARGURA_UTIL - 100;
  LInfo.Top := 4;
  LInfo.Width := 100;
  LInfo.Alignment := taRightJustify;
  LInfo.Font.Size := 7;
end;

destructor TMontador.Destroy;
begin
  FForm.Free; // leva o relatório e as bandas junto
  FFonte.Free;
  FTabela.Free;
  inherited;
end;

function TMontador.Banda(ATipo: TRLBandType; AAltura: Integer): TRLBand;
begin
  Result := TRLBand.Create(FRel);
  Result.Parent := FRel;
  Result.BandType := ATipo;
  Result.Height := AAltura;
end;

function TMontador.Rotulo(ABanda: TRLBand; const ATexto: string; AEsquerda, ATopo, ALargura: Integer;
  ADireita, ANegrito: Boolean; ATamanho: Integer): TRLLabel;
begin
  Result := TRLLabel.Create(FRel);
  Result.Parent := ABanda;
  Result.AutoSize := False;
  Result.Left := AEsquerda;
  Result.Top := ATopo;
  Result.Width := ALargura;
  Result.Caption := ATexto;
  Result.Font.Size := ATamanho;
  Result.Height := Round(ATamanho * 1.9) + 2; // com AutoSize desligado a altura não acompanha a fonte
  if ANegrito then
    Result.Font.Style := [fsBold];
  if ADireita then
    Result.Alignment := taRightJustify;
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
  LFiltro: TRLPDFFilter;
  LArquivo: string;
begin
  if FTabela.Active then
    FTabela.First;
  if not FRel.Prepare then
    raise Exception.Create('O Fortes não conseguiu preparar o relatório.');

  LArquivo := TPath.Combine(TPath.GetTempPath, 'rel_fortes_' + TGUID.NewGuid.ToString.Trim(['{', '}']) + '.pdf');
  LFiltro := TRLPDFFilter.Create(nil);
  try
    LFiltro.ShowProgress := False;
    LFiltro.FileName := LArquivo;
    LFiltro.FilterPages(FRel.Pages);
    Result := TFile.ReadAllBytes(LArquivo);
  finally
    LFiltro.Free;
    if TFile.Exists(LArquivo) then
      TFile.Delete(LArquivo);
  end;
end;

{ TGeradorFortes }

function TGeradorFortes.PedidosPorPeriodo(const ADados: TRelPedidos): TBytes;
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
      M.Rotulo(M.Resumo, 'Nenhum pedido no período.', 0, 8, LARGURA_UTIL)
    else
      M.Rotulo(M.Resumo, Format('%d pedido(s)   ·   Total sem cancelados: R$ %s',
        [Length(ADados.Linhas), Dinheiro(ADados.Total)]), 0, 8, LARGURA_UTIL, True, True);
    Result := M.GerarPdf;
  finally
    M.Free;
  end;
end;

function TGeradorFortes.VendasPorProduto(const ADados: TRelVendasProduto): TBytes;
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
      M.Rotulo(M.Resumo, 'Nenhuma venda no período.', 0, 8, LARGURA_UTIL)
    else
      M.Rotulo(M.Resumo, 'Total: R$ ' + Dinheiro(ADados.Total), 0, 8, LARGURA_UTIL, True, True);
    Result := M.GerarPdf;
  finally
    M.Free;
  end;
end;

function TGeradorFortes.Visitas(const ADados: TRelVisitas): TBytes;
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
      M.Rotulo(M.Resumo, 'Nenhuma visita no período.', 0, 8, LARGURA_UTIL)
    else
      M.Rotulo(M.Resumo, Format('%d visita(s)', [Length(ADados.Linhas)]), 0, 8, LARGURA_UTIL, True, True);
    Result := M.GerarPdf;
  finally
    M.Free;
  end;
end;

function TGeradorFortes.EspelhoPedido(const ADados: TRelEspelho): TBytes;
var
  M: TMontador;
  P: TPedido;
  LCab: TCabecalhoRel;
  LItem: TPedidoItem;
  LDados: TRLBand;
  LImagem: TRLImage;
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
    Coluna('Unitário (R$)', 'UNIT', 150, True), Coluna('Total (R$)', 'TOTAL', 160, True)]);
  try
    // dados do pedido logo abaixo do cabeçalho, só na primeira página
    LDados := M.Banda(btTitle, 64);
    if P.Status = spCancelado then
      LStatus := 'CANCELADO'
    else
      LStatus := 'ABERTO';
    LNota := 'não faturado';
    if P.Faturado then
      LNota := Format('NF-e %d (série %d)', [P.NotaNumero, P.NotaSerie]);
    M.Rotulo(LDados, 'Cliente: ' + P.NomeCliente, 0, 4, LARGURA_UTIL, False, True, 10);
    M.Rotulo(LDados, Format('Data: %s   ·   Status: %s   ·   Faturamento: %s',
      [FormatDateTime('dd/mm/yyyy hh:nn', P.Data), LStatus, LNota]), 0, 24, LARGURA_UTIL);
    if P.Observacao <> '' then
      M.Rotulo(LDados, 'Observação: ' + P.Observacao, 0, 42, LARGURA_UTIL);

    for LItem in P.Itens do
      M.Linha([LItem.DescricaoProduto, LItem.Quantidade.ToString, Dinheiro(LItem.PrecoUnitario),
        Dinheiro(LItem.ValorTotal)]);

    M.Resumo.Height := 150;
    // alinhado à esquerda de propósito: no PDF a fonte em negrito mede um pouco mais que na tela,
    // e alinhado à direita o último dígito saía cortado
    M.Rotulo(M.Resumo, 'Total do pedido: R$ ' + Dinheiro(P.ValorTotal), LARGURA_UTIL - 300, 6, 300, False, True, 11);
    LTopo := 32;
    if P.TemLocalizacao then
      M.Rotulo(M.Resumo, Format('Local da venda: %s, %s (precisão de %s m)',
        [FormatFloat('0.000000', P.Latitude, FormatoBR), FormatFloat('0.000000', P.Longitude, FormatoBR),
         FormatFloat('0', P.Precisao, FormatoBR)]), 0, LTopo, LARGURA_UTIL)
    else
      M.Rotulo(M.Resumo, 'Local da venda: não registrado', 0, LTopo, LARGURA_UTIL);

    if Length(ADados.Assinatura) > 0 then
    begin
      M.Rotulo(M.Resumo, 'Assinatura do cliente:', 0, LTopo + 22, 200);
      LPng := TPngImage.Create;
      LStream := TBytesStream.Create(ADados.Assinatura);
      try
        try
          LPng.LoadFromStream(LStream);
          LImagem := TRLImage.Create(M.Rel);
          LImagem.Parent := M.Resumo;
          LImagem.Left := 0;
          LImagem.Top := LTopo + 40;
          LImagem.Width := 240;
          LImagem.Height := 70;
          LImagem.Stretch := True;
          LImagem.Scaled := True;
          LImagem.Picture.Assign(LPng);
        except
          // a API só confere o começo do arquivo; um PNG quebrado não pode derrubar o espelho
          // (o decodificador levanta classes próprias, por isso o Exception)
          on Exception do
            M.Rotulo(M.Resumo, '(a imagem da assinatura está corrompida e não pôde ser exibida)',
              0, LTopo + 40, LARGURA_UTIL);
        end;
      finally
        LStream.Free;
        LPng.Free;
      end;
    end
    else
      M.Rotulo(M.Resumo, 'Sem assinatura do cliente.', 0, LTopo + 22, LARGURA_UTIL);

    Result := M.GerarPdf;
  finally
    M.Free;
  end;
end;

initialization
  FormatoBR := TFormatSettings.Create('pt-BR');

end.
