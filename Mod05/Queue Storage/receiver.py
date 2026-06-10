"""
Lê e processa mensagens da fila do Azure Queue Storage.
"""

import os
import json

from azure.storage.queue import QueueClient
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STRING = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
QUEUE_NAME = os.getenv("QUEUE_NAME")

BATCH_SIZE = 5
VISIBILITY_TIMEOUT = 30  # segundos que a mensagem fica invisível para outros consumidores


def process_message(msg_data: dict) -> None:
    acao = msg_data.get("acao", "desconhecida")

    if acao == "cadastro_cliente":
        print(f"  -> Cadastrando cliente: {msg_data['cliente']} ({msg_data['email']})")

    elif acao == "atualizar_estoque":
        print(f"  -> Atualizando estoque: {msg_data['produto']} (+{msg_data['quantidade']} unidades)")

    elif acao == "enviar_email":
        print(f"  -> Enviando email para {msg_data['destinatario']}: \"{msg_data['assunto']}\"")

    elif acao == "gerar_relatorio":
        print(f"  -> Gerando relatório: {msg_data['tipo']} ({msg_data['mes']})")

    elif acao == "processar_pagamento":
        print(f"  -> Processando pagamento: R$ {msg_data['valor']:.2f} via {msg_data['metodo']}")

    else:
        print(f"  -> Ação desconhecida: {acao}")


def receive_messages():
    queue_client = QueueClient.from_connection_string(CONNECTION_STRING, QUEUE_NAME)

    props = queue_client.get_queue_properties()
    print(f"Fila '{QUEUE_NAME}' — mensagens pendentes: {props.approximate_message_count}\n")

    messages = queue_client.receive_messages(
        messages_per_page=BATCH_SIZE,
        visibility_timeout=VISIBILITY_TIMEOUT,
    )

    count = 0
    for message in messages:
        body = json.loads(message.content)
        print(f"[RECEBIDA] ID={body.get('id')} | Ação={body.get('acao')}")
        print(f"  Tentativa: {message.dequeue_count} | Inserida em: {message.inserted_on}")

        process_message(body)

        queue_client.delete_message(message)
        print(f"  -> Mensagem removida da fila.\n")
        count += 1

    if count == 0:
        print("Nenhuma mensagem na fila.")
    else:
        print(f"Total processadas: {count}")


if __name__ == "__main__":
    receive_messages()
