"""Two-pass PBF reader. SQLite stages candidates on disk; the node index is platform-dependent."""

import json
import sqlite3
import sys
import time
from collections import Counter
from pathlib import Path

from .catalog_geometry import CatalogInputError
from .catalog_rules import eligibility, source_values


def peak_rss():
    try:
        import resource
        import sys

        value = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        return int(value if sys.platform == "darwin" else value * 1024)
    except ImportError:
        import psutil

        memory = psutil.Process().memory_info()
        return int(getattr(memory, "peak_wset", memory.rss))


def location_index(directory, platform=None):
    """Avoid file-backed node indexes locked by libosmium on Windows."""
    platform = sys.platform if platform is None else platform
    if platform == "win32":
        # On Windows, a file-backed libosmium index can remain open until process exit.
        # Memory is proportional to the number of source nodes; measure peak RSS.
        return "sparse_mem_array"
    return f"sparse_file_array,{Path(directory) / 'locations.idx'}"


class PBFStage:
    def __init__(self, directory, boundary, heartbeat=None):
        self.directory, self.boundary, self.heartbeat = Path(directory), boundary, heartbeat
        self.db = sqlite3.connect(self.directory / "staging.sqlite3")
        self.db.execute(
            "CREATE TABLE accepted (identity TEXT PRIMARY KEY, payload TEXT NOT NULL, "
            "match_key TEXT, lat REAL, lon REAL)"
        )
        self.db.execute("CREATE INDEX accepted_match ON accepted(match_key, lat)")
        self.db.execute("CREATE TABLE pending (identity TEXT PRIMARY KEY, metadata TEXT NOT NULL)")
        self.db.execute("CREATE TABLE rejected_known (identity TEXT PRIMARY KEY)")
        self.db.execute("CREATE TABLE ambiguous_source (identity TEXT PRIMARY KEY)")
        self.db.execute("CREATE TABLE proposed_links (identity TEXT PRIMARY KEY, local_id INTEGER, method TEXT)")
        self.stats = {
            key: Counter()
            for key in ("examined", "eligible", "rejected", "categories", "accepted_types", "geometry_types")
        }
        self.stats.update(accepted=0, without_name=0, without_address=0, crosses_boundary=0, on_boundary=0)
        self.stats["rejection_samples"] = {}
        self.last_tick = time.monotonic()
        self.peak_rss = 0

    def tick(self):
        if time.monotonic() - self.last_tick >= 20:
            if self.heartbeat:
                self.heartbeat()
            self.peak_rss = max(self.peak_rss, peak_rss())
            self.db.commit()
            self.last_tick = time.monotonic()

    def reject(self, reason, identity=None):
        self.stats["rejected"][reason] += 1
        sample = self.stats["rejection_samples"].setdefault(reason, [])
        if identity and len(sample) < 10:
            sample.append(identity)
        if identity and reason in ("inactive", "restricted_access"):
            self.db.execute("INSERT OR IGNORE INTO rejected_known VALUES (?)", (identity,))

    @staticmethod
    def metadata(obj):
        version = int(obj.version) if obj.version else None
        stamp = obj.timestamp if version and obj.timestamp.year > 1970 else None
        return {"osm_version": version, "osm_timestamp": stamp.isoformat() if stamp else None}

    def accept(self, identity, tags, geometry, metadata):
        try:
            lat, lon, method, crossing, border = self.boundary.point(geometry)
        except CatalogInputError as exc:
            self.reject(exc.code, identity)
            return
        values = source_values(
            tags,
            latitude=lat,
            longitude=lon,
            geometry_type=geometry.geom_type,
            point_method=method,
            crosses_boundary=crossing,
            **metadata,
        )
        payload = json.dumps(values, default=str, ensure_ascii=False)
        try:
            from .matching import normalize

            key = json.dumps([normalize(values["original_name"]), normalize(values["address"]), values["category"]])
            self.db.execute(
                "INSERT INTO accepted VALUES (?,?,?,?,?)",
                (identity, payload, key if values["original_name"] and values["address"] else None, lat, lon),
            )
        except sqlite3.IntegrityError:
            self.reject("duplicate_source_identity")
            return
        self.stats["accepted"] += 1
        self.stats["categories"][values["category"]] += 1
        self.stats["accepted_types"][identity.split(":")[1]] += 1
        self.stats["geometry_types"][geometry.geom_type] += 1
        self.stats["without_name"] += not bool(values["original_name"])
        self.stats["without_address"] += not bool(values["address"])
        self.stats["crosses_boundary"] += crossing
        self.stats["on_boundary"] += border

    def read(self, path):
        import osmium
        from shapely.geometry import Point
        from shapely import wkb

        stage = self
        factory = osmium.geom.WKBFactory()

        class RelationSeed(osmium.SimpleHandler):
            # Area callbacks can precede the relation callback in the assembly pass.
            def relation(self, obj):
                stage.tick()
                if obj.tags.get("type") == "multipolygon" and eligibility(dict(obj.tags)) is None:
                    if len(obj.members) <= 100000:
                        stage.db.execute(
                            "INSERT OR REPLACE INTO pending VALUES (?,?)",
                            (f"osm:relation:{obj.id}", json.dumps(stage.metadata(obj))),
                        )

        class Handler(osmium.SimpleHandler):
            def tags(self, obj, kind):
                stage.stats["examined"][kind] += 1
                if stage.stats["examined"][kind] % 100000 == 0:
                    stage.tick()
                if len(obj.tags) == 0:
                    return None
                tags = {t.k: t.v for t in obj.tags}
                reason = eligibility(tags)
                identity = f"osm:{kind}:{obj.id}"
                if reason:
                    stage.reject(reason, identity)
                    return None
                stage.stats["eligible"][kind] += 1
                if not 0 < obj.id <= 9223372036854775807:
                    stage.reject("invalid_identity")
                    return None
                return tags

            def node(self, obj):
                tags = self.tags(obj, "node")
                if tags is None:
                    return
                if not obj.location.valid():
                    stage.reject("incomplete_geometry")
                    return
                stage.accept(f"osm:node:{obj.id}", tags, Point(obj.location.lon, obj.location.lat), stage.metadata(obj))

            def way(self, obj):
                tags = self.tags(obj, "way")
                if tags is None:
                    return
                if len(obj.nodes) < 4 or obj.nodes[0].ref != obj.nodes[-1].ref or tags.get("area") == "no":
                    stage.reject("unsupported_open_way")
                    return
                if len(obj.nodes) > 100000:
                    stage.reject("geometry_vertex_limit")
                    return
                if not all(n.location.valid() for n in obj.nodes):
                    stage.reject("incomplete_geometry")
                    return
                west, south, east, north = stage.boundary.geometry.bounds
                xs = [n.location.lon for n in obj.nodes]
                ys = [n.location.lat for n in obj.nodes]
                if max(xs) < west or min(xs) > east or max(ys) < south or min(ys) > north:
                    stage.reject("outside_municipality_bbox")
                    return
                stage.db.execute(
                    "INSERT OR REPLACE INTO pending VALUES (?,?)",
                    (f"osm:way:{obj.id}", json.dumps(stage.metadata(obj))),
                )

            def relation(self, obj):
                tags = self.tags(obj, "relation")
                if tags is None:
                    return
                if tags.get("type") != "multipolygon":
                    stage.reject("unsupported_relation", f"osm:relation:{obj.id}")
                    return
                if len(obj.members) > 100000:
                    stage.reject("geometry_vertex_limit", f"osm:relation:{obj.id}")

            def area(self, obj):
                kind = "way" if obj.from_way() else "relation"
                identity = f"osm:{kind}:{obj.orig_id()}"
                row = stage.db.execute("SELECT metadata FROM pending WHERE identity=?", (identity,)).fetchone()
                if row is None:
                    return
                stage.db.execute("DELETE FROM pending WHERE identity=?", (identity,))
                try:
                    geometry = wkb.loads(factory.create_multipolygon(obj), hex=True)
                    stage.accept(identity, {t.k: t.v for t in obj.tags}, geometry, json.loads(row[0]))
                except (ValueError, RuntimeError):
                    stage.reject("invalid_geometry", identity)

        RelationSeed().apply_file(str(path))
        # Windows uses an in-memory index so TemporaryDirectory can be removed.
        # Other platforms retain the disk-backed index to limit peak memory.
        handler = Handler()
        try:
            handler.apply_file(str(path), locations=True, idx=location_index(self.directory))
        finally:
            del handler
            import gc

            gc.collect()
        missing = self.db.execute("SELECT COUNT(*) FROM pending").fetchone()[0]
        self.stats["rejected"]["incomplete_geometry"] += missing
        self.stats["rejection_samples"]["incomplete_geometry"] = [
            r[0] for r in self.db.execute("SELECT identity FROM pending ORDER BY identity LIMIT 10")
        ]
        self.duplicates()
        self.db.commit()
        self.peak_rss = max(self.peak_rss, peak_rss())
        self.stats["peak_rss_bytes"] = self.peak_rss
        self.stats["temporary_bytes"] = sum(p.stat().st_size for p in self.directory.iterdir() if p.is_file())
        self.stats["auxiliary_objects"] = sum(self.stats["examined"].values()) - sum(self.stats["eligible"].values())
        self.stats["complete_geometry"] = not any(
            self.stats["rejected"][key] for key in ("incomplete_geometry", "invalid_geometry", "invalid_point")
        )
        return self.stats

    def duplicates(self):
        import math
        from .matching import distance_m

        pairs, sample = 0, []
        for left, right, lat, lon, lat2, lon2 in self.db.execute(
            "SELECT a.identity,b.identity,a.lat,a.lon,b.lat,b.lon FROM accepted a JOIN accepted b "
            "ON b.match_key=a.match_key AND b.lat BETWEEN a.lat-0.0003 AND a.lat+0.0003 "
            "AND a.identity<b.identity WHERE a.match_key IS NOT NULL"
        ):
            if abs(lon2 - lon) * max(0.00001, math.cos(math.radians(lat))) > 0.0003:
                continue
            if distance_m(lat, lon, lat2, lon2) <= 25:
                pairs += 1
                self.db.executemany("INSERT OR IGNORE INTO ambiguous_source VALUES (?)", [(left,), (right,)])
                if len(sample) < 20:
                    sample.append([left, right])
        self.stats["candidate_duplicate_pairs"] = pairs
        self.stats["duplicate_sample"] = sample

    def chunks(self, size):
        cursor = self.db.execute("SELECT identity,payload FROM accepted ORDER BY identity")
        while rows := cursor.fetchmany(size):
            yield [(identity, json.loads(payload)) for identity, payload in rows]

    def close(self):
        self.db.close()
