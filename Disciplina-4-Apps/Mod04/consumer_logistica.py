"""
Consumer 2: subscription 'logistica'.

Abordagem assíncrona com asyncio — melhor throughput quando o
processamento é I/O-bound (chama APIs, escreve em DB, etc.).
"""
import asyncio
import json
import logging
import os
from datetime import datetime

from azure.servicebus.aio import ServiceBusClient
from azure.servicebus.exceptions import MessageLockLostError
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.WARNING,
    format="%(asctime)s [logistica] %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

CONNECTION_STR = os.environ["SERVICE_BUS_CONNECTION_STR"]
TOPIC_NAME = os.environ.get("TOPIC_NAME", "pedidos")
SUBSCRIPTION = os.environ.get("SUBSCRIPTION_LOGISTICA", "logistica")

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


async def processar_logistica(pedido: dict) -> None:
    """Lógica de negócio: reservar estoque, agendar coleta, etc."""
    _section(f"Pedido recebido  ({_now()})")
    _row("ID", pedido["pedido_id"])
    _row("Cliente", pedido["cliente"])
    _row("Acao", "Agendando coleta...")
    # Simula chamada I/O (API de transportadora, por exemplo)
    await asyncio.sleep(0.2)
    _row("Status", "Coleta confirmada [OK]")


async def run() -> None:
    _header("CONSUMER - LOGISTICA")
    _section("Conexao")
    _row("Topico", TOPIC_NAME)
    _row("Subscription", SUBSCRIPTION)
    _row("Modo", "assincrono")

    async with ServiceBusClient.from_connection_string(CONNECTION_STR) as client:
        receiver = client.get_subscription_receiver(
            topic_name=TOPIC_NAME,
            subscription_name=SUBSCRIPTION,
            max_wait_time=5,
        )
        async with receiver:
            _row("Status", "Aguardando mensagens...")
            while True:
                mensagens = await receiver.receive_messages(
                    max_message_count=10,
                    max_wait_time=5,
                )
                if not mensagens:
                    continue

                # Processa as N mensagens do batch em paralelo
                await asyncio.gather(
                    *(_handle(receiver, m) for m in mensagens)
                )


async def _handle(receiver, msg) -> None:
    try:
        payload = json.loads(str(msg))
        await processar_logistica(payload)
        await receiver.complete_message(msg)
    except MessageLockLostError:
        log.warning("Lock perdido para %s, sera reentregue", msg.message_id)
    except Exception:
        log.exception("Erro ao processar %s", msg.message_id)
        await receiver.abandon_message(msg)


if __name__ == "__main__":
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        print("\n" + "=" * LINE_WIDTH)
        print("Consumer encerrado.")
        print("=" * LINE_WIDTH)
