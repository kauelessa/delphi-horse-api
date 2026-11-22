program DelphiHorseApiTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  Model.Usuario in '..\src\Models\Model.Usuario.pas',
  Model.Cliente in '..\src\Models\Model.Cliente.pas',
  Model.Produto in '..\src\Models\Model.Produto.pas',
  Model.Pedido in '..\src\Models\Model.Pedido.pas',
  Model.Paginacao in '..\src\Models\Model.Paginacao.pas',
  Model.Documento in '..\src\Models\Model.Documento.pas',
  Model.Sessao in '..\src\Models\Model.Sessao.pas',
  Model.CodigoBarras in '..\src\Models\Model.CodigoBarras.pas',
  Infra.Config in '..\src\Infra\Infra.Config.pas',
  Infra.Conexao in '..\src\Infra\Infra.Conexao.pas',
  Infra.Migracao in '..\src\Infra\Infra.Migracao.pas',
  Infra.Excecoes in '..\src\Infra\Infra.Excecoes.pas',
  Infra.Senha in '..\src\Infra\Infra.Senha.pas',
  Infra.Token in '..\src\Infra\Infra.Token.pas',
  Infra.JWT in '..\src\Infra\Infra.JWT.pas',
  Repository.Usuario in '..\src\Repositories\Repository.Usuario.pas',
  Repository.Cliente in '..\src\Repositories\Repository.Cliente.pas',
  Repository.Produto in '..\src\Repositories\Repository.Produto.pas',
  Repository.Pedido in '..\src\Repositories\Repository.Pedido.pas',
  Repository.Sessao in '..\src\Repositories\Repository.Sessao.pas',
  Repository.Relogio in '..\src\Repositories\Repository.Relogio.pas',
  Service.Auth in '..\src\Services\Service.Auth.pas',
  Service.Cliente in '..\src\Services\Service.Cliente.pas',
  Service.Produto in '..\src\Services\Service.Produto.pas',
  Service.Pedido in '..\src\Services\Service.Pedido.pas',
  Tests.Fakes in 'Tests.Fakes.pas',
  Tests.Infra.Senha in 'Tests.Infra.Senha.pas',
  Tests.Infra.Migracao in 'Tests.Infra.Migracao.pas',
  Tests.Model.Documento in 'Tests.Model.Documento.pas',
  Tests.Service.Auth in 'Tests.Service.Auth.pas',
  Tests.Service.Cliente in 'Tests.Service.Cliente.pas',
  Tests.Service.Produto in 'Tests.Service.Produto.pas',
  Tests.Service.Pedido in 'Tests.Service.Pedido.pas',
  Tests.Repository.Filtro in 'Tests.Repository.Filtro.pas',
  Tests.Infra.JWT in 'Tests.Infra.JWT.pas',
  Tests.Model.CodigoBarras in 'Tests.Model.CodigoBarras.pas';

var
  LRunner: ITestRunner;
  LResultados: IRunResults;
begin
  try
    TDUnitX.CheckCommandLine;
    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := True;
    LRunner.AddLogger(TDUnitXConsoleLogger.Create(True));
    LRunner.AddLogger(TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile));

    LResultados := LRunner.Execute;
    if not LResultados.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      Write('Pressione <Enter> para sair.');
      Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
