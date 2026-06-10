"""
Envia mensagens para uma fila do Azure Queue Storage.
"""

import os
import json
from datetime import datetime

from azure.storage.queue import QueueClient
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STRING = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
QUEUE_NAME = os.getenv("QUEUE_NAME")


def send_messages():
    queue_client = QueueClient.from_connection_string(CONNECTION_STRING, QUEUE_NAME)

    # cria a fila se não existir
    try:
        queue_client.create_queue()
        print(f"Fila '{QUEUE_NAME}' criada.")
    except Exception:
        print(f"Fila '{QUEUE_NAME}' já existe.")

    messages = [
        {"id": 1, "acao": "cadastro_cliente", "cliente": "Maria Silva", "email": "maria@email.com"},
        {"id": 2, "acao": "atualizar_estoque", "produto": "Notebook Dell", "quantidade": 50},
        {"id": 3, "acao": "enviar_email", "destinatario": "joao@email.com", "assunto": "Pedido confirmado"},
        {"id": 4, "acao": "gerar_relatorio", "tipo": "vendas_mensal", "mes": "2026-05"},
        {"id": 5, "acao": "processar_pagamento", "valor": 1299.90, "metodo": "pix"},
    ]

    for msg in messages:
        msg["enviado_em"] = datetime.utcnow().isoformat()
        body = json.dumps(msg, ensure_ascii=False)
        queue_client.send_message(body)
        print(f"[ENVIADA] ID={msg['id']} | Ação={msg['acao']}")

    props = queue_client.get_queue_properties()
    print(f"\nTotal de mensagens na fila: {props.approximate_message_count}")


if __name__ == "__main__":
    send_messages()
