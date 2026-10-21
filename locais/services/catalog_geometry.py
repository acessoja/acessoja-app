"""Optional file-import geometry. Never imported by the HTTP read path."""

import hashlib
import io
import json
import math
import zipfile
from pathlib import Path


class CatalogInputError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def file_hash(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path, value):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + ".part")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2, default=str) + "\n", encoding="utf-8")
    temporary.replace(target)


def prepare_ibge(archive, municipality, output):
    import shapefile
    from pyproj import CRS, Transformer
    from shapely.geometry import shape, mapping
    from shapely.ops import transform

    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        selected = next((n[:-4] for n in names if n.lower().endswith(".shp")), None)
        if selected is None:
            raise CatalogInputError("boundary_shapefile_missing")
        try:
            prj_bytes = z.read(selected + ".prj")
            try:
                prj_text = prj_bytes.decode("utf-8-sig")
            except UnicodeDecodeError:
                # Some shapefiles use Windows-1252 in their .prj WKT.
                prj_text = prj_bytes.decode("cp1252")
            crs = CRS.from_wkt(prj_text)
            encoding = z.read(selected + ".cpg").decode("ascii").strip() if selected + ".cpg" in names else "utf-8"
            if encoding.isdigit():
                encoding = "cp" + encoding
            reader = shapefile.Reader(
                shp=io.BytesIO(z.read(selected + ".shp")),
                shx=io.BytesIO(z.read(selected + ".shx")),
                dbf=io.BytesIO(z.read(selected + ".dbf")),
                encoding=encoding,
            )
            record = next(
                (r for r in reader.iterShapeRecords() if str(r.record.as_dict().get("CD_MUN")) == str(municipality)),
                None,
            )
        except (KeyError, ValueError) as exc:
            raise CatalogInputError("boundary_source_invalid") from exc
        if record is None:
            raise CatalogInputError("municipality_not_in_boundary")
        geometry = transform(
            Transformer.from_crs(crs, "EPSG:4326", always_xy=True).transform, shape(record.shape.__geo_interface__)
        )
        valid_polygon(geometry)
        feature = {
            "type": "Feature",
            "geometry": mapping(geometry),
            "properties": {
                "municipality": str(municipality),
                "name": record.record.as_dict().get("NM_MUN", ""),
                "edition": "IBGE-2024",
                "source_crs": crs.to_string(),
                "output_crs": "EPSG:4326",
                "axis_order": "longitude,latitude",
                "source_sha256": file_hash(archive),
                "source": "IBGE GO_Municipios_2024.zip",
                "license": "IBGE public geographic data; retain attribution",
            },
        }
        write_json(output, feature)
        return feature["properties"]


def valid_polygon(geometry):
    if geometry.is_empty or not geometry.is_valid or geometry.geom_type not in ("Polygon", "MultiPolygon"):
        raise CatalogInputError("invalid_polygon")
    if not all(math.isfinite(v) for v in geometry.bounds):
        raise CatalogInputError("nonfinite_geometry")
    west, south, east, north = geometry.bounds
    if west < -180 or east > 180 or south < -90 or north > 90:
        raise CatalogInputError("invalid_coordinate_order_or_crs")


class MunicipalityBoundary:
    def __init__(self, path, municipality):
        from pyproj import CRS, Transformer
        from shapely.geometry import shape
        from shapely.ops import transform
        from shapely.prepared import prep

        document = json.loads(Path(path).read_text(encoding="utf-8-sig"))
        if document.get("type") != "Feature" or document.get("properties", {}).get("municipality") != municipality:
            raise CatalogInputError("boundary_municipality_required")
        properties = document["properties"]
        crs = CRS.from_user_input(properties.get("output_crs", "EPSG:4326"))
        geometry = shape(document["geometry"])
        if crs != CRS.from_epsg(4326):
            geometry = transform(Transformer.from_crs(crs, 4326, always_xy=True).transform, geometry)
        valid_polygon(geometry)
        self.geometry, self.prepared = geometry, prep(geometry)
        self.hash = hashlib.sha256(geometry.wkb + municipality.encode()).hexdigest()
        self.manifest = {
            **properties,
            "file_sha256": file_hash(path),
            "geometry_sha256": self.hash,
            "normalized_crs": "EPSG:4326",
            "bbox_west_south_east_north": list(geometry.bounds),
            "inclusion": "covers representative point; do not move it into the municipality",
        }

    def point(self, geometry):
        if geometry.is_empty or not geometry.is_valid:
            raise CatalogInputError("invalid_geometry")
        if geometry.geom_type == "Point":
            point, method = geometry, "original_node"
        elif geometry.geom_type in ("Polygon", "MultiPolygon"):
            point, method = geometry.representative_point(), "point_on_surface"
        else:
            raise CatalogInputError("unsupported_geometry")
        if not (math.isfinite(point.x) and math.isfinite(point.y) and abs(point.x) <= 180 and abs(point.y) <= 90):
            raise CatalogInputError("invalid_point")
        if not self.prepared.covers(point):
            raise CatalogInputError("outside_municipality")
        crossing = geometry.geom_type != "Point" and not self.prepared.covers(geometry)
        return point.y, point.x, method, crossing, self.geometry.touches(point)

    def coverage(self, path):
        from shapely.geometry import shape, Polygon
        from shapely.ops import unary_union

        p = Path(path)
        if p.suffix.lower() in (".json", ".geojson"):
            doc = json.loads(p.read_text(encoding="utf-8-sig"))
            geometry = shape(doc.get("geometry", doc))
        else:
            lines = iter(p.read_text(encoding="utf-8-sig").splitlines())
            next(lines, None)
            shells, holes = [], []
            for title in lines:
                title = title.strip()
                if title == "END":
                    break
                if not title:
                    continue
                coordinates = []
                for line in lines:
                    if line.strip() == "END":
                        break
                    coordinates.append(tuple(map(float, line.split())))
                (holes if title.startswith("!") else shells).append(Polygon(coordinates))
            geometry = unary_union(shells)
            if holes:
                geometry = geometry.difference(unary_union(holes))
        valid_polygon(geometry)
        if not geometry.covers(self.geometry):
            raise CatalogInputError("source_does_not_cover_municipality")
        return {
            "sha256": file_hash(path),
            "covers_municipality": True,
            "format": p.suffix,
            "bbox_west_south_east_north": list(geometry.bounds),
        }
