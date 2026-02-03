#!/bin/bash
# Test LSP server

# Initialize message
init_msg='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":1234,"rootUri":"file:///Users/yey/projects/vaisto","capabilities":{}}}'

# didOpen message
did_open_msg='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///tmp/test.va","languageId":"vaisto","version":1,"text":"(defn add [x :int] :int (+ x 1))"}}}'

# hover message at position (1, 7) - should be on "add"
hover_msg='{"jsonrpc":"2.0","id":2,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///tmp/test.va"},"position":{"line":0,"character":7}}}'

# Send messages with Content-Length headers
{
  printf "Content-Length: %d\r\n\r\n%s" ${#init_msg} "$init_msg"
  sleep 0.5
  printf "Content-Length: %d\r\n\r\n%s" ${#did_open_msg} "$did_open_msg"
  sleep 0.5
  printf "Content-Length: %d\r\n\r\n%s" ${#hover_msg} "$hover_msg"
  sleep 1
} | /opt/homebrew/bin/gtimeout 5 ./vaistoc lsp 2>&1
