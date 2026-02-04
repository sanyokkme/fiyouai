import re
import pytz
from datetime import datetime
from typing import Any

POLAND_TZ = pytz.timezone('Europe/Warsaw')

def get_now_poland() -> datetime:
    return datetime.now(POLAND_TZ)

def safe_parse_datetime(dt_str: str) -> datetime:
    try:
        base_part = dt_str.split('.')[0].split('+')[0].split('Z')[0]
        dt_utc = datetime.strptime(base_part, "%Y-%m-%dT%H:%M:%S").replace(tzinfo=pytz.UTC)
        return dt_utc.astimezone(POLAND_TZ)
    except Exception:
        return get_now_poland()

def clean_to_int(val) -> int:
    try:
        if isinstance(val, (int, float)): return int(val)
        return int(float(re.sub(r'[^0-9.]', '', str(val)) or 0))
    except: return 0

def clean_to_float(val) -> float:
    try:
        if val is None or str(val).lower() == 'невідомо': return 0.0
        cleaned = re.sub(r'[^0-9.]', '', str(val))
        return float(cleaned) if cleaned else 0.0
    except: return 0.0

def is_invalid_user(user_id: Any) -> bool:
    if not user_id: return True
    s_id = str(user_id).lower().strip()
    return s_id in ["null", "undefined", "none", ""]