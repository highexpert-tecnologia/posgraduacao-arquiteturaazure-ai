"""
Consumer 1: subscription 'faturamento'.

Abordagem síncrona com receive_messages() em loop.
Boa para workloads CPU-bound ou quando o time já trabalha com código sync.
"""
import json
import logging
import os
from datetime import datetime

from azure.servicebus import ServiceBusClient
from azure.servicebus.exceptions import MessageLockLostError
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.WARNING,
    format="%(asctime)s [faturamento] %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

CONNECTION_STR = os.environ["SERVICE_BUS_CONNECTION_STR"]
TOPIC_NAME = os.environ.get("TOPIC_NAME", "pedidos")
SUBSCRIPTION = os.environ.get("SUBSCRIPTION_FATURAMENTO", "faturamento")

LINE_WIDTH = 60
LABEL_WIDTH = 18


def _header(title: str) -> None:
    print("+" + "-" * (LINE_WIDTH - 2) + "+")
    print("|" + title.center(LINE_WIDTH - 2) + "|")
    print("+" + "-" * (LINE_WIDTH - 2) + "+")


def _section(title: str) -> None:
    bar = "-" * (LINE_WIDTH - len(title) - 3)
    print(f"\n[ {title} ]{bar}")


def _row(label: str, value: str) -> None:
    print(f"  {label.ljust(LABEL_WIDTH)}: {value}")


def _now() -> str:
    return datetime.now().strftime("%H:%M:%S")


def processar_faturamento(pedido: dict) -> None:
    """Lógica de negócio: gerar NF, lançar contas a receber, etc."""
    _section(f"Pedido recebido  ({_now()})")
    _row("ID", pedido["pedido_id"])
    _row("Cliente", pedido["cliente"])
    _row("Valor", f"R$ {pedido['valor']:.2f}")
    _row("Acao", "NF gerada [OK]")
    # Aqui chamaria o ERP, API fiscal, etc.


def run() -> None:
    _header("CONSUMER - FATURAMENTO")
    _section("Conexao")
    _row("Topico", TOPIC_NAME)
    _row("Subscription", SUBSCRIPTION)
    _row("Modo", "sincrono")

    with ServiceBusClient.from_connection_string(CONNECTION_STR) as client:
        receiver = client.get_subscription_receiver(
            topic_name=TOPIC_NAME,
            subscription_name=SUBSCRIPTION,
            max_wait_time=5,  # segundos para esperar antes de retornar vazio
        )
        with receiver:
            _row("Status", "Aguardando mensagens...")
            while True:
                mensagens = receiver.receive_messages(
                    max_message_count=10,
                    max_wait_time=5,
                )
                if not mensagens:
                    continue

                for msg in mensagens:
                    try:
                        payload = json.loads(str(msg))
                        processar_faturamento(payload)
                        receiver.complete_message(msg)  # ACK: remove da subscription
                    except MessageLockLostError:
                        log.warning("Lock perdido para %s, sera reentregue", msg.message_id)
                    except Exception:
                        log.exception("Erro ao processar %s", msg.message_id)
                        # abandon devolve a mensagem para reentrega
                        # (após N tentativas vai para a DLQ)
                        receiver.abandon_message(msg)


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        print("\n" + "=" * LINE_WIDTH)
        print("Consumer encerrado.")
        print("=" * LINE_WIDTH)
