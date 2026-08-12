"""
Processa mensagens da dead-letter queue (sub-fila de mensagens com falha).
"""

import os
import json

from azure.servicebus import ServiceBusClient
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STRING = os.getenv("SERVICE_BUS_CONNECTION_STRING")
QUEUE_NAME = os.getenv("SERVICE_BUS_QUEUE_NAME")

MAX_WAIT_TIME = 10


def handle_dead_letter(body: dict, reason: str, description: str) -> None:
    print(f"  Razão: {reason}")
    print(f"  Descrição do erro: {description}")
    print(f"  Dados originais: {json.dumps(body, ensure_ascii=False, indent=4)}")
    print(f"  -> Ação corretiva: registrar em log de auditoria / notificar equipe.")


def process_dead_letters():
    client = ServiceBusClient.from_connection_string(CONNECTION_STRING)

    with client:
        # deadletter_receiver aponta para a sub-fila $DeadLetterQueue
        dl_receiver = client.get_queue_receiver(
            queue_name=QUEUE_NAME,
            sub_queue="deadletter",
            max_wait_time=MAX_WAIT_TIME,
        )

        with dl_receiver:
            print(f"Lendo dead-letter queue de '{QUEUE_NAME}' (timeout: {MAX_WAIT_TIME}s)...\n")

            messages = dl_receiver.receive_messages(max_message_count=20, max_wait_time=MAX_WAIT_TIME)

            if not messages:
                print("Nenhuma mensagem na dead-letter queue.")
                return

            for message in messages:
                body = json.loads(str(message))
                reason = message.dead_letter_reason or "Desconhecido"
                description = message.dead_letter_error_description or "Sem descrição"

                print(f"[DEAD-LETTER] ID={body.get('id')} | Tipo={body.get('tipo')}")

                handle_dead_letter(body, reason, description)

                dl_receiver.complete_message(message)
                print(f"  -> Mensagem removida da dead-letter queue.\n")

    print("Processamento da dead-letter queue finalizado.")


if __name__ == "__main__":
    process_dead_letters()
