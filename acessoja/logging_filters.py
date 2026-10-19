"""Do not put transient proximity origins into development HTTP access logs."""
import logging
import re


class RedactCoordinates(logging.Filter):
    def filter(self, record):
        record.msg = re.sub(r'((?:origin_lat|origin_lon|latitude|longitude)=)[^&\s"\\]+',
                            r'\1[redacted]', record.getMessage(), flags=re.IGNORECASE)
        record.args = ()
        return True
