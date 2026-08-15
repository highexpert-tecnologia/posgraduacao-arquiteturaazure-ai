"""
Envia 10.000 mensagens para o Azure Event Hubs usando batches assíncronos.
Demonstra a capacidade de alto volume do Event Hubs.
"""

import os
import json
import asyncio
import time
import uuid
from datetime import datetime

from azure.eventhub import EventData
from azure.eventhub.aio import EventHubProducerClient
from dotenv import load_dotenv

load_dotenv()

CONNECTION_STRING = os.getenv("EVENTHUB_CONNECTION_STRING")
EVENTHUB_NAME = os.getenv("EVENTHUB_NAME")

TOTAL_MESSAGES = 10_000
PARTITION_COUNT = 4  # distribui mensagens entre partições


def create_event(index: int) -> EventData:
    payload = {
        "id": str(uuid.uuid4()),
        "sequence": index,
        "tipo": "transacao",
        "valor": round(10 + (index % 500) * 0.75, 2),
        "cliente": f"cliente-{index % 200:04d}",
        "timestamp": datetime.utcnow().isoformat(),
    }
    event = EventData(json.dumps(payload, ensure_ascii=False))
    event.properties = {"source": "demo-volume", "index": str(index)}
    return event


async def send_batch_to_partition(producer: EventHubProducerClient, start: int, end: int, partition_id: str):
    """Envia um lote de mensagens para uma partição específica."""
    sent = 0
    batch = await producer.create_batch(partition_id=partition_id)

    for i in range(start, end):
        event = create_event(i)
        try:
            batch.add(event)
        except ValueError:
            # batch cheio — envia e cria um novo
            await producer.send_batch(batch)
            sent += batch.size_in_bytes
            batch = await producer.create_batch(partition_id=partition_id)
            batch.add(event)

    if len(batch) > 0:
        await producer.send_batch(batch)
        sent += batch.size_in_bytes

    return sent


async def send_messages():
    print("=" * 60)
    print(f"  AZURE EVENT HUBS — ENVIO DE {TOTAL_MESSAGES:,} MENSAGENS")
    print("=" * 60)

    producer = EventHubProducerClient.from_connection_string(
        conn_str=CONNECTION_STRING,
        eventhub_name=EVENTHUB_NAME,
    )

    async with producer:
        # descobre quantas partições o Event Hub realmente tem
        info = await producer.get_eventhub_properties()
        partition_ids = info["partition_ids"]
        real_partitions = len(partition_ids)
        print(f"\nEvent Hub: {info['name']}")
        print(f"Partições disponíveis: {partition_ids}")

        # divide as mensagens igualmente entre as partições
        chunk_size = TOTAL_MESSAGES // real_partitions
        tasks = []

        for idx, pid in enumerate(partition_ids):
            start = idx * chunk_size
            end = start + chunk_size if idx < real_partitions - 1 else TOTAL_MESSAGES
            tasks.append(send_batch_to_partition(producer, start, end, pid))

        print(f"\nEnviando {TOTAL_MESSAGES:,} mensagens em {real_partitions} partições simultâneas...")
        start_time = time.perf_counter()

        # executa todas as partições em paralelo
        results = await asyncio.gather(*tasks)

        elapsed = time.perf_counter() - start_time
        total_bytes = sum(results)

    print(f"\n{'=' * 60}")
    print(f"  RESULTADO")
    print(f"{'=' * 60}")
    print(f"  Mensagens enviadas:  {TOTAL_MESSAGES:,}")
    print(f"  Tempo total:         {elapsed:.2f} segundos")
    print(f"  Throughput:          {TOTAL_MESSAGES / elapsed:,.0f} msgs/seg")
    print(f"  Volume total:        {total_bytes / 1024:.1f} KB")
    print(f"  Partições usadas:    {real_partitions}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    asyncio.run(send_messages())
