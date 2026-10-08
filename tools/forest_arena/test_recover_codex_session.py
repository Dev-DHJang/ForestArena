import base64
from contextlib import contextmanager
import importlib.util
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('recovery', Path(__file__).with_name('recover_codex_session.py'))
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
SID = '01a0a530-8f01-7f61-a947-9719bb0397f4'
OTHER = '01a0a06b-a99c-7453-80ee-c1023babde9b'


@contextmanager
def db(path):
    conn = sqlite3.connect(path)
    try:
        with conn:
            yield conn
    finally:
        conn.close()


class RecoveryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.db = self.home / 'thread_history_1.sqlite'
        with db(self.db) as c:
            c.executescript('''CREATE TABLE thread_items(thread_id TEXT,item_id TEXT,item_type TEXT,item_json TEXT,PRIMARY KEY(thread_id,item_id));
                CREATE TABLE thread_turns(thread_id TEXT,turn_id TEXT,status TEXT);
                CREATE TABLE thread_history_projection_state(thread_id TEXT,next_rollout_ordinal INT);''')
        self.rollout = self.home / 'sessions' / f'rollout-{SID}.jsonl'
        self.rollout.parent.mkdir()
        self.rollout.write_text('original full history\n')
        with db(self.home / 'goals_1.sqlite') as c:
            c.execute('CREATE TABLE thread_goals(thread_id TEXT,objective TEXT,status TEXT)')
            c.execute('INSERT INTO thread_goals VALUES(?,?,?)', (SID, 'preserve objective', 'usage_limited'))

    def add(self, item, sid=SID):
        raw = json.dumps(item)
        with db(self.db) as c:
            c.execute('INSERT INTO thread_items VALUES(?,?,?,?)', (sid,item['id'],item['type'],raw))
        return raw

    def get(self, item, sid=SID):
        with db(self.db) as c:
            return c.execute('SELECT item_json FROM thread_items WHERE thread_id=? AND item_id=?',(sid,item)).fetchone()[0]

    def tool(self, ident='tool', status='completed'):
        return {'type':'mcpToolCall','id':ident,'status':status,'arguments':{'code':'x'*20000},
                'result':{'content':[{'type':'image','data':'a'*15000,'mimeType':'image/png'}],
                          '_meta':{'screenshot':{'url':'data:image/png;base64,'+'a'*20000}}}}

    def test_preserves_dialogue_goal_rollout_other_thread_and_pending(self):
        original = self.add(self.tool())
        pending = self.add(self.tool('pending','inProgress'))
        user = self.add({'type':'userMessage','id':'user','text':'x'*25000})
        other = self.add(self.tool(),OTHER)
        goal_hash = r.file_digest(self.home/'goals_1.sqlite')
        result = r.repair(self.home,SID)
        self.assertEqual(result['changed_items'],1)
        self.assertLess(result['display_after'],result['display_before'])
        self.assertEqual(self.get('pending'),pending)
        self.assertEqual(self.get('user'),user)
        self.assertEqual(self.get('tool',OTHER),other)
        self.assertEqual(r.file_digest(self.home/'goals_1.sqlite'),goal_hash)
        self.assertEqual(self.rollout.read_text(),'original full history\n')
        self.assertEqual(json.loads(self.get('tool'))['result']['content'][0]['type'],'text')
        r.restore(self.home,SID,Path(result['backup']))
        self.assertEqual(self.get('tool'),original)

    def test_second_repair_noop(self):
        self.add(self.tool())
        r.repair(self.home,SID)
        second=r.repair(self.home,SID)
        self.assertEqual(second['changed_items'],0)
        self.assertIsNone(second['backup'])

    def test_restore_refuses_newer_cache_without_partial_update(self):
        self.add(self.tool('a'));self.add(self.tool('b'))
        result=r.repair(self.home,SID);saved=self.get('a')
        with db(self.db) as c:
            c.execute('UPDATE thread_items SET item_json=? WHERE item_id=?',('newer','b'))
        with self.assertRaises(ValueError):r.restore(self.home,SID,Path(result['backup']))
        self.assertEqual(self.get('a'),saved)
        self.assertEqual(self.get('b'),'newer')

    def test_missing_rollout_aborts_without_cache_write(self):
        original=self.add(self.tool());self.rollout.unlink()
        with self.assertRaises(ValueError):r.repair(self.home,SID)
        self.assertEqual(self.get('tool'),original)

    def test_unknown_schema_and_missing_db_not_created(self):
        missing=self.home/'missing';missing.mkdir()
        with self.assertRaises(ValueError):r.inspect(missing,SID)
        self.assertFalse((missing/'thread_history_1.sqlite').exists())
        with db(self.db) as c:c.execute('DROP TABLE thread_items')
        with self.assertRaises(ValueError):r.inspect(self.home,SID)

    def test_png_thumbnail_alpha_and_original_preserved(self):
        from PIL import Image
        image=Image.effect_noise((512,512),80).convert('RGBA')
        image.putpixel((0,0),(0,0,0,0))
        original=io.BytesIO();image.save(original,format='PNG')
        asset=self.home/'original.png';asset.write_bytes(original.getvalue())
        self.add({'id':'image','type':'imageGeneration','status':'completed','savedPath':str(asset),
                  'result':base64.b64encode(original.getvalue()).decode()})
        result=r.repair(self.home,SID)
        self.assertEqual(result['image_previews'],1)
        self.assertEqual(asset.read_bytes(),original.getvalue())
        preview=Image.open(io.BytesIO(base64.b64decode(json.loads(self.get('image'))['result'])))
        self.assertEqual(preview.size,(192,192));self.assertEqual(preview.mode,'RGBA')
        self.assertEqual(r.repair(self.home,SID)['changed_items'],0)


if __name__ == '__main__':
    unittest.main()
