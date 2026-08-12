"""
Lê e processa mensagens da fila do Azure Service Bus.
Mensagens com tipo "erro_proposital" são rejeitadas e enviadas para a dead-letter queue.
"""

import os
import json

from azure.servicebus import ServiceBusClient
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STRING = os.getenv("SERVICE_BUS_CONNECTION_STRING")
QUEUE_NAME = os.getenv("SERVICE_BUS_QUEUE_NAME")

MAX_WAIT_TIME = 10  # segundos


def process_message(msg_data: dict) -> None:
    if msg_data.get("tipo") == "erro_proposital":
        raise ValueError(f"Valor inválido detectado: {msg_data.get('valor')}")

    print(f"  -> Processado com sucesso: {msg_data['descricao']} (R$ {msg_data['valor']:.2f})")


def receive_messages():
    client = ServiceBusClient.from_connection_string(CONNECTION_STRING)

    with client:
        receiver = client.get_queue_receiver(queue_name=QUEUE_NAME, max_wait_time=MAX_WAIT_TIME)
        with receiver:
            print(f"Aguardando mensagens na fila '{QUEUE_NAME}' (timeout: {MAX_WAIT_TIME}s)...\n")

            messages = receiver.receive_messages(max_message_count=20, max_wait_time=MAX_WAIT_TIME)

            if not messages:
                print("Nenhuma mensagem encontrada na fila.")
                return

            for message in messages:
                body = json.loads(str(message))
                print(f"[RECEBIDA] ID={body.get('id')} | Tipo={body.get('tipo')}")

                try:
                    process_message(body)
                    receiver.complete_message(message)
                    print(f"  -> Mensagem ID={body.get('id')} completada.\n")

                except ValueError as e:
                    print(f"  -> ERRO ao processar: {e}")
                    receiver.dead_letter_message(
                        message,
                        reason="ProcessingError",
                        error_description=str(e),
                    )
                    print(f"  -> Mensagem ID={body.get('id')} enviada para DEAD-LETTER.\n")

    print("Processamento da fila finalizado.")


if __name__ == "__main__":
    receive_messages()
