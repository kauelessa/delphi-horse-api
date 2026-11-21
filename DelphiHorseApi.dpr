program DelphiHorseApi;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  Horse.CORS,
  Model.Usuario in 'src\Models\Model.Usuario.pas',
  Model.Cliente in 'src\Models\Model.Cliente.pas',
  Model.Produto in 'src\Models\Model.Produto.pas',
  Model.Pedido in 'src\Models\Model.Pedido.pas',
  Model.Paginacao in 'src\Models\Model.Paginacao.pas',
  Model.Documento in 'src\Models\Model.Documento.pas',
  Infra.Config in 'src\Infra\Infra.Config.pas',
  Infra.Conexao in 'src\Infra\Infra.Conexao.pas',
  Infra.Excecoes in 'src\Infra\Infra.Excecoes.pas',
  Infra.Senha in 'src\Infra\Infra.Senha.pas',
  Infra.Token in 'src\Infra\Infra.Token.pas',
  Infra.JWT in 'src\Infra\Infra.JWT.pas',
  Infra.Middleware.Erros in 'src\Infra\Infra.Middleware.Erros.pas',
  Infra.Middleware.Autenticacao in 'src\Infra\Infra.Middleware.Autenticacao.pas',
  Repository.Usuario in 'src\Repositories\Repository.Usuario.pas',
  Repository.Cliente in 'src\Repositories\Repository.Cliente.pas',
  Repository.Produto in 'src\Repositories\Repository.Produto.pas',
  Repository.Pedido in 'src\Repositories\Repository.Pedido.pas',
  Service.Auth in 'src\Services\Service.Auth.pas',
  Service.Cliente in 'src\Services\Service.Cliente.pas',
  Service.Produto in 'src\Services\Service.Produto.pas',
  Service.Pedido in 'src\Services\Service.Pedido.pas',
  Controller.Utils in 'src\Controllers\Controller.Utils.pas',
  Controller.Health in 'src\Controllers\Controller.Health.pas',
  Controller.Auth in 'src\Controllers\Controller.Auth.pas',
  Controller.Cliente in 'src\Controllers\Controller.Cliente.pas',
  Controller.Produto in 'src\Controllers\Controller.Produto.pas',
  Controller.Pedido in 'src\Controllers\Controller.Pedido.pas',
  Infra.Migracao in 'src\Infra\Infra.Migracao.pas';

var
  LScript: string;

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  try
    TConfig.Carregar(TConfig.ArquivoPadrao);
    TConexao.Configurar(TConfig.Banco);

    if TConfig.Migracao.Executar then
      for LScript in TMigrador.Executar(TConfig.Migracao) do
        Writeln('Migração aplicada: ', ExtractFileName(LScript));
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, 'Falha na inicialização: ', E.Message);
      ExitCode := 1;
      Exit;
    end;
  end;

  // A ordem dos middlewares importa:
  //  - CORS primeiro, para responder o preflight (OPTIONS) sem exigir token;
  //  - Jhonson antes do tratamento de erros, para serializar o { "erro": ... };
  //  - Autenticar por último, para que o 401 dele também passe pelo TratarErros.
  THorse
    .Use(CORS)
    .Use(Jhonson('UTF-8', ResponderJSONInvalido))
    .Use(TratarErros)
    .Use(Autenticar);

  TControllerHealth.Registrar;
  TControllerAuth.Registrar;
  TControllerCliente.Registrar;
  TControllerProduto.Registrar;
  TControllerPedido.Registrar;

  THorse.Listen(TConfig.PortaServidor,
    procedure
    begin
      Writeln(Format('API rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
    end);
end.
