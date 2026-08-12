from pathlib import Path
p = Path('firebase/functions/integration/callable_integration.mjs')
text = p.read_text(encoding='utf-8')
text = text.replace('const {createDispatchCommands} = require("../dispatch_commands");\n', '', 1)
block = '''const dispatchCommands = createDispatchCommands({
  firestore: commandFirestore,
  auth: () => auth,
});
'''
if text.count(block) != 1:
    raise RuntimeError('dispatchCommands fixture block not found exactly once')
text = text.replace(block, '', 1)
p.write_text(text, encoding='utf-8')
print('Removed obsolete dispatchCommands integration fixture.')
