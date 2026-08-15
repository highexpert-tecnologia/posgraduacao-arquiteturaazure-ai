"""
Recebe mensagens do Azure Event Hubs e exibe métricas de throughput em tempo real.
Usa o EventHubConsumerClient com checkpoint em memória (InMemoryCheckpointStore).
"""

import os
import json
import time
import threading
from datetime import datetime

from azure.eventhub import EventHubConsumerClient
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STRING = os.getenv("EVENTHUB_CONNECTION_STRING")
EVENTHUB_NAME = os.getenv("EVENTHUB_NAME")

CONSUMER_GROUP = "$Default"
TIMEOUT_SECONDS = 15  # encerra após N segundos sem mensagens

stats = {
    "total": 0,
    "per_partition": {},
    "start_time": None,
    "last_event_time": None,
}
lock = threading.Lock()


def on_event(partition_context, event):
    with lock:
        if stats["start_time"] is None:
            stats["start_time"] = time.perf_counter()

        stats["total"] += 1
        stats["last_event_time"] = time.perf_counter()

        pid = partition_context.partition_id
        stats["per_partition"][pid] = stats["per_partition"].get(pid, 0) + 1

        if stats["total"] % 1000 == 0:
            elapsed = time.perf_counter() - stats["start_time"]
            rate = stats["total"] / elapsed if elapsed > 0 else 0
            print(f"  [PROGRESSO] {stats['total']:,} mensagens recebidas | {rate:,.0f} msgs/seg")

    partition_context.update_checkpoint(event)


def on_error(partition_context, error):
    pid = partition_context.partition_id if partition_context else "?"
    print(f"  [ERRO] Partição {pid}: {error}")


def on_partition_initialize(partition_context):
    print(f"  [INIT] Partição {partition_context.partition_id} conectada")


def on_partition_close(partition_context, reason):
    print(f"  [CLOSE] Partição {partition_context.partition_id} fechada ({reason})")


def receive_messages():
    print("=" * 60)
    print("  AZURE EVENT HUBS — RECEIVER")
    print("=" * 60)
    print(f"\nConectando ao Event Hub '{EVENTHUB_NAME}'...")
    print(f"Consumer Group: {CONSUMER_GROUP}")
    print(f"Timeout: {TIMEOUT_SECONDS}s sem mensagens\n")

    client = EventHubConsumerClient.from_connection_string(
        conn_str=CONNECTION_STRING,
        consumer_group=CONSUMER_GROUP,
        eventhub_name=EVENTHUB_NAME,
    )

    with client:
        worker = threading.Thread(
            target=client.receive,
            kwargs={
                "on_event": on_event,
                "on_error": on_error,
                "on_partition_initialize": on_partition_initialize,
                "on_partition_close": on_partition_close,
                "starting_position": "-1",  # início do stream
            },
            daemon=True,
        )
        worker.start()

        # monitora e encerra após timeout sem eventos
        while True:
            time.sleep(2)
            with lock:
                if stats["last_event_time"] and (time.perf_counter() - stats["last_event_time"]) > TIMEOUT_SECONDS:
                    break

                if stats["start_time"] and stats["total"] == 0 and (time.perf_counter() - stats["start_time"]) > TIMEOUT_SECONDS:
                    break

    elapsed = time.perf_counter() - stats["start_time"] if stats["start_time"] else 0
    rate = stats["total"] / elapsed if elapsed > 0 else 0

    print(f"\n{'=' * 60}")
    print(f"  RESULTADO DA LEITURA")
    print(f"{'=' * 60}")
    print(f"  Total recebidas:  {stats['total']:,}")
    print(f"  Tempo total:      {elapsed:.2f} segundos")
    print(f"  Throughput:       {rate:,.0f} msgs/seg")
    print(f"  Por partição:")
    for pid, count in sorted(stats["per_partition"].items()):
        print(f"    Partição {pid}: {count:,} mensagens")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    receive_messages()
