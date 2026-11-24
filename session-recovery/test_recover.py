import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from recover import recover


def row(role, body):
    return json.dumps({'type': 'response_item', 'payload': {
        'type': 'message', 'role': role, 'content': [
            {'type': 'input_text' if role == 'user' else 'output_text',
             'text': body}, {'type': 'input_image', 'image_url': 'ignored'}]}},
        ensure_ascii=False).encode('utf-8')


class RecoveryTests(unittest.TestCase):
    def test_mixed_records_and_source_integrity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = root / 'sample.jsonl'
            src.write_bytes(b'\n'.join([row('user', 'Za\xc5\xbc\xc3\xb3\xc5\x82\xc4\x87'.encode('latin1').decode('utf8')),
                                       b'x' * 200_000, b'{broken', b'\xff',
                                       row('tool', 'private tool output'),
                                       row('assistant', 'Recovered')]))
            before = hashlib.sha256(src.read_bytes()).digest()
            dest = root / 'out'
            stats = recover(src, dest, 1024)
            self.assertEqual(stats, dict(records=6, oversized=1, malformed=2,
                                         ignored=1, user=1, assistant=1))
            transcript = (dest / 'transcript.txt').read_text(encoding='utf-8')
            self.assertIn('Recovered', transcript)
            self.assertIn('Za\u017c\u00f3\u0142\u0107', transcript)
            self.assertNotIn('private tool output', transcript)
            self.assertNotIn('ignored', transcript)
            self.assertEqual(before, hashlib.sha256(src.read_bytes()).digest())
            self.assertEqual(stats, json.loads((dest / 'report.json').read_text()))
            with self.assertRaises(FileExistsError):
                recover(src, dest, 1024)

    def test_oversized_final_record(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = root / 'sample.jsonl'
            src.write_bytes(b'x' * 80000)
            stats = recover(src, root / 'out', 100)
            self.assertEqual((stats['records'], stats['oversized']), (1, 1))

    def test_reject_compressed_and_invalid_limit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = root / 'sample.jsonl.zst'
            src.touch()
            with self.assertRaises(ValueError):
                recover(src, root / 'out')
            src = root / 'sample.jsonl'
            src.touch()
            with self.assertRaises(ValueError):
                recover(src, root / 'out', 0)
            self.assertFalse((root / 'out').exists())


if __name__ == '__main__':
    unittest.main()
