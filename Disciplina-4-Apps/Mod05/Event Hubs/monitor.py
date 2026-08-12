"""
Exibe informações e métricas do Event Hub (partições, offsets, sequências).
Útil para verificar o estado do Event Hub antes e depois do envio.
"""

import os
import asyncio

from azure.eventhub.aio import EventHubConsumerClient
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STRING = os.getenv("EVENTHUB_CONNECTION_STRING")
EVENTHUB_NAME = os.getenv("EVENTHUB_NAME")


async def show_info():
    print("=" * 60)
    print("  AZURE EVENT HUBS — MONITOR")
    print("=" * 60)

    client = EventHubConsumerClient.from_connection_string(
        conn_str=CONNECTION_STRING,
        consumer_group="$Default",
        eventhub_name=EVENTHUB_NAME,
    )

    async with client:
        info = await client.get_eventhub_properties()
        print(f"\n  Event Hub:      {info['name']}")
        print(f"  Criado em:      {info['created_at']}")
        print(f"  Partições:      {info['partition_ids']}")

        print(f"\n  {'Partição':<12} {'Último Seq':<15} {'Último Offset':<20} {'Último Enqueue'}")
        print(f"  {'-'*12} {'-'*15} {'-'*20} {'-'*25}")

        total_events = 0
        for pid in info["partition_ids"]:
            props = await client.get_partition_properties(pid)
            seq = props["last_enqueued_sequence_number"]
            offset = props["last_enqueued_offset"]
            enqueue_time = props["last_enqueued_time_utc"]
            is_empty = props["is_empty"]

            status = "(vazia)" if is_empty else ""
            print(f"  {pid:<12} {seq:<15} {offset:<20} {enqueue_time} {status}")

            if not is_empty:
                total_events += seq + 1

        print(f"\n  Total estimado de eventos: {total_events:,}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    asyncio.run(show_info())
