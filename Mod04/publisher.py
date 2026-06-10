"""
Publisher: envia mensagens para o tópico 'pedidos'.

Cada subscription do tópico receberá uma cópia da mensagem.
"""
import json
import os
import uuid
from datetime import datetime, timezone

from azure.servicebus import ServiceBusClient, ServiceBusMessage
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STR = os.environ["SERVICE_BUS_CONNECTION_STR"]
TOPIC_NAME = os.environ.get("TOPIC_NAME", "pedidos")

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


def _footer(msg: str) -> None:
    print("\n" + "=" * LINE_WIDTH)
    print(msg)
    print("=" * LINE_WIDTH)


def build_message(pedido_id: str, valor: float, cliente: str) -> ServiceBusMessage:
    """Monta a mensagem com payload JSON + propriedades de aplicação."""
    payload = {
        "pedido_id": pedido_id,
        "cliente": cliente,
        "valor": valor,
        "criado_em": datetime.now(timezone.utc).isoformat(),
    }

    msg = ServiceBusMessage(
        body=json.dumps(payload),
        content_type="application/json",
        message_id=pedido_id,
        # application_properties permite filtros nas subscriptions
        # (ex.: criar uma SQL rule que só entrega valor > 1000)
        application_properties={
            "tipo": "novo_pedido",
            "valor": valor,
        },
    )
    return msg


def publish(pedidos: list[dict]) -> None:
    _header("PUBLISHER - AZURE SERVICE BUS")
    _section("Destino")
    _row("Topico", TOPIC_NAME)
    _row("Total de pedidos", str(len(pedidos)))

    with ServiceBusClient.from_connection_string(CONNECTION_STR) as client:
        sender = client.get_topic_sender(topic_name=TOPIC_NAME)
        with sender:
            mensagens = []
            _section("Mensagens preparadas")
            for i, p in enumerate(pedidos, start=1):
                pedido_id = str(uuid.uuid4())
                msg = build_message(
                    pedido_id=pedido_id,
                    valor=p["valor"],
                    cliente=p["cliente"],
                )
                mensagens.append(msg)
                _row(f"#{i} ID", pedido_id)
                _row("   Cliente", p["cliente"])
                _row("   Valor", f"R$ {p['valor']:.2f}")

            # Envio em batch é mais eficiente que um a um
            batch = sender.create_message_batch()
            for m in mensagens:
                try:
                    batch.add_message(m)
                except ValueError:
                    # Batch cheio, envia o atual e abre um novo
                    sender.send_messages(batch)
                    batch = sender.create_message_batch()
                    batch.add_message(m)
            sender.send_messages(batch)

            _section("Resultado")
            _row("Publicadas", str(len(mensagens)))
            _row("Status", "[OK]")

    _footer("Publicacao concluida.")


if __name__ == "__main__":
    pedidos_exemplo = [
        {"cliente": "ACME Ltda", "valor": 1500.00},
        {"cliente": "João Silva", "valor": 89.90},
        {"cliente": "Empresa X", "valor": 12500.50},
    ]
    publish(pedidos_exemplo)
