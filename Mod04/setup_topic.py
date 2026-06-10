"""
Cria o tópico e as duas subscriptions caso não existam.
Útil para subir o ambiente local/dev rapidamente.

"""
import os

from azure.servicebus.management import ServiceBusAdministrationClient
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STR = os.environ["SERVICE_BUS_CONNECTION_STR"]
TOPIC_NAME = os.environ.get("TOPIC_NAME", "pedidos")
SUBSCRIPTIONS = [
    os.environ.get("SUBSCRIPTION_FATURAMENTO", "faturamento"),
    os.environ.get("SUBSCRIPTION_LOGISTICA", "logistica"),
]

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


def main() -> None:
    _header("SETUP - AZURE SERVICE BUS TOPIC")

    with ServiceBusAdministrationClient.from_connection_string(CONNECTION_STR) as admin:
        _section("Topico")
        topicos = [t.name for t in admin.list_topics()]
        if TOPIC_NAME not in topicos:
            admin.create_topic(TOPIC_NAME)
            status_topico = "[CRIADO]"
        else:
            status_topico = "[JA EXISTE]"
        _row("Nome", TOPIC_NAME)
        _row("Status", status_topico)

        _section("Subscriptions")
        existentes = [s.name for s in admin.list_subscriptions(TOPIC_NAME)]
        for sub in SUBSCRIPTIONS:
            if sub not in existentes:
                admin.create_subscription(TOPIC_NAME, sub)
                status_sub = "[CRIADA]"
            else:
                status_sub = "[JA EXISTE]"
            _row(sub, status_sub)

    _footer("Setup concluido com sucesso.")


if __name__ == "__main__":
    main()
