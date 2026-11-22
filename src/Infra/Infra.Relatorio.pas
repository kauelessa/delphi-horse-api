unit Infra.Relatorio;

{ Relatórios em PDF com dois motores à escolha do usuário (Fortes Report ou
  FastReport). Cada motor implementa IGeradorRelatorio e se registra em
  TRegistroGeradores na subida da API.

  Os dois motores são VCL e não são seguros para várias threads ao mesmo
  tempo (o Horse atende cada requisição numa thread). Por isso a execução
  passa por TRegistroGeradores.Executar, que serializa por motor: dois PDFs
  do Fortes esperam um pelo outro, mas um do Fortes e um do FastReport
  podem sair juntos. Para o volume do portfólio isso basta; com muita carga
  o caminho seria um pool de processos dedicados. }

interface

uses
  System.SysUtils, System.Generics.Collections, Model.Relatorio;

type
  TMotorRelatorio = (mrFortes, mrFastReport);

  TMotorRelatorioHelper = record helper for TMotorRelatorio
    function Nome: string; // como aparece no rodapé
    // 'fortes' | 'fastreport'; outro texto levanta ERequisicaoInvalida
    class function DeTexto(const AValor: string): TMotorRelatorio; static;
  end;

  IGeradorRelatorio = interface
    ['{8D3B1F6A-2C47-4E95-A0B8-6E1D4C7F2A93}']
    function PedidosPorPeriodo(const ADados: TRelPedidos): TBytes;
    function EspelhoPedido(const ADados: TRelEspelho): TBytes;
    function VendasPorProduto(const ADados: TRelVendasProduto): TBytes;
    function Visitas(const ADados: TRelVisitas): TBytes;
  end;

  // quem roda o gerador; o Service depende disto para poder ser testado com um fake
  IExecutorRelatorio = interface
    ['{5F92A0C4-8B1E-4D37-9E6A-C3B7D2F14E08}']
    function Executar(AMotor: TMotorRelatorio; const AGerar: TFunc<IGeradorRelatorio, TBytes>): TBytes;
  end;

  TRegistroGeradores = class(TInterfacedObject, IExecutorRelatorio)
  private
    class var FFabricas: TDictionary<TMotorRelatorio, TFunc<IGeradorRelatorio>>;
    class var FTravas: array[TMotorRelatorio] of TObject;
  public
    class constructor Create;
    class destructor Destroy;
    class procedure Registrar(AMotor: TMotorRelatorio; const AFabrica: TFunc<IGeradorRelatorio>); static;

    { Motor não registrado (ex.: FastReport sem a diretiva FASTREPORT)
      levanta ENaoImplementado. }
    function Executar(AMotor: TMotorRelatorio; const AGerar: TFunc<IGeradorRelatorio, TBytes>): TBytes;
  end;

implementation

uses
  Infra.Excecoes;

{ TMotorRelatorioHelper }

function TMotorRelatorioHelper.Nome: string;
begin
  case Self of
    mrFortes: Result := 'Fortes Report';
    mrFastReport: Result := 'FastReport';
  end;
end;

class function TMotorRelatorioHelper.DeTexto(const AValor: string): TMotorRelatorio;
begin
  if SameText(AValor.Trim, 'fortes') then
    Result := mrFortes
  else if SameText(AValor.Trim, 'fastreport') then
    Result := mrFastReport
  else
    raise ERequisicaoInvalida.Create('Motor de relatório desconhecido. Use fortes ou fastreport.');
end;

{ TRegistroGeradores }

class constructor TRegistroGeradores.Create;
var
  M: TMotorRelatorio;
begin
  FFabricas := TDictionary<TMotorRelatorio, TFunc<IGeradorRelatorio>>.Create;
  for M := Low(TMotorRelatorio) to High(TMotorRelatorio) do
    FTravas[M] := TObject.Create;
end;

class destructor TRegistroGeradores.Destroy;
var
  M: TMotorRelatorio;
begin
  FFabricas.Free;
  for M := Low(TMotorRelatorio) to High(TMotorRelatorio) do
    FTravas[M].Free;
end;

class procedure TRegistroGeradores.Registrar(AMotor: TMotorRelatorio; const AFabrica: TFunc<IGeradorRelatorio>);
begin
  // chamado só na subida da API, antes de aceitar requisições
  FFabricas.AddOrSetValue(AMotor, AFabrica);
end;

function TRegistroGeradores.Executar(AMotor: TMotorRelatorio;
  const AGerar: TFunc<IGeradorRelatorio, TBytes>): TBytes;
var
  LFabrica: TFunc<IGeradorRelatorio>;
begin
  if not FFabricas.TryGetValue(AMotor, LFabrica) then
    raise ENaoImplementado.CreateFmt('%s não está disponível nesta compilação da API.', [AMotor.Nome]);

  TMonitor.Enter(FTravas[AMotor]);
  try
    Result := AGerar(LFabrica());
  finally
    TMonitor.Exit(FTravas[AMotor]);
  end;
end;

end.
