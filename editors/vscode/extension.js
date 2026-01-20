const vscode = require('vscode');
const { LanguageClient, TransportKind } = require('vscode-languageclient/node');

let client;

function activate(context) {
    const config = vscode.workspace.getConfiguration('vaisto');
    const serverPath = config.get('serverPath', 'vaistoc');

    // Server options - run vaistoc lsp via stdio
    const serverOptions = {
        command: serverPath,
        args: ['lsp'],
        transport: TransportKind.stdio
    };

    // Client options
    const clientOptions = {
        documentSelector: [{ scheme: 'file', language: 'vaisto' }],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.va')
        }
    };

    // Create and start the client
    client = new LanguageClient(
        'vaisto',
        'Vaisto Language Server',
        serverOptions,
        clientOptions
    );

    // Start the client (also starts the server)
    client.start();

    console.log('Vaisto language server started');
}

function deactivate() {
    if (client) {
        return client.stop();
    }
}

module.exports = { activate, deactivate };
