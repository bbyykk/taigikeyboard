"""Small, configurable online-dictionary client for the Linux IBus prototype.

The client deliberately owns a separate result list. It never changes the
Rust engine's local candidate ordering or writes remote results into the local
dictionary.
"""

import html
import json
import os
import re
import tempfile
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DEFAULT_CONFIG = {
    "sources": [
        {
            "id": "taijittoasutian",
            "name": "台日大辭典台語譯本",
            "type": "kemdict_html",
            "search_url": "https://kemdict.com/search",
            "dictionary_id": "chhoetaigi_taijittoasutian",
            "mode": "prefix",
            "enabled": True,
        }
    ]
}
MAX_RESULTS = 8
MAX_RESPONSE_BYTES = 512 * 1024
USER_AGENT = "Taigi-Keyboard-online-dictionary/0.1"


def default_config_path():
    config_home = os.environ.get("XDG_CONFIG_HOME")
    if config_home:
        return Path(config_home) / "taigi-keyboard" / "online-dictionaries.json"
    return Path.home() / ".config" / "taigi-keyboard" / "online-dictionaries.json"


def default_cache_path():
    cache_home = os.environ.get("XDG_CACHE_HOME")
    if cache_home:
        return Path(cache_home) / "taigi-keyboard" / "online-dictionary.json"
    return Path.home() / ".cache" / "taigi-keyboard" / "online-dictionary.json"


def load_sources(path=None):
    """Load source definitions, falling back to the built-in 台日 source."""
    path = Path(path or default_config_path())
    if not path.is_file():
        return list(DEFAULT_CONFIG["sources"])
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        sources = data.get("sources", [])
        return [source for source in sources if source.get("enabled", True)]
    except (OSError, ValueError, TypeError):
        return list(DEFAULT_CONFIG["sources"])


class _KemdictParser(HTMLParser):
    """Extract result word, reading, and source link from Kemdict HTML."""

    def __init__(self, dictionary_id):
        super().__init__(convert_charrefs=True)
        self.dictionary_id = dictionary_id
        self.entry = None
        self.in_heading = False
        self.heading = []
        self.entries = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and attrs.get("href", "").endswith("#" + self.dictionary_id):
            self.entry = {"href": attrs["href"]}
            self.heading = []
        elif self.entry is not None and tag == "h2":
            self.in_heading = True

    def handle_endtag(self, tag):
        if tag == "h2":
            self.in_heading = False
        elif tag == "a" and self.entry is not None:
            heading = "".join(self.heading).strip()
            match = re.match(r"(.+?)（(.+?)）$", heading)
            if match:
                word, reading = match.groups()
            else:
                word, reading = heading, ""
            if word:
                self.entries.append(
                    {
                        "display": "{}  {}".format(word, reading).strip(),
                        "commit": html.unescape(word),
                        "url": "https://kemdict.com" + self.entry["href"],
                    }
                )
            self.entry = None
            self.heading = []

    def handle_data(self, data):
        if self.entry is not None and self.in_heading:
            self.heading.append(data)


class OnlineDictionary:
    """Configurable source dispatch with a small persistent cache."""

    def __init__(self, config_path=None, cache_path=None, opener=urlopen):
        self.sources = load_sources(config_path)
        self.cache_path = Path(cache_path or default_cache_path())
        self.opener = opener
        self.cache = self._read_cache()

    def _read_cache(self):
        try:
            value = json.loads(self.cache_path.read_text(encoding="utf-8"))
            return value if isinstance(value, dict) else {}
        except (OSError, ValueError, TypeError):
            return {}

    def _write_cache(self):
        try:
            self.cache_path.parent.mkdir(parents=True, exist_ok=True)
            handle, name = tempfile.mkstemp(
                prefix="online-dictionary-", dir=str(self.cache_path.parent)
            )
            with os.fdopen(handle, "w", encoding="utf-8") as stream:
                json.dump(self.cache, stream, ensure_ascii=False)
            os.replace(name, self.cache_path)
        except OSError:
            # A read-only cache must not make the keyboard unusable.
            pass

    def lookup(self, query):
        query = query.strip()
        if not query:
            return []
        results = []
        for source in self.sources:
            if source.get("type") != "kemdict_html":
                continue
            key = "{}\n{}\n{}".format(source.get("id"), source.get("mode", "prefix"), query)
            if key in self.cache:
                entries = self.cache[key]
            else:
                try:
                    entries = self._lookup_kemdict(source, query)
                except (OSError, ValueError, UnicodeError):
                    entries = []
                self.cache[key] = entries
                self._write_cache()
            results.extend(entries)
        unique = []
        seen = set()
        for entry in results:
            if entry["display"] not in seen:
                unique.append(entry)
                seen.add(entry["display"])
        return unique[:MAX_RESULTS]

    def _lookup_kemdict(self, source, query):
        params = urlencode(
            {
                "q": query,
                "m": source.get("mode", "prefix"),
            }
        )
        request = Request(
            source["search_url"] + "?" + params,
            headers={"User-Agent": USER_AGENT},
        )
        with self.opener(request, timeout=4) as response:
            body = response.read(MAX_RESPONSE_BYTES + 1)
        if len(body) > MAX_RESPONSE_BYTES:
            raise ValueError("online dictionary response is too large")
        parser = _KemdictParser(source["dictionary_id"])
        parser.feed(body.decode("utf-8", errors="replace"))
        return parser.entries
