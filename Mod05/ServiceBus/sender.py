"""
Envia mensagens para a fila do Azure Service Bus.
"""

import os
import json
from datetime import datetime

from azure.servicebus import ServiceBusClient, ServiceBusMessage
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STRING = os.getenv("SERVICE_BUS_CONNECTION_STRING")
QUEUE_NAME = os.getenv("SERVICE_BUS_QUEUE_NAME")


def send_messages():
    messages = [
        {"id": 1, "tipo": "pedido", "descricao": "Pedido de compra #1001", "valor": 250.00},
        {"id": 2, "tipo": "pedido", "descricao": "Pedido de compra #1002", "valor": 450.50},
        {"id": 3, "tipo": "erro_proposital", "descricao": "Esta mensagem vai falhar no processamento", "valor": -1},
        {"id": 4, "tipo": "pedido", "descricao": "Pedido de compra #1004", "valor": 120.75},
        {"id": 5, "tipo": "erro_proposital", "descricao": "Outra mensagem que vai para dead-letter", "valor": -999},
    ]

    client = ServiceBusClient.from_connection_string(CONNECTION_STRING)

    with client:
        sender = client.get_queue_sender(queue_name=QUEUE_NAME)
        with sender:
            for msg_data in messages:
                msg_data["enviado_em"] = datetime.now().isoformat()
                body = json.dumps(msg_data, ensure_ascii=False)

                message = ServiceBusMessage(
                    body=body,
                    subject=msg_data["tipo"],
                    application_properties={"source": "demo-python", "message_id": str(msg_data["id"])},
                )

                sender.send_messages(message)
                print(f"[ENVIADA] ID={msg_data['id']} | Tipo={msg_data['tipo']} | {msg_data['descricao']}")

    print(f"\n{len(messages)} mensagens enviadas com sucesso para a fila '{QUEUE_NAME}'.")


if __name__ == "__main__":
    send_messages()
