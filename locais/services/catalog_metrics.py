"""Measure catalog tables/indexes when supported, without attributing unrelated pages."""

import statistics
import time

from django.db import DatabaseError, connection

from locais.catalog_models import CatalogBatch, CatalogEntry, CatalogPOI, CatalogScope
from locais.discovery import DiscoveryOptions
from locais.accessibility import parse_filters
from .catalog_query import catalog_queryset


def measure_catalog():
    tables = [model._meta.db_table for model in (CatalogScope, CatalogBatch, CatalogPOI, CatalogEntry)]
    result = {"database": connection.vendor, "tables": {}, "measurement": "table_and_index_allocated_bytes"}
    with connection.cursor() as cursor:
        if connection.vendor == "sqlite":
            cursor.execute("PRAGMA page_count")
            pages = cursor.fetchone()[0]
            cursor.execute("PRAGMA page_size")
            size = cursor.fetchone()[0]
            cursor.execute("PRAGMA freelist_count")
            result.update(database_bytes=pages * size, free_bytes=cursor.fetchone()[0] * size)
            for table in tables:
                cursor.execute(
                    "SELECT name FROM sqlite_master WHERE tbl_name=%s AND type IN ('table','index')", [table]
                )
                names = [r[0] for r in cursor.fetchall()]
                try:
                    cursor.execute(
                        "SELECT name,SUM(pgsize) FROM dbstat WHERE name IN ("
                        + ",".join(["%s"] * len(names))
                        + ") GROUP BY name",
                        names,
                    )
                    parts = dict(cursor.fetchall())
                except DatabaseError as exc:
                    # dbstat is an optional SQLite extension, absent on some Windows builds.
                    # Never invent catalog table/index byte counts from total database size.
                    if "dbstat" not in str(exc).lower():
                        raise
                    result.update(
                        measurement="dbstat_unavailable",
                        measurement_note="SQLite build does not expose dbstat; per-table bytes cannot be measured.",
                        tables={},
                    )
                    break
                result["tables"][table] = {
                    "table_bytes": parts.get(table, 0),
                    "index_bytes": sum(v for k, v in parts.items() if k != table),
                }
        elif connection.vendor == "postgresql":
            cursor.execute("SELECT pg_database_size(current_database())")
            result["database_bytes"] = cursor.fetchone()[0]
            for table in tables:
                cursor.execute("SELECT pg_table_size(%s),pg_indexes_size(%s)", [table, table])
                table_bytes, index_bytes = cursor.fetchone()
                result["tables"][table] = {"table_bytes": table_bytes, "index_bytes": index_bytes}
        else:
            raise ValueError("unsupported_database_measurement")
    if result["measurement"] == "table_and_index_allocated_bytes":
        result["catalog_bytes"] = sum(sum(parts.values()) for parts in result["tables"].values())
        result["unattributed_bytes"] = (
            result["database_bytes"] - result.get("free_bytes", 0) - result["catalog_bytes"]
        )
    count = CatalogPOI.objects.count()
    result["poi_count"], result["edition_count"] = count, CatalogBatch.objects.count()
    result["estimates"] = {
        "assumptions": "same schema/tag sizes/density; 40% margin; not inventory",
        "margin": 1.4,
        "sample_pois": count,
        "records": [],
    }
    if count and result["measurement"] == "table_and_index_allocated_bytes":
        fixed = sum(result["tables"][t][k] for t in tables[:2] for k in ("table_bytes", "index_bytes"))
        identities = sum(result["tables"][tables[2]].values())
        entries = sum(result["tables"][tables[3]].values())
        for n in (10000, 30000, 50000):
            result["estimates"]["records"].append(
                {
                    "pois": n,
                    "one_edition_bytes": round((fixed + (identities + entries) * n / count) * 1.4),
                    "two_editions_bytes": round((fixed * 2 + (identities + 2 * entries) * n / count) * 1.4),
                }
            )
    if result["measurement"] == "dbstat_unavailable":
        result["estimates"]["unavailable_reason"] = "table_and_index_bytes_not_measured"
    scope = CatalogScope.objects.filter(active_batch__isnull=False).first()
    timings = []
    if scope:
        rows = catalog_queryset(scope.active_batch_id, DiscoveryOptions({"paginated": "true"}), parse_filters({}))
        for _ in range(5):
            start = time.perf_counter()
            count = rows.count()
            ids = list(rows.values_list("poi_id", flat=True)[:20])
            timings.append((time.perf_counter() - start) * 1000)
        result["query"] = {
            "scope": "SQL count and 20 IDs, not full HTTP/rendering",
            "count": count,
            "page_items": len(ids),
            "median_ms": round(statistics.median(timings), 3),
            "samples_ms": timings,
            "plan": rows.explain(),
        }
    return result
