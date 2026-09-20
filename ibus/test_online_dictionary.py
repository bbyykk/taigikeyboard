import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from online_dictionary import OnlineDictionary, _KemdictParser, load_sources


RESULT_HTML = """
<a href="/word/台語#chhoetaigi_taijittoasutian">
  <h2>台語（Tâi-gí）</h2>
</a>
<a href="/word/台語羅馬字#other_dictionary">
  <h2>台語羅馬字（Tâi-gí）</h2>
</a>
"""


class OnlineDictionaryTest(unittest.TestCase):
    def test_parser_keeps_only_the_configured_dictionary(self):
        parser = _KemdictParser("chhoetaigi_taijittoasutian")
        parser.feed(RESULT_HTML)
        self.assertEqual(parser.entries[0]["display"], "台語  Tâi-gí")
        self.assertEqual(parser.entries[0]["commit"], "台語")

    def test_lookup_uses_cache_after_first_request(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            config = directory / "sources.json"
            config.write_text(
                json.dumps({"sources": [
                    {
                        "id": "taijittoasutian",
                        "type": "kemdict_html",
                        "search_url": "https://kemdict.test/search",
                        "dictionary_id": "chhoetaigi_taijittoasutian",
                        "mode": "prefix",
                    }
                ]}),
                encoding="utf-8",
            )
            response = mock.MagicMock()
            response.read.return_value = RESULT_HTML.encode()
            response.__enter__.return_value = response
            opener = mock.Mock(return_value=response)
            client = OnlineDictionary(config, directory / "cache.json", opener)

            self.assertEqual(client.lookup("台語")[0]["commit"], "台語")
            self.assertEqual(client.lookup("台語")[0]["commit"], "台語")
            opener.assert_called_once()

    def test_invalid_config_falls_back_to_builtin_source(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            path.write_text("not json", encoding="utf-8")
            self.assertEqual(load_sources(path)[0]["id"], "taijittoasutian")


if __name__ == "__main__":
    unittest.main()
