def parse_progress_line(line: str) -> dict | None:
    parts = line.strip().split(":")
    if len(parts) != 4 or parts[0] != "download":
        return None
    try:
        percent = float(parts[1].strip().removesuffix("%"))
        transferred, total = int(parts[2]), int(parts[3])
    except ValueError:
        return None
    return {"state": "downloading", "percent": max(0.0, min(100.0, percent)), "transferredBytes": transferred, "totalBytes": total}
